import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/printer_model.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';
import '../services/mock_counter_data.dart';

class PrinterSettingsView extends StatefulWidget {
  const PrinterSettingsView({super.key});

  @override
  State<PrinterSettingsView> createState() => _PrinterSettingsViewState();
}

class _PrinterSettingsViewState extends State<PrinterSettingsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CounterProvider>();
      if (provider.discoveredPrinters.isEmpty && !provider.isDiscoveringPrinters) {
        provider.autoDiscoverPrinters();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CounterProvider>();
    final printerList = provider.printers.isNotEmpty
        ? provider.printers
        : MockCounterData.getPrinters();
    final displayPrinters = provider.isSinglePrinterMode
        ? [printerList.firstWhere((p) => p.role == PrinterRole.counterBill, orElse: () => printerList.first)]
        : printerList;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final padding = isMobile ? 12.0 : 24.0;

        return Container(
          color: AppColors.background,
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thermal Printers',
                          style: TextStyle(
                            fontSize: isMobile ? 19 : 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Automatic Wi-Fi, Ethernet & USB Detection (Zero IP addresses or drivers needed for Wi-Fi)',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: provider.isDiscoveringPrinters
                        ? null
                        : () async {
                            await provider.autoDiscoverPrinters();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.success,
                                  content: Text(
                                    provider.discoveredPrinters.isNotEmpty
                                        ? 'Found ${provider.discoveredPrinters.length} thermal printers (Wi-Fi & USB ready)!'
                                        : 'Scan complete. If using a Wi-Fi printer, ensure it is powered on and connected to this Wi-Fi.',
                                  ),
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                    icon: provider.isDiscoveringPrinters
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.wifi_find, size: 18),
                    label: Text(provider.isDiscoveringPrinters ? 'Scanning...' : 'Auto-Detect Connected Printers'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 2-Option Mode Selector
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune, size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'PRINTER SETUP MODE',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => provider.setPrinterMode('single'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: provider.isSinglePrinterMode ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: provider.isSinglePrinterMode ? AppColors.primary : AppColors.border,
                                  width: provider.isSinglePrinterMode ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    provider.isSinglePrinterMode ? Icons.radio_button_checked : Icons.radio_button_off,
                                    size: 18,
                                    color: provider.isSinglePrinterMode ? AppColors.primary : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('1. Single Printer Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text(
                                          'Customer Bills and Kitchen KOTs all print to one counter thermal printer.',
                                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => provider.setPrinterMode('double'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: !provider.isSinglePrinterMode ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: !provider.isSinglePrinterMode ? AppColors.primary : AppColors.border,
                                  width: !provider.isSinglePrinterMode ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    !provider.isSinglePrinterMode ? Icons.radio_button_checked : Icons.radio_button_off,
                                    size: 18,
                                    color: !provider.isSinglePrinterMode ? AppColors.primary : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('2. Two Printers Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text(
                                          'Customer Bills print at Counter, and Kitchen KOTs print separately in the Kitchen.',
                                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Printers Grid
              Expanded(
                child: isMobile
                    ? ListView.separated(
                        itemCount: displayPrinters.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _buildPrinterCard(
                          context,
                          provider,
                          displayPrinters[index],
                          isMobile: true,
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: displayPrinters.map((printer) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: _buildPrinterCard(
                                context,
                                provider,
                                printer,
                                isMobile: false,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrinterCard(
    BuildContext context,
    CounterProvider provider,
    ThermalPrinterConfig printer, {
    required bool isMobile,
  }) {
    final isBill = printer.role == PrinterRole.counterBill;
    final lastTestStr = printer.lastTestPrintAt != null
        ? DateFormat('hh:mm a').format(printer.lastTestPrintAt!)
        : 'Never tested';

    final isEthernet = printer.address.contains(':');

    String displayName = printer.name;
    if (isEthernet) {
      displayName = isBill ? 'Counter Wi-Fi Thermal Printer' : 'Kitchen Wi-Fi Thermal Printer';
    } else if (printer.address.isNotEmpty && !printer.address.contains(':')) {
      displayName = printer.address;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isBill ? AppColors.primary : const Color(0xFFE65100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isBill ? Icons.receipt_long : Icons.kitchen,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      printer.role.label,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      displayName,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: printer.isConnected ? AppColors.successBg : AppColors.errorBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: printer.isConnected ? AppColors.success : AppColors.error),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: printer.isConnected ? AppColors.success : AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      printer.isConnected ? 'READY' : 'OFFLINE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: printer.isConnected ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(color: AppColors.borderLight, height: 20),

          // Configuration Details (Zero IP Jargon)
          _buildConfigItem(
            'Assigned Printer',
            displayName,
            isEthernet ? Icons.wifi : Icons.print,
          ),
          const SizedBox(height: 8),
          _buildConfigItem(
            'Connection Type',
            isEthernet ? 'Wi-Fi / Ethernet Network (No Drivers Needed)' : 'USB Cable (Windows Spooler)',
            isEthernet ? Icons.wifi_protected_setup : Icons.usb,
          ),
          const SizedBox(height: 8),
          _buildConfigItem('Paper Roll Width', '${printer.paperWidthMm}mm Standard Thermal Roll', Icons.straighten),
          const SizedBox(height: 8),
          _buildConfigItem('Last Test Print', lastTestStr, Icons.history),

          if (isMobile)
            const SizedBox(height: 16)
          else
            const Spacer(),

          const Divider(color: AppColors.borderLight, height: 20),

          // Action Buttons: Send Test Print & Choose Printer
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: provider.isLicenseLocked
                      ? null
                      : () async {
                          await provider.testPrint(printer.role);
                          if (context.mounted) {
                            final updated = provider.printers
                                .where((p) => p.role == printer.role)
                                .firstOrNull;
                            final succeeded = updated?.isConnected ?? false;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: succeeded ? AppColors.success : AppColors.error,
                                content: Row(
                                  children: [
                                    Icon(
                                      succeeded ? Icons.check_circle : Icons.error_outline,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        succeeded
                                            ? 'Test slip printed successfully on $displayName!'
                                            : 'Failed to print test ticket. Ensure printer is powered on and connected.',
                                      ),
                                    ),
                                  ],
                                ),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Send Test Print'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showSelectPrinterDialog(context, provider, printer),
                icon: const Icon(Icons.touch_app, size: 16),
                label: const Text('Select Printer'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSelectPrinterDialog(
    BuildContext context,
    CounterProvider provider,
    ThermalPrinterConfig printer,
  ) async {
    if (provider.discoveredPrinters.isEmpty) {
      await provider.autoDiscoverPrinters();
    }
    if (!context.mounted) return;

    final discovered = provider.discoveredPrinters;
    int selectedWidth = printer.paperWidthMm;
    final manualIpController = TextEditingController(text: printer.address.contains(':') ? printer.address : '');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              title: Row(
                children: [
                  const Icon(Icons.print, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select ${printer.role.label}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const Text('Choose from auto-detected Wi-Fi and USB printers', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (discovered.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.textSecondary),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No printers auto-detected yet. You can tap "Scan Again" or type the printer IP below.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Available Detected Printers:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      for (final p in discovered) ...[
                        InkWell(
                          onTap: () async {
                            final target = (p['target'] ?? '').toString();
                            await provider.updatePrinterAddress(printer.role, target, selectedWidth);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.success,
                                  content: Text('Assigned "${p['name']}" to ${printer.role.label}!'),
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: printer.address == p['target']
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: printer.address == p['target'] ? AppColors.primary : AppColors.border,
                                width: printer.address == p['target'] ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  p['type'] == 'network' ? Icons.wifi : Icons.usb,
                                  color: p['type'] == 'network' ? const Color(0xFF0284C7) : AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['name']?.toString() ?? 'Printer',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                      Text(
                                        p['type'] == 'network'
                                            ? 'Connected via Wi-Fi / LAN (No Drivers Needed)'
                                            : 'Connected via USB Cable (Windows Spooler)',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                if (printer.address == p['target'])
                                  const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    // Manual IP Entry Box (e.g., from feed self-test slip 192.168.1.45)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Or Enter Thermal Printer IP directly (from Self-Test Slip):',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: manualIpController,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 192.168.1.45 or 192.168.1.45:9100',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    fillColor: Colors.white,
                                    filled: true,
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  String input = manualIpController.text.trim();
                                  if (input.isNotEmpty) {
                                    if (!input.contains(':')) {
                                      input = '$input:9100';
                                    }
                                    await provider.updatePrinterAddress(printer.role, input, selectedWidth);
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: AppColors.success,
                                          content: Text('Saved "${printer.role.label}" target: $input!'),
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                child: const Text('Connect', style: TextStyle(fontSize: 12, color: Colors.white)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            await provider.autoDiscoverPrinters();
                            setDialogState(() {});
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Scan Again'),
                        ),
                        Row(
                          children: [
                            const Text('Paper Width: ', style: TextStyle(fontSize: 12)),
                            DropdownButton<int>(
                              value: selectedWidth,
                              items: const [
                                DropdownMenuItem(value: 80, child: Text('80mm (3-inch)')),
                                DropdownMenuItem(value: 58, child: Text('58mm (2-inch)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => selectedWidth = val);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildConfigItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
