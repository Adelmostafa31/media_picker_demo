// The picker must open from a plain `package:flutter/material.dart` app —
// that's what every 0.1.x integration uses.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:custom_media_picker/custom_media_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('custom_media_picker');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'requestPermission' || 'checkPermission' => 'granted',
            'getAssets' || 'getAlbums' => <Object?>[],
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final layout in LayoutStyle.values) {
    testWidgets('opens as $layout under a flutter/material MaterialApp', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => CustomMediaPicker.pick(
                context,
                config: MediaPickerConfig(
                  layoutStyle: layout,
                  enableSort: true,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('No media found'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
}
