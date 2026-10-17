import 'order_model.dart';

enum PaymentMethod {
  cash,
  upi,
  card,
  split;

  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.upi:
        return 'UPI / QR Scan';
      case PaymentMethod.card:
        return 'Credit / Debit Card';
      case PaymentMethod.split:
        return 'Split Payment';
    }
  }
}

enum PaymentStatus {
  pending,
  settled,
  voided;

  String get label {
    switch (this) {
      case PaymentStatus.pending:
        return 'Payment Pending';
      case PaymentStatus.settled:
        return 'Settled & Closed';
      case PaymentStatus.voided:
        return 'Voided';
    }
  }
}

class BillItemSnapshot {
  final String name;
  final int quantity;
  final int unitPricePaise;
  final int totalPaise;
  final String? variant;

  BillItemSnapshot({
    required this.name,
    required this.quantity,
    required this.unitPricePaise,
    required this.totalPaise,
    this.variant,
  });

  double get unitPriceRupees => unitPricePaise / 100.0;
  double get totalRupees => totalPaise / 100.0;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unitPricePaise': unitPricePaise,
      'totalPaise': totalPaise,
      'variant': variant,
    };
  }

  factory BillItemSnapshot.fromJson(Map<String, dynamic> json) {
    return BillItemSnapshot(
      name: json['name'] as String,
      quantity: json['quantity'] as int? ?? 1,
      unitPricePaise: json['unitPricePaise'] as int? ?? 0,
      totalPaise: json['totalPaise'] as int? ?? 0,
      variant: json['variant'] as String?,
    );
  }
}

class RestaurantBill {
  final String id;
  final String billNumber;
  final String orderId;
  final String tableId;
  final String tableName;
  final String cashierName;
  final List<BillItemSnapshot> items;
  final int subtotalPaise;
  final int discountPaise;
  final String? discountReason;
  final int cgstPaise;
  final int sgstPaise;
  final int totalPaise;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final String? paymentReference;
  final DateTime createdAt;
  final DateTime? settledAt;
  final bool isReprint;
  final int reprintCount;

  RestaurantBill({
    required this.id,
    required this.billNumber,
    required this.orderId,
    required this.tableId,
    required this.tableName,
    this.cashierName = 'Cashier 1',
    required this.items,
    required this.subtotalPaise,
    this.discountPaise = 0,
    this.discountReason,
    required this.cgstPaise,
    required this.sgstPaise,
    required this.totalPaise,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentStatus = PaymentStatus.pending,
    this.paymentReference,
    required this.createdAt,
    this.settledAt,
    this.isReprint = false,
    this.reprintCount = 0,
  });

  double get subtotalRupees => subtotalPaise / 100.0;
  double get discountRupees => discountPaise / 100.0;
  double get cgstRupees => cgstPaise / 100.0;
  double get sgstRupees => sgstPaise / 100.0;
  double get totalRupees => totalPaise / 100.0;
  double get totalGstRupees => (cgstPaise + sgstPaise) / 100.0;

  RestaurantBill copyWith({
    String? id,
    String? billNumber,
    String? orderId,
    String? tableId,
    String? tableName,
    String? cashierName,
    List<BillItemSnapshot>? items,
    int? subtotalPaise,
    int? discountPaise,
    String? discountReason,
    int? cgstPaise,
    int? sgstPaise,
    int? totalPaise,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    String? paymentReference,
    DateTime? createdAt,
    DateTime? settledAt,
    bool? isReprint,
    int? reprintCount,
  }) {
    return RestaurantBill(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      orderId: orderId ?? this.orderId,
      tableId: tableId ?? this.tableId,
      tableName: tableName ?? this.tableName,
      cashierName: cashierName ?? this.cashierName,
      items: items ?? this.items,
      subtotalPaise: subtotalPaise ?? this.subtotalPaise,
      discountPaise: discountPaise ?? this.discountPaise,
      discountReason: discountReason ?? this.discountReason,
      cgstPaise: cgstPaise ?? this.cgstPaise,
      sgstPaise: sgstPaise ?? this.sgstPaise,
      totalPaise: totalPaise ?? this.totalPaise,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentReference: paymentReference ?? this.paymentReference,
      createdAt: createdAt ?? this.createdAt,
      settledAt: settledAt ?? this.settledAt,
      isReprint: isReprint ?? this.isReprint,
      reprintCount: reprintCount ?? this.reprintCount,
    );
  }

  factory RestaurantBill.fromOrder({
    required RestaurantOrder order,
    required String billNumber,
    int discountPaise = 0,
    String? discountReason,
    String cashierName = 'Deepa',
  }) {
    final snapshots = order.activeItems.map((item) {
      return BillItemSnapshot(
        name: item.name,
        quantity: item.quantity,
        unitPricePaise: item.pricePaise,
        totalPaise: item.totalPaise,
        variant: item.selectedVariant,
      );
    }).toList();

    final subtotal = order.totalPaise;
    final taxable = (subtotal - discountPaise).clamp(0, double.infinity).toInt();
    // 5% GST divided into 2.5% CGST + 2.5% SGST
    final cgst = (taxable * 0.025).round();
    final sgst = (taxable * 0.025).round();
    final total = taxable + cgst + sgst;

    return RestaurantBill(
      id: 'bill-${DateTime.now().millisecondsSinceEpoch}',
      billNumber: billNumber,
      orderId: order.id,
      tableId: order.tableId,
      tableName: order.tableName,
      cashierName: cashierName,
      items: snapshots,
      subtotalPaise: subtotal,
      discountPaise: discountPaise,
      discountReason: discountReason,
      cgstPaise: cgst,
      sgstPaise: sgst,
      totalPaise: total,
      createdAt: DateTime.now(),
    );
  }

  factory RestaurantBill.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>?)
            ?.map((e) => BillItemSnapshot(
                  name: (e['nameSnapshot'] ?? e['name'] ?? 'Item') as String,
                  quantity: e['quantity'] as int? ?? 1,
                  unitPricePaise: (e['unitPricePaise'] ?? e['unitPrice'] ?? 0) as int,
                  totalPaise: (e['totalPaise'] ?? e['total'] ?? 0) as int,
                  variant: e['variant'] as String?,
                ))
            .toList() ??
        [];

    final subtotal = json['subtotalPaise'] as int? ?? 0;
    final discount = json['discountPaise'] as int? ?? 0;
    final tax = json['taxPaise'] as int? ?? 0;
    final cgst = (tax / 2).round();
    final sgst = tax - cgst;
    final total = json['totalPaise'] as int? ?? (subtotal + tax - discount);

    return RestaurantBill(
      id: json['id'] as String,
      billNumber: json['billNumber'] as String? ?? 'INV-001',
      orderId: json['orderId'] as String? ?? '',
      tableId: json['tableId'] as String? ?? '',
      tableName: json['tableName'] as String? ?? '',
      cashierName: json['cashierName'] as String? ?? 'Deepa',
      items: itemsList,
      subtotalPaise: subtotal,
      discountPaise: discount,
      discountReason: json['discountReason'] as String?,
      cgstPaise: cgst,
      sgstPaise: sgst,
      totalPaise: total,
      paymentMethod: PaymentMethod.values.firstWhere(
        (m) => m.name.toLowerCase() == (json['paymentMethod'] as String? ?? 'cash').toLowerCase(),
        orElse: () => PaymentMethod.cash,
      ),
      paymentStatus: (json['status'] == 'settled')
          ? PaymentStatus.settled
          : PaymentStatus.pending,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      settledAt: json['settledAt'] != null ? DateTime.tryParse(json['settledAt']) : null,
    );
  }
}
