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
    String cashierName = 'Cashier 1',
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
}
