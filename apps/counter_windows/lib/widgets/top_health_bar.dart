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
          // Brand Logo & Restaurant
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restaurant, color: AppColors.accent, size: 20),
              SizedBox(width: 8),
              Text(
                'Hinopt POS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(width: 8),
              Text(
                '|  Curry Leaf',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),

          // Scrollable System Health Pills & Clock
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _showServerDialog(context, provider),
                    borderRadius: BorderRadius.circular(6),
                    child: _buildHealthIndicator(
                      label: 'Server: ${provider.serverHost}',
                      isOk: provider.localServerHealthy,
                      icon: Icons.dns_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildHealthIndicator(
                    label: 'PostgreSQL: OK',
                    isOk: provider.databaseHealthy,
                    icon: Icons.storage_outlined,
                  ),
                  const SizedBox(width: 8),
                  _buildHealthIndicator(
                    label: 'Bill: ${provider.billPrinter?.name.split(" ").first ?? "OK"}',
                    isOk: provider.billPrinter?.isConnected ?? false,
                    icon: Icons.print_outlined,
                  ),
                  const SizedBox(width: 8),
                  _buildHealthIndicator(
                    label: 'KOT: ${provider.kotPrinter?.name.split(" ").first ?? "OK"}',
                    isOk: provider.kotPrinter?.isConnected ?? false,
                    icon: Icons.kitchen_outlined,
                  ),
                  const SizedBox(width: 8),
                  _buildHealthIndicator(
                    label: 'License: ${provider.licenseDaysRemaining}d',
                    isOk: true,
                    icon: Icons.verified_user_outlined,
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Refresh Live Orders & Tables',
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
      barrierDismissible: true,
      builder: (dialogCtx) => ServerConnectionDialog(provider: provider),
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
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOk
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.error.withValues(alpha: 0.4),
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
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
