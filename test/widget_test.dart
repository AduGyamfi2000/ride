import 'package:flutter_test/flutter_test.dart';
import 'package:ride/main.dart';

void main() {
  testWidgets('shows the onboarding experience', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(hasSeenOnboarding: false));

    expect(find.text('Smart Rural Ride'), findsOneWidget);
    expect(find.text('Start Journey'), findsOneWidget);
  });
}
