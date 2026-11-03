import { LicenseService } from '../services/licenseService.js';
import { CloudOrderSyncService } from '../services/cloudOrderSyncService.js';
import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { inMemoryStore, MenuItemRecord } from '../db/inMemoryStore.js';
import { NotFoundError } from '../utils/errors.js';
import { authenticateDevice, requireRole } from '../middleware/auth.js';
import { validateBody } from '../middleware/validate.js';

export const menuRouter = Router();

menuRouter.use(authenticateDevice);

// GET /api/menu - Hierarchical menu with categories, items, variants, and addons
menuRouter.get('/', (req: Request, res: Response) => {
  const categories = Array.from(inMemoryStore.categories.values())
    .filter((c) => c.isActive)
    .sort((a, b) => a.sortOrder - b.sortOrder);

  const items = Array.from(inMemoryStore.menuItems.values());

  const menu = categories.map((cat) => ({
    ...cat,
    items: items
      .filter((item) => item.categoryId === cat.id)
      .sort((a, b) => a.sortOrder - b.sortOrder),
  }));

  res.json({
    success: true,
    data: {
      menu,
    },
  });
});

// GET /api/menu/items - Flat item listing with search & availability filter
menuRouter.get('/items', (req: Request, res: Response) => {
  const { categoryId, search, availableOnly } = req.query;

  let items = Array.from(inMemoryStore.menuItems.values());

  if (categoryId) {
    items = items.filter((i) => i.categoryId === categoryId);
  }

  if (availableOnly === 'true') {
    items = items.filter((i) => i.isAvailable);
  }

  if (search && typeof search === 'string') {
    const q = search.toLowerCase();
    items = items.filter(
      (i) =>
        i.name.toLowerCase().includes(q) ||
        (i.shortCode && i.shortCode.toLowerCase().includes(q))
    );
  }

  const enrichedItems = items.map((i) => {
    const cat = inMemoryStore.categories.get(i.categoryId);
    return {
      ...i,
      category: cat ? cat.name : i.categoryId,
      categoryName: cat ? cat.name : i.categoryId,
    };
  });

  res.json({
    success: true,
    data: {
      items: enrichedItems.sort((a, b) => a.sortOrder - b.sortOrder),
    },
  });
});

// GET /api/menu/categories - List all active menu categories
menuRouter.get('/categories', (req: Request, res: Response) => {
  const categories = Array.from(inMemoryStore.categories.values())
    .filter((c) => c.isActive)
    .sort((a, b) => a.sortOrder - b.sortOrder);
  res.json({
    success: true,
    data: { categories },
  });
});

const createCategorySchema = z.object({
  name: z.string().min(1),
  sortOrder: z.number().optional(),
});

// POST /api/menu/categories - Create custom category
menuRouter.post(
  '/categories',
  requireRole('counter', 'admin'),
  validateBody(createCategorySchema),
  (req: Request, res: Response, next: NextFunction) => {
    try {
      const { name, sortOrder } = req.body;
      const trimmed = name.trim();
      const existing = Array.from(inMemoryStore.categories.values()).find(
        (c) => c.name.toLowerCase() === trimmed.toLowerCase()
      );
      if (existing) {
        return res.json({ success: true, data: { category: existing } });
      }

      const catId = `cat_${Date.now()}_${trimmed.toLowerCase().replace(/[^a-z0-9]/g, '_')}`;
      const newCategory = {
        id: catId,
        name: trimmed,
        sortOrder: sortOrder ?? inMemoryStore.categories.size + 1,
        isActive: true,
      };
      inMemoryStore.categories.set(catId, newCategory);
      inMemoryStore.saveToDisk();

      res.status(201).json({
        success: true,
        data: { category: newCategory },
      });
    } catch (err) {
      next(err);
    }
  }
);

const toggleAvailabilitySchema = z.object({
  isAvailable: z.boolean().optional(),
  isDeliveryAvailable: z.boolean().optional(),
});

// PATCH /api/menu/items/:id/availability - Toggle item 86/available state (Counter / Admin)
menuRouter.patch(
  '/items/:id/availability',
  requireRole('counter', 'admin'),
  validateBody(toggleAvailabilitySchema),
  (req: Request, res: Response, next: NextFunction) => {
    try {
      const id = req.params.id as string;
      const item = inMemoryStore.menuItems.get(id);
      if (!item) {
        throw new NotFoundError('Menu Item', id);
      }

      if (req.body.isAvailable !== undefined) {
        item.isAvailable = req.body.isAvailable;
      }
      if (req.body.isDeliveryAvailable !== undefined) {
        item.isDeliveryAvailable = req.body.isDeliveryAvailable;
      }
      inMemoryStore.saveToDisk();
      CloudOrderSyncService.syncDeliverableMenuToCloud().catch(() => {});

      res.json({
        success: true,
        data: {
          item,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

const toggleDeliveryAvailabilitySchema = z.object({
  isDeliveryAvailable: z.boolean(),
});

// PATCH /api/menu/items/:id/delivery-availability - Toggle exclusive online delivery state
menuRouter.patch(
  '/items/:id/delivery-availability',
  requireRole('counter', 'admin'),
  validateBody(toggleDeliveryAvailabilitySchema),
  (req: Request, res: Response, next: NextFunction) => {
    try {
      const id = req.params.id as string;
      const item = inMemoryStore.menuItems.get(id);
      if (!item) {
        throw new NotFoundError('Menu Item', id);
      }

      item.isDeliveryAvailable = req.body.isDeliveryAvailable;
      inMemoryStore.saveToDisk();
      CloudOrderSyncService.syncDeliverableMenuToCloud().catch(() => {});

      res.json({
        success: true,
        data: {
          item,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

const createMenuItemSchema = z.object({
  name: z.string().min(1),
  categoryId: z.string().min(1),
  shortCode: z.string().nullable().optional(),
  description: z.string().nullable().optional(),
  pricePaise: z.number().int().positive(),
  taxRatePercent: z.number().min(0).default(5.0),
  isAvailable: z.boolean().default(true),
  isDeliveryAvailable: z.boolean().default(true),
  isVeg: z.boolean().default(true),
  imageUrl: z.string().nullable().optional(),
  variants: z
    .array(
      z.object({
        id: z.string(),
        name: z.string(),
        pricePaise: z.number().int(),
      })
    )
    .optional()
    .default([]),
  addOns: z
    .array(
      z.object({
        id: z.string(),
        name: z.string(),
        pricePaise: z.number().int(),
      })
    )
    .optional()
    .default([]),
});

// POST /api/menu/items - Add a new menu item (Counter / Admin)
menuRouter.post(
  '/items',
  requireRole('counter', 'admin'),
  validateBody(createMenuItemSchema),
  (req: Request, res: Response, next: NextFunction) => {
    try {
      const {
        name,
        categoryId,
        shortCode,
        description,
        pricePaise,
        taxRatePercent,
        isAvailable,
        isVeg,
        imageUrl,
        variants,
        addOns,
      } = req.body;

      // Check license menu items limit
      const limitCheck = LicenseService.canAddMenuItem();
      if (!limitCheck.allowed) {
        return res.status(403).json({
          success: false,
          error: {
            code: 'LICENSE_LIMIT_EXCEEDED',
            message: limitCheck.message,
          },
        });
      }

      // Verify category exists or dynamically auto-create custom category
      let targetCategoryId = categoryId;
      let categoryName = categoryId;
      const catById = inMemoryStore.categories.get(categoryId);
      if (catById) {
        targetCategoryId = catById.id;
        categoryName = catById.name;
      } else {
        const found = Array.from(inMemoryStore.categories.values()).find(
          (c) => c.name.toLowerCase() === categoryId.trim().toLowerCase()
        );
        if (found) {
          targetCategoryId = found.id;
          categoryName = found.name;
        } else {
          // Auto-create custom category on the fly!
          const trimmed = categoryId.trim();
          const newCatId = `cat_${Date.now()}_${trimmed.toLowerCase().replace(/[^a-z0-9]/g, '_')}`;
          const newCat = {
            id: newCatId,
            name: trimmed,
            sortOrder: inMemoryStore.categories.size + 1,
            isActive: true,
          };
          inMemoryStore.categories.set(newCatId, newCat);
          targetCategoryId = newCatId;
          categoryName = trimmed;
        }
      }

      const id = `item_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
      const newItem: MenuItemRecord = {
        id,
        categoryId: targetCategoryId,
        name,
        shortCode: shortCode || name.substring(0, 3).toUpperCase(),
        description: description || '',
        pricePaise,
        taxRatePercent: taxRatePercent ?? 5.0,
        isAvailable: isAvailable ?? true,
        isDeliveryAvailable: req.body.isDeliveryAvailable ?? true,
        isVeg: isVeg ?? true,
        imageUrl: imageUrl || undefined,
        variants: variants || [],
        addOns: addOns || [],
        sortOrder: inMemoryStore.menuItems.size + 1,
      };

      inMemoryStore.menuItems.set(newItem.id, newItem);
      inMemoryStore.saveToDisk();

      res.status(201).json({
        success: true,
        data: {
          item: {
            ...newItem,
            category: categoryName,
            categoryName: categoryName,
          },
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

const updateItemSchema = z.object({
  name: z.string().min(1).optional(),
  categoryId: z.string().optional(),
  category: z.string().optional(),
  pricePaise: z.number().int().positive().optional(),
  isVeg: z.boolean().optional(),
  isAvailable: z.boolean().optional(),
  isDeliveryAvailable: z.boolean().optional(),
  description: z.string().optional(),
});

// PATCH or PUT /api/menu/items/:id - Update dish details (Counter / Admin)
const handleUpdateMenuItem = (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = req.params.id as string;
    const item = inMemoryStore.menuItems.get(id);
    if (!item) {
      throw new NotFoundError('Menu Item', id);
    }

    if (req.body.name) item.name = req.body.name;
    if (req.body.pricePaise) item.pricePaise = req.body.pricePaise;
    if (req.body.isVeg !== undefined) item.isVeg = req.body.isVeg;
    if (req.body.isAvailable !== undefined) item.isAvailable = req.body.isAvailable;
    if (req.body.isDeliveryAvailable !== undefined) item.isDeliveryAvailable = req.body.isDeliveryAvailable;
    if (req.body.description !== undefined) item.description = req.body.description;

    const catInput = req.body.categoryId || req.body.category;
    if (catInput) {
      const catById = inMemoryStore.categories.get(catInput);
      if (catById) {
        item.categoryId = catById.id;
      } else {
        const found = Array.from(inMemoryStore.categories.values()).find(
          (c) => c.name.toLowerCase() === catInput.trim().toLowerCase()
        );
        if (found) {
          item.categoryId = found.id;
        } else {
          const trimmed = catInput.trim();
          const newCatId = `cat_${Date.now()}_${trimmed.toLowerCase().replace(/[^a-z0-9]/g, '_')}`;
          const newCat = {
            id: newCatId,
            name: trimmed,
            sortOrder: inMemoryStore.categories.size + 1,
            isActive: true,
          };
          inMemoryStore.categories.set(newCatId, newCat);
          item.categoryId = newCatId;
        }
      }
    }

    inMemoryStore.saveToDisk();
    CloudOrderSyncService.syncDeliverableMenuToCloud().catch(() => {});

    const cat = inMemoryStore.categories.get(item.categoryId);
    res.json({
      success: true,
      data: {
        item: {
          ...item,
          category: cat ? cat.name : item.categoryId,
          categoryName: cat ? cat.name : item.categoryId,
        },
      },
    });
  } catch (err) {
    next(err);
  }
};

menuRouter.patch('/items/:id', requireRole('counter', 'admin'), validateBody(updateItemSchema), handleUpdateMenuItem);
menuRouter.put('/items/:id', requireRole('counter', 'admin'), validateBody(updateItemSchema), handleUpdateMenuItem);

const updatePriceSchema = z.object({
  pricePaise: z.number().int().positive(),
});

// PATCH /api/menu/items/:id/price - Update dish price (Counter / Admin)
menuRouter.patch(
  '/items/:id/price',
  requireRole('counter', 'admin'),
  validateBody(updatePriceSchema),
  (req: Request, res: Response, next: NextFunction) => {
    try {
      const id = req.params.id as string;
      const item = inMemoryStore.menuItems.get(id);
      if (!item) {
        throw new NotFoundError('Menu Item', id);
      }

      item.pricePaise = req.body.pricePaise;
      inMemoryStore.saveToDisk();

      res.json({
        success: true,
        data: {
          item,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// PUT /api/menu/categories/rename - Rename a category across all dishes and categories
menuRouter.put(
  '/categories/rename',
  requireRole('counter', 'admin'),
  (req: Request, res: Response, next: NextFunction) => {
    try {
      const { oldName, newName } = req.body;
      if (!oldName || !newName || typeof oldName !== 'string' || typeof newName !== 'string') {
        return res.status(400).json({ success: false, error: { message: 'oldName and newName are required' } });
      }

      const trimmedOld = oldName.trim();
      const trimmedNew = newName.trim();

      // Find or rename category in inMemoryStore.categories
      let targetCat = Array.from(inMemoryStore.categories.values()).find(
        (c) => c.name.toLowerCase() === trimmedOld.toLowerCase()
      );
      if (targetCat) {
        targetCat.name = trimmedNew;
      } else {
        // Create the new category record if it didn't exist
        const newCatId = `cat_${Date.now()}_${trimmedNew.toLowerCase().replace(/[^a-z0-9]/g, '_')}`;
        targetCat = {
          id: newCatId,
          name: trimmedNew,
          sortOrder: inMemoryStore.categories.size + 1,
          isActive: true,
        };
        inMemoryStore.categories.set(newCatId, targetCat);
      }

      // Update all dishes using this category name or ID
      let updatedCount = 0;
      for (const item of inMemoryStore.menuItems.values()) {
        const cat = inMemoryStore.categories.get(item.categoryId);
        const matchByName = cat ? cat.name.toLowerCase() === trimmedOld.toLowerCase() : false;
        const matchByRaw = item.categoryId ? item.categoryId.toLowerCase() === trimmedOld.toLowerCase() : false;

        if (matchByName || matchByRaw) {
          item.categoryId = targetCat.id;
          updatedCount++;
        }
      }

      inMemoryStore.saveToDisk();

      res.json({
        success: true,
        data: {
          message: `Category "${trimmedOld}" renamed to "${trimmedNew}" across ${updatedCount} dishes.`,
          oldName: trimmedOld,
          newName: trimmedNew,
          updatedCount,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// DELETE /api/menu/categories/:name - Delete a category and reassign dishes to another category
menuRouter.delete(
  '/categories/:name',
  requireRole('counter', 'admin'),
  (req: Request, res: Response, next: NextFunction) => {
    try {
      const catName = decodeURIComponent(req.params.name as string).trim();
      const reassignTo = (req.query.reassignTo as string || 'Others').trim();

      // Find or create reassign category
      let reassignCat = Array.from(inMemoryStore.categories.values()).find(
        (c) => c.name.toLowerCase() === reassignTo.toLowerCase()
      );
      if (!reassignCat) {
        const newCatId = `cat_${Date.now()}_${reassignTo.toLowerCase().replace(/[^a-z0-9]/g, '_')}`;
        reassignCat = {
          id: newCatId,
          name: reassignTo,
          sortOrder: inMemoryStore.categories.size + 1,
          isActive: true,
        };
        inMemoryStore.categories.set(newCatId, reassignCat);
      }

      // Find category to delete
      const catToDelete = Array.from(inMemoryStore.categories.values()).find(
        (c) => c.name.toLowerCase() === catName.toLowerCase() || c.id === catName
      );

      let movedCount = 0;
      for (const item of inMemoryStore.menuItems.values()) {
        const cat = inMemoryStore.categories.get(item.categoryId);
        const isMatch = (cat && cat.id === catToDelete?.id) ||
                        (cat && cat.name.toLowerCase() === catName.toLowerCase()) ||
                        (item.categoryId && item.categoryId.toLowerCase() === catName.toLowerCase());

        if (isMatch) {
          item.categoryId = reassignCat.id;
          movedCount++;
        }
      }

      if (catToDelete) {
        inMemoryStore.categories.delete(catToDelete.id);
      }

      inMemoryStore.saveToDisk();

      res.json({
        success: true,
        data: {
          message: `Category "${catName}" deleted. ${movedCount} dishes moved to "${reassignTo}".`,
          movedCount,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// DELETE /api/menu/items/all/wipe - Wipe all menu dishes for fresh restaurant onboarding
menuRouter.delete(
  '/items/all/wipe',
  requireRole('counter', 'admin'),
  (req: Request, res: Response, next: NextFunction) => {
    try {
      const previousCount = inMemoryStore.menuItems.size;
      inMemoryStore.menuItems.clear();
      inMemoryStore.saveToDisk();

      res.json({
        success: true,
        data: {
          message: 'All menu items wiped cleanly for client onboarding.',
          deletedCount: previousCount,
          count: 0,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// DELETE /api/menu/items/:id - Delete a specific dish from menu (Counter / Admin)
menuRouter.delete(
  '/items/:id',
  requireRole('counter', 'admin'),
  (req: Request, res: Response, next: NextFunction) => {
    try {
      const id = req.params.id as string;
      const item = inMemoryStore.menuItems.get(id);
      if (item) {
        inMemoryStore.menuItems.delete(id);
        inMemoryStore.saveToDisk();
      }

      res.json({
        success: true,
        data: {
          message: item ? `Dish "${item.name}" deleted successfully.` : 'Dish removed from menu.',
          deletedId: id,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// POST /api/menu/demo/seed - Re-seed sample restaurant menu & tables
menuRouter.post(
  '/demo/seed',
  requireRole('counter', 'admin'),
  (req: Request, res: Response, next: NextFunction) => {
    try {
      inMemoryStore.seed();
      inMemoryStore.saveToDisk();

      res.json({
        success: true,
        data: {
          message: 'Sample demo menu loaded successfully.',
          menuCount: inMemoryStore.menuItems.size,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

