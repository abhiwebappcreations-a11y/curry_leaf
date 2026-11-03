import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/counter_provider.dart';
import '../widgets/top_health_bar.dart';
import '../widgets/license_activation_dialog.dart';
import '../widgets/upgrade_request_dialog.dart';
import '../theme/app_colors.dart';
import '../widgets/sidebar_navigation.dart';
import 'active_orders_view.dart';
import 'tables_floor_view.dart';
import 'billing_settlement_view.dart';
import 'menu_management_view.dart';
import 'printer_settings_view.dart';
import 'reports_view.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  bool _hasPromptedLicense = false;
  String? _currentlyPromptedDeviceId;
  bool _isDeviceDialogShowing = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CounterProvider>();

    if (!_hasPromptedLicense && provider.isLicenseLocked) {
      _hasPromptedLicense = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && provider.isLicenseLocked) {
          showLicenseActivationDialog(context, provider);
        }
      });
    }

    final pending = provider.pendingDevices;
    if (pending.isNotEmpty && !_isDeviceDialogShowing) {
      final firstDevice = pending.first;
      final devId = firstDevice['id']?.toString() ?? '';
      if (_currentlyPromptedDeviceId != devId) {
        _currentlyPromptedDeviceId = devId;
        _isDeviceDialogShowing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && provider.pendingDevices.any((d) => d['id'] == devId)) {
            _showDeviceApprovalModal(context, provider, firstDevice).then((_) {
              if (mounted) {
                setState(() {
                  _isDeviceDialogShowing = false;
                  _currentlyPromptedDeviceId = null;
                });
              }
            });
          } else {
            _isDeviceDialogShowing = false;
          }
        });
      }
    }

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
              for (var req in provider.pendingCancelRequests)
                _buildPendingCancelRequestBanner(context, provider, req),
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
                              "License Activation Required",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                            Text(
                              "Enter your license key in Terminal Settings to unlock full features.",
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
                        label: const Text("ACTIVATE LICENSE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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
            for (var req in provider.pendingCancelRequests)
              _buildPendingCancelRequestBanner(context, provider, req),
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
                              "License Activation Required",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                            Text(
                              "Enter your license key in Terminal Settings to unlock full features.",
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
                        label: const Text("ACTIVATE LICENSE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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

  Future<void> _showDeviceApprovalModal(
    BuildContext context,
    CounterProvider provider,
    Map<String, dynamic> device,
  ) async {
    final id = device['id']?.toString() ?? '';
    final name = device['deviceName']?.toString() ?? 'Captain Device';
    final ip = device['deviceIp']?.toString() ?? 'Wi-Fi';

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 24,
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Icon Header
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_android_rounded,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                const Text(
                  'New Captain Connection Request',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'A waiter phone is requesting permission to connect and take orders.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Device Card Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_pin, size: 22, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              'ID: $id',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              'IP: $ip',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Active Captains: ${provider.captainDevicesUsage} / ${provider.captainDevicesLimit} allowed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: provider.isCaptainDeviceLimitReached ? AppColors.error : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await provider.rejectDevice(id);
                        },
                        child: const Text('Decline Request', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final res = await provider.approveDeviceWithResult(id);
                          if (context.mounted) {
                            if (!res.success && provider.isCaptainDeviceLimitReached) {
                              UpgradeRequestDialog.show(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: res.success ? AppColors.success : AppColors.error,
                                  content: Text(res.success
                                      ? 'Captain "$name" connected & activated!'
                                      : (res.errorMessage ?? 'Failed to approve device.')),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text(
                          'ACCEPT & ACTIVATE',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
              final res = await provider.approveDeviceWithResult(id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res.success
                        ? 'Captain device "$name" approved successfully.'
                        : (res.errorMessage ?? 'Failed to approve device.')),
                    backgroundColor: res.success ? AppColors.success : AppColors.error,
                    duration: Duration(seconds: res.success ? 3 : 6),
                    action: !res.success
                        ? SnackBarAction(
                            label: 'Upgrade Limits',
                            textColor: Colors.yellowAccent,
                            onPressed: () => UpgradeRequestDialog.show(context),
                          )
                        : null,
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

  Widget _buildPendingCancelRequestBanner(BuildContext context, CounterProvider provider, Map<String, dynamic> req) {
    final reqId = req['id']?.toString() ?? '';
    final tableName = req['tableName']?.toString() ?? req['tableId']?.toString() ?? 'Table';
    final itemName = req['itemName']?.toString();
    final itemQty = req['itemQuantity']?.toString() ?? '1';
    final reason = req['reason']?.toString() ?? 'Customer requested cancellation';
    final isItem = itemName != null && itemName.isNotEmpty;

    return Container(
      width: double.infinity,
      color: const Color(0xFFB91C1C), // Vivid red-amber alert
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'TABLE $tableName',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isItem ? 'CANCELLATION REQUEST: "$itemName (x$itemQty)"' : 'WHOLE ORDER CANCELLATION REQUEST',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Reason: "$reason" • Awaiting Counter Manager approval to halt kitchen preparation.',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFB91C1C),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () async {
              final ok = await provider.approveCancelRequest(reqId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Cancellation approved! Kitchen cancellation ticket printed.' : 'Failed to approve cancellation.'),
                    backgroundColor: ok ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            icon: const Icon(Icons.check, size: 16),
            label: const Text('ACCEPT & CANCEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () async {
              await provider.rejectCancelRequest(reqId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cancellation request rejected.'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            child: const Text('Reject', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
