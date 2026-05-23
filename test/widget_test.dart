import 'package:flutter_test/flutter_test.dart';

import 'package:oddtunes_app/main.dart';

void main() {
  testWidgets('Oddtunes smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OddtunesApp());
    expect(find.text('Oddtunes – Coming Soon'), findsOneWidget);
  });
}
