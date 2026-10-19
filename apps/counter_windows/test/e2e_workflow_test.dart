import 'package:flutter_test/flutter_test.dart';
import 'package:counter_windows/models/table_model.dart';
import 'package:counter_windows/models/bill_model.dart';
import 'package:counter_windows/models/printer_model.dart';
import 'package:counter_windows/providers/counter_provider.dart';

void main() {
  group('Counter Windows End-to-End Workflow Tests', () {
    test('E2E: Order Intake, Billing Math with Discount, Settlement, and Printer Test', () async {
      final provider = CounterProvider();
      await provider.refreshFromLiveApi();

      // 1. Order Intake & Review
      expect(provider.activeOrders.isNotEmpty, isTrue);
      final activeOrder = provider.activeOrders.first;
      expect(activeOrder.status.toLowerCase(), isIn(['in_kitchen', 'active', 'preparing']));

      // 2. Select Order to Generate Bill
      await provider.selectOrder(activeOrder);
      expect(provider.currentDraftBill, isNotNull);
      final initialDraft = provider.currentDraftBill!;

      // Verify Cashier Name is strictly Deepa
      expect(initialDraft.cashierName, equals('Deepa'));

      // 3. Tax and Total Paise Math Verification
      final initialSubtotal = initialDraft.subtotalPaise;
      final expectedInitialCgst = (initialSubtotal * 0.025).round();
      final expectedInitialSgst = (initialSubtotal * 0.025).round();
      expect(initialDraft.cgstPaise, equals(expectedInitialCgst));
      expect(initialDraft.sgstPaise, equals(expectedInitialSgst));
      expect(initialDraft.totalPaise, equals(initialSubtotal + expectedInitialCgst + expectedInitialSgst));

      // 4. Apply ₹50 Discount (5000 Paise)
      const discountPaise = 5000;
      provider.applyDiscount(discountPaise, 'Manager Courtesy');

      final discountedDraft = provider.currentDraftBill!;
      expect(discountedDraft.discountPaise, equals(5000));
      expect(discountedDraft.discountReason, equals('Manager Courtesy'));

      // Verify Taxes recalculate on the discounted taxable amount:
      final taxableAmount = initialSubtotal - discountPaise;
      final expectedCgst = (taxableAmount * 0.025).round();
      final expectedSgst = (taxableAmount * 0.025).round();
      expect(discountedDraft.cgstPaise, equals(expectedCgst));
      expect(discountedDraft.sgstPaise, equals(expectedSgst));
      expect(discountedDraft.totalPaise, equals(taxableAmount + expectedCgst + expectedSgst));

      // 5. Payment Settlement with Duplicate Click Guard
      expect(provider.isSettlingPayment, isFalse);
      final settlementFuture = provider.settlePayment(
        method: PaymentMethod.upi,
        reference: 'UPI-REF-9876543210',
      );
      // Verify repeated clicks are blocked while settling
      expect(provider.isSettlingPayment, isTrue);

      final settledSuccess = await settlementFuture;
      expect(settledSuccess, isTrue);
      expect(provider.isSettlingPayment, isFalse);

      // Verify Settled Bill state
      expect(provider.lastSettledBill, isNotNull);
      final settledBill = provider.lastSettledBill!;
      expect(settledBill.cashierName, equals('Deepa'));
      expect(settledBill.paymentMethod, equals(PaymentMethod.upi));
      expect(settledBill.paymentStatus, equals(PaymentStatus.settled));
      expect(settledBill.settledAt, isNotNull);

      // 6. Table State Verification (returns to AVAILABLE)
      final table = provider.tables.firstWhere(
        (t) => t.id == settledBill.tableId || t.name.contains('3') || t.id.contains('3'),
        orElse: () => provider.tables.first,
      );
      expect(table.status, equals(TableStatus.available));
      expect(table.activeOrderId, isNull);

      // 7. Printer Settings & Test Print
      expect(provider.printers.isNotEmpty, isTrue);
      await provider.testPrint(PrinterRole.counterBill);
      final billPrinter = provider.billPrinter;
      expect(billPrinter, isNotNull);
      expect(billPrinter!.isConnected, isTrue);
      expect(billPrinter.lastTestPrintAt, isNotNull);
      provider.dispose();
    });
  });
}
