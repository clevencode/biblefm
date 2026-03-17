import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_app/app/app.dart';

void main() {
  testWidgets('App inicia e exibe o botão de play', (WidgetTester tester) async {
    await tester.pumpWidget(const RadioApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });
}
