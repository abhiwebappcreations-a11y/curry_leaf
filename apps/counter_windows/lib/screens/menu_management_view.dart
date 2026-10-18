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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        final padding = isMobile ? 12.0 : 24.0;

        return Container(
          color: AppColors.background,
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Menu & Kitchen Inventory',
                    style: TextStyle(
                      fontSize: isMobile ? 19 : 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isMobile
                        ? 'Manage prices and live stock for Captains'
                        : 'Manage dish prices and toggle real-time stock availability for Captain devices',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Menu Content: Mobile Cards or Desktop Table
              Expanded(
                child: isMobile
                    ? ListView.separated(
                        itemCount: provider.menuItems.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = provider.menuItems[index];
                          return _buildMobileMenuItemCard(context, provider, item, currencyFormatter);
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
                            itemCount: provider.menuItems.length + 1,
                            separatorBuilder: (context, index) => const Divider(color: AppColors.borderLight, height: 1),
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
                                          activeThumbColor: AppColors.accent,
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
      },
    );
  }

  Widget _buildMobileMenuItemCard(
    BuildContext context,
    CounterProvider provider,
    MenuItem item,
    NumberFormat currencyFormatter,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.isAvailable ? AppColors.border : AppColors.borderLight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Veg/NonVeg dot
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.isVeg ? AppColors.veg : AppColors.nonVeg,
                ),
              ),
              const SizedBox(width: 8),
              // Item Name and Category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: item.isAvailable ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.category,
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              // Price
              Text(
                currencyFormatter.format(item.priceRupees),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(color: AppColors.borderLight, height: 1),
          const SizedBox(height: 6),

          // Bottom Controls: Stock Toggle & Edit Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    item.isAvailable ? 'In Stock' : 'Out of Stock',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: item.isAvailable ? AppColors.success : AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: item.isAvailable,
                      activeThumbColor: AppColors.accent,
                      activeTrackColor: AppColors.primary,
                      onChanged: (_) => provider.toggleMenuItemAvailability(item.id),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _showEditPriceDialog(context, provider, item),
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Edit Price', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(60, 30),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
