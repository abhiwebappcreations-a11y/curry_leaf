import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/menu_model.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/upgrade_request_dialog.dart';

class MenuManagementView extends StatefulWidget {
  const MenuManagementView({super.key});

  @override
  State<MenuManagementView> createState() => _MenuManagementViewState();
}

class _MenuManagementViewState extends State<MenuManagementView> {
  String _selectedCategoryFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddDishDialog(BuildContext context, CounterProvider provider) {
    if (provider.isMenuItemLimitReached) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.lock_clock_outlined, color: AppColors.error, size: 24),
              SizedBox(width: 8),
              Text('Menu Limit Reached', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your current software license allows a maximum of ${provider.menuItemsLimit} menu items.\n\nYou currently have ${provider.menuItems.length} active dishes in the system.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFB74D)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.admin_panel_settings_outlined, color: Color(0xFFE65100), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'To add more dishes, please update or upgrade your license key via Hinopt Cloud Admin.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFE65100), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                UpgradeRequestDialog.show(context);
              },
              icon: const Icon(Icons.arrow_upward_rounded, size: 16),
              label: const Text('Request Limit Upgrade'),
            ),
          ],
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final descController = TextEditingController();
    final customCategoryController = TextEditingController();
    bool isVeg = true;
    const customOption = '+ Add Custom Category...';

    final defaultCategories = [
      'Starters',
      'Tandoor',
      'Curries',
      'Biryani & Rice',
      'Breads',
      'Beverages',
      'Desserts',
    ];

    final existingCategories = provider.menuItems
        .map((m) => m.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet();

    final categoryList = {
      ...defaultCategories,
      ...existingCategories,
    }.toList();
    categoryList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    categoryList.add(customOption);

    String selectedCategory = categoryList.first;
    bool isCustomCategory = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> submit() async {
            final name = nameController.text.trim();
            final priceRupees = int.tryParse(priceController.text.trim()) ?? 0;
            final categoryName = isCustomCategory
                ? customCategoryController.text.trim()
                : selectedCategory;

            if (name.isEmpty || priceRupees <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a valid dish name and price')),
              );
              return;
            }

            if (categoryName.isEmpty || categoryName == customOption) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter your custom category name')),
              );
              return;
            }

            final res = await provider.addNewMenuItemWithResult(
              name: name,
              category: categoryName,
              pricePaise: priceRupees * 100,
              isVeg: isVeg,
              description: descController.text.trim(),
              imageUrl: null,
            );

            if (ctx.mounted) {
              if (res.success) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Dish "$name" added under category "$categoryName"!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res.errorMessage ?? 'Failed to add dish to menu'),
                    backgroundColor: AppColors.error,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            }
          }

          return AlertDialog(
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
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'e.g. Malabar Fish Curry, Paneer Tikka...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onSubmitted: (_) => submit(),
                    ),
                    const SizedBox(height: 12),

                    // Category & Veg/Non-Veg in a Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                isExpanded: true,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                items: categoryList
                                    .map((c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(
                                            c,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: c == customOption ? FontWeight.bold : FontWeight.normal,
                                              color: c == customOption ? AppColors.primary : AppColors.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      selectedCategory = val;
                                      isCustomCategory = (val == customOption);
                                    });
                                  }
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

                    // If "+ Add Custom Category..." selected, show dedicated custom category field
                    if (isCustomCategory) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Custom Category Name *',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: customCategoryController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'e.g. Chinese, Mocktails, Pizza, Seafood, Specials...',
                          prefixIcon: const Icon(Icons.category_outlined, color: AppColors.primary, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                        onSubmitted: (_) => submit(),
                      ),
                    ],

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
                      onSubmitted: (_) => submit(),
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
                onPressed: submit,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Save & Publish Dish'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDishDialog(BuildContext context, CounterProvider provider, MenuItem item) {
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(text: '${(item.pricePaise / 100).round()}');
    final descController = TextEditingController(text: item.description);
    final customCategoryController = TextEditingController();
    bool isVeg = item.isVeg;
    const customOption = '+ Add Custom Category...';

    final defaultCategories = [
      'Starters',
      'Tandoor',
      'Curries',
      'Biryani & Rice',
      'Breads',
      'Beverages',
      'Desserts',
    ];

    final existingCategories = provider.menuItems
        .map((m) => m.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet();

    final categoryList = {
      ...defaultCategories,
      ...existingCategories,
      if (item.category.isNotEmpty) item.category,
    }.toList();
    categoryList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    categoryList.add(customOption);

    String selectedCategory = categoryList.contains(item.category) ? item.category : categoryList.first;
    bool isCustomCategory = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> submit() async {
            final name = nameController.text.trim();
            final priceRupees = int.tryParse(priceController.text.trim()) ?? 0;
            final categoryName = isCustomCategory
                ? customCategoryController.text.trim()
                : selectedCategory;

            if (name.isEmpty || priceRupees <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a valid dish name and price')),
              );
              return;
            }

            if (categoryName.isEmpty || categoryName == customOption) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter your custom category name')),
              );
              return;
            }

            await provider.updateMenuItemDetails(
              id: item.id,
              name: name,
              category: categoryName,
              pricePaise: priceRupees * 100,
              isVeg: isVeg,
              description: descController.text.trim(),
            );

            if (ctx.mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Dish "$name" updated under "$categoryName"!'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.edit_note, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Edit Dish: ${item.name}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
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
                    const Text('Dish Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onSubmitted: (_) => submit(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Category *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  if (!isCustomCategory && selectedCategory != customOption)
                                    InkWell(
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _showRenameCategoryDialog(context, provider, selectedCategory);
                                      },
                                      child: const Text(
                                        'Rename Category',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: selectedCategory,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                items: categoryList
                                    .map((c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(
                                            c,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: c == customOption ? FontWeight.bold : FontWeight.normal,
                                              color: c == customOption ? AppColors.primary : AppColors.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      selectedCategory = val;
                                      isCustomCategory = (val == customOption);
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Diet Type *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
                    if (isCustomCategory) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Custom Category Name *',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: customCategoryController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'e.g. Chinese, Mocktails, Pizza, Seafood, Specials...',
                          prefixIcon: const Icon(Icons.category_outlined, color: AppColors.primary, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                        onSubmitted: (_) => submit(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text('Base Price (₹) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onSubmitted: (_) => submit(),
                    ),
                    const SizedBox(height: 12),
                    const Text('Description (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
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
                onPressed: submit,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRenameCategoryDialog(BuildContext context, CounterProvider provider, String currentCategory) {
    final controller = TextEditingController(text: currentCategory);
    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);

    Future<void> submit() async {
      final newName = controller.text.trim();
      if (newName.isNotEmpty && newName != currentCategory) {
        Navigator.pop(context);
        final ok = await provider.renameCategory(currentCategory, newName);
        if (!mounted) return;
        if (_selectedCategoryFilter == currentCategory) {
          setState(() => _selectedCategoryFilter = newName);
        }
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Renamed "$currentCategory" to "$newName"' : 'Failed to rename category'),
            backgroundColor: ok ? AppColors.success : AppColors.error,
          ),
        );
      } else if (newName == currentCategory) {
        Navigator.pop(context);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.drive_file_rename_outline, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Rename Category: $currentCategory',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the new name for this category. All associated dishes will be updated instantly across all counter PCs and Captain apps.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. Starters & Snacks, Hot Beverages...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onSubmitted: (_) => submit(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: submit,
            child: const Text('Save New Name'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(
    BuildContext context,
    CounterProvider provider,
    String categoryName,
    int dishCount, {
    VoidCallback? onDeleted,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text('Delete Category?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          dishCount > 0
              ? 'Deleting "$categoryName" will keep all its $dishCount dishes safely by reassigning them to category "Others".\n\nDo you want to proceed?'
              : 'Are you sure you want to delete category "$categoryName"?',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await provider.deleteCategory(categoryName, 'Others');
              if (!mounted) return;
              if (_selectedCategoryFilter == categoryName) {
                setState(() => _selectedCategoryFilter = 'All');
              }
              onDeleted?.call();
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? 'Category "$categoryName" removed. Dishes moved to "Others".'
                      : 'Failed to delete category'),
                  backgroundColor: ok ? AppColors.success : AppColors.error,
                ),
              );
            },
            child: const Text('Delete Category'),
          ),
        ],
      ),
    );
  }

  void _showManageCategoriesDialog(BuildContext context, CounterProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final categories = provider.menuItems
              .map((m) => m.category.trim())
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Row(
              children: [
                Icon(Icons.category, color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Text('Manage Menu Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 520,
              height: 380,
              child: categories.isEmpty
                  ? const Center(
                      child: Text('No categories created yet.', style: TextStyle(color: AppColors.textMuted)),
                    )
                  : ListView.separated(
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final count = provider.menuItems
                            .where((m) => m.category.trim().toLowerCase() == cat.toLowerCase())
                            .length;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.folder_outlined, color: AppColors.primary, size: 20),
                          ),
                          title: Text(cat, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: Text(
                            '$count ${count == 1 ? "dish" : "dishes"}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                tooltip: 'Rename Category',
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showRenameCategoryDialog(context, provider, cat);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                tooltip: 'Delete Category (moves dishes to "Others")',
                                onPressed: () {
                                  _confirmDeleteCategory(context, provider, cat, count, onDeleted: () {
                                    setDialogState(() {});
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAddDishDialog(context, provider);
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('+ Add Dish with New Category'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showQuickPriceDialog(BuildContext context, CounterProvider provider, MenuItem item) {
    final priceController = TextEditingController(text: '${item.priceRupees}');
    priceController.selection = TextSelection(baseOffset: 0, extentOffset: priceController.text.length);

    Future<void> submit() async {
      final newPrice = int.tryParse(priceController.text.trim());
      if (newPrice != null && newPrice > 0) {
        Navigator.pop(context);
        await provider.updateMenuItemDetails(
          id: item.id,
          name: item.name,
          category: item.category,
          pricePaise: newPrice * 100,
          isVeg: item.isVeg,
          description: item.description,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text('Updated price for "${item.name}" to ₹$newPrice'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.currency_rupee, color: AppColors.primary, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Quick Price Change: ${item.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter new price in ₹ (Press Enter to save instantly):',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onSubmitted: (_) => submit(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: submit,
            child: const Text('Save Price'),
          ),
        ],
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

    // Extract all dynamic categories present in dishes
    final dynamicCategories = {'All'};
    for (var m in provider.menuItems) {
      if (m.category.trim().isNotEmpty) {
        dynamicCategories.add(m.category.trim());
      }
    }

    // Filter items based on category chip and search query
    final displayedItems = provider.menuItems.where((item) {
      final matchesCat = _selectedCategoryFilter == 'All' || item.category == _selectedCategoryFilter;
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          item.name.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q) ||
          item.description.toLowerCase().contains(q);
      return matchesCat && matchesSearch;
    }).toList();

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
                              ? 'Manage dishes, custom categories, and stock'
                              : 'Create custom categories, manage dish prices, and toggle real-time stock for Captain phones',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Click to request license limit upgrade',
                        child: InkWell(
                          onTap: () => UpgradeRequestDialog.show(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: provider.isMenuItemLimitReached ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                              border: Border.all(
                                color: provider.isMenuItemLimitReached ? AppColors.error : AppColors.success,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  provider.isMenuItemLimitReached ? Icons.lock_outline : Icons.inventory_2_outlined,
                                  size: 14,
                                  color: provider.isMenuItemLimitReached ? AppColors.error : AppColors.success,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Dishes: ${provider.menuItems.length} / ${provider.menuItemsLimit}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: provider.isMenuItemLimitReached ? AppColors.error : const Color(0xFF2E7D32),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_upward_rounded, size: 12, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (provider.menuItems.isNotEmpty) ...[
                        OutlinedButton.icon(
                          onPressed: () => _confirmWipeAllMenu(context, provider),
                          icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: AppColors.error),
                          label: Text(
                            isMobile ? 'Wipe All' : 'Wipe All Dishes',
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
                        label: Text(isMobile ? 'Add' : '+ Add New Dish'),
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

              const SizedBox(height: 14),

              // Online Ordering Storefront Banner
              if (provider.isOnlineOrderingEnabled) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.delivery_dining, color: Color(0xFF16A34A), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Online Delivery Storefront is LIVE',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFBBF7D0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Own Delivery Module Active',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              provider.customDomain.isNotEmpty
                                  ? 'https://${provider.customDomain}'
                                  : (provider.onlineStoreUrl.isNotEmpty
                                      ? provider.onlineStoreUrl
                                      : 'http://${provider.lanInfo?['ip'] ?? "localhost"}:4000/orders'),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF15803D),
                          side: const BorderSide(color: Color(0xFF86EFAC)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.copy, size: 13),
                        label: const Text('Copy Store Link', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          final link = provider.customDomain.isNotEmpty
                              ? 'https://${provider.customDomain}'
                              : (provider.onlineStoreUrl.isNotEmpty
                                  ? provider.onlineStoreUrl
                                  : 'http://${provider.lanInfo?['ip'] ?? "localhost"}:4000/orders');
                          Clipboard.setData(ClipboardData(text: link));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied store link: $link'),
                              backgroundColor: AppColors.success,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],

              // Search & Category Filter Toolbar
              if (provider.menuItems.isNotEmpty) ...[
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search dish name, category, or ingredients...',
                            hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Manage Categories Button
                    ActionChip(
                      avatar: const Icon(Icons.category_outlined, size: 16, color: AppColors.primary),
                      label: const Text(
                        'Manage Categories',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                      backgroundColor: const Color(0xFFEFF6FF),
                      side: const BorderSide(color: Color(0xFF93C5FD)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onPressed: () => _showManageCategoriesDialog(context, provider),
                    ),
                    const SizedBox(width: 8),

                    // Quick Add Category Pill
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16, color: AppColors.primary),
                      label: const Text('Add Dish in Custom Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      backgroundColor: const Color(0xFFF0FDF4),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onPressed: () => _showAddDishDialog(context, provider),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Category Filter Chips & Selected Category Quick Actions
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: dynamicCategories.map((cat) {
                            final isSelected = _selectedCategoryFilter == cat;
                            final count = cat == 'All'
                                ? provider.menuItems.length
                                : provider.menuItems.where((m) => m.category == cat).length;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                selected: isSelected,
                                label: Text('$cat ($count)', style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                )),
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.surface,
                                checkmarkColor: Colors.white,
                                showCheckmark: false,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isSelected ? AppColors.primary : AppColors.border,
                                  ),
                                ),
                                onSelected: (_) {
                                  setState(() => _selectedCategoryFilter = cat);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    if (_selectedCategoryFilter != 'All') ...[
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                        label: Text(
                          'Rename "$_selectedCategoryFilter"',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                        backgroundColor: const Color(0xFFFEF3C7),
                        side: const BorderSide(color: Color(0xFFF59E0B)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onPressed: () => _showRenameCategoryDialog(context, provider, _selectedCategoryFilter),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.delete_outline, size: 14, color: AppColors.error),
                        label: const Text(
                          'Delete Category',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.error),
                        ),
                        backgroundColor: const Color(0xFFFEE2E2),
                        side: const BorderSide(color: Color(0xFFF87171)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onPressed: () {
                          final count = provider.menuItems.where((m) => m.category == _selectedCategoryFilter).length;
                          _confirmDeleteCategory(context, provider, _selectedCategoryFilter, count);
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
              ],

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
                                'All demo dishes wiped cleanly. Click "+ Add New Dish" above to create dishes under standard or custom categories.',
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
                                    label: const Text('Add First Dish (Custom Category)'),
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
                    : displayedItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off_outlined, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 10),
                            Text(
                              'No dishes found in "$_selectedCategoryFilter"',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: () => setState(() {
                                _selectedCategoryFilter = 'All';
                                _searchQuery = '';
                                _searchController.clear();
                              }),
                              child: const Text('Clear Filters & Show All'),
                            ),
                          ],
                        ),
                      )
                    : isMobile
                    ? ListView.separated(
                        itemCount: displayedItems.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = displayedItems[index];
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
                            itemCount: displayedItems.length + 1,
                            separatorBuilder: (context, index) => const Divider(color: AppColors.borderLight, height: 1),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                // Table Header
                                return Container(
                                  color: AppColors.surfaceMuted,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  child: const Row(
                                    children: [
                                      SizedBox(width: 32, child: Text('TYPE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                                      Expanded(
                                        flex: 5,
                                        child: Row(
                                          children: [
                                            Text('DISH NAME', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                                            SizedBox(width: 6),
                                            Text('(Double-click row to edit)', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
                                          ],
                                        ),
                                      ),
                                      Expanded(flex: 3, child: Text('CATEGORY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                                      Expanded(flex: 2, child: Text('PRICE', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                                      Expanded(flex: 3, child: Text('CAPTAIN STOCK', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                                      Expanded(flex: 3, child: Text('ONLINE DELIVERY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                                      Expanded(flex: 3, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                                    ],
                                  ),
                                );
                              }

                              final item = displayedItems[index - 1];
                              return InkWell(
                                onDoubleTap: () => _showEditDishDialog(context, provider, item),
                                hoverColor: AppColors.primary.withValues(alpha: 0.04),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  child: Row(
                                    children: [
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
                                        flex: 5,
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
                                          child: Tooltip(
                                            message: 'Click to rename category "${item.category}"',
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(6),
                                              onTap: () => _showRenameCategoryDialog(context, provider, item.category),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEFF6FF),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      item.category,
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Icon(Icons.edit_outlined, size: 10, color: Color(0xFF1D4ED8)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Price
                                      Expanded(
                                        flex: 2,
                                        child: Tooltip(
                                          message: 'Click to quick-change price',
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(4),
                                            onTap: () => _showQuickPriceDialog(context, provider, item),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    currencyFormatter.format(item.priceRupees),
                                                    textAlign: TextAlign.right,
                                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.edit_outlined, size: 11, color: AppColors.textMuted),
                                                ],
                                              ),
                                            ),
                                          ),
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
                                      // Online Delivery Toggle
                                      Expanded(
                                        flex: 3,
                                        child: Center(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                item.isDeliveryAvailable ? 'Deliverable' : 'Dine-in Only',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: item.isDeliveryAvailable ? const Color(0xFF0D9488) : AppColors.textMuted,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Transform.scale(
                                                scale: 0.85,
                                                child: Switch(
                                                  value: item.isDeliveryAvailable,
                                                  activeColor: const Color(0xFF0D9488),
                                                  activeTrackColor: const Color(0xFF99F6E4),
                                                  onChanged: (_) => provider.toggleMenuItemDeliveryAvailability(item.id),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Action Buttons: Edit Dish & Delete
                                      Expanded(
                                        flex: 3,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () => _showEditDishDialog(context, provider, item),
                                              icon: const Icon(Icons.edit, size: 13),
                                              label: const Text('Edit Dish', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: item.isAvailable ? AppColors.textPrimary : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        item.category,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                      ),
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Row(
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
                      const SizedBox(width: 4),
                      Transform.scale(
                        scale: 0.8,
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
                      Text(
                        item.isDeliveryAvailable ? 'Delivery: On' : 'Delivery: Off',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: item.isDeliveryAvailable ? const Color(0xFF0D9488) : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: item.isDeliveryAvailable,
                          activeColor: const Color(0xFF0D9488),
                          activeTrackColor: const Color(0xFF99F6E4),
                          onChanged: (_) => provider.toggleMenuItemDeliveryAvailability(item.id),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () => _showEditDishDialog(context, provider, item),
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Edit Dish', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
