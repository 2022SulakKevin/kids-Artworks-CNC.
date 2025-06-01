import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cnc_controller/main.dart';

void main() {
  testWidgets('CNCControllerApp builds and shows title', (
    WidgetTester tester,
  ) async {
    // Build the app
    await tester.pumpWidget(CNCControllerApp());

    // Verify the AppBar title is shown
    expect(find.text('CNC Controller'), findsOneWidget);

    // Verify the TextField for G-code input is present
    expect(find.byType(TextField), findsOneWidget);

    // Verify the Send button is present
    expect(find.widgetWithText(ElevatedButton, 'Send'), findsOneWidget);
  });
}
