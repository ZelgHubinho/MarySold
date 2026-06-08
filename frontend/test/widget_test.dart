import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('App smoke test - should show MarySold POS login', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MarySoldApp());

    // Settle the async loading process
    await tester.pumpAndSettle();

    // Verify that the title is displayed.
    expect(find.text('MarySold POS'), findsOneWidget);
  });
}
