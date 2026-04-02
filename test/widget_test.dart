import 'package:flutter_test/flutter_test.dart';
import 'package:bibliofani/app/app.dart';
import 'package:bibliofani/core/strings/bible_fm_strings.dart';
import 'package:bibliofani/features/radio/screens/radio_player_page.dart';

void main() {
  testWidgets('App inicia (leitor Web)', (WidgetTester tester) async {
    await tester.pumpWidget(
      const RadioApp(home: RadioPlayerPage()),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(kBibleFmSemanticsPlayerPage),
      findsOneWidget,
    );
  });
}
