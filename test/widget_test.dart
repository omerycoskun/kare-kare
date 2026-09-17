import 'package:flutter_test/flutter_test.dart';

import 'package:karekare/main.dart';

void main() {
  testWidgets('Uygulama açılış smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KareKareApp());
    await tester.pump();

    // Ana menü: başlık ve iki mod görünmeli
    expect(find.text('KARE KARE'), findsOneWidget);
    expect(find.text('Çini Macerası'), findsOneWidget);
    expect(find.text('Serbest Oyun'), findsOneWidget);
  });
}
