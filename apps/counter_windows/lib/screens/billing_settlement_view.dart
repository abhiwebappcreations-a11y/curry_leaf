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
    final existingRupees = (provider.currentDraftBill?.discountPaise ?? 0) ~/ 100;
    final amountController = TextEditingController(text: existingRupees > 0 ? '$existingRupees' : '');
    final reasonController = TextEditingController(text: provider.currentDraftBill?.discountReason ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Apply / Edit Discount',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
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
              cursorColor: AppColors.primary,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                hintText: 'e.g. 100 or 0 to clear',
                prefixText: '₹ ',
                prefixStyle: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Reason / Authorization:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: reasonController,
              cursorColor: AppColors.primary,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(hintText: 'e.g. Regular Guest / Promotional'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final text = amountController.text.trim();
              final rupees = int.tryParse(text) ?? 0;
              final reason = reasonController.text.trim().isNotEmpty
                  ? reasonController.text.trim()
                  : (rupees == 0 ? '' : 'Manager Discount');
              provider.applyDiscount(rupees * 100, reason);
              Navigator.pop(ctx);
            },
            child: const Text('Update Discount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showAddItemToBillDialog(
    BuildContext context,
    CounterProvider provider,
    RestaurantBill bill,
  ) {
    String query = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final filtered = provider.menuItems.where((item) {
            if (!item.isAvailable) return false;
            if (query.isEmpty) return true;
            return item.name.toLowerCase().contains(query.toLowerCase()) ||
                item.category.toLowerCase().contains(query.toLowerCase());
          }).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.add_shopping_cart, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Add Dish to ${bill.tableName}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search dishes by name or category...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) => setState(() => query = val),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching dishes found.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                leading: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: item.isVeg ? AppColors.veg : AppColors.nonVeg,
                                  ),
                                ),
                                title: Text(
                                  item.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                subtitle: Text(
                                  '${item.category} • ₹ ${(item.pricePaise / 100).round()}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: const Size(50, 28),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    provider.addItemToCurrentBill(item, 1);
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Added 1x ${item.name} to ${bill.tableName}'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: const Text('ADD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.point_of_sale_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              const Text(
                'No active bill selected for checkout.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Select an active order from the "Active Orders" or "Tables / Floor" tab to begin checkout.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => provider.setActiveTab(CounterTab.orders),
                icon: const Icon(Icons.receipt_long),
                label: const Text('View Active Orders'),
              ),
            ],
          ),
        ),
      );
    }

    final totalRupees = bill.totalRupees;
    final changeDueRupees = (_cashTenderedPaise - bill.totalPaise) / 100.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        final padding = isMobile ? 12.0 : 24.0;

        if (isMobile) {
          return Container(
            color: AppColors.background,
            padding: EdgeInsets.all(padding),
            child: ListView(
              children: [
                // Line items & financial summary card
                _buildBillItemsCard(context, provider, bill, currencyFormatter, isMobile: true),
                const SizedBox(height: 16),

                // Payment station card
                _buildPaymentStationCard(context, provider, bill, totalRupees, changeDueRupees, currencyFormatter),
                const SizedBox(height: 16),

                // Thermal receipt preview
                BillReceiptPreview(bill: bill),
              ],
            ),
          );
        }

        return Container(
          color: AppColors.background,
          padding: EdgeInsets.all(padding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Bill Line Items & Pricing Breakdown
              Expanded(
                flex: 6,
                child: _buildBillItemsCard(context, provider, bill, currencyFormatter, isMobile: false),
              ),

              const SizedBox(width: 20),

              // Right Column: Payment Settlement Station & Thermal Slip
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPaymentStationCard(context, provider, bill, totalRupees, changeDueRupees, currencyFormatter),
                      const SizedBox(height: 20),
                      BillReceiptPreview(bill: bill),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBillItemsCard(
    BuildContext context,
    CounterProvider provider,
    RestaurantBill bill,
    NumberFormat currencyFormatter, {
    required bool isMobile,
  }) {
    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bill Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${bill.tableName} • ${bill.billNumber}',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
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
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    provider.refreshCurrentBill();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bill synced with latest order items.'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.sync_rounded, size: 20),
                  tooltip: 'Sync Bill with Latest Order Items',
                  color: AppColors.primary,
                  splashRadius: 18,
                ),
                const SizedBox(width: 4),
                OutlinedButton.icon(
                  onPressed: () => _showDiscountDialog(context, provider),
                  icon: const Icon(Icons.discount_outlined, size: 14),
                  label: Text(bill.discountPaise > 0 ? 'Edit Disc' : 'Add Disc', style: const TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: () => _showAddItemToBillDialog(context, provider, bill),
                  icon: const Icon(Icons.add_shopping_cart, size: 14),
                  label: const Text('Add Dish', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),

        const Divider(color: AppColors.borderLight, height: 20),

        // Line Items Table Header
        const Row(
          children: [
            Expanded(flex: 5, child: Text('ITEM', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
            Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
            Expanded(flex: 3, child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
            Expanded(flex: 3, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
          ],
        ),
        const Divider(color: AppColors.borderLight, height: 12),

        // Line Items
        if (isMobile)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: bill.items.length,
            separatorBuilder: (context, index) => const Divider(color: AppColors.borderLight, height: 6),
            itemBuilder: (context, index) {
              final item = bill.items[index];
              return _buildItemRow(item, currencyFormatter);
            },
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: bill.items.length,
              separatorBuilder: (context, index) => const Divider(color: AppColors.borderLight, height: 8),
              itemBuilder: (context, index) {
                final item = bill.items[index];
                return _buildItemRow(item, currencyFormatter);
              },
            ),
          ),

        const Divider(color: AppColors.border, height: 16),

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

        const Divider(color: AppColors.primary, height: 16, thickness: 1.5),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Payable',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            Text(
              currencyFormatter.format(bill.totalRupees),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      child: cardContent,
    );
  }

  Widget _buildItemRow(BillItemSnapshot item, NumberFormat currencyFormatter) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              currencyFormatter.format(item.unitPriceRupees),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              currencyFormatter.format(item.totalRupees),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStationCard(
    BuildContext context,
    CounterProvider provider,
    RestaurantBill bill,
    double totalRupees,
    double changeDueRupees,
    NumberFormat currencyFormatter,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
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
              _buildMethodChip(PaymentMethod.upi, 'UPI', Icons.qr_code_scanner),
              const SizedBox(width: 6),
              _buildMethodChip(PaymentMethod.cash, 'Cash', Icons.money),
              const SizedBox(width: 6),
              _buildMethodChip(PaymentMethod.card, 'Card', Icons.credit_card),
              const SizedBox(width: 6),
              _buildMethodChip(PaymentMethod.split, 'Split', Icons.call_split),
            ],
          ),

          const SizedBox(height: 14),

          // Mode Specific Input
          if (_selectedMethod == PaymentMethod.upi) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code, size: 40, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Scan Dynamic Counter QR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        Text('Amount: ${currencyFormatter.format(totalRupees)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
                isDense: true,
              ),
            ),
          ] else if (_selectedMethod == PaymentMethod.cash) ...[
            TextField(
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
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [500, 1000, 2000].map((note) {
                return ActionChip(
                  label: Text('₹$note', style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    _tenderedController.text = '$note';
                    setState(() => _cashTenderedPaise = note * 100);
                  },
                );
              }).toList(),
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
                        fontSize: 15,
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
                isDense: true,
              ),
            ),
          ],

          const SizedBox(height: 16),

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
                              Expanded(
                                child: Text('Payment settled! Receipt printed to ${provider.billPrinter?.name ?? "Counter Printer"}.'),
                              ),
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
                  ? 'COMMITTING...'
                  : 'SETTLE & PRINT (${currencyFormatter.format(totalRupees)})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size.fromHeight(48),
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.textPrimary),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
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
