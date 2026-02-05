import 'package:flutter_test/flutter_test.dart';

import 'package:are_you_alive_flutter/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AreYouAliveApp());
    await tester.pumpAndSettle();
  });
}
