import { Router, Request, Response } from 'express';
import { inMemoryStore } from '../db/inMemoryStore.js';
import { authenticateDevice, requireRole } from '../middleware/auth.js';

export const reportsRouter = Router();

reportsRouter.use(authenticateDevice);

// GET /api/reports/daily-summary - Daily sales and financial breakdown in integer paise
reportsRouter.get(
  '/daily-summary',
  requireRole('counter', 'admin'),
  (req: Request, res: Response) => {
    const bills = Array.from(inMemoryStore.bills.values());
    const settledBills = bills.filter((b) => b.status === 'settled');
    const voidedBills = bills.filter((b) => b.status === 'voided');

    const totalSalesPaise = settledBills.reduce((acc, b) => acc + b.totalPaise, 0);
    const totalTaxPaise = settledBills.reduce((acc, b) => acc + b.taxPaise, 0);
    const totalDiscountsPaise = settledBills.reduce((acc, b) => acc + b.discountPaise, 0);

    const payments = Array.from(inMemoryStore.payments.values()).filter(
      (p) => p.status === 'completed'
    );

    const paymentBreakdown = {
      cash: payments
        .filter((p) => p.paymentMethod === 'cash')
        .reduce((acc, p) => acc + p.amountPaise, 0),
      upi: payments
        .filter((p) => p.paymentMethod === 'upi')
        .reduce((acc, p) => acc + p.amountPaise, 0),
      card: payments
        .filter((p) => p.paymentMethod === 'card')
        .reduce((acc, p) => acc + p.amountPaise, 0),
      other: payments
        .filter((p) => !['cash', 'upi', 'card'].includes(p.paymentMethod))
        .reduce((acc, p) => acc + p.amountPaise, 0),
    };

    res.json({
      success: true,
      data: {
        summary: {
          settledBillsCount: settledBills.length,
          voidedBillsCount: voidedBills.length,
          totalSalesPaise,
          totalTaxPaise,
          totalDiscountsPaise,
          paymentBreakdown,
        },
      },
    });
  }
);

// GET /api/reports/audit-logs - View operational audit logs (Admin only)
reportsRouter.get('/audit-logs', requireRole('admin'), (req: Request, res: Response) => {
  const logs = [...inMemoryStore.auditLogs].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  );

  res.json({
    success: true,
    data: {
      logs,
    },
  });
});
