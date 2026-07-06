import 'package:flutter_test/flutter_test.dart';
import 'package:media_picker_demo/main.dart';

void main() {
  testWidgets('Demo home renders', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Custom Media Picker'), findsOneWidget);
  });
}
