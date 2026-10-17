enum TableStatus {
  available,
  occupied,
  billed,
  reserved;

  String get label {
    switch (this) {
      case TableStatus.available:
        return 'Available';
      case TableStatus.occupied:
        return 'Occupied';
      case TableStatus.billed:
        return 'Billed';
      case TableStatus.reserved:
        return 'Reserved';
    }
  }
}

class RestaurantTable {
  final String id;
  final String name;
  final String section;
  final int capacity;
  final TableStatus status;
  final String? activeOrderId;
  final int activeOrderTotalPaise;
  final DateTime? occupiedSince;
  final int? guestCount;

  RestaurantTable({
    required this.id,
    required this.name,
    required this.section,
    required this.capacity,
    required this.status,
    this.activeOrderId,
    this.activeOrderTotalPaise = 0,
    this.occupiedSince,
    this.guestCount,
  });

  double get activeOrderTotalRupees => activeOrderTotalPaise / 100.0;

  RestaurantTable copyWith({
    String? id,
    String? name,
    String? section,
    int? capacity,
    TableStatus? status,
    String? activeOrderId,
    bool clearActiveOrder = false,
    int? activeOrderTotalPaise,
    DateTime? occupiedSince,
    bool clearOccupiedSince = false,
    int? guestCount,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      name: name ?? this.name,
      section: section ?? this.section,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      activeOrderId: clearActiveOrder ? null : (activeOrderId ?? this.activeOrderId),
      activeOrderTotalPaise: activeOrderTotalPaise ?? this.activeOrderTotalPaise,
      occupiedSince: clearOccupiedSince ? null : (occupiedSince ?? this.occupiedSince),
      guestCount: guestCount ?? this.guestCount,
    );
  }

  factory RestaurantTable.fromJson(Map<String, dynamic> json) {
    final activeOrder = json['activeOrder'] as Map<String, dynamic>?;
    return RestaurantTable(
      id: json['id'] as String,
      name: (json['displayName'] ?? json['name'] ?? json['tableNumber'] ?? 'Table') as String,
      section: json['section'] as String? ?? 'Main Hall',
      capacity: json['capacity'] as int? ?? 4,
      status: TableStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['status'] as String? ?? 'available').toLowerCase(),
        orElse: () => TableStatus.available,
      ),
      activeOrderId: (json['activeOrderId'] ?? activeOrder?['orderId']) as String?,
      activeOrderTotalPaise: (activeOrder?['totalPaise'] ?? json['activeOrderTotalPaise'] ?? 0) as int,
      occupiedSince: json['occupiedSince'] != null ? DateTime.tryParse(json['occupiedSince']) : null,
      guestCount: json['guestCount'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'section': section,
      'capacity': capacity,
      'status': status.name,
      'activeOrderId': activeOrderId,
      'activeOrderTotalPaise': activeOrderTotalPaise,
      'occupiedSince': occupiedSince?.toIso8601String(),
      'guestCount': guestCount,
    };
  }
}
