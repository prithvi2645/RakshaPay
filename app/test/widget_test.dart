import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rakshapay/main.dart';
import 'package:rakshapay/screens/splash_screen.dart';

void main() {
  testWidgets('shows the branded splash while models load',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RakshaPayApp());

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('RakshaPay'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
