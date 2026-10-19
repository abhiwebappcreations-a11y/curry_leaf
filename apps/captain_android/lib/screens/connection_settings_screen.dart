import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import '../theme/app_colors.dart';

class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  State<ConnectionSettingsScreen> createState() => _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late bool _demoMode;
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    final provider = context.read<PosProvider>();
    _hostController = TextEditingController(text: provider.apiService.host);
    _portController = TextEditingController(text: provider.apiService.port.toString());
    _demoMode = provider.apiService.useDemoMode;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 4000;

    await Future.delayed(const Duration(milliseconds: 600));

    if (_demoMode) {
      setState(() {
        _isTesting = false;
        _testSuccess = true;
        _testResult = 'Demo Mode Active: Simulating local server response perfectly.';
      });
      return;
    }

    final posProvider = context.read<PosProvider>();

    try {
      final success = await posProvider.apiService.checkHealth(customHost: host, customPort: port);
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _testSuccess = success;
        _testResult = success
            ? 'Connected to Counter PC ($host:$port) successfully!'
            : 'Could not connect to $host:$port. Ensure Counter PC is on the same Wi-Fi and port 4000 is open.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _testSuccess = false;
        _testResult = 'Connection error: $e';
      });
    }
  }

  void _saveSettings() {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 4000;

    context.read<PosProvider>().updateServerConfig(host, port, _demoMode);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connection configuration saved.'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter Connection Setup'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.wifi, color: AppColors.info, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Captain devices connect directly to the Counter PC via local restaurant Wi-Fi/LAN. Internet access is not required for daily order taking.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.info,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Demo Mode Switch
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: SwitchListTile(
              title: const Text(
                'Demo / Standalone Mode',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Use built-in mock data when Counter PC backend is not running.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              value: _demoMode,
              activeThumbColor: AppColors.accent,
              activeTrackColor: AppColors.primary,
              onChanged: (val) {
                setState(() => _demoMode = val);
              },
            ),
          ),

          const SizedBox(height: 20),

          // Host input
          const Text(
            'Counter PC Local IP Address',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _hostController,
            enabled: !_demoMode,
            decoration: const InputDecoration(
              hintText: 'e.g. 192.168.1.100 or 127.0.0.1',
              prefixIcon: Icon(Icons.computer, size: 20),
            ),
          ),

          const SizedBox(height: 16),

          // Port input
          const Text(
            'Counter Local API Port',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _portController,
            enabled: !_demoMode,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '4000',
              prefixIcon: Icon(Icons.numbers, size: 20),
            ),
          ),

          const SizedBox(height: 20),

          // Test button
          OutlinedButton.icon(
            onPressed: _isTesting ? null : _testConnection,
            icon: _isTesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check),
            label: const Text('Test Connection to Counter PC'),
          ),

          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _testSuccess == true ? AppColors.successBg : AppColors.errorBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _testSuccess == true ? AppColors.success : AppColors.error,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _testSuccess == true ? Icons.check_circle : Icons.error,
                    color: _testSuccess == true ? AppColors.success : AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _testSuccess == true ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Save button
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Save & Apply Settings'),
          ),
        ],
      ),
    );
  }
}
