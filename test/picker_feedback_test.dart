// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:custom_media_picker/custom_media_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('custom_media_picker');

/// Native side with [count] images on page 0.
void _mockNative(int count) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
        return switch (call.method) {
          'requestPermission' || 'checkPermission' => 'granted',
          'getAssets' when (call.arguments as Map)['page'] == 0 => [
            for (var i = 0; i < count; i++) {'id': '$i', 'type': 'image'},
          ],
          'getAssets' || 'getAlbums' => <Object?>[],
          _ => null,
        };
      });
}

Future<void> _openPicker(WidgetTester tester, MediaPickerConfig config) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => CustomMediaPicker.pick(context, config: config),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );

  testWidgets('tapping past maxSelection shows a notice inside the picker', (
    tester,
  ) async {
    _mockNative(3);
    await _openPicker(
      tester,
      const MediaPickerConfig(maxSelection: 1, enableAlbums: false),
    );
    final tiles = find.byType(PickerAssetThumbnail);
    await tester.tap(tiles.at(0));
    await tester.pump();
    expect(find.text('You can select up to 1 items'), findsNothing);

    await tester.tap(tiles.at(1));
    await tester.pump();
    expect(find.text('You can select up to 1 items'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('You can select up to 1 items'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the notice text is configurable and can be turned off', (
    tester,
  ) async {
    _mockNative(2);
    await _openPicker(
      tester,
      MediaPickerConfig(
        maxSelection: 1,
        enableAlbums: false,
        selectionLimitMessage: (max) => 'Max $max',
      ),
    );
    final tiles = find.byType(PickerAssetThumbnail);
    await tester.tap(tiles.at(0));
    await tester.tap(tiles.at(1));
    await tester.pump();
    expect(find.text('Max 1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a custom notice widget replaces the default one', (
    tester,
  ) async {
    _mockNative(2);
    await _openPicker(
      tester,
      MediaPickerConfig(
        maxSelection: 1,
        enableAlbums: false,
        selectionLimitMessage: (max) => 'ignored',
        selectionLimitNoticeBuilder: (context, max) =>
            Text('custom $max', key: const ValueKey('custom-notice')),
      ),
    );
    final tiles = find.byType(PickerAssetThumbnail);
    await tester.tap(tiles.at(0));
    await tester.tap(tiles.at(1));
    await tester.pump();
    expect(find.byKey(const ValueKey('custom-notice')), findsOneWidget);
    expect(find.text('custom 1'), findsOneWidget);
    expect(find.text('ignored'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('no notice when showSelectionLimitMessage is false', (
    tester,
  ) async {
    _mockNative(2);
    var calls = 0;
    await _openPicker(
      tester,
      MediaPickerConfig(
        maxSelection: 1,
        enableAlbums: false,
        showSelectionLimitMessage: false,
        onSelectionLimitReached: () => calls++,
      ),
    );
    final tiles = find.byType(PickerAssetThumbnail);
    await tester.tap(tiles.at(0));
    await tester.tap(tiles.at(1));
    await tester.pump();
    expect(find.textContaining('select up to'), findsNothing);
    expect(calls, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('date range sheet icon buttons have screen-reader labels', (
    tester,
  ) async {
    _mockNative(0);
    await _openPicker(tester, const MediaPickerConfig(enableSort: true));
    await tester.tap(find.textContaining('Sort:'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom range'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.byTooltip('Previous month'), findsOneWidget);
    expect(find.byTooltip('Next month'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  group('externalSelectedCount (camera captures count too)', () {
    testWidgets('max 2 with 1 captured: only 1 more can be picked', (
      tester,
    ) async {
      _mockNative(3);
      var reached = 0;
      await _openPicker(
        tester,
        MediaPickerConfig(
          maxSelection: 2,
          externalSelectedCount: 1,
          enableAlbums: false,
          onSelectionLimitReached: () => reached++,
        ),
      );
      expect(find.text('1 / 2'), findsOneWidget);
      final tiles = find.byType(PickerAssetThumbnail);
      await tester.tap(tiles.at(0));
      await tester.pump();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.tap(tiles.at(1));
      await tester.pump();
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('You can select up to 2 items'), findsOneWidget);
      expect(reached, 1);
      await tester.pump(const Duration(seconds: 3));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('already full from captures: every pick is refused', (
      tester,
    ) async {
      _mockNative(2);
      await _openPicker(
        tester,
        const MediaPickerConfig(
          maxSelection: 2,
          externalSelectedCount: 2,
          enableAlbums: false,
        ),
      );
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.tap(find.byType(PickerAssetThumbnail).first);
      await tester.pump();
      expect(find.text('You can select up to 2 items'), findsOneWidget);
      expect(find.textContaining('Confirm ('), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    test('remainingSelection', () {
      expect(const MediaPickerConfig().remainingSelection, isNull);
      expect(
        const MediaPickerConfig(
          maxSelection: 3,
          externalSelectedCount: 1,
        ).remainingSelection,
        2,
      );
      expect(
        const MediaPickerConfig(
          maxSelection: 2,
          externalSelectedCount: 5,
        ).remainingSelection,
        0,
      );
    });
  });
}
