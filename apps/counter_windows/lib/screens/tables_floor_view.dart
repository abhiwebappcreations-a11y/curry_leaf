import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/table_model.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';

class TablesFloorView extends StatelessWidget {
  const TablesFloorView({super.key});

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
          childAspectRatio = 1.12;
        } else if (constraints.maxWidth < 800) {
          crossAxisCount = 3;
          childAspectRatio = 1.25;
        } else {
          crossAxisCount = 4;
          childAspectRatio = 1.35;
        }

        final filteredTables = provider.tables
            .where((t) => provider.selectedSection == 'All' || t.section == provider.selectedSection)
            .toList();

        return Container(
          color: AppColors.background,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              if (isMobile) ...[
                const Text(
                  'Floor Plan & Dining Tables',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Real-time dining table seating and order totals',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Main Hall', 'AC Dining', 'Rooftop', 'Takeaway'].map((sec) {
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
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Floor Plan & Dining Tables',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Real-time seating status across all dining sections',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Row(
                      children: ['All', 'Main Hall', 'AC Dining', 'Rooftop', 'Takeaway'].map((sec) {
                        final isSelected = provider.selectedSection == sec;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
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
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Tables Grid
              Expanded(
                child: filteredTables.isEmpty
                    ? const Center(
                        child: Text(
                          'No tables found in this section.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : GridView.builder(
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
