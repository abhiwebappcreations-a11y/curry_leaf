import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/counter_provider.dart';
import '../widgets/top_health_bar.dart';
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

    return Scaffold(
      body: Column(
        children: [
          const TopHealthBar(),
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
    );
  }
}
