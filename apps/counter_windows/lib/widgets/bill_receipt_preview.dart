import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../providers/counter_provider.dart';

class BillReceiptPreview extends StatelessWidget {
  final RestaurantBill bill;
  final VoidCallback? onReprint;

  const BillReceiptPreview({
    super.key,
    required this.bill,
    this.onReprint,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹ ',
      decimalDigits: 2,
    );
    final dateStr = DateFormat('dd-MM-yyyy hh:mm a').format(bill.createdAt);
    final counterProv = context.watch<CounterProvider?>();
    final restName = counterProv?.restaurantName ?? 'Hinopt POS';

    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reprint Watermark Banner
          if (bill.isReprint)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              margin: const EdgeInsets.only(bottom: 12),
              color: AppColors.errorBg,
              child: const Text(
                '*** DUPLICATE REPRINT ***',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ),

          // Restaurant Header
          Text(
            restName.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Plot 42, Jubilee Hills Road No. 36\nHyderabad, Telangana - 500033\nGSTIN: 36AABCU9603R1ZM | FSSAI: 13621014000412',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.3),
          ),

          const SizedBox(height: 12),
          const Text(
            '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.border, fontSize: 10),
          ),
          const SizedBox(height: 6),

          // Bill Metadata
          _buildMetaRow('Bill No:', bill.billNumber),
          _buildMetaRow('Date/Time:', dateStr),
          _buildMetaRow('Table:', '${bill.tableName} (${bill.cashierName})'),
          if (bill.paymentReference != null)
            _buildMetaRow('Ref / Txn:', bill.paymentReference!),

          const SizedBox(height: 6),
          const Text(
            '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.border, fontSize: 10),
          ),
          const SizedBox(height: 8),

          // Line Items Header
          const Row(
            children: [
              Expanded(
                flex: 5,
                child: Text('ITEM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
              Expanded(
                flex: 2,
                child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
              Expanded(
                flex: 3,
                child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
              Expanded(
                flex: 3,
                child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Line Items
          ...bill.items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      item.name,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${item.quantity}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      currencyFormatter.format(item.unitPriceRupees),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      currencyFormatter.format(item.totalRupees),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),
          const Text(
            '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.border, fontSize: 10),
          ),
          const SizedBox(height: 6),

          // Summary Financials
          _buildSummaryRow('Subtotal:', currencyFormatter.format(bill.subtotalRupees)),
          if (bill.discountPaise > 0)
            _buildSummaryRow(
              'Discount (${bill.discountReason ?? "Special"}):',
              '- ${currencyFormatter.format(bill.discountRupees)}',
              isNegative: true,
            ),
          _buildSummaryRow('CGST (2.5%):', currencyFormatter.format(bill.cgstRupees)),
          _buildSummaryRow('SGST (2.5%):', currencyFormatter.format(bill.sgstRupees)),

          const SizedBox(height: 6),
          const Text(
            '================================',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 11),
          ),
          const SizedBox(height: 6),

          // Grand Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GRAND TOTAL:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              Text(
                currencyFormatter.format(bill.totalRupees),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          _buildMetaRow('Payment Mode:', '${bill.paymentMethod.label} (${bill.paymentStatus.label})'),

          const SizedBox(height: 16),
          Text(
            'Thank you for dining at $restName!\nPlease visit again.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
          ),

          if (onReprint != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onReprint,
              icon: const Icon(Icons.print, size: 16),
              label: Text(bill.isReprint ? 'Reprint Duplicate Again' : 'Print Duplicate Receipt'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isNegative ? AppColors.error : AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
