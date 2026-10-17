import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';

class TopHealthBar extends StatefulWidget {
  const TopHealthBar({super.key});

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
                  _buildHealthIndicator(
                    label: 'Server: 127.0.0.1',
                    isOk: provider.localServerHealthy,
                    icon: Icons.dns_outlined,
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

  Widget _buildHealthIndicator({
    required String label,
    required bool isOk,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOk
              ? AppColors.success.withOpacity(0.4)
              : AppColors.error.withOpacity(0.4),
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
