import 'package:flutter_test/flutter_test.dart';

import 'package:android_file_manager/main.dart';

void main() {
  testWidgets('App renders title', (WidgetTester tester) async {
    await tester.pumpWidget(const AndroidFileManagerApp());
    expect(find.text('Android File Manager'), findsOneWidget);
  });
}
