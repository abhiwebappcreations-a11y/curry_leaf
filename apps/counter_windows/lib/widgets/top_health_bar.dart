import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';
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
      _currentTime = DateFormat('EEE, dd MMM yyyy • hh:mm:ss a').format(now);
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
      height: 52,
      decoration: const BoxDecoration(
        color: AppColors.primaryDark,
        border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
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
                tooltip: 'Open Menu',
              ),
            ),
            const SizedBox(width: 12),
          ],
          // Commercial Brand & Restaurant Name (Petpooja style)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restaurant, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                provider.restaurantName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Counter POS',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),

          // Commercial System Status Pills & Live Clock
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // System Online Status (Clickable for network support)
                  InkWell(
                    onTap: () => _showServerDialog(context, provider),
                    borderRadius: BorderRadius.circular(6),
                    child: _buildHealthIndicator(
                      label: provider.localServerHealthy ? 'System: Online' : 'System: Offline',
                      isOk: provider.localServerHealthy,
                      icon: Icons.cloud_done_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Wi-Fi LAN & Captain Auto-Discovery Status
                  InkWell(
                    onTap: () => _showCaptainPairingDialog(context, provider),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_tethering, size: 13, color: AppColors.accent),
                          const SizedBox(width: 4),
                          Text(
                            'Wi-Fi: ${provider.lanHost}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (provider.hasPendingDevices) ...[
                            const SizedBox(width: 5),
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

                  // Thermal Printers Status
                  _buildHealthIndicator(
                    label: 'Printers: Ready',
                    isOk: (provider.billPrinter?.isConnected ?? true),
                    icon: Icons.print_outlined,
                  ),
                  const SizedBox(width: 8),

                  // Subscription Status
                  Tooltip(
                    message: 'Click to view license or enter license key',
                    child: InkWell(
                      onTap: () => showLicenseActivationDialog(context, provider),
                      borderRadius: BorderRadius.circular(6),
                      child: _buildHealthIndicator(
                        label: 'Active (${provider.licenseDaysRemaining}d)',
                        isOk: !provider.isLicenseLocked,
                        icon: Icons.verified_user_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Refresh Button
                  Tooltip(
                    message: 'Refresh Live Tables & Orders',
                    child: InkWell(
                      onTap: provider.isRefreshing
                          ? null
                          : () => provider.refreshFromLiveApi(isManual: true),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (provider.isRefreshing)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  color: AppColors.accent,
                                ),
                              )
                            else
                              const Icon(Icons.refresh, size: 13, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              provider.isRefreshing ? 'Refreshing...' : 'Refresh',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // USB / Disk Backup & Restore Button
                  Tooltip(
                    message: 'Database Backup & USB Restore',
                    child: InkWell(
                      onTap: () => _showBackupDialog(context, provider),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.usb_rounded, size: 13, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Backup & USB',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

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
            ),
          ),
        ],
      ),
    );
  }

  void _showServerDialog(BuildContext context, CounterProvider provider) {
    showDialog(
      context: context,
      builder: (_) => ServerConnectionDialog(
        provider: provider,
      ),
    );
  }

  void _showBackupDialog(BuildContext context, CounterProvider provider) {
    showDialog(
      context: context,
      builder: (_) => BackupRestoreDialog(
        provider: provider,
      ),
    );
  }

  void _showCaptainPairingDialog(BuildContext context, CounterProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.wifi_tethering, color: AppColors.accent, size: 24),
            SizedBox(width: 10),
            Text(
              'Wi-Fi Auto-Discovery & Captain Pairing',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.router_outlined, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Counter Wi-Fi IP: ${provider.lanHost}:4000',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'UDP Auto-Discovery Beacon is active on Port 41234.\nCaptain phones on the same Wi-Fi router will automatically discover this Counter without typing any IP address.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pending Device Requests',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 8),
              if (!provider.hasPendingDevices)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: const Center(
                    child: Text(
                      'No new Captain devices waiting. Open the Captain app on any phone to connect.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...provider.pendingDevices.map((dev) {
                  final devName = dev['deviceName']?.toString() ?? 'Captain Phone';
                  final devId = dev['id']?.toString() ?? '';
                  final devIp = dev['deviceIp']?.toString() ?? 'Wi-Fi';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_android, color: Color(0xFF1D4ED8), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(devName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                              Text('$devId • IP: $devIp', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () {
                            provider.approveDevice(devId);
                            Navigator.pop(ctx);
                          },
                          child: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () {
                            provider.rejectDevice(devId);
                            Navigator.pop(ctx);
                          },
                          child: const Text('Decline', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  );
                }),
            ],
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

  Widget _buildHealthIndicator({
    required String label,
    required bool isOk,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOk ? Colors.white.withValues(alpha: 0.08) : AppColors.errorBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOk ? Colors.white.withValues(alpha: 0.18) : AppColors.error.withValues(alpha: 0.5),
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
              color: isOk ? AppColors.accent : AppColors.error,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 13, color: isOk ? Colors.white70 : AppColors.error),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: isOk ? Colors.white : AppColors.error,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
