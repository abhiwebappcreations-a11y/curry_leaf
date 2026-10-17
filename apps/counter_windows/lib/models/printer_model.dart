enum PrinterRole {
  counterBill,
  kitchenKot;

  String get label {
    switch (this) {
      case PrinterRole.counterBill:
        return 'Counter Bill Thermal Printer';
      case PrinterRole.kitchenKot:
        return 'Kitchen KOT Thermal Printer';
    }
  }
}

enum PrinterConnectionType {
  usb,
  ethernet,
  wifi,
  bluetooth;

  String get label {
    switch (this) {
      case PrinterConnectionType.usb:
        return 'USB Port';
      case PrinterConnectionType.ethernet:
        return 'Ethernet (LAN Cable)';
      case PrinterConnectionType.wifi:
        return 'Wi-Fi Network';
      case PrinterConnectionType.bluetooth:
        return 'Bluetooth';
    }
  }
}

class ThermalPrinterConfig {
  final String id;
  final PrinterRole role;
  final String name;
  final PrinterConnectionType connectionType;
  final String address; // USB Port or IP Address
  final int port;
  final int paperWidthMm; // 80 or 58
  final bool isConnected;
  final DateTime? lastTestPrintAt;

  ThermalPrinterConfig({
    required this.id,
    required this.role,
    required this.name,
    required this.connectionType,
    required this.address,
    this.port = 9100,
    this.paperWidthMm = 80,
    this.isConnected = true,
    this.lastTestPrintAt,
  });

  ThermalPrinterConfig copyWith({
    String? id,
    PrinterRole? role,
    String? name,
    PrinterConnectionType? connectionType,
    String? address,
    int? port,
    int? paperWidthMm,
    bool? isConnected,
    DateTime? lastTestPrintAt,
  }) {
    return ThermalPrinterConfig(
      id: id ?? this.id,
      role: role ?? this.role,
      name: name ?? this.name,
      connectionType: connectionType ?? this.connectionType,
      address: address ?? this.address,
      port: port ?? this.port,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      isConnected: isConnected ?? this.isConnected,
      lastTestPrintAt: lastTestPrintAt ?? this.lastTestPrintAt,
    );
  }
}
