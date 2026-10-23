import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/printer_model.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';

class PrinterSettingsView extends StatelessWidget {
  const PrinterSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CounterProvider>();

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thermal Printer Configurations',
                    style: TextStyle(
                      fontSize: isMobile ? 19 : 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isMobile
                        ? 'Durable print queues for Counter & Kitchen (USB & Ethernet)'
                        : 'Independent durable queues for Counter Bill Printer and Kitchen KOT Printer (supports USB Windows Drivers & Ethernet TCP Port 9100)',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Cards Layout: Vertical ListView on Mobile, Two-Column Row on Desktop
              Expanded(
                child: isMobile
                    ? ListView(
                        children: provider.printers.map((printer) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildPrinterCard(context, provider, printer, isMobile: true),
                          );
                        }).toList(),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: provider.printers.map((printer) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: _buildPrinterCard(context, provider, printer, isMobile: false),
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
                  color: isBill ? AppColors.primary : AppColors.accentLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isBill ? Icons.receipt_long : Icons.kitchen,
                  color: isBill ? Colors.white : AppColors.primaryDark,
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
                      printer.name,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                      printer.isConnected ? 'CONFIGURED' : 'OFFLINE',
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

          // Configuration Details
          _buildConfigItem(
            'Connection Mode',
            isEthernet ? 'Ethernet LAN (TCP Socket Port 9100)' : 'USB Port (Windows Print Spooler)',
            isEthernet ? Icons.lan : Icons.usb,
          ),
          const SizedBox(height: 8),
          _buildConfigItem(
            isEthernet ? 'Ethernet Target IP & Port' : 'USB Windows Printer Name',
            printer.address,
            isEthernet ? Icons.settings_ethernet : Icons.print,
          ),
          const SizedBox(height: 8),
          _buildConfigItem('Paper Width', '${printer.paperWidthMm}mm Thermal Paper (Standard)', Icons.straighten),
          const SizedBox(height: 8),
          _buildConfigItem('Last Test Print', lastTestStr, Icons.history),

          if (isMobile)
            const SizedBox(height: 16)
          else
            const Spacer(),

          const Divider(color: AppColors.borderLight, height: 20),

          // Action Buttons: Send Test Print & Configure IP
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
                                      ? 'Test ticket sent to "${printer.address}" via ${isEthernet ? "Ethernet" : "USB"}!'
                                      : 'Print dispatch failed to "${printer.address}". Check that printer is powered on and connected.',
                                ),
                              ),
                            ],
                          ),
                          duration: const Duration(seconds: 5),
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
                onPressed: () => _showEditPrinterDialog(context, provider, printer),
                icon: Icon(isEthernet ? Icons.settings_ethernet : Icons.usb, size: 16),
                label: const Text('Configure (USB / LAN)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditPrinterDialog(
    BuildContext context,
    CounterProvider provider,
    ThermalPrinterConfig printer,
  ) async {
    // 1. Pre-fetch detected system Windows printers
    final detectedPrinters = await provider.fetchSystemPrinters();

    if (!context.mounted) return;

    bool isEthernetMode = printer.address.contains(':');
    final ipController = TextEditingController(
      text: isEthernetMode ? printer.address : '192.168.1.200:9100',
    );
    final customUsbController = TextEditingController(
      text: isEthernetMode ? '' : printer.address,
    );

    String? selectedUsbPrinter;
    if (!isEthernetMode && detectedPrinters.contains(printer.address)) {
      selectedUsbPrinter = printer.address;
    } else if (detectedPrinters.isNotEmpty) {
      selectedUsbPrinter = detectedPrinters.first;
    }

    int selectedWidth = printer.paperWidthMm;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  Icon(
                    isEthernetMode ? Icons.lan : Icons.usb,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Configure ${printer.role.label}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
                      // Mode Selector Tabs (USB vs Ethernet)
                      const Text(
                        'Select Connection Interface:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              avatar: const Icon(Icons.usb, size: 16),
                              label: const Text('USB Cable (Windows Drivers)'),
                              selected: !isEthernetMode,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: !isEthernetMode ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                              onSelected: (_) {
                                setDialogState(() => isEthernetMode = false);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              avatar: const Icon(Icons.lan, size: 16),
                              label: const Text('Ethernet LAN (Port 9100)'),
                              selected: isEthernetMode,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isEthernetMode ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                              onSelected: (_) {
                                setDialogState(() => isEthernetMode = true);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (!isEthernetMode) ...[
                        // USB Driver Selector
                        const Text(
                          'Detected Windows USB Printers:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        if (detectedPrinters.isNotEmpty) ...[
                          DropdownButtonFormField<String>(
                            value: selectedUsbPrinter,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.print, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: detectedPrinters.map((p) {
                              return DropdownMenuItem(value: p, child: Text(p));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedUsbPrinter = val;
                                  customUsbController.text = val;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Or type custom Windows printer queue name:',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                        ],
                        TextField(
                          controller: customUsbController,
                          decoration: InputDecoration(
                            hintText: 'e.g. EPSON TM-T82X Receipt',
                            prefixIcon: const Icon(Icons.edit, size: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (val) {
                            selectedUsbPrinter = val;
                          },
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Windows will send ESC/POS binary directly via the native spooler driver.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ] else ...[
                        // Ethernet IP & Port
                        const Text(
                          'Ethernet Printer IP & Port:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: ipController,
                          decoration: InputDecoration(
                            hintText: 'e.g. 192.168.1.200:9100',
                            prefixIcon: const Icon(Icons.settings_ethernet, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: ['192.168.1.200:9100', '192.168.0.200:9100', '192.168.29.200:9100'].map((preset) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text(preset, style: const TextStyle(fontSize: 10)),
                                onPressed: () {
                                  setDialogState(() => ipController.text = preset);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Direct raw TCP socket dispatch over port 9100.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],

                      const SizedBox(height: 16),

                      const Text(
                        'Thermal Paper Roll Width:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: selectedWidth,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 80, child: Text('80mm Standard Thermal Roll (3 inches)')),
                          DropdownMenuItem(value: 58, child: Text('58mm Narrow Thermal Roll (2 inches)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedWidth = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String finalTarget = '';
                    if (isEthernetMode) {
                      finalTarget = ipController.text.trim();
                    } else {
                      finalTarget = customUsbController.text.trim().isNotEmpty
                          ? customUsbController.text.trim()
                          : (selectedUsbPrinter ?? 'EPSON TM-T82X Receipt');
                    }

                    if (finalTarget.isNotEmpty) {
                      await provider.updatePrinterAddress(printer.role, finalTarget, selectedWidth);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.success,
                            content: Text('${printer.name} target updated to "$finalTarget"!'),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Save & Apply'),
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(
                  value,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
