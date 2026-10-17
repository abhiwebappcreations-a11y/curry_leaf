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
