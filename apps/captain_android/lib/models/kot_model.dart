enum KotStatus {
  queued,
  printing,
  printed,
  failed;

  String get label {
    switch (this) {
      case KotStatus.queued:
        return 'Queued';
      case KotStatus.printing:
        return 'Printing';
      case KotStatus.printed:
        return 'Printed in Kitchen';
      case KotStatus.failed:
        return 'Print Failed';
    }
  }
}

class KotTicket {
  final String id;
  final String kotNumber;
  final String orderId;
  final String tableId;
  final String tableName;
  final List<KotItem> items;
  final DateTime timestamp;
  final KotStatus status;
  final String? errorMessage;

  KotTicket({
    required this.id,
    required this.kotNumber,
    required this.orderId,
    required this.tableId,
    required this.tableName,
    required this.items,
    required this.timestamp,
    this.status = KotStatus.printed,
    this.errorMessage,
  });

  factory KotTicket.fromJson(Map<String, dynamic> json) {
    return KotTicket(
      id: json['id'] as String,
      kotNumber: json['kotNumber'] as String? ?? 'KOT-001',
      orderId: json['orderId'] as String,
      tableId: json['tableId'] as String,
      tableName: json['tableName'] as String? ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => KotItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      status: KotStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['status'] as String? ?? 'printed').toLowerCase(),
        orElse: () => KotStatus.printed,
      ),
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

class KotItem {
  final String name;
  final int quantity;
  final String? notes;
  final String? variant;

  KotItem({
    required this.name,
    required this.quantity,
    this.notes,
    this.variant,
  });

  factory KotItem.fromJson(Map<String, dynamic> json) {
    return KotItem(
      name: json['name'] as String,
      quantity: json['quantity'] as int? ?? 1,
      notes: json['notes'] as String?,
      variant: json['variant'] as String?,
    );
  }
}
