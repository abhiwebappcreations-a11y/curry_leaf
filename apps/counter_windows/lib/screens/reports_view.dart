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
        title: Text('Reprint: ${bill.billNumber}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Security Notice: This prints a duplicate thermal copy labeled with *** DUPLICATE REPRINT ***.',
                style: TextStyle(fontSize: 11, color: AppColors.error),
              ),
              const SizedBox(height: 12),
              BillReceiptPreview(bill: bill),
            ],
          ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final padding = isMobile ? 12.0 : 24.0;

        return Container(
          color: AppColors.background,
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              if (isMobile) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shift & Day End Reports',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Reconcile cash till, UPI scans, cards & audit reprints',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Day summary report exported.')),
                        );
                      },
                      icon: const Icon(Icons.download, size: 14),
                      label: const Text('Z-Report', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(60, 32),
                      ),
                    ),
                  ],
                ),
              ] else ...[
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
              ],

              const SizedBox(height: 14),

              // KPI Metric Cards: 2x2 grid on mobile, 4-row on desktop
              if (isMobile) ...[
                Row(
                  children: [
                    _buildMetricCard(
                      title: 'Total Net Sales',
                      value: currencyFormatter.format(provider.totalSalesRupees),
                      icon: Icons.payments,
                      color: AppColors.success,
                      isMobile: true,
                    ),
                    const SizedBox(width: 8),
                    _buildMetricCard(
                      title: 'GST Collected',
                      value: currencyFormatter.format(provider.totalGstRupees),
                      icon: Icons.account_balance,
                      color: AppColors.info,
                      isMobile: true,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMetricCard(
                      title: 'Discounts Granted',
                      value: currencyFormatter.format(provider.totalDiscountsRupees),
                      icon: Icons.local_offer,
                      color: AppColors.warning,
                      isMobile: true,
                    ),
                    const SizedBox(width: 8),
                    _buildMetricCard(
                      title: 'Settled Bills',
                      value: '${provider.settledBills.length}',
                      icon: Icons.receipt,
                      color: AppColors.primary,
                      isMobile: true,
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    _buildMetricCard(
                      title: 'Total Net Sales',
                      value: currencyFormatter.format(provider.totalSalesRupees),
                      icon: Icons.payments,
                      color: AppColors.success,
                      isMobile: false,
                    ),
                    const SizedBox(width: 14),
                    _buildMetricCard(
                      title: 'GST Collected (5%)',
                      value: currencyFormatter.format(provider.totalGstRupees),
                      icon: Icons.account_balance,
                      color: AppColors.info,
                      isMobile: false,
                    ),
                    const SizedBox(width: 14),
                    _buildMetricCard(
                      title: 'Discounts Granted',
                      value: currencyFormatter.format(provider.totalDiscountsRupees),
                      icon: Icons.local_offer,
                      color: AppColors.warning,
                      isMobile: false,
                    ),
                    const SizedBox(width: 14),
                    _buildMetricCard(
                      title: 'Settled Bills Count',
                      value: '${provider.settledBills.length}',
                      icon: Icons.receipt,
                      color: AppColors.primary,
                      isMobile: false,
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Payment Mode Breakdown Cards: 2x2 on mobile, 4-row on desktop
              if (isMobile) ...[
                Row(
                  children: [
                    _buildPaymentChip('UPI / QR', currencyFormatter.format(salesByMethod[PaymentMethod.upi] ?? 0), Icons.qr_code),
                    const SizedBox(width: 8),
                    _buildPaymentChip('Cash in Till', currencyFormatter.format(salesByMethod[PaymentMethod.cash] ?? 0), Icons.money),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildPaymentChip('Card Terminal', currencyFormatter.format(salesByMethod[PaymentMethod.card] ?? 0), Icons.credit_card),
                    const SizedBox(width: 8),
                    _buildPaymentChip('Split Payments', currencyFormatter.format(salesByMethod[PaymentMethod.split] ?? 0), Icons.call_split),
                  ],
                ),
              ] else ...[
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
              ],

              const SizedBox(height: 14),

              Text(
                'Settled Bills Ledger (Audit & Reprints)',
                style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),

              // Settled Bills: Mobile Cards or Desktop Table
              Expanded(
                child: isMobile
                    ? ListView.separated(
                        itemCount: provider.settledBills.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final bill = provider.settledBills[index];
                          return _buildMobileBillCard(context, provider, bill, currencyFormatter);
                        },
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ListView.separated(
                            itemCount: provider.settledBills.length + 1,
                            separatorBuilder: (context, index) => const Divider(color: AppColors.borderLight, height: 1),
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
      },
    );
  }

  Widget _buildMobileBillCard(
    BuildContext context,
    CounterProvider provider,
    RestaurantBill bill,
    NumberFormat currencyFormatter,
  ) {
    final settledTimeStr = bill.settledAt != null
        ? DateFormat('hh:mm a').format(bill.settledAt!)
        : '-';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top: Bill Number, Table & Reprint Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    bill.billNumber,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      bill.tableName,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              if (bill.reprintCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
          ),

          const SizedBox(height: 6),

          // Mid: Cashier, Settled Time, Payment Method
          Row(
            children: [
              Text(
                'By ${bill.cashierName} • $settledTimeStr',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(
                  bill.paymentMethod.label,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(color: AppColors.borderLight, height: 1),
          const SizedBox(height: 6),

          // Bottom: Amount and Reprint Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currencyFormatter.format(bill.totalRupees),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showReprintDialog(context, provider, bill),
                icon: const Icon(Icons.print_outlined, size: 14),
                label: const Text('Reprint', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(60, 28),
                ),
              ),
            ],
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
    required bool isMobile,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 10 : 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 8 : 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: isMobile ? 18 : 22),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: isMobile ? 10 : 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    overflow: TextOverflow.ellipsis,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                method,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              amount,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }
}
