import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/table_model.dart';
import '../models/order_model.dart';

class StatusPill extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final IconData? icon;

  const StatusPill({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.icon,
  });

  factory StatusPill.tableStatus(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return const StatusPill(
          label: 'Available',
          textColor: AppColors.success,
          backgroundColor: AppColors.successBg,
          icon: Icons.check_circle_outline,
        );
      case TableStatus.occupied:
        return const StatusPill(
          label: 'Occupied',
          textColor: AppColors.info,
          backgroundColor: AppColors.infoBg,
          icon: Icons.people_outline,
        );
      case TableStatus.billed:
        return const StatusPill(
          label: 'Billed',
          textColor: AppColors.billed,
          backgroundColor: AppColors.billedBg,
          icon: Icons.receipt_long_outlined,
        );
      case TableStatus.reserved:
        return const StatusPill(
          label: 'Reserved',
          textColor: AppColors.warning,
          backgroundColor: AppColors.warningBg,
          icon: Icons.bookmark_border,
        );
    }
  }

  factory StatusPill.orderItemStatus(OrderItemStatus status) {
    switch (status) {
      case OrderItemStatus.draft:
        return const StatusPill(
          label: 'DRAFT',
          textColor: AppColors.textSecondary,
          backgroundColor: AppColors.surfaceMuted,
          icon: Icons.edit_note,
        );
      case OrderItemStatus.sentToKitchen:
        return const StatusPill(
          label: 'SENT TO KITCHEN',
          textColor: AppColors.info,
          backgroundColor: AppColors.infoBg,
          icon: Icons.outdoor_grill_outlined,
        );
      case OrderItemStatus.preparing:
        return const StatusPill(
          label: 'PREPARING',
          textColor: AppColors.warning,
          backgroundColor: AppColors.warningBg,
          icon: Icons.soup_kitchen_outlined,
        );
      case OrderItemStatus.served:
        return const StatusPill(
          label: 'SERVED',
          textColor: AppColors.success,
          backgroundColor: AppColors.successBg,
          icon: Icons.done_all,
        );
      case OrderItemStatus.cancelRequested:
        return const StatusPill(
          label: 'CANCEL REQ',
          textColor: AppColors.warning,
          backgroundColor: AppColors.warningBg,
          icon: Icons.pending_actions,
        );
      case OrderItemStatus.cancelled:
        return const StatusPill(
          label: 'CANCELLED',
          textColor: AppColors.error,
          backgroundColor: AppColors.errorBg,
          icon: Icons.cancel_outlined,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: textColor.withOpacity(0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
