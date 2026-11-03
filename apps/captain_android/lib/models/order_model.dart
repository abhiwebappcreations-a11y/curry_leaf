enum OrderItemStatus {
  draft,
  sentToKitchen,
  preparing,
  served,
  cancelRequested,
  cancelled;

  String get label {
    switch (this) {
      case OrderItemStatus.draft:
        return 'Draft (Unsent)';
      case OrderItemStatus.sentToKitchen:
        return 'Sent to Kitchen';
      case OrderItemStatus.preparing:
        return 'Preparing';
      case OrderItemStatus.served:
        return 'Served';
      case OrderItemStatus.cancelRequested:
        return 'Cancellation Requested';
      case OrderItemStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class OrderItem {
  final String id;
  final String menuItemId;
  final String name;
  final int quantity;
  final int pricePaise;
  final bool isVeg;
  final String? notes;
  final String? selectedVariant;
  final List<String> selectedAddons;
  final bool isDraft;
  final DateTime? sentAt;
  final OrderItemStatus status;

  OrderItem({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.pricePaise,
    required this.isVeg,
    this.notes,
    this.selectedVariant,
    this.selectedAddons = const [],
    this.isDraft = true,
    this.sentAt,
    this.status = OrderItemStatus.draft,
  });

  int get totalPaise => quantity * pricePaise;
  double get totalRupees => totalPaise / 100.0;
  double get unitPriceRupees => pricePaise / 100.0;

  OrderItem copyWith({
    String? id,
    String? menuItemId,
    String? name,
    int? quantity,
    int? pricePaise,
    bool? isVeg,
    String? notes,
    String? selectedVariant,
    List<String>? selectedAddons,
    bool? isDraft,
    DateTime? sentAt,
    OrderItemStatus? status,
  }) {
    return OrderItem(
      id: id ?? this.id,
      menuItemId: menuItemId ?? this.menuItemId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      pricePaise: pricePaise ?? this.pricePaise,
      isVeg: isVeg ?? this.isVeg,
      notes: notes ?? this.notes,
      selectedVariant: selectedVariant ?? this.selectedVariant,
      selectedAddons: selectedAddons ?? this.selectedAddons,
      isDraft: isDraft ?? this.isDraft,
      sentAt: sentAt ?? this.sentAt,
      status: status ?? this.status,
    );
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    String? variant;
    if (json['selectedVariant'] != null) {
      variant = json['selectedVariant'].toString();
    } else if (json['selectedVariants'] != null &&
        json['selectedVariants'] is List &&
        (json['selectedVariants'] as List).isNotEmpty) {
      final first = (json['selectedVariants'] as List).first;
      variant = first is Map ? first['name']?.toString() : first?.toString();
    }

    final addons = <String>[];
    if (json['selectedAddons'] != null && json['selectedAddons'] is List) {
      for (final a in json['selectedAddons'] as List) {
        if (a is Map && a['name'] != null) {
          addons.add(a['name'].toString());
        } else if (a != null) {
          addons.add(a.toString());
        }
      }
    }

    final rawStatus = (json['status'] as String? ?? 'sentToKitchen')
        .replaceAll('_', '')
        .toLowerCase();

    return OrderItem(
      id: (json['id'] ?? 'item-${DateTime.now().millisecondsSinceEpoch}').toString(),
      menuItemId: (json['menuItemId'] ?? json['id'] ?? '').toString(),
      name: (json['nameSnapshot'] ?? json['name'] ?? 'Item').toString(),
      quantity: json['quantity'] as int? ?? 1,
      pricePaise: (json['pricePaiseSnapshot'] ?? json['pricePaise'] ?? 0) as int,
      isVeg: json['isVeg'] as bool? ?? true,
      notes: (json['itemNotes'] ?? json['notes']) as String?,
      selectedVariant: variant,
      selectedAddons: addons,
      isDraft: json['isDraft'] as bool? ?? (rawStatus == 'draft'),
      sentAt: json['sentAt'] != null ? DateTime.tryParse(json['sentAt'].toString()) : null,
      status: OrderItemStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == rawStatus,
        orElse: () => OrderItemStatus.sentToKitchen,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'menuItemId': menuItemId,
      'name': name,
      'quantity': quantity,
      'pricePaise': pricePaise,
      'isVeg': isVeg,
      'notes': notes,
      'selectedVariant': selectedVariant,
      'selectedAddons': selectedAddons,
      'isDraft': isDraft,
      'sentAt': sentAt?.toIso8601String(),
      'status': status.name,
    };
  }
}

class RestaurantOrder {
  final String id;
  final String tableId;
  final String tableName;
  final List<OrderItem> items;
  final String status;
  final int guestCount;
  final DateTime createdAt;

  RestaurantOrder({
    required this.id,
    required this.tableId,
    required this.tableName,
    required this.items,
    this.status = 'ACTIVE',
    this.guestCount = 2,
    required this.createdAt,
  });

  List<OrderItem> get draftItems => items.where((i) => i.isDraft).toList();
  List<OrderItem> get submittedItems => items.where((i) => !i.isDraft).toList();

  int get totalPaise {
    return items
        .where((i) => i.status != OrderItemStatus.cancelled)
        .fold(0, (sum, item) => sum + item.totalPaise);
  }

  double get totalRupees => totalPaise / 100.0;

  RestaurantOrder copyWith({
    String? id,
    String? tableId,
    String? tableName,
    List<OrderItem>? items,
    String? status,
    int? guestCount,
    DateTime? createdAt,
  }) {
    return RestaurantOrder(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      tableName: tableName ?? this.tableName,
      items: items ?? this.items,
      status: status ?? this.status,
      guestCount: guestCount ?? this.guestCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory RestaurantOrder.fromJson(Map<String, dynamic> json) {
    return RestaurantOrder(
      id: (json['id'] ?? 'ord-${DateTime.now().millisecondsSinceEpoch}').toString(),
      tableId: (json['tableId'] ?? '').toString(),
      tableName: (json['tableName'] ?? '').toString(),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) {
                try {
                  return OrderItem.fromJson(e as Map<String, dynamic>);
                } catch (_) {
                  return null;
                }
              })
              .whereType<OrderItem>()
              .toList() ??
          [],
      status: (json['status'] ?? 'ACTIVE').toString(),
      guestCount: json['guestCount'] as int? ?? 2,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tableId': tableId,
      'tableName': tableName,
      'items': items.map((i) => i.toJson()).toList(),
      'status': status,
      'guestCount': guestCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
