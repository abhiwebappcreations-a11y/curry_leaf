import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:captain_android/main.dart';
import 'package:captain_android/providers/pos_provider.dart';

void main() {
  testWidgets('Captain App smoke test', (WidgetTester tester) async {
    final provider = PosProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PosProvider>.value(value: provider),
        ],
        child: const CaptainApp(),
      ),
    );

    // Let mock timers complete and settle UI
    await tester.pumpAndSettle();

    // Verify app title loads
    expect(find.text('Hinopt Captain'), findsOneWidget);
    expect(find.text('Free Tables'), findsOneWidget);
  });
}
