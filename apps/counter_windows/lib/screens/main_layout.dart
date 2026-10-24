import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/counter_provider.dart';
import '../widgets/top_health_bar.dart';
import '../widgets/license_activation_dialog.dart';
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
              for (var device in provider.pendingDevices)
                _buildPendingDeviceBanner(context, provider, device),
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
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => showLicenseActivationDialog(context, provider),
                        icon: const Icon(Icons.vpn_key, size: 14),
                        label: const Text("ENTER LICENSE KEY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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
            for (var device in provider.pendingDevices)
              _buildPendingDeviceBanner(context, provider, device),
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
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => showLicenseActivationDialog(context, provider),
                        icon: const Icon(Icons.vpn_key, size: 14),
                        label: const Text("ENTER LICENSE KEY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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

  Widget _buildPendingDeviceBanner(BuildContext context, CounterProvider provider, Map<String, dynamic> device) {
    final name = device['deviceName']?.toString() ?? 'Captain Phone';
    final id = device['id']?.toString() ?? '';
    final ip = device['deviceIp']?.toString() ?? 'Wi-Fi Device';

    return Container(
      width: double.infinity,
      color: const Color(0xFF1E3A8A), // Deep indigo alert banner
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.wifi_tethering, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEW CAPTAIN DEVICE DETECTED: "$name"',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                ),
                Text(
                  'Device ID: $id • IP: $ip • Requesting permission to connect and take orders on table floor.',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () async {
              final ok = await provider.approveDevice(id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Captain device "$name" approved successfully.' : 'Failed to approve device.'),
                    backgroundColor: ok ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Approve & Activate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () => provider.rejectDevice(id),
            child: const Text('Decline', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
