import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/table_card.dart';
import '../widgets/connection_badge.dart';
import 'order_screen.dart';
import 'kot_status_screen.dart';
import 'connection_settings_screen.dart';

class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PosProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.restaurant_menu, size: 22, color: AppColors.accent),
            SizedBox(width: 8),
            Text(
              'Hinopt Captain',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
            ),
          ],
        ),
        actions: [
          const ConnectionBadge(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            tooltip: 'KOT History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const KotStatusScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConnectionSettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Quick Operational Metrics Bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildMetricChip(
                  label: 'Free Tables',
                  count: provider.availableTableCount,
                  color: AppColors.success,
                  bgColor: AppColors.successBg,
                ),
                const SizedBox(width: 8),
                _buildMetricChip(
                  label: 'Occupied',
                  count: provider.occupiedTableCount,
                  color: AppColors.info,
                  bgColor: AppColors.infoBg,
                ),
                const SizedBox(width: 8),
                _buildMetricChip(
                  label: 'Total Tables',
                  count: provider.tables.length,
                  color: AppColors.primary,
                  bgColor: AppColors.surfaceMuted,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Area / Section Filter Tabs
          Container(
            color: AppColors.surface,
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: provider.availableSections.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final section = provider.availableSections[index];
                final isSelected = provider.selectedSection == section;

                return ChoiceChip(
                  label: Text(section),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceMuted,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  showCheckmark: false,
                  onSelected: (_) => provider.setSection(section),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Tables Grid
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => provider.init(),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Adaptive columns: 2 for mobile, 3-4 for larger screen/tablet
                          final crossAxisCount = constraints.maxWidth > 900
                              ? 5
                              : (constraints.maxWidth > 600 ? 3 : 2);

                          return GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.15,
                            ),
                            itemCount: provider.filteredTables.length,
                            itemBuilder: (context, index) {
                              final table = provider.filteredTables[index];
                              return TableCard(
                                table: table,
                                onTap: () {
                                  provider.selectTable(table);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const OrderScreen(),
                                    ),
                                  );
                                },
                              );
                            },
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

  Widget _buildMetricChip({
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
