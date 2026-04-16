import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/app.dart';

void main() {
  testWidgets('app shell renders primary tabs', (tester) async {
    await tester.pumpWidget(const MuslimAiApp());
    await tester.pump();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Prayer'), findsWidgets);
    expect(find.text('Quran'), findsWidgets);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });
}
