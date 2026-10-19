import 'package:flutter/material.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';

class ServerConnectionDialog extends StatefulWidget {
  final CounterProvider provider;

  const ServerConnectionDialog({
    super.key,
    required this.provider,
  });

  @override
  State<ServerConnectionDialog> createState() => _ServerConnectionDialogState();
}

class _ServerConnectionDialogState extends State<ServerConnectionDialog> {
  late TextEditingController _hostController;
  late TextEditingController _portController;

  bool _isTesting = false;
  bool? _testSuccess;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.provider.serverHost);
    _portController = TextEditingController(text: widget.provider.serverPort.toString());

    _hostController.addListener(_onInputChanged);
    _portController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _hostController.removeListener(_onInputChanged);
    _portController.removeListener(_onInputChanged);
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _handleTestConnection() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 4000;

    if (host.isEmpty) {
      setState(() {
        _testSuccess = false;
        _testMessage = 'Please enter a valid IP address or hostname.';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testSuccess = null;
      _testMessage = null;
    });

    final isHealthy = await widget.provider.testServerConnection(host, port);

    if (!mounted) return;

    setState(() {
      _isTesting = false;
      _testSuccess = isHealthy;
      if (isHealthy) {
        _testMessage = 'Connection Successful! Local POS server responded at http://$host:$port/api/health';
      } else {
        _testMessage = 'Could not connect to http://$host:$port/api/health. Please ensure the local API backend is running.';
      }
    });
  }

  void _applyPreset(String host, int port) {
    setState(() {
      _hostController.text = host;
      _portController.text = port.toString();
      _testSuccess = null;
      _testMessage = null;
    });
  }

  void _handleSaveAndConnect() {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 4000;

    if (host.isEmpty) {
      setState(() {
        _testSuccess = false;
        _testMessage = 'Please enter a valid IP address or hostname.';
      });
      return;
    }

    widget.provider.setServerHost(host, port);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Server set to http://$host:$port/api. Connecting...',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      elevation: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.dns_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'POS Server Connection',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Configure the local API server host and port for this terminal.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                      splashRadius: 18,
                      tooltip: 'Close',
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: AppColors.borderLight, height: 1),
                const SizedBox(height: 16),

                // 2. Live Connection Status Card (Reactive via ListenableBuilder)
                ListenableBuilder(
                  listenable: widget.provider,
                  builder: (context, _) {
                    final isConnected = widget.provider.localServerHealthy;
                    final activeUrl = 'http://${widget.provider.serverHost}:${widget.provider.serverPort}/api';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isConnected ? AppColors.successBg : AppColors.warningBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isConnected
                              ? AppColors.success.withValues(alpha: 0.4)
                              : AppColors.warning.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isConnected
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.warning.withValues(alpha: 0.15),
                            ),
                            child: Icon(
                              isConnected ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                              color: isConnected ? AppColors.success : AppColors.warning,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isConnected ? AppColors.success : AppColors.warning,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        isConnected
                                            ? 'Status: Connected to Local API'
                                            : 'Status: Server Disconnected / Unreachable',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isConnected ? AppColors.success : AppColors.warning,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isConnected
                                      ? 'Active URL: $activeUrl'
                                      : 'Active URL: $activeUrl (Unreachable)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 18),

                // 1. High-Contrast Server IP Field
                const Text(
                  'Server IP / Hostname',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _hostController,
                  cursorColor: AppColors.primary,
                  cursorWidth: 2.0,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                    letterSpacing: 0.3,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF7FAFA),
                    hintText: 'e.g. 127.0.0.1 or 192.168.1.100',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: const Icon(Icons.computer_rounded, color: AppColors.primary, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 1. High-Contrast Port Field
                const Text(
                  'Port Number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  cursorColor: AppColors.primary,
                  cursorWidth: 2.0,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                    letterSpacing: 0.3,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF7FAFA),
                    hintText: '4000',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: const Icon(Icons.numbers_rounded, color: AppColors.primary, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 4. Quick Selection Presets
                const Text(
                  'Quick Presets:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPresetChip('127.0.0.1 (This Counter PC)', '127.0.0.1', 4000),
                    _buildPresetChip('10.0.2.2 (Emulator)', '10.0.2.2', 4000),
                    _buildPresetChip('192.168.1.100 (LAN)', '192.168.1.100', 4000),
                  ],
                ),

                const SizedBox(height: 16),

                // 3. Inline Test Connection Result (Banner)
                if (_testMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _testSuccess == true ? AppColors.successBg : AppColors.errorBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _testSuccess == true
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.error.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _testSuccess == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                          size: 20,
                          color: _testSuccess == true ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _testSuccess == true ? 'Connection Confirmed' : 'Connection Failed',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _testSuccess == true ? AppColors.success : AppColors.error,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _testMessage!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _testSuccess == true ? AppColors.success : AppColors.error,
                                  height: 1.3,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                const Divider(color: AppColors.borderLight, height: 1),
                const SizedBox(height: 16),

                // 3. Footer Actions: "Test Connection" button + Cancel / Save & Connect
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isTesting ? null : _handleTestConnection,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(Icons.network_check_rounded, size: 16),
                      label: Text(_isTesting ? 'Testing Ping...' : 'Test Connection'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.border, width: 1.2),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _handleSaveAndConnect,
                          icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                          label: const Text(
                            'Save & Connect',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String host, int port) {
    final isSelected = _hostController.text.trim() == host &&
        _portController.text.trim() == port.toString();

    return InkWell(
      onTap: () => _applyPreset(host, port),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFFF0F4F4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_circle_rounded, size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
