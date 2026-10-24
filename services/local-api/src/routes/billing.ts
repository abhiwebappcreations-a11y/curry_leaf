import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { BillingService } from '../services/billingService.js';
import { authenticateDevice, requireRole, requireActiveLicense } from '../middleware/auth.js';
import { validateBody } from '../middleware/validate.js';

export const billingRouter = Router();

billingRouter.use(authenticateDevice);

const finalizeBillSchema = z.object({
  discountPaise: z.number().int().min(0).optional(),
});

// POST /orders/:id/bill or /bills/orders/:id/bill - Finalize bill
billingRouter.post(
  ['/orders/:id/bill', '/bills/orders/:id/bill'],
  requireActiveLicense,
  requireRole('counter', 'admin'),
  validateBody(finalizeBillSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const bill = await BillingService.finalizeBill(
        req.params.id as string,
        req.body,
        req.device?.id
      );
      res.status(201).json({
        success: true,
        data: {
          bill,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// GET /:id or /bills/:id - Get bill details
billingRouter.get(['/:id', '/bills/:id'], async (req: Request, res: Response, next: NextFunction) => {
  try {
    const bill = await BillingService.getBillById(req.params.id as string);
    res.json({
      success: true,
      data: {
        bill,
      },
    });
  } catch (err) {
    next(err);
  }
});

// GET / or /bills - List bills
billingRouter.get(['/', '/bills'], async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { status } = req.query;
    const bills = await BillingService.listBills(
      typeof status === 'string' ? status : undefined
    );
    res.json({
      success: true,
      data: {
        bills,
      },
    });
  } catch (err) {
    next(err);
  }
});

const settlePaymentSchema = z.object({
  amountPaise: z.number().int().positive(),
  paymentMethod: z.enum(['cash', 'upi', 'card', 'split', 'other']),
  idempotencyKey: z.string().min(5),
  orderId: z.string().optional(),
  referenceNumber: z.string().optional(),
  notes: z.string().optional(),
});

// POST /:id/payments or /bills/:id/payments - Settle payment (Counter / Admin only)
billingRouter.post(
  ['/:id/payments', '/bills/:id/payments'],
  requireActiveLicense,
  requireRole('counter', 'admin'),
  validateBody(settlePaymentSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const result = await BillingService.settlePayment(
        req.params.id as string,
        req.body,
        req.device?.id
      );
      res.status(201).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }
);


// POST /:id/print or /bills/:id/print or /orders/:id/print-bill - Direct Customer Bill Print
billingRouter.post(
  ['/:id/print', '/bills/:id/print', '/orders/:id/print-bill'],
  requireActiveLicense,
  requireRole('counter', 'admin'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const bill = await BillingService.printBill(req.params.id as string, false);
      res.json({
        success: true,
        data: {
          message: 'Customer bill sent to counter printer',
          bill,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// POST /:id/reprint or /bills/:id/reprint - Safe reprint with REPRINT watermark
billingRouter.post(
  ['/:id/reprint', '/bills/:id/reprint'],
  requireActiveLicense,
  requireRole('counter', 'admin'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const result = await BillingService.reprintBill(req.params.id as string, req.device?.id);
      res.json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }
);

const voidBillSchema = z.object({
  reason: z.string().min(3),
});

// POST /:id/void or /bills/:id/void - Void bill with auditable reason
billingRouter.post(
  ['/:id/void', '/bills/:id/void'],
  requireActiveLicense,
  requireRole('counter', 'admin'),
  validateBody(voidBillSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const bill = await BillingService.voidBill(
        req.params.id as string,
        req.body.reason,
        req.device?.id
      );
      res.json({
        success: true,
        data: {
          bill,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);


