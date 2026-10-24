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

  res.json({
    success: true,
    data: {
      items: items.sort((a, b) => a.sortOrder - b.sortOrder),
    },
  });
});

const toggleAvailabilitySchema = z.object({
  isAvailable: z.boolean(),
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

      item.isAvailable = req.body.isAvailable;

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
  shortCode: z.string().optional(),
  description: z.string().optional(),
  pricePaise: z.number().int().positive(),
  taxRatePercent: z.number().min(0).default(5.0),
  isAvailable: z.boolean().default(true),
  isVeg: z.boolean().default(true),
  imageUrl: z.string().optional(),
  variants: z
    .array(
      z.object({
        id: z.string(),
        name: z.string(),
        pricePaise: z.number().int(),
      })
    )
    .default([]),
  addOns: z
    .array(
      z.object({
        id: z.string(),
        name: z.string(),
        pricePaise: z.number().int(),
      })
    )
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

      // Verify category exists or fallback
      let targetCategoryId = categoryId;
      const catById = inMemoryStore.categories.get(categoryId);
      if (!catById) {
        const found = Array.from(inMemoryStore.categories.values()).find(
          (c) => c.name.toLowerCase() === categoryId.toLowerCase()
        );
        if (found) {
          targetCategoryId = found.id;
        } else if (inMemoryStore.categories.size > 0) {
          targetCategoryId = Array.from(inMemoryStore.categories.values())[0].id;
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
          item: newItem,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

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
      if (!item) {
        throw new NotFoundError('Menu Item', id);
      }

      inMemoryStore.menuItems.delete(id);
      inMemoryStore.saveToDisk();

      res.json({
        success: true,
        data: {
          message: `Dish "${item.name}" deleted successfully.`,
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

