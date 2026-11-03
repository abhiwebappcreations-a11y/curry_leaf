import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/table_card.dart';
import '../widgets/connection_badge.dart';
import 'order_screen.dart';
import 'kot_status_screen.dart';
import 'connection_settings_screen.dart';

class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PosProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.restaurant_menu, size: 22, color: AppColors.accent),
            SizedBox(width: 8),
            Text(
              'Hinopt Captain',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
            ),
          ],
        ),
        actions: [
          const ConnectionBadge(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            tooltip: 'KOT History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const KotStatusScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConnectionSettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: (!provider.isNameConfigured && !provider.apiService.useDemoMode)
          ? _buildDeviceNamePromptScreen(context, provider)
          : provider.isLimitExceeded
              ? _buildLimitExceededScreen(context, provider)
              : !provider.isPairingApproved
                  ? (provider.isPairingPending
                      ? _buildPairingPendingScreen(context, provider)
                      : _buildConnectionErrorScreen(context, provider))
                  : Column(
                      children: [
                        // Quick Operational Metrics Bar
                        Container(
                          color: AppColors.surface,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              _buildMetricChip(
                                label: 'Free Tables',
                                count: provider.availableTableCount,
                                color: AppColors.success,
                                bgColor: AppColors.successBg,
                              ),
                              const SizedBox(width: 8),
                              _buildMetricChip(
                                label: 'Occupied',
                                count: provider.occupiedTableCount,
                                color: AppColors.info,
                                bgColor: AppColors.infoBg,
                              ),
                              const SizedBox(width: 8),
                              _buildMetricChip(
                                label: 'Total Tables',
                                count: provider.tables.length,
                                color: AppColors.primary,
                                bgColor: AppColors.surfaceMuted,
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 1),

                        // Area / Section Filter Tabs
                        Container(
                          color: AppColors.surface,
                          height: 48,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: provider.availableSections.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final section = provider.availableSections[index];
                              final isSelected = provider.selectedSection == section;

                              return ChoiceChip(
                                label: Text(section),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.surfaceMuted,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                                side: BorderSide(
                                  color: isSelected ? AppColors.primary : AppColors.border,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                onSelected: (_) {
                                  provider.setSection(section);
                                },
                              );
                            },
                          ),
                        ),

                        const Divider(height: 1),

                        // Floor Plan Grid of Tables
                        Expanded(
                          child: provider.isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : provider.filteredTables.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No tables match this section',
                                        style: TextStyle(color: AppColors.textSecondary),
                                      ),
                                    )
                                  : RefreshIndicator(
                                      onRefresh: () async {
                                        await provider.pollLatestState();
                                      },
                                      child: GridView.builder(
                                        padding: const EdgeInsets.all(16),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                          childAspectRatio: 1.15,
                                        ),
                                        itemCount: provider.filteredTables.length,
                                        itemBuilder: (context, index) {
                                          final table = provider.filteredTables[index];

                                          return TableCard(
                                            table: table,
                                            onTap: () async {
                                              provider.selectTable(table);
                                              await Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => const OrderScreen(),
                                                ),
                                              );
                                              provider.clearSelectedTable();
                                            },
                                          );
                                        },
                                      ),
                                    ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildDeviceNamePromptScreen(BuildContext context, PosProvider provider) {
    final nameController = TextEditingController(
      text: provider.deviceName == 'Captain Phone' ? '' : provider.deviceName,
    );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.badge_rounded, size: 38, color: AppColors.primary),
              ),
              const SizedBox(height: 18),
              const Text(
                'Waiter Device Registration',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Connecting to Counter POS (${provider.apiService.host})',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF1D4ED8), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Enter your name or section so the manager on the Counter POS screen can identify and approve your phone.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF1D4ED8), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Waiter / Captain Name *',
                  hintText: 'e.g. Ramesh (Captain 1), Suresh, Patio Section',
                  prefixIcon: const Icon(Icons.person_pin_rounded, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_tethering, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Counter IP: ${provider.apiService.host}:${provider.apiService.port}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ConnectionSettingsScreen()),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text('Edit', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final entered = nameController.text.trim();
                    if (entered.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a name to send request')),
                      );
                      return;
                    }
                    provider.updateDeviceName(entered);
                  },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Send Connection Request', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConnectionSettingsScreen()),
                ),
                icon: const Icon(Icons.settings, size: 16),
                label: const Text('Change Connection Settings', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPairingPendingScreen(BuildContext context, PosProvider provider) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_tethering, size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: 18),
              const Text(
                'New Device Detected',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Connected to Counter on Wi-Fi (${provider.apiService.host})',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Waiting for Approval',
                          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.warning, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please look at the Counter POS screen.\nA notification appeared asking the manager to activate this phone.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textPrimary, height: 1.3),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Device: ${provider.deviceName}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => provider.promptRename(),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 12, color: AppColors.primary),
                                SizedBox(width: 2),
                                Text('Edit', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConnectionSettingsScreen()),
                ),
                icon: const Icon(Icons.settings, size: 16),
                label: const Text('Change Connection Settings', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionErrorScreen(BuildContext context, PosProvider provider) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.warningBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded, size: 36, color: AppColors.warning),
              ),
              const SizedBox(height: 18),
              const Text(
                'Connecting to Counter POS',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Target: http://${provider.apiService.host}:${provider.apiService.port}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  provider.pairingMessage ??
                      'Ensure this phone and the Counter POS PC are connected to the same Wi-Fi router / network.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.35),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => provider.sendPairingRequest(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry Connection', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConnectionSettingsScreen()),
                ),
                icon: const Icon(Icons.settings, size: 16),
                label: const Text('Configure Counter IP & Port', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLimitExceededScreen(BuildContext context, PosProvider provider) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_clock, size: 38, color: AppColors.error),
              ),
              const SizedBox(height: 18),
              const Text(
                'Device Limit Reached',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.error),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hinopt License Enforcement',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.workspace_premium_outlined, color: Color(0xFFEA580C), size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Upgrade License Required',
                          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFEA580C), fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      provider.pairingMessage ??
                          'The restaurant has reached the maximum allowed Captain devices under its active Hinopt license.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.35),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'To connect additional captain phones, ask your manager to request a license upgrade in Hinopt Admin.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 1,
                ),
                onPressed: () => _showCaptainUpgradeDialog(context, provider),
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                label: const Text('Request Limit Upgrade Now', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => provider.pollLatestState(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Check Status Again', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 38),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConnectionSettingsScreen()),
                ),
                icon: const Icon(Icons.settings, size: 16),
                label: const Text('Connection Settings', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCaptainUpgradeDialog(BuildContext context, PosProvider provider) {
    final countController = TextEditingController(text: '8');
    final phoneController = TextEditingController();
    final notesController = TextEditingController(text: 'Requesting extra captain phones from waiter terminal');
    bool isSending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: Color(0xFFEA580C), size: 24),
              SizedBox(width: 8),
              Text('Request Limit Upgrade', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Submit a request directly to Hinopt Admin to increase active captain devices for this restaurant.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: countController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total Captain Devices Needed *',
                    hintText: 'e.g. 8 or 10',
                    prefixIcon: Icon(Icons.phone_android),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact Phone / WhatsApp',
                    hintText: 'e.g. +91 98765 43210',
                    prefixIcon: Icon(Icons.phone),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason / Notes',
                    hintText: 'e.g. Weekend crowd, adding outdoor section',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
              ),
              onPressed: isSending
                  ? null
                  : () async {
                      final count = int.tryParse(countController.text.trim()) ?? 8;
                      setDialogState(() => isSending = true);

                      final res = await provider.apiService.submitUpgradeRequest(
                        requestedCaptains: count,
                        contactPhone: phoneController.text.trim(),
                        notes: notesController.text.trim(),
                      );

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: res.success ? AppColors.success : AppColors.error,
                            content: Text(res.message),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                        provider.pollLatestState();
                      }
                    },
              child: isSending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Send Request', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
