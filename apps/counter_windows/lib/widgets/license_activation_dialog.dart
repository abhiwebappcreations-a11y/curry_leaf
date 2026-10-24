import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../providers/counter_provider.dart';
import 'upgrade_request_dialog.dart';

void showLicenseActivationDialog(BuildContext context, CounterProvider provider) {
  final textController = TextEditingController();
  bool isSubmitting = false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: AppColors.primary),
            SizedBox(width: 8),
            Text('License & Renewal Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Licensed Restaurant: ${provider.restaurantName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Status: ${provider.licenseStatus.toUpperCase()} (${provider.licenseDaysRemaining} days remaining)',
                style: TextStyle(
                  color: provider.isLicenseLocked ? AppColors.error : AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Dishes: ${provider.menuItems.length}/${provider.menuItemsLimit}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    Text('Captains: ${provider.captainDevicesUsage}/${provider.captainDevicesLimit}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    Text('Counters: 1/${provider.counterPcsLimit}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    UpgradeRequestDialog.show(context);
                  },
                  icon: const Icon(Icons.arrow_upward_rounded, size: 14),
                  label: const Text('Request Limits Upgrade', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const Divider(height: 18),
              const Text(
                'Enter License / Renewal Key:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  hintText: 'e.g. HINOPT-LIC-SPICE_GARDEN-MVM6QTE9',
                  prefixIcon: Icon(Icons.vpn_key_outlined, size: 18),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Paste the license key received on WhatsApp or email from Hinopt Cloud to activate or extend subscription by 365 days. No files needed.',
                style: TextStyle(color: Colors.black54, fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: isSubmitting
                ? null
                : () async {
                    final key = textController.text.trim();
                    if (key.isEmpty) return;
                    setState(() => isSubmitting = true);
                    final ok = await provider.activateLicense(key);
                    setState(() => isSubmitting = false);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? 'License successfully activated for "${provider.restaurantName}"!'
                              : 'Failed to activate key. Please verify the license key.'),
                          backgroundColor: ok ? AppColors.success : AppColors.error,
                        ),
                      );
                    }
                  },
            child: isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Activate License'),
          ),
        ],
      ),
    ),
  );
}
