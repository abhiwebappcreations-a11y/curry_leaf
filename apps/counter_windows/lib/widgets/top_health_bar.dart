import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';
import 'takeaway_order_dialog.dart';
import 'server_connection_dialog.dart';
import 'backup_restore_dialog.dart';
import 'license_activation_dialog.dart';

class TopHealthBar extends StatefulWidget {
  final bool showMenuButton;
  const TopHealthBar({super.key, this.showMenuButton = false});

  @override
  State<TopHealthBar> createState() => _TopHealthBarState();
}

class _TopHealthBarState extends State<TopHealthBar> {
  late Timer _timer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime = DateFormat('EEE, dd MMM • hh:mm:ss a').format(now);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CounterProvider>();

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.primaryDark,
        border: Border(bottom: BorderSide(color: Color(0xFF1E3A39), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (widget.showMenuButton) ...[
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                tooltip: 'Open Navigation',
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Modern Brand Section
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 1),
                ),
                child: const Icon(Icons.restaurant, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        provider.restaurantName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Subtle live status dot
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: provider.localServerHealthy
                              ? const Color(0xFF10B981).withValues(alpha: 0.2)
                              : Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: provider.localServerHealthy ? const Color(0xFF10B981) : Colors.red,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: provider.localServerHealthy ? const Color(0xFF10B981) : Colors.red,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              provider.localServerHealthy ? 'ONLINE' : 'OFFLINE',
                              style: TextStyle(
                                color: provider.localServerHealthy ? const Color(0xFF6EE7B7) : Colors.redAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (provider.ownerName.isNotEmpty)
                    Text(
                      '${provider.ownerName}${provider.city.isNotEmpty ? " • ${provider.city}" : ""}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(width: 20),

          // Central Quick Actions (App-like POS Workflow)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // 1. Prominent Takeaway / Parcel Button (Accessible ANYWHERE)
                  ElevatedButton.icon(
                    onPressed: () => TakeawayOrderDialog.show(context, provider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                    label: const Text(
                      '+ Takeaway / Parcel',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 2. Floor Tables Shortcut
                  OutlinedButton.icon(
                    onPressed: () => provider.setActiveTab(CounterTab.tables),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: provider.activeTab == CounterTab.tables ? AppColors.accent : Colors.white24,
                        width: 1,
                      ),
                      backgroundColor: provider.activeTab == CounterTab.tables
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.table_restaurant, size: 15, color: AppColors.accent),
                    label: const Text(
                      'Tables',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 3. Billing & Till Shortcut
                  OutlinedButton.icon(
                    onPressed: () => provider.setActiveTab(CounterTab.billing),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: provider.activeTab == CounterTab.billing ? AppColors.accent : Colors.white24,
                        width: 1,
                      ),
                      backgroundColor: provider.activeTab == CounterTab.billing
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.point_of_sale, size: 15, color: AppColors.accent),
                    label: const Text(
                      'Billing',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // GST Mode Toggle Pill
                  InkWell(
                    onTap: () => provider.toggleGst(),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: provider.isGstEnabled
                            ? AppColors.primaryLight.withValues(alpha: 0.3)
                            : Colors.orange.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: provider.isGstEnabled
                              ? AppColors.accent.withValues(alpha: 0.6)
                              : Colors.orangeAccent.withValues(alpha: 0.6),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            provider.isGstEnabled ? Icons.receipt_long : Icons.money_off,
                            size: 14,
                            color: provider.isGstEnabled ? AppColors.accent : Colors.orangeAccent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            provider.isGstEnabled
                                ? 'GST: ${provider.gstRatePercent.toStringAsFixed(0)}%'
                                : 'NON-GST (0%)',
                            style: TextStyle(
                              color: provider.isGstEnabled ? Colors.white : Colors.orangeAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Right Section: Diagnostics Pill & Live Clock
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // System Health & Diagnostics Pill (replaces 6 raw engineering widgets)
              InkWell(
                onTap: () => _showSystemDiagnosticsModal(context, provider),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        provider.localServerHealthy ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                        size: 15,
                        color: provider.localServerHealthy ? AppColors.accent : Colors.amberAccent,
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Diagnostics',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      if (provider.hasPendingDevices) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${provider.pendingDevices.length}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Refresh Button
              Tooltip(
                message: 'Refresh Tables & Orders',
                child: InkWell(
                  onTap: provider.isRefreshing
                      ? null
                      : () => provider.refreshFromLiveApi(isManual: true),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
                    ),
                    child: provider.isRefreshing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                          )
                        : const Icon(Icons.refresh, size: 16, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Live Clock
              Text(
                _currentTime,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSystemDiagnosticsModal(BuildContext context, CounterProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.tune, color: AppColors.accent, size: 24),
            SizedBox(width: 10),
            Text('System Health & Terminal Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Network Status Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            provider.localServerHealthy ? Icons.cloud_done : Icons.cloud_off,
                            color: provider.localServerHealthy ? AppColors.success : AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            provider.localServerHealthy ? 'Local POS Server: Online' : 'Local POS Server: Offline',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              showDialog(
                                context: context,
                                builder: (_) => ServerConnectionDialog(provider: provider),
                              );
                            },
                            child: const Text('Change Host'),
                          ),
                        ],
                      ),
                      const Divider(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.wifi, color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Wi-Fi LAN IP: ${provider.lanHost}:4000\nCaptain phones auto-discover this PC on Wi-Fi.',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ),
                          if (provider.hasPendingDevices)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${provider.pendingDevices.length} Pending Devices',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Thermal Printers Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.print_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Thermal Printers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            Text(
                              'Mode: ${provider.isSinglePrinterMode ? "Single Shared Printer" : "Dual (Counter & Kitchen)"}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          provider.setActiveTab(CounterTab.printers);
                        },
                        child: const Text('Printer Settings'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // USB Backup Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.usb_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Database Backup & Restore', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            Text('Export snapshot to USB flash drive or restore', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          showDialog(
                            context: context,
                            builder: (_) => BackupRestoreDialog(provider: provider),
                          );
                        },
                        child: const Text('Backup & USB'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // License Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_outlined, color: AppColors.accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.isLicenseLocked ? 'Unlicensed' : 'Active License (${provider.licenseDaysRemaining} days remaining)',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            Text('Terminal: ${provider.restaurantName}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          showLicenseActivationDialog(context, provider);
                        },
                        child: const Text('License Details'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
