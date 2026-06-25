import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vbt/app/app.dart';

void main() {
  testWidgets('App renders VBT home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VBTApp()));
    expect(find.text('VBT'), findsOneWidget);
  });
}
