import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/menu_item_model.dart';
import '../providers/pos_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/menu_item_card.dart';
import '../widgets/order_summary_sheet.dart';

class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key});

  void _showCustomizationSheet(BuildContext context, MenuItem item) {
    String? selectedVariant = item.variants.isNotEmpty ? item.variants.first : null;
    final selectedAddons = <String>{};
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.borderLight),

                  // Variants
                  if (item.variants.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Choose Variant / Preparation',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: item.variants.map((v) {
                        final isSelected = selectedVariant == v;
                        return ChoiceChip(
                          label: Text(v),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          onSelected: (val) {
                            if (val) setSheetState(() => selectedVariant = v);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Addons
                  if (item.addons.isNotEmpty) ...[
                    const Text(
                      'Optional Add-ons',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: item.addons.map((addon) {
                        final isSelected = selectedAddons.contains(addon);
                        return FilterChip(
                          label: Text(addon),
                          selected: isSelected,
                          selectedColor: AppColors.accentLight,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          onSelected: (val) {
                            setSheetState(() {
                              if (val) {
                                selectedAddons.add(addon);
                              } else {
                                selectedAddons.remove(addon);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Kitchen Special Instructions
                  const Text(
                    'Special Kitchen Note',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Less salt, extra gravy, crispier',
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      context.read<PosProvider>().addItemToDraft(
                            item,
                            quantity: 1,
                            variant: selectedVariant,
                            addons: selectedAddons.toList(),
                            notes: noteController.text.trim().isNotEmpty
                                ? noteController.text.trim()
                                : null,
                          );
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Add to Order with Options'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OrderSummarySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PosProvider>();
    final currentTable = provider.currentTable;
    final order = provider.currentOrder;

    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹ ',
      decimalDigits: 0,
    );

    final draftCount = order?.draftItems.length ?? 0;
    final submittedCount = order?.submittedItems.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${currentTable?.name} • ${currentTable?.section}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            Text(
              'Table Order #${order?.id.substring(order.id.length - 4) ?? ""} • ${currentTable?.capacity} Guests',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'View Cart / Kitchen Slip',
            onPressed: () => _openCartSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Search Input
                TextField(
                  onChanged: (val) => provider.setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'Search dishes, biryani, starters...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                    suffixIcon: provider.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => provider.setSearchQuery(''),
                          )
                        : null,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),

                // Category Chips
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.availableCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = provider.availableCategories[index];
                      final isSelected = provider.selectedCategory == cat;

                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surfaceMuted,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        showCheckmark: false,
                        onSelected: (_) => provider.setCategory(cat),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Menu Items Grid
          Expanded(
            child: provider.filteredMenu.isEmpty
                ? const Center(
                    child: Text(
                      'No matching dishes found.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth > 900
                            ? 4
                            : (constraints.maxWidth > 600 ? 3 : 2);

                        return GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.74,
                          ),
                          itemCount: provider.filteredMenu.length,
                          itemBuilder: (context, index) {
                            final item = provider.filteredMenu[index];
                            final draftQty = order?.draftItems
                                    .where((i) => i.menuItemId == item.id)
                                    .fold(0, (sum, i) => sum + i.quantity) ??
                                0;

                            return MenuItemCard(
                              item: item,
                              draftQuantity: draftQty,
                              onAdd: () => provider.addItemToDraft(item),
                              onIncrement: () {
                                final existing = order?.draftItems
                                    .firstWhere((i) => i.menuItemId == item.id);
                                if (existing != null) {
                                  provider.updateDraftQuantity(existing.id, 1);
                                }
                              },
                              onDecrement: () {
                                final existing = order?.draftItems
                                    .firstWhere((i) => i.menuItemId == item.id);
                                if (existing != null) {
                                  provider.updateDraftQuantity(existing.id, -1);
                                }
                              },
                              onCustomize: () => _showCustomizationSheet(context, item),
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),

      // Bottom Persistent Summary Bar
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SafeArea(
          child: Row(
            children: [
              // Details preview
              Expanded(
                child: InkWell(
                  onTap: () => _openCartSheet(context),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: draftCount > 0 ? AppColors.warningBg : AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: draftCount > 0 ? AppColors.warning : AppColors.border,
                              ),
                            ),
                            child: Text(
                              '$draftCount Draft Items',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: draftCount > 0 ? AppColors.warning : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$submittedCount Sent',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormatter.format(order?.totalRupees ?? 0),
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
              ),

              // Action button: View Order / Send KOT
              ElevatedButton.icon(
                onPressed: () => _openCartSheet(context),
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: Text(
                  draftCount > 0 ? 'Review & Send KOT ($draftCount)' : 'View Order',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: draftCount > 0 ? AppColors.primary : AppColors.primaryLight,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
