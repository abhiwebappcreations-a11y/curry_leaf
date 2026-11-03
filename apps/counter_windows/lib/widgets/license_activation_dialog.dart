import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
              if (provider.isLicenseLocked) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    border: Border.all(color: AppColors.error),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Unlicensed System: Enter your Hinopt license key below to activate in real time.',
                          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Text(
                'Licensed Restaurant: ${provider.restaurantName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (provider.ownerName.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  'Owner / Contact: ${provider.ownerName}${provider.city.isNotEmpty ? " (${provider.city})" : ""}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.memory, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'HWID: ${provider.hardwareId.isNotEmpty ? provider.hardwareId : "Detecting..."}',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (provider.hardwareId.isNotEmpty)
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: provider.hardwareId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Hardware ID copied to clipboard!'), duration: Duration(seconds: 2)),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            children: [
                              Icon(Icons.copy, size: 12, color: AppColors.primary),
                              SizedBox(width: 2),
                              Text('Copy', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
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
