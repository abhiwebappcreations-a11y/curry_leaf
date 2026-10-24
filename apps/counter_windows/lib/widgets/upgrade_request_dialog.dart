import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';

class UpgradeRequestDialog extends StatefulWidget {
  const UpgradeRequestDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const UpgradeRequestDialog(),
    );
  }

  @override
  State<UpgradeRequestDialog> createState() => _UpgradeRequestDialogState();
}

class _UpgradeRequestDialogState extends State<UpgradeRequestDialog> {
  late TextEditingController _menuItemsCtrl;
  late TextEditingController _captainsCtrl;
  late TextEditingController _countersCtrl;
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<CounterProvider>();
    // Default to current + reasonable expansion
    _menuItemsCtrl = TextEditingController(text: '${provider.menuItemsLimit + 50}');
    _captainsCtrl = TextEditingController(text: '${provider.captainDevicesLimit + 3}');
    _countersCtrl = TextEditingController(text: '${provider.counterPcsLimit}');
  }

  @override
  void dispose() {
    _menuItemsCtrl.dispose();
    _captainsCtrl.dispose();
    _countersCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CounterProvider>();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_upward_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request License Limits Upgrade',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Submit limit expansion directly to Hinopt Cloud Admin',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Limits Overview Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT ACTIVE LIMITS (${provider.restaurantName})',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildCurrentMetric('Menu Dishes', '${provider.menuItems.length} / ${provider.menuItemsLimit}', provider.isMenuItemLimitReached),
                        _buildCurrentMetric('Captains', '${provider.captainDevicesUsage} / ${provider.captainDevicesLimit}', provider.isCaptainDeviceLimitReached),
                        _buildCurrentMetric('Counters', '1 / ${provider.counterPcsLimit}', false),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Requested New Limits:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),

              // Inputs in a Row for limits
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Dishes Max', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _menuItemsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Captains Max', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _captainsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Counters Max', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _countersCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Contact Phone
              const Text(
                'Contact Phone / WhatsApp Number *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _phoneCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. +91 98490 12345',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 16),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),

              // Reason / Notes
              const Text(
                'Upgrade Reason / Business Notes (Optional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. Expanding banquet floor, require 5 additional captain devices.',
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 16),
          label: Text(_isSubmitting ? 'Submitting...' : 'Send Upgrade Request'),
        ),
      ],
    );
  }

  Widget _buildCurrentMetric(String label, String value, bool isLimitHit) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isLimitHit ? const Color(0xFFFFEBEE) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isLimitHit ? AppColors.error : AppColors.border),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isLimitHit ? AppColors.error : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final provider = context.read<CounterProvider>();
    final menuItems = int.tryParse(_menuItemsCtrl.text.trim()) ?? (provider.menuItemsLimit + 50);
    final captains = int.tryParse(_captainsCtrl.text.trim()) ?? (provider.captainDevicesLimit + 3);
    final counters = int.tryParse(_countersCtrl.text.trim()) ?? provider.counterPcsLimit;
    final phone = _phoneCtrl.text.trim();
    final notes = _notesCtrl.text.trim();

    setState(() => _isSubmitting = true);

    final res = await provider.submitUpgradeRequest(
      requestedMenuItems: menuItems,
      requestedCaptainDevices: captains,
      requestedCounterPcs: counters,
      contactPhone: phone,
      notes: notes,
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.success
              ? 'Upgrade request sent to Hinopt Cloud! Our team will approve shortly.'
              : (res.message ?? 'Failed to submit upgrade request')),
          backgroundColor: res.success ? AppColors.success : AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
