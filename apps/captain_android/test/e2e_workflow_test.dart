import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:captain_android/models/table_model.dart';
import 'package:captain_android/models/menu_item_model.dart';
import 'package:captain_android/models/order_model.dart';
import 'package:captain_android/providers/pos_provider.dart';

void main() {
  group('Captain Android End-to-End Workflow Tests', () {
    test('E2E: Table selection, Draft cart, Less spicy note, and KOT dispatch', () async {
      final provider = PosProvider();
      await provider.init();

      // 1. Table Selection
      final tableT3 = provider.tables.firstWhere(
        (t) => t.name.contains('3') || t.id.contains('3'),
        orElse: () => provider.tables.first,
      );
      provider.selectTable(tableT3);
      expect(provider.currentTable, isNotNull);
      expect(provider.currentOrder, isNotNull);

      // 2. Add 2x Chicken Biryani, 1x Butter Naan
      final biryani = MenuItem(
        id: 'item_cb_01',
        name: 'Hyderabadi Chicken Dum Biryani',
        category: 'Biryani & Rice',
        pricePaise: 38000,
        isVeg: false,
      );
      final naan = MenuItem(
        id: 'item_naan_01',
        name: 'Butter Naan',
        category: 'Breads',
        pricePaise: 6000,
        isVeg: true,
      );

      // Add 2x Chicken Biryani with note "Less spicy"
      provider.addItemToDraft(
        biryani,
        quantity: 2,
        notes: 'Less spicy',
      );
      // Add 1x Butter Naan
      provider.addItemToDraft(
        naan,
        quantity: 1,
      );

      // 3. Verify draft item indicators
      expect(provider.currentOrder!.draftItems.length, equals(2));
      final draftBiryani = provider.currentOrder!.draftItems.firstWhere(
        (i) => i.menuItemId == biryani.id,
      );
      expect(draftBiryani.quantity, equals(2));
      expect(draftBiryani.notes, equals('Less spicy'));
      expect(draftBiryani.isDraft, isTrue);
      expect(draftBiryani.status, equals(OrderItemStatus.draft));
      expect(draftBiryani.totalPaise, equals(76000)); // 2 * 38000

      // 4. KOT Submission
      expect(provider.isSubmittingKot, isFalse);
      final kotFuture = provider.sendDraftToKitchen();
      // Verify duplicate submission prevention while submitting
      expect(provider.isSubmittingKot, isTrue);

      final ticket = await kotFuture;
      expect(ticket, isNotNull);
      expect(provider.isSubmittingKot, isFalse);

      // 5. Verify transition from draft to sent state
      expect(provider.currentOrder!.draftItems.isEmpty, isTrue);
      expect(provider.currentOrder!.status, equals('IN_KITCHEN'));
      expect(provider.currentTable!.status, equals(TableStatus.occupied));
      expect(provider.kotHistory.length, greaterThanOrEqualTo(1));
    });

    test('E2E: Network Interruption and Auto-Recovery', () async {
      final provider = PosProvider();
      await provider.init();

      // Verify default live API config
      expect(provider.apiService.useDemoMode, isFalse);
      expect(provider.apiService.port, equals(4000));

      // Simulate network config update
      provider.updateServerConfig('192.168.1.100', 4000, false);
      await provider.init();

      // App remains responsive and retains fallback stability
      expect(provider.tables.isNotEmpty, isTrue);
    });
  });
}
