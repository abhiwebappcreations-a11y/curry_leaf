import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/menu_model.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';

class MenuManagementView extends StatelessWidget {
  const MenuManagementView({super.key});

  void _showEditPriceDialog(BuildContext context, CounterProvider provider, MenuItem item) {
    final priceController = TextEditingController(text: '${(item.pricePaise / 100).round()}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Price: ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Base Selling Price (₹):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(prefixText: '₹ '),
            ),
            const SizedBox(height: 8),
            const Text(
              'Note: Price updates apply to new orders only. Historical bills retain their exact original price snapshot.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newPriceRupees = int.tryParse(priceController.text.trim()) ?? 0;
              if (newPriceRupees > 0) {
                provider.updateMenuItemPrice(item.id, newPriceRupees * 100);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Update Price'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CounterProvider>();
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Menu & Kitchen Inventory',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage dish prices and toggle real-time stock availability for Captain devices',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Menu Table
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
                  itemCount: provider.menuItems.length + 1,
                  separatorBuilder: (_, __) => const Divider(color: AppColors.borderLight, height: 1),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Table Header
                      return Container(
                        color: AppColors.surfaceMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: const Row(
                          children: [
                            Expanded(flex: 1, child: Text('TYPE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                            Expanded(flex: 5, child: Text('DISH NAME', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                            Expanded(flex: 3, child: Text('CATEGORY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                            Expanded(flex: 3, child: Text('PRICE', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                            Expanded(flex: 3, child: Text('CAPTAIN AVAILABILITY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                            Expanded(flex: 2, child: Text('ACTION', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                          ],
                        ),
                      );
                    }

                    final item = provider.menuItems[index - 1];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          // Type
                          Expanded(
                            flex: 1,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: item.isVeg ? AppColors.veg : AppColors.nonVeg,
                              ),
                            ),
                          ),
                          // Name
                          Expanded(
                            flex: 5,
                            child: Text(
                              item.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: item.isAvailable ? AppColors.textPrimary : AppColors.textMuted,
                              ),
                            ),
                          ),
                          // Category
                          Expanded(
                            flex: 3,
                            child: Text(item.category, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ),
                          // Price
                          Expanded(
                            flex: 3,
                            child: Text(
                              currencyFormatter.format(item.priceRupees),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]),
                            ),
                          ),
                          // Stock Toggle
                          Expanded(
                            flex: 3,
                            child: Center(
                              child: Switch(
                                value: item.isAvailable,
                                activeColor: AppColors.accent,
                                activeTrackColor: AppColors.primary,
                                onChanged: (_) => provider.toggleMenuItemAvailability(item.id),
                              ),
                            ),
                          ),
                          // Edit Button
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _showEditPriceDialog(context, provider, item),
                                icon: const Icon(Icons.edit, size: 14),
                                label: const Text('Edit Price', style: TextStyle(fontSize: 11)),
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
}
