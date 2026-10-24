import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/menu_model.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';

class MenuManagementView extends StatelessWidget {
  const MenuManagementView({super.key});

  void _showAddDishDialog(BuildContext context, CounterProvider provider) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final descController = TextEditingController();
    String selectedCategory = 'Starters';
    bool isVeg = true;

    final categories = [
      'Starters',
      'Tandoor',
      'Curries',
      'Biryani & Rice',
      'Breads',
      'Beverages',
      'Desserts',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.restaurant_menu, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'Add New Dish to Menu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dish Name
                  const Text(
                    'Dish Name *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Malabar Fish Curry',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category & Veg/Non-Veg in a Row
                  Row(
                    children: [
                      // Category
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Category *',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedCategory,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: categories
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => selectedCategory = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Veg / Non-Veg
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Diet Type *',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => setState(() => isVeg = !isVeg),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(8),
                                  color: isVeg ? const Color(0xFFF1F8E9) : const Color(0xFFFBE9E7),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isVeg ? AppColors.veg : AppColors.nonVeg,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isVeg ? 'Veg' : 'Non-Veg',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: isVeg ? AppColors.veg : AppColors.nonVeg,
                                      ),
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
                  const SizedBox(height: 12),

                  // Price (₹)
                  const Text(
                    'Base Price (₹) *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      hintText: '250',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),



                  // Description
                  const Text(
                    'Description (Optional)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Short description of ingredients, preparation style, or taste...',
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final name = nameController.text.trim();
                final priceRupees = int.tryParse(priceController.text.trim()) ?? 0;
                if (name.isEmpty || priceRupees <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid dish name and price')),
                  );
                  return;
                }

                await provider.addNewMenuItem(
                  name: name,
                  category: selectedCategory,
                  pricePaise: priceRupees * 100,
                  isVeg: isVeg,
                  description: descController.text.trim(),
                  imageUrl: null,
                );

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Dish "$name" added to live menu!')),
                  );
                }
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Save & Publish Dish'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildDishThumbnail(MenuItem item, {double size = 42}) {
    IconData fallbackIcon = Icons.restaurant;
    final cat = item.category.toLowerCase();
    if (cat.contains('starter')) {
      fallbackIcon = Icons.tapas;
    } else if (cat.contains('tandoor')) {
      fallbackIcon = Icons.outdoor_grill;
    } else if (cat.contains('biryani') || cat.contains('rice')) {
      fallbackIcon = Icons.rice_bowl;
    } else if (cat.contains('bread')) {
      fallbackIcon = Icons.bakery_dining;
    } else if (cat.contains('beverage') || cat.contains('drink')) {
      fallbackIcon = Icons.local_cafe;
    } else if (cat.contains('dessert')) {
      fallbackIcon = Icons.icecream;
    } else if (cat.contains('curry')) {
      fallbackIcon = Icons.dinner_dining;
    }

    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: item.isVeg ? const Color(0xFFF1F8E9) : const Color(0xFFFBE9E7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        fallbackIcon,
        size: size * 0.52,
        color: item.isVeg ? AppColors.veg.withValues(alpha: 0.5) : AppColors.nonVeg.withValues(alpha: 0.5),
      ),
    );

    if (item.imageUrl == null || item.imageUrl!.isEmpty) {
      return placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          item.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => placeholder,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return placeholder;
          },
        ),
      ),
    );
  }

  void _confirmDeleteDish(BuildContext context, CounterProvider provider, MenuItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text('Delete Dish', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${item.name}" from the menu?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await provider.deleteMenuItem(item.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Dish "${item.name}" deleted successfully.'
                        : 'Failed to delete dish from server.'),
                    backgroundColor: ok ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Delete Dish'),
          ),
        ],
      ),
    );
  }

  void _confirmWipeAllMenu(BuildContext context, CounterProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('Wipe All Menu Items?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
          'This will permanently delete ALL demo menu items for this restaurant so you can start clean for a fresh client onboarding.\n\nThis action cannot be undone. Are you sure?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await provider.wipeAllMenuItems();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'All menu items wiped cleanly. Menu is now blank for fresh setup.'
                        : 'Failed to wipe menu from server.'),
                    backgroundColor: ok ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Wipe All Dishes'),
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
              // Header Row with Add Dish Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
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
                              ? 'Manage prices, pictures, and live stock'
                              : 'Manage dish pictures, prices, and toggle real-time stock availability for Captain devices',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (provider.menuItems.isNotEmpty) ...[
                        OutlinedButton.icon(
                          onPressed: () => _confirmWipeAllMenu(context, provider),
                          icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: AppColors.error),
                          label: Text(
                            isMobile ? 'Wipe All' : 'Wipe All Dishes (Fresh Setup)',
                            style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                            padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      ElevatedButton.icon(
                        onPressed: () => _showAddDishDialog(context, provider),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(isMobile ? 'Add' : 'Add New Dish'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Menu Content: Mobile Cards or Desktop Table or Empty State
              Expanded(
                child: provider.menuItems.isEmpty
                    ? Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 480),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.restaurant_menu_outlined, size: 56, color: AppColors.textMuted.withValues(alpha: 0.6)),
                              const SizedBox(height: 14),
                              const Text(
                                'No Dishes in Menu',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'All demo dishes wiped cleanly. Click "Add New Dish" above to create live items for this client restaurant.',
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _showAddDishDialog(context, provider),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add First Dish'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final ok = await provider.seedDemoMenu();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(ok ? 'Sample demo menu loaded.' : 'Failed to load demo menu.'),
                                            backgroundColor: ok ? AppColors.success : AppColors.error,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                                    label: const Text('Load Sample Demo Menu', style: TextStyle(color: AppColors.primary)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: AppColors.primary),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    : isMobile
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
                                      SizedBox(width: 48, child: Text('PHOTO', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                                      SizedBox(width: 32, child: Text('TYPE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                                      Expanded(flex: 4, child: Text('DISH NAME', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                                      Expanded(flex: 3, child: Text('CATEGORY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                                      Expanded(flex: 2, child: Text('PRICE', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                                      Expanded(flex: 3, child: Text('CAPTAIN STOCK', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                                      Expanded(flex: 3, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                                    ],
                                  ),
                                );
                              }

                              final item = provider.menuItems[index - 1];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                child: Row(
                                  children: [
                                    // Picture Thumbnail
                                    SizedBox(
                                      width: 48,
                                      child: _buildDishThumbnail(item, size: 38),
                                    ),
                                    // Type Veg/Non-Veg
                                    SizedBox(
                                      width: 32,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: item.isVeg ? AppColors.veg : AppColors.nonVeg,
                                        ),
                                      ),
                                    ),
                                    // Name & Description
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: item.isAvailable ? AppColors.textPrimary : AppColors.textMuted,
                                            ),
                                          ),
                                          if (item.description.isNotEmpty)
                                            Text(
                                              item.description,
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    // Category Pill
                                    Expanded(
                                      flex: 3,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceMuted,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item.category,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Price
                                    Expanded(
                                      flex: 2,
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
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              item.isAvailable ? 'In Stock' : 'Out of Stock',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: item.isAvailable ? AppColors.success : AppColors.error,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Transform.scale(
                                              scale: 0.85,
                                              child: Switch(
                                                value: item.isAvailable,
                                                activeColor: AppColors.accent,
                                                activeTrackColor: AppColors.primary,
                                                onChanged: (_) => provider.toggleMenuItemAvailability(item.id),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Action Buttons: Edit Price & Delete
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () => _showEditPriceDialog(context, provider, item),
                                            icon: const Icon(Icons.edit, size: 13),
                                            label: const Text('Edit', style: TextStyle(fontSize: 11)),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            tooltip: 'Delete dish',
                                            icon: const Icon(Icons.delete_outline, size: 17, color: AppColors.error),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                            splashRadius: 16,
                                            onPressed: () => _confirmDeleteDish(context, provider, item),
                                          ),
                                        ],
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
              // Dish Picture Thumbnail
              _buildDishThumbnail(item, size: 54),
              const SizedBox(width: 10),

              // Item Name and Category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: item.isVeg ? AppColors.veg : AppColors.nonVeg,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: item.isAvailable ? AppColors.textPrimary : AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
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
                        const SizedBox(width: 6),
                        if (item.description.isNotEmpty)
                          Expanded(
                            child: Text(
                              item.description,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Price
              Text(
                currencyFormatter.format(item.priceRupees),
                style: const TextStyle(
                  fontSize: 15,
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
                      activeColor: AppColors.accent,
                      activeTrackColor: AppColors.primary,
                      onChanged: (_) => provider.toggleMenuItemAvailability(item.id),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () => _showEditPriceDialog(context, provider, item),
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Edit Price', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(60, 30),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Delete dish',
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    splashRadius: 16,
                    onPressed: () => _confirmDeleteDish(context, provider, item),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
