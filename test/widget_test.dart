import 'package:flutter_test/flutter_test.dart';

import 'package:karekare/main.dart';

void main() {
  testWidgets('Uygulama açılış smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KareKareApp());
    await tester.pump();

    // Başlık ekranda görünmeli
    expect(find.text('Kare Kare'), findsOneWidget);
  });
}
