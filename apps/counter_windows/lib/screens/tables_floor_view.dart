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

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
              // Section filter
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

          const SizedBox(height: 20),

          // Tables Grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.35,
              ),
              itemCount: provider.tables
                  .where((t) => provider.selectedSection == 'All' || t.section == provider.selectedSection)
                  .length,
              itemBuilder: (context, index) {
                final filtered = provider.tables
                    .where((t) => provider.selectedSection == 'All' || t.section == provider.selectedSection)
                    .toList();
                final table = filtered[index];
                return _buildTableCard(context, provider, table, currencyFormatter);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(
    BuildContext context,
    CounterProvider provider,
    RestaurantTable table,
    NumberFormat currencyFormatter,
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
        statusLabel = 'Bill Printed';
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
          color: isOccupied ? statusColor.withOpacity(0.4) : AppColors.border,
          width: isOccupied ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                table.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${table.section} • ${table.capacity} Seats',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (table.activeOrderTotalPaise > 0)
                Text(
                  currencyFormatter.format(table.activeOrderTotalRupees),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),

          const Divider(color: AppColors.borderLight, height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isOccupied)
                ElevatedButton(
                  onPressed: () => provider.selectOrderByTableId(table.id),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(80, 30),
                  ),
                  child: const Text('View Bill', style: TextStyle(fontSize: 11)),
                )
              else
                const Text('No Active Order', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
