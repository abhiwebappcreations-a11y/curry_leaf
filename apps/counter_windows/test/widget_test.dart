import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:counter_windows/main.dart';
import 'package:counter_windows/providers/counter_provider.dart';

void main() {
  testWidgets('Counter Windows App desktop smoke test', (WidgetTester tester) async {
    // Set standard desktop resolution
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final provider = CounterProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CounterProvider>.value(value: provider),
        ],
        child: const CounterApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify brand title and sidebar tabs load
    expect(find.text('Hinopt POS'), findsOneWidget);
    expect(find.text('Active Orders'), findsWidgets);
    expect(find.text('Tables / Floor'), findsOneWidget);
    expect(find.text('Billing & Till'), findsOneWidget);
    expect(find.text('Thermal Printers'), findsOneWidget);
  });
}
