import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/table_model.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';

class SidebarNavigation extends StatelessWidget {
  final bool isDrawer;
  const SidebarNavigation({super.key, this.isDrawer = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CounterProvider>();

    return Container(
      width: 240,
      color: AppColors.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // User Profile Box
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(Icons.person, size: 18, color: Colors.white),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deepa',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Cashier • Shift A',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Navigation Items (Scrollable to prevent overflow)
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildNavItem(
                  context,
                  tab: CounterTab.orders,
                  icon: Icons.receipt_long,
                  title: 'Active Orders',
                  badge: '${provider.activeOrders.length}',
                  badgeColor: AppColors.warning,
                  isSelected: provider.activeTab == CounterTab.orders,
                ),
                _buildNavItem(
                  context,
                  tab: CounterTab.tables,
                  icon: Icons.table_restaurant,
                  title: 'Tables / Floor',
                  badge: '${provider.tables.where((t) => t.status == TableStatus.occupied).length}/${provider.tables.length}',
                  badgeColor: AppColors.info,
                  isSelected: provider.activeTab == CounterTab.tables,
                ),
                _buildNavItem(
                  context,
                  tab: CounterTab.billing,
                  icon: Icons.point_of_sale,
                  title: 'Billing & Till',
                  badge: provider.currentDraftBill != null ? 'Active' : null,
                  badgeColor: AppColors.accent,
                  isSelected: provider.activeTab == CounterTab.billing,
                ),
                _buildNavItem(
                  context,
                  tab: CounterTab.menu,
                  icon: Icons.restaurant_menu,
                  title: 'Menu & Stock',
                  isSelected: provider.activeTab == CounterTab.menu,
                ),
                _buildNavItem(
                  context,
                  tab: CounterTab.printers,
                  icon: Icons.print,
                  title: 'Thermal Printers',
                  isSelected: provider.activeTab == CounterTab.printers,
                ),
                _buildNavItem(
                  context,
                  tab: CounterTab.reports,
                  icon: Icons.bar_chart,
                  title: 'Day End Reports',
                  isSelected: provider.activeTab == CounterTab.reports,
                ),
              ],
            ),
          ),

          // Version / Licensing Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: AppColors.accent),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'HINOPT POS',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'v1.0.0 (POS Terminal) • Local LAN',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required CounterTab tab,
    required IconData icon,
    required String title,
    String? badge,
    Color? badgeColor,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: isSelected ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            context.read<CounterProvider>().setActiveTab(tab);
            if (isDrawer) {
              Navigator.of(context).pop();
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? AppColors.accent : Colors.white70,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor ?? AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
