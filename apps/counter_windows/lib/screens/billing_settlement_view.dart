import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/bill_model.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/bill_receipt_preview.dart';

class BillingSettlementView extends StatefulWidget {
  const BillingSettlementView({super.key});

  @override
  State<BillingSettlementView> createState() => _BillingSettlementViewState();
}

class _BillingSettlementViewState extends State<BillingSettlementView> {
  PaymentMethod _selectedMethod = PaymentMethod.upi;
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _tenderedController = TextEditingController();
  int _cashTenderedPaise = 0;

  @override
  void dispose() {
    _refController.dispose();
    _tenderedController.dispose();
    super.dispose();
  }

  void _showDiscountDialog(BuildContext context, CounterProvider provider) {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply Manager Discount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Discount Amount (₹):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'e.g. 100'),
            ),
            const SizedBox(height: 12),
            const Text('Reason / Authorization:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(hintText: 'e.g. Regular Guest / Promotional'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final rupees = int.tryParse(amountController.text.trim()) ?? 0;
              final reason = reasonController.text.trim().isNotEmpty
                  ? reasonController.text.trim()
                  : 'Manager Discount';
              if (rupees > 0) {
                provider.applyDiscount(rupees * 100, reason);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Apply Discount'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CounterProvider>();
    final bill = provider.currentDraftBill;
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹ ',
      decimalDigits: 2,
    );

    if (bill == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.point_of_sale_outlined, size: 64, color: AppColors.textMuted.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'No active bill selected for checkout.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select an active order from the "Active Orders" or "Tables / Floor" tab to begin checkout.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => provider.setActiveTab(CounterTab.orders),
              icon: const Icon(Icons.receipt_long),
              label: const Text('View Active Orders'),
            ),
          ],
        ),
      );
    }

    final totalRupees = bill.totalRupees;
    final changeDueRupees = (_cashTenderedPaise - bill.totalPaise) / 100.0;

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Bill Line Items & Pricing Breakdown
          Expanded(
            flex: 6,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bill Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Checkout: ${bill.tableName} • ${bill.billNumber}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Order #${bill.orderId} • Cashier: Deepa',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _showDiscountDialog(context, provider),
                        icon: const Icon(Icons.discount_outlined, size: 16),
                        label: Text(bill.discountPaise > 0 ? 'Edit Discount' : 'Add Discount'),
                      ),
                    ],
                  ),

                  const Divider(color: AppColors.borderLight, height: 24),

                  // Line Items Table Header
                  const Row(
                    children: [
                      Expanded(flex: 5, child: Text('ITEM', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      Expanded(flex: 3, child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      Expanded(flex: 3, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    ],
                  ),
                  const Divider(color: AppColors.borderLight, height: 16),

                  // Line Items Scrollable List
                  Expanded(
                    child: ListView.separated(
                      itemCount: bill.items.length,
                      separatorBuilder: (_, __) => const Divider(color: AppColors.borderLight, height: 8),
                      itemBuilder: (context, index) {
                        final item = bill.items[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Text(
                                  item.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  currencyFormatter.format(item.unitPriceRupees),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  currencyFormatter.format(item.totalRupees),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const Divider(color: AppColors.border, height: 20),

                  // Financial Totals
                  _buildTotalRow('Subtotal', currencyFormatter.format(bill.subtotalRupees)),
                  if (bill.discountPaise > 0)
                    _buildTotalRow(
                      'Discount (${bill.discountReason ?? "Promo"})',
                      '- ${currencyFormatter.format(bill.discountRupees)}',
                      textColor: AppColors.error,
                    ),
                  _buildTotalRow('CGST (2.5%)', currencyFormatter.format(bill.cgstRupees)),
                  _buildTotalRow('SGST (2.5%)', currencyFormatter.format(bill.sgstRupees)),

                  const Divider(color: AppColors.primary, height: 20, thickness: 1.5),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Payable Amount',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        currencyFormatter.format(totalRupees),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 20),

          // Right Column: Payment Settlement Station & Thermal Slip
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Payment Mode Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Payment Method',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),

                        // Method Tabs
                        Row(
                          children: [
                            _buildMethodChip(PaymentMethod.upi, 'UPI / QR', Icons.qr_code_scanner),
                            const SizedBox(width: 8),
                            _buildMethodChip(PaymentMethod.cash, 'Cash', Icons.money),
                            const SizedBox(width: 8),
                            _buildMethodChip(PaymentMethod.card, 'Card', Icons.credit_card),
                            const SizedBox(width: 8),
                            _buildMethodChip(PaymentMethod.split, 'Split', Icons.call_split),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Mode Specific Input
                        if (_selectedMethod == PaymentMethod.upi) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.qr_code, size: 48, color: AppColors.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Scan Dynamic Counter QR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                      Text('Amount: ${currencyFormatter.format(totalRupees)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _refController,
                            decoration: const InputDecoration(
                              hintText: 'UPI Reference / UTR Number (Optional)',
                              prefixIcon: Icon(Icons.tag, size: 18),
                            ),
                          ),
                        ] else if (_selectedMethod == PaymentMethod.cash) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _tenderedController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    final rupees = int.tryParse(val) ?? 0;
                                    setState(() => _cashTenderedPaise = rupees * 100);
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Cash Tendered (₹)',
                                    hintText: 'e.g. 2000',
                                    prefixIcon: Icon(Icons.currency_rupee, size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Quick notes
                              Wrap(
                                spacing: 6,
                                children: [500, 1000, 2000].map((note) {
                                  return ActionChip(
                                    label: Text('₹$note'),
                                    onPressed: () {
                                      _tenderedController.text = '$note';
                                      setState(() => _cashTenderedPaise = note * 100);
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          if (_cashTenderedPaise > 0) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: changeDueRupees >= 0 ? AppColors.successBg : AppColors.errorBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    changeDueRupees >= 0 ? 'Change to Return:' : 'Short Amount:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: changeDueRupees >= 0 ? AppColors.success : AppColors.error,
                                    ),
                                  ),
                                  Text(
                                    currencyFormatter.format(changeDueRupees.abs()),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: changeDueRupees >= 0 ? AppColors.success : AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ] else if (_selectedMethod == PaymentMethod.card) ...[
                          TextField(
                            controller: _refController,
                            decoration: const InputDecoration(
                              hintText: 'Card Terminal Approval Code / RRN',
                              prefixIcon: Icon(Icons.pin, size: 18),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Big Settlement Button
                        ElevatedButton.icon(
                          onPressed: provider.isSettlingPayment
                              ? null
                              : () async {
                                  final success = await provider.settlePayment(
                                    method: _selectedMethod,
                                    reference: _refController.text.trim().isNotEmpty
                                        ? _refController.text.trim()
                                        : null,
                                  );
                                  if (context.mounted && success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppColors.success,
                                        content: Row(
                                          children: [
                                            const Icon(Icons.check_circle, color: Colors.white),
                                            const SizedBox(width: 8),
                                            Text('Payment settled! Receipt printed to ${provider.billPrinter?.name ?? "Counter Printer"}.'),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                },
                          icon: provider.isSettlingPayment
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_outline, size: 20),
                          label: Text(
                            provider.isSettlingPayment
                                ? 'COMMITTING SETTLEMENT...'
                                : 'SETTLE PAYMENT & PRINT BILL (${currencyFormatter.format(totalRupees)})',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size.fromHeight(52),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Receipt Preview Box
                  BillReceiptPreview(
                    bill: bill,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodChip(PaymentMethod method, String label, IconData icon) {
    final isSelected = _selectedMethod == method;
    return Expanded(
      child: Material(
        color: isSelected ? AppColors.primary : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() => _selectedMethod = method),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.textPrimary),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textColor ?? AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
