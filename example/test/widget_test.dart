import 'package:custom_media_picker_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MyApp renders', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Custom Media Picker'), findsOneWidget);
  });
}
