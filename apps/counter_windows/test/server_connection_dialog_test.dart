import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:counter_windows/providers/counter_provider.dart';
import 'package:counter_windows/widgets/server_connection_dialog.dart';

void main() {
  group('ServerConnectionDialog Tests', () {
    testWidgets('renders high-contrast inputs, status card, and preset pills', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = CounterProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServerConnectionDialog(provider: provider),
          ),
        ),
      );

      await tester.pump();

      // 1. Verify Header and Labels
      expect(find.text('POS Server Connection'), findsOneWidget);
      expect(find.text('Server IP / Hostname'), findsOneWidget);
      expect(find.text('Port Number'), findsOneWidget);
      expect(find.text('Quick Presets:'), findsOneWidget);

      // 2. Verify Live Connection Status Card
      expect(find.textContaining('Status:'), findsOneWidget);
      expect(find.textContaining('http://'), findsOneWidget);

      // 3. Verify Quick Selection Presets
      expect(find.text('127.0.0.1 (This Counter PC)'), findsOneWidget);
      expect(find.text('10.0.2.2 (Emulator)'), findsOneWidget);
      expect(find.text('192.168.1.100 (LAN)'), findsOneWidget);

      // 4. Verify Buttons
      expect(find.text('Test Connection'), findsOneWidget);
      expect(find.text('Save & Connect'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // 5. Test Quick Selection Preset tap (e.g., 10.0.2.2)
      await tester.tap(find.text('10.0.2.2 (Emulator)'));
      await tester.pump();

      final hostTextField = tester.widget<TextField>(
        find.widgetWithText(TextField, '10.0.2.2'),
      );
      expect(hostTextField.controller?.text, equals('10.0.2.2'));

      // Clean up
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    });

    testWidgets('tapping LAN preset sets 192.168.1.100 and updates UI', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = CounterProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServerConnectionDialog(provider: provider),
          ),
        ),
      );

      await tester.pump();

      // Tap LAN preset
      await tester.tap(find.text('192.168.1.100 (LAN)'));
      await tester.pump();

      final hostTextField = tester.widget<TextField>(
        find.widgetWithText(TextField, '192.168.1.100'),
      );
      expect(hostTextField.controller?.text, equals('192.168.1.100'));

      // Clean up
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    });
  });
}
