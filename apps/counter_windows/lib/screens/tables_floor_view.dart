import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/table_model.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';

class TablesFloorView extends StatelessWidget {
  const TablesFloorView({super.key});

  void _showAddTableDialog(BuildContext context, CounterProvider provider) {
    final tableNumberController = TextEditingController();
    final displayNameController = TextEditingController();
    final customSectionController = TextEditingController();
    final capacityController = TextEditingController(text: '4');

    final existingSections = provider.availableSections
        .where((s) => s != 'All')
        .toList();
    if (existingSections.isEmpty) {
      existingSections.add('Main Dining');
    }

    String selectedSection = existingSections.first;
    bool isCustomSection = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.table_restaurant, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'Add Dining Table',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Table Number / Code *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: tableNumberController,
                    decoration: InputDecoration(
                      hintText: 'e.g. T1, AC-1, Table 10',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Display Name (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: displayNameController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Corner Window, Booth 1',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Room / Dining Section *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  if (!isCustomSection) ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedSection,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: existingSections
                                .map((sec) => DropdownMenuItem(value: sec, child: Text(sec)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => selectedSection = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => setState(() => isCustomSection = true),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('New Room'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customSectionController,
                            decoration: InputDecoration(
                              hintText: 'Enter new Room name (e.g. Garden, AC Hall)',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textSecondary),
                          tooltip: 'Choose existing room',
                          onPressed: () => setState(() => isCustomSection = false),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),

                  const Text('Seating Capacity (Guests) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: capacityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'e.g. 2, 4, 6, 8',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                final tableNumber = tableNumberController.text.trim();
                final displayName = displayNameController.text.trim();
                final section = isCustomSection
                    ? customSectionController.text.trim()
                    : selectedSection.trim();
                final capacity = int.tryParse(capacityController.text.trim()) ?? 4;

                if (tableNumber.isEmpty || section.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter table number and room section.')),
                  );
                  return;
                }

                final success = await provider.createTable(
                  tableNumber: tableNumber,
                  displayName: displayName.isNotEmpty ? displayName : null,
                  section: section,
                  capacity: capacity,
                );

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Table "$tableNumber" created under section "$section"!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Create Table'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTableDialog(BuildContext context, CounterProvider provider, RestaurantTable table) {
    final tableNumberController = TextEditingController(text: table.name);
    final sectionController = TextEditingController(text: table.section);
    final capacityController = TextEditingController(text: table.capacity.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.edit, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text('Edit Table: ${table.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Table Name / Number *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                controller: tableNumberController,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),

              const Text('Room / Dining Section *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                controller: sectionController,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),

              const Text('Capacity (Seats) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                controller: capacityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
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
            onPressed: () async {
              final newName = tableNumberController.text.trim();
              final newSection = sectionController.text.trim();
              final newCap = int.tryParse(capacityController.text.trim()) ?? table.capacity;

              if (newName.isEmpty || newSection.isEmpty) return;

              final ok = await provider.updateTable(
                table.id,
                tableNumber: newName,
                displayName: newName,
                section: newSection,
                capacity: newCap,
              );

              if (ctx.mounted) {
                Navigator.pop(ctx);
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Table "$newName" updated successfully.')),
                  );
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTable(BuildContext context, CounterProvider provider, RestaurantTable table) {
    final hasActive = table.status == TableStatus.occupied || table.status == TableStatus.billed;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
            const SizedBox(width: 8),
            Text('Delete Table ${table.name}?'),
          ],
        ),
        content: Text(
          hasActive
              ? 'Table "${table.name}" currently has an active order. Deleting this table will cancel the active order and remove the table permanently.\n\nAre you sure you want to proceed?'
              : 'Are you sure you want to remove table "${table.name}" from ${table.section}?',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await provider.deleteTable(table.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Table ${table.name} deleted successfully.' : 'Failed to delete table.'),
                    backgroundColor: ok ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Delete Table'),
          ),
        ],
      ),
    );
  }

  void _showPetpoojaCancelDialog(BuildContext context, CounterProvider provider, RestaurantTable table) {
    final activeOrder = provider.activeOrders.where((o) => o.tableId == table.id).firstOrNull;
    if (activeOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active order found for this table.')),
      );
      return;
    }

    final cancellationReasons = [
      'Customer Left / Emergency',
      'Punched Wrong Order by Mistake',
      'Item Not Available / Kitchen Issue',
      'Customer Changed Mind',
    ];

    String selectedReason = cancellationReasons.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.cancel_outlined, color: AppColors.error, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cancel Order: ${table.name}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Why is this order being cancelled? (Petpooja Kitchen Alert)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text(
                  'A cancellation ticket will be dispatched to the kitchen printer to stop food preparation immediately.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Column(
                  children: cancellationReasons.map((r) {
                    final isSelected = selectedReason == r;
                    return RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: r,
                      groupValue: selectedReason,
                      title: Text(r, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedReason = val);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Order'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await provider.cancelOrder(activeOrder.id, selectedReason);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(ok ? Icons.check_circle : Icons.error, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ok
                                  ? 'Order cancelled! ${table.name} is now free and kitchen was alerted.'
                                  : 'Failed to cancel order.',
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: ok ? AppColors.success : AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('Confirm & Cancel Order'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmWipeAllData(BuildContext context, CounterProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('Reset to Fresh Client Setup?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: const Text(
          'This will wipe all sample demo tables, sample orders, test KOTs, and bills.\n\nYour restaurant floor plan will be a 100% clean canvas, ready to set up your client\'s real rooms and tables.\n\nAre you sure you want to proceed?',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await provider.wipeAllDemoData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Fresh client setup complete! Floor plan is now clean.' : 'Could not wipe demo data.'),
                    backgroundColor: ok ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Wipe All Demo Data (Fresh Setup)'),
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
        final horizontalPadding = isMobile ? 12.0 : 24.0;
        final verticalPadding = isMobile ? 12.0 : 20.0;

        int crossAxisCount;
        double childAspectRatio;
        if (constraints.maxWidth < 480) {
          crossAxisCount = 2;
          childAspectRatio = 1.05;
        } else if (constraints.maxWidth < 800) {
          crossAxisCount = 3;
          childAspectRatio = 1.20;
        } else {
          crossAxisCount = 4;
          childAspectRatio = 1.30;
        }

        final filteredTables = provider.tables
            .where((t) => provider.selectedSection == 'All' || t.section == provider.selectedSection)
            .toList();

        final availableSections = provider.availableSections;

        return Container(
          color: AppColors.background,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Floor Plan & Dining Tables',
                        style: TextStyle(
                          fontSize: isMobile ? 20 : 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Real-time seating status and custom room layout',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Fresh Client Setup Wipe Button
                      OutlinedButton.icon(
                        onPressed: () => _confirmWipeAllData(context, provider),
                        icon: const Icon(Icons.restart_alt, size: 14, color: AppColors.error),
                        label: Text(
                          isMobile ? 'Reset' : 'Fresh Client Reset',
                          style: const TextStyle(color: AppColors.error),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Add Table Button
                      ElevatedButton.icon(
                        onPressed: () => _showAddTableDialog(context, provider),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(isMobile ? 'Add' : '+ Add Table'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Dynamic Room / Section Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: availableSections.map((sec) {
                    final isSelected = provider.selectedSection == sec;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(sec),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        onSelected: (_) => provider.setSection(sec),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 14),

              // Tables Grid with Pull-to-Refresh
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.refreshFromLiveApi(isManual: true),
                  color: AppColors.accent,
                  child: filteredTables.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.table_restaurant_outlined, size: 48, color: AppColors.textMuted),
                                  const SizedBox(height: 12),
                                  Text(
                                    provider.tables.isEmpty
                                        ? 'Floor plan is completely clean.\nClick [+ Add Table] to create your restaurant\'s first table!'
                                        : 'No tables found in "${provider.selectedSection}".',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => _showAddTableDialog(context, provider),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add First Table Here'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: childAspectRatio,
                          ),
                          itemCount: filteredTables.length,
                          itemBuilder: (context, index) {
                            final table = filteredTables[index];
                            return _buildTableCard(context, provider, table, currencyFormatter, isMobile);
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableCard(
    BuildContext context,
    CounterProvider provider,
    RestaurantTable table,
    NumberFormat currencyFormatter,
    bool isMobile,
  ) {
    Color statusColor;
    Color statusBg;
    String statusLabel;

    switch (table.status) {
      case TableStatus.available:
        statusColor = AppColors.success;
        statusBg = AppColors.successBg;
        statusLabel = 'Available';
        break;
      case TableStatus.occupied:
        statusColor = AppColors.info;
        statusBg = AppColors.infoBg;
        statusLabel = 'Dining';
        break;
      case TableStatus.billed:
        statusColor = AppColors.billed;
        statusBg = AppColors.billedBg;
        statusLabel = 'Billed';
        break;
      case TableStatus.reserved:
        statusColor = AppColors.warning;
        statusBg = AppColors.warningBg;
        statusLabel = 'Reserved';
        break;
    }

    final isOccupied = table.status == TableStatus.occupied || table.status == TableStatus.billed;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOccupied ? statusColor.withValues(alpha: 0.4) : AppColors.border,
          width: isOccupied ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                table.name,
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                    onSelected: (val) {
                      if (val == 'cancel_order') {
                        _showPetpoojaCancelDialog(context, provider, table);
                      } else if (val == 'edit') {
                        _showEditTableDialog(context, provider, table);
                      } else if (val == 'delete') {
                        _confirmDeleteTable(context, provider, table);
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (isOccupied)
                        const PopupMenuItem(
                          value: 'cancel_order',
                          child: Row(
                            children: [
                              Icon(Icons.cancel, size: 16, color: AppColors.error),
                              SizedBox(width: 8),
                              Text('Cancel Order (Void)', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('Edit Table'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Delete Table', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${table.section} • ${table.capacity}S',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (table.activeOrderTotalPaise > 0)
                Text(
                  currencyFormatter.format(table.activeOrderTotalRupees),
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),

          const Divider(color: AppColors.borderLight, height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isOccupied)
                ElevatedButton(
                  onPressed: () => provider.selectOrderByTableId(table.id),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(60, 26),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('View Bill', style: TextStyle(fontSize: 11)),
                )
              else
                const Text('Free', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
