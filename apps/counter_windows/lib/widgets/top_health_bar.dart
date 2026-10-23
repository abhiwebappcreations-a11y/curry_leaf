import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';
import 'server_connection_dialog.dart';

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

                  // Thermal Printers Status
                  _buildHealthIndicator(
                    label: 'Printers: Ready',
                    isOk: (provider.billPrinter?.isConnected ?? true),
                    icon: Icons.print_outlined,
                  ),
                  const SizedBox(width: 8),

                  // Subscription Status
                  _buildHealthIndicator(
                    label: 'Active (${provider.licenseDaysRemaining}d)',
                    isOk: !provider.isLicenseLocked,
                    icon: Icons.verified_user_outlined,
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
