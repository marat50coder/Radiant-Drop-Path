import 'package:flutter_test/flutter_test.dart';

import 'package:radiant_drop_path/app.dart';

void main() {
  testWidgets('Game app boots without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const RadiantDropPathApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(RadiantDropPathApp), findsOneWidget);
  });
}
