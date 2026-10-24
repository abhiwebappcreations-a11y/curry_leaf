import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/table_model.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';

class CounterOrderPunchDialog extends StatefulWidget {
  final RestaurantTable initialTable;
  final CounterProvider provider;

  const CounterOrderPunchDialog({
    super.key,
    required this.initialTable,
    required this.provider,
  });

  @override
  State<CounterOrderPunchDialog> createState() => _CounterOrderPunchDialogState();
}

class _CounterOrderPunchDialogState extends State<CounterOrderPunchDialog> {
  late RestaurantTable _selectedTable;
  final Map<String, int> _cart = {}; // menuItemId -> qty
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSubmitting = false;

  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _selectedTable = widget.initialTable;
  }

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int get _totalItems => _cart.values.fold(0, (sum, q) => sum + q);

  int get _subtotalPaise {
    int total = 0;
    for (final entry in _cart.entries) {
      final item = widget.provider.menuItems.where((m) => m.id == entry.key).firstOrNull;
      if (item != null) {
        total += item.pricePaise * entry.value;
      }
    }
    return total;
  }

  int get _taxPaise => (_subtotalPaise * 0.05).round();
  int get _grandTotalPaise => _subtotalPaise + _taxPaise;

  void _addItem(String id) {
    setState(() {
      _cart[id] = (_cart[id] ?? 0) + 1;
    });
  }

  void _removeItem(String id) {
    setState(() {
      if ((_cart[id] ?? 0) > 1) {
        _cart[id] = _cart[id]! - 1;
      } else {
        _cart.remove(id);
      }
    });
  }

  List<Map<String, dynamic>> _buildOrderPayload() {
    final list = <Map<String, dynamic>>[];
    for (final entry in _cart.entries) {
      final item = widget.provider.menuItems.where((m) => m.id == entry.key).firstOrNull;
      if (item != null) {
        list.add({
          'menuItemId': item.id,
          'name': item.name,
          'quantity': entry.value,
          'pricePaise': item.pricePaise,
          'itemNotes': '',
        });
      }
    }
    return list;
  }

  Future<void> _fireKot({bool andSettle = false}) async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 food item'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = _buildOrderPayload();
    final ok = await widget.provider.fireKotForTable(
      tableId: _selectedTable.id,
      items: payload,
      customerNotes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'KOT fired to kitchen printer for ${_selectedTable.name}! Table is now occupied.'
              : 'Failed to dispatch KOT. Check printer connection.'),
          backgroundColor: ok ? AppColors.success : AppColors.error,
        ),
      );

      if (ok && andSettle) {
        widget.provider.selectOrderByTableId(_selectedTable.id);
        widget.provider.setActiveTab(CounterTab.billing);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...widget.provider.menuItems.map((m) => m.category).toSet()];
    final filteredItems = widget.provider.menuItems.where((item) {
      final matchesCat = _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty || item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 960,
        height: 640,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.restaurant_menu, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Counter Order Station — ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          Text(_selectedTable.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
                        ],
                      ),
                      Text(
                        'Punch items and fire KOT directly to kitchen. Current Mode: ${widget.provider.isSinglePrinterMode ? "Single Shared Printer" : "Double Printer Setup"}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 24),

            // Main Body: 2 Columns (Menu on Left, Cart on Right)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Menu Items & Category Filters
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search & Categories
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search dishes...',
                                  prefixIcon: const Icon(Icons.search, size: 20),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onChanged: (v) => setState(() => _searchQuery = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Categories Bar
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 6),
                            itemBuilder: (ctx, idx) {
                              final cat = categories[idx];
                              final isSelected = _selectedCategory == cat;
                              return ChoiceChip(
                                label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary),
                                onSelected: (val) => setState(() => _selectedCategory = cat),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Menu Grid
                        Expanded(
                          child: filteredItems.isEmpty
                              ? const Center(
                                  child: Text('No menu items found. Add dishes in Menu Management tab.', style: TextStyle(color: AppColors.textMuted)),
                                )
                              : GridView.builder(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 2.1,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemCount: filteredItems.length,
                                  itemBuilder: (ctx, idx) {
                                    final item = filteredItems[idx];
                                    final qty = _cart[item.id] ?? 0;
                                    return InkWell(
                                      onTap: () => _addItem(item.id),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: qty > 0 ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: qty > 0 ? AppColors.primary : AppColors.border,
                                            width: qty > 0 ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              item.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  currencyFormatter.format(item.priceRupees),
                                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13),
                                                ),
                                                if (qty > 0)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text('$qty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                                  )
                                                else
                                                  const Icon(Icons.add_circle_outline, size: 20, color: AppColors.primary),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),

                  const VerticalDivider(width: 24),

                  // Right Column: Cart & Action Buttons
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Cart ($_totalItems items)', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                              if (_cart.isNotEmpty)
                                TextButton(
                                  onPressed: () => setState(() => _cart.clear()),
                                  child: const Text('Clear', style: TextStyle(color: AppColors.error, fontSize: 11)),
                                ),
                            ],
                          ),
                          const Divider(height: 16),

                          // Cart Items
                          Expanded(
                            child: _cart.isEmpty
                                ? const Center(
                                    child: Text('Tap dishes from the menu to add to cart', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                  )
                                : ListView(
                                    children: _cart.entries.map((entry) {
                                      final item = widget.provider.menuItems.where((m) => m.id == entry.key).firstOrNull;
                                      if (item == null) return const SizedBox.shrink();
                                      final itemTotal = (item.priceRupees * entry.value);
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(item.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                  Text(currencyFormatter.format(item.priceRupees), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                                ],
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                                                  onPressed: () => _removeItem(item.id),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                                  child: Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.add_circle_outline, size: 18),
                                                  onPressed: () => _addItem(item.id),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              currencyFormatter.format(itemTotal),
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),

                          const Divider(height: 16),

                          // Cooking instructions / notes
                          TextField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              hintText: 'Special instructions (e.g. less spicy)...',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 10),

                          // Pricing Summary
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              Text(currencyFormatter.format(_subtotalPaise / 100), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('GST Tax (5%):', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              Text(currencyFormatter.format(_taxPaise / 100), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                              Text(
                                currencyFormatter.format(_grandTotalPaise / 100),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Two Buttons: FIRE KOT and KOT & SETTLE
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _isSubmitting || _cart.isEmpty ? null : () => _fireKot(andSettle: false),
                            icon: const Icon(Icons.outdoor_grill, size: 18),
                            label: const Text('FIRE KOT TO KITCHEN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: _isSubmitting || _cart.isEmpty ? null : () => _fireKot(andSettle: true),
                            icon: const Icon(Icons.receipt_long, size: 16),
                            label: const Text('KOT + GO TO BILLING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
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
}
