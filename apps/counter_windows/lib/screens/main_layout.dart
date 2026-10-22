import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/counter_provider.dart';
import '../widgets/top_health_bar.dart';
import '../theme/app_colors.dart';
import '../widgets/sidebar_navigation.dart';
import 'active_orders_view.dart';
import 'tables_floor_view.dart';
import 'billing_settlement_view.dart';
import 'menu_management_view.dart';
import 'printer_settings_view.dart';
import 'reports_view.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CounterProvider>();

    Widget content;
    switch (provider.activeTab) {
      case CounterTab.orders:
        content = const ActiveOrdersView();
        break;
      case CounterTab.tables:
        content = const TablesFloorView();
        break;
      case CounterTab.billing:
        content = const BillingSettlementView();
        break;
      case CounterTab.menu:
        content = const MenuManagementView();
        break;
      case CounterTab.printers:
        content = const PrinterSettingsView();
        break;
      case CounterTab.reports:
        content = const ReportsView();
        break;
    }

    final isCompact = MediaQuery.sizeOf(context).width < 768;

    if (isCompact) {
      return Scaffold(
        drawer: const Drawer(
          child: SafeArea(
            child: SidebarNavigation(isDrawer: true),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              const TopHealthBar(showMenuButton: true),
              if (provider.isLicenseLocked)
                Container(
                  width: double.infinity,
                  color: AppColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock, color: Colors.white, size: 22),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "SUBSCRIPTION EXPIRED / LOCKED -- RESTAURANT OPERATIONS STOPPED",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                            Text(
                              "KOT dispatch, bill finalization, payment settlement, and thermal printing are disabled until renewed in Hinopt Admin.",
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                          border: Border.all(color: Colors.white54),
                        ),
                        child: const Text(
                          "CONTACT HINOPT ADMIN",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopHealthBar(showMenuButton: false),
              if (provider.isLicenseLocked)
                Container(
                  width: double.infinity,
                  color: AppColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock, color: Colors.white, size: 22),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "SUBSCRIPTION EXPIRED / LOCKED -- RESTAURANT OPERATIONS STOPPED",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                            Text(
                              "KOT dispatch, bill finalization, payment settlement, and thermal printing are disabled until renewed in Hinopt Admin.",
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                          border: Border.all(color: Colors.white54),
                        ),
                        child: const Text(
                          "CONTACT HINOPT ADMIN",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
            Expanded(
              child: Row(
                children: [
                  const SidebarNavigation(),
                  Expanded(child: content),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
