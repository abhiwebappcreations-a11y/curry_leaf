import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/bill_model.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/bill_receipt_preview.dart';

class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  void _showReprintDialog(BuildContext context, CounterProvider provider, RestaurantBill bill) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Controlled Reprint: ${bill.billNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Security Notice: This action will print a duplicate thermal copy clearly labeled with *** DUPLICATE REPRINT *** to prevent cashier fraud.',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            BillReceiptPreview(bill: bill),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              provider.reprintBill(bill, 'Customer duplicate request');
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Duplicate copy dispatched to Counter Printer.'),
                  backgroundColor: AppColors.warning,
                ),
              );
            },
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print Duplicate Receipt'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CounterProvider>();
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 2);
    final salesByMethod = provider.salesByMethod;

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shift & Day End Audit Reports',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Reconcile cash till, UPI scans, cards, and audit duplicate reprints',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Day summary report exported to desktop.')),
                  );
                },
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export Shift Z-Report'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // KPI Cards
          Row(
            children: [
              _buildMetricCard(
                title: 'Total Net Sales',
                value: currencyFormatter.format(provider.totalSalesRupees),
                icon: Icons.payments,
                color: AppColors.success,
              ),
              const SizedBox(width: 14),
              _buildMetricCard(
                title: 'GST Collected (5%)',
                value: currencyFormatter.format(provider.totalGstRupees),
                icon: Icons.account_balance,
                color: AppColors.info,
              ),
              const SizedBox(width: 14),
              _buildMetricCard(
                title: 'Discounts Granted',
                value: currencyFormatter.format(provider.totalDiscountsRupees),
                icon: Icons.local_offer,
                color: AppColors.warning,
              ),
              const SizedBox(width: 14),
              _buildMetricCard(
                title: 'Settled Bills Count',
                value: '${provider.settledBills.length}',
                icon: Icons.receipt,
                color: AppColors.primary,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Payment Mode Breakdown Cards
          Row(
            children: [
              _buildPaymentChip('UPI / QR', currencyFormatter.format(salesByMethod[PaymentMethod.upi] ?? 0), Icons.qr_code),
              const SizedBox(width: 12),
              _buildPaymentChip('Cash in Till', currencyFormatter.format(salesByMethod[PaymentMethod.cash] ?? 0), Icons.money),
              const SizedBox(width: 12),
              _buildPaymentChip('Card Terminal', currencyFormatter.format(salesByMethod[PaymentMethod.card] ?? 0), Icons.credit_card),
              const SizedBox(width: 12),
              _buildPaymentChip('Split Payments', currencyFormatter.format(salesByMethod[PaymentMethod.split] ?? 0), Icons.call_split),
            ],
          ),

          const SizedBox(height: 20),

          const Text(
            'Settled Bills Ledger (Audit & Reprints)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),

          // Settled Bills Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ListView.separated(
                  itemCount: provider.settledBills.length + 1,
                  separatorBuilder: (_, __) => const Divider(color: AppColors.borderLight, height: 1),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Container(
                        color: AppColors.surfaceMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: const Row(
                          children: [
                            Expanded(flex: 3, child: Text('BILL NO', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                            Expanded(flex: 2, child: Text('TABLE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                            Expanded(flex: 3, child: Text('CASHIER', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                            Expanded(flex: 3, child: Text('PAYMENT METHOD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                            Expanded(flex: 3, child: Text('SETTLED AT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                            Expanded(flex: 3, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                            Expanded(flex: 2, child: Text('REPRINT', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                          ],
                        ),
                      );
                    }

                    final bill = provider.settledBills[index - 1];
                    final settledTimeStr = bill.settledAt != null
                        ? DateFormat('hh:mm a').format(bill.settledAt!)
                        : '-';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Text(
                                  bill.billNumber,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                                if (bill.reprintCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.errorBg,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      '${bill.reprintCount}x Reprints',
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.error),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(bill.tableName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(bill.cashierName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    bill.paymentMethod.label,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(settledTimeStr, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              currencyFormatter.format(bill.totalRupees),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: const Icon(Icons.print_outlined, size: 18),
                                tooltip: 'Reprint duplicate receipt',
                                onPressed: () => _showReprintDialog(context, provider, bill),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentChip(String method, String amount, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(method, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              amount,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }
}
