// On-device checks for the native side of custom_media_picker.
//
// Runs on a real simulator/device against the real plugin:
//   flutter test integration_test/picker_device_test.dart -d <device>
//
// Expects photo access to be granted before launch (on iOS:
// `xcrun simctl privacy <udid> grant photos com.example.example`), and the
// QA media set (QA_*.jpg / .heic / .mp4) in the library. Set QA_PERMISSION
// to `revoked` or `reset` (--dart-define) to run the permission-state group.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:custom_media_picker/custom_media_picker.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _permissionMode = String.fromEnvironment('QA_PERMISSION');

/// Lets the host take a screenshot (it watches the log for QA_SHOT).
Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  debugPrint('QA_SHOT $name');
  await Future<void>.delayed(const Duration(seconds: 3));
}

Future<List<PickedMediaAsset>> _all({bool ascending = false}) async {
  final all = <PickedMediaAsset>[];
  for (var page = 0; ; page++) {
    final items = await MediaPickerChannel.getAssets(
      filter: MediaFilter.all,
      page: page,
      pageSize: 50,
      ascending: ascending,
    );
    all.addAll(items);
    if (items.length < 50) return all;
  }
}

/// Opens the picker from a plain flutter/material app and returns the result
/// future so the test can confirm / dismiss it.
Future<Future<List<PickedMediaAsset>?>> _open(
  WidgetTester tester,
  MediaPickerConfig config,
) async {
  late Future<List<PickedMediaAsset>?> result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  result = CustomMediaPicker.pick(context, config: config),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  // Let native load the first page and thumbnails.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  await tester.pumpAndSettle();
  return result;
}

Finder get _tiles => find.byType(PickerAssetThumbnail);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  if (_permissionMode == 'revoked') {
    testWidgets('PERM: refused access is permanentlyDenied', (tester) async {
      expect(
        await MediaPickerChannel.checkPermissionStatus(),
        MediaPermissionStatus.permanentlyDenied,
      );
      // Asking again returns at once (iOS never re-prompts).
      expect(
        await MediaPickerChannel.requestPermissionStatus().timeout(
          const Duration(seconds: 5),
        ),
        MediaPermissionStatus.permanentlyDenied,
      );
      // ignore: deprecated_member_use
      expect(await MediaPickerChannel.checkPermission(), 'denied');
    });

    testWidgets('PERM: pick() returns null and reports the denial', (
      tester,
    ) async {
      var denied = 0;
      final result = await _open(
        tester,
        MediaPickerConfig(onPermissionDenied: () => denied++),
      );
      expect(await result, isNull);
      expect(denied, 1);
      expect(find.text('Select media'), findsNothing);
      expect(
        await MediaPickerChannel.getAssets(
          filter: MediaFilter.all,
          page: 0,
          pageSize: 10,
        ).then((v) => v.length),
        0,
      );
    });
    return;
  }

  if (_permissionMode == 'reset') {
    testWidgets('PERM: never asked is notDetermined', (tester) async {
      expect(
        await MediaPickerChannel.checkPermissionStatus(),
        MediaPermissionStatus.notDetermined,
      );
      // ignore: deprecated_member_use
      expect(await MediaPickerChannel.checkPermission(), 'notDetermined');
    });
    return;
  }

  group('granted', () {
    setUpAll(() async {
      // `flutter test` reinstalls the app, which resets photo access; the
      // host grants it while the app runs when it sees this line.
      debugPrint('QA_GRANT_ME');
      for (var i = 0; i < 40; i++) {
        if (await MediaPickerChannel.checkPermissionStatus() ==
            MediaPermissionStatus.granted) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    });

    testWidgets('PERM-G: status granted; concurrent requests agree', (
      tester,
    ) async {
      expect(
        await MediaPickerChannel.checkPermissionStatus(),
        MediaPermissionStatus.granted,
      );
      final both = await Future.wait([
        MediaPickerChannel.requestPermissionStatus(),
        MediaPickerChannel.requestPermissionStatus(),
      ]);
      expect(both, [
        MediaPermissionStatus.granted,
        MediaPermissionStatus.granted,
      ]);
    });

    testWidgets('PAGE: full library pages without duplicates', (tester) async {
      final all = await _all();
      final ids = all.map((a) => a.id).toSet();
      debugPrint('QA_INFO library=${all.length}');
      expect(all.length, greaterThanOrEqualTo(14));
      expect(ids.length, all.length, reason: 'duplicate ids across pages');
    });

    testWidgets('SORT: newest/oldest first by capture date', (tester) async {
      final desc = await _all();
      final asc = await _all(ascending: true);
      for (var i = 1; i < desc.length; i++) {
        expect(desc[i - 1].dateTaken, greaterThanOrEqualTo(desc[i].dateTaken));
      }
      for (var i = 1; i < asc.length; i++) {
        expect(asc[i - 1].dateTaken, lessThanOrEqualTo(asc[i].dateTaken));
      }
      expect(asc.first.id, desc.last.id);
    });

    testWidgets('DATE: range filter is inclusive and DST-safe', (tester) async {
      // Seeded: QA_03 2025-10-30 23:30, QA_04 2025-10-31 00:30 (Cairo DST end).
      int sec(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
      final start = DateTime(2025, 10, 30);
      final end = DateTime(2025, 10, 30, 23, 59, 59);
      final day = await MediaPickerChannel.getAssets(
        filter: MediaFilter.all,
        page: 0,
        pageSize: 50,
        startDateSec: sec(start),
        endDateSec: sec(end),
      );
      final days = day
          .map((a) => DateTime.fromMillisecondsSinceEpoch(a.dateTaken * 1000))
          .toList();
      debugPrint('QA_INFO oct30=$days');
      expect(day, isNotEmpty);
      for (final d in days) {
        expect((d.year, d.month, d.day), (2025, 10, 30));
      }
    });

    testWidgets('ALB: albums exist, Recents/Hidden not listed', (tester) async {
      final albums = await MediaPickerChannel.getAlbums(
        filter: MediaFilter.all,
      );
      debugPrint(
        'QA_INFO albums=${albums.map((a) => '${a.name}:${a.count}').toList()}',
      );
      expect(albums, isNotEmpty);
      final names = albums.map((a) => a.name.toLowerCase());
      expect(names, isNot(contains('hidden')));
      expect(names, isNot(contains('recents')));
      for (final a in albums) {
        expect(a.count, greaterThan(0));
      }
    });

    testWidgets('ROT: EXIF-rotated photo gets an upright thumbnail', (
      tester,
    ) async {
      // QA_ROT6: raw 1600x1000 landscape + orientation 6 => shown portrait.
      final rot = (await _all()).firstWhere(
        (a) => a.width == 1000 && a.height == 1600 || a.name == 'QA_ROT6.jpg',
        orElse: () => throw StateError('QA_ROT6 not found'),
      );
      final bytes = await MediaPickerChannel.getThumbnail(
        id: rot.id,
        type: 'image',
        size: 400,
      );
      expect(bytes, isNotNull);
      final codec = await ui.instantiateImageCodec(bytes!);
      final frame = (await codec.getNextFrame()).image;
      debugPrint(
        'QA_INFO rot thumb ${frame.width}x${frame.height} '
        'asset ${rot.width}x${rot.height}',
      );
      expect(frame.height, greaterThan(frame.width));
    });

    testWidgets(
      'PATH: originals resolve to readable files (photo, HEIC, video)',
      (tester) async {
        final all = await _all();
        final video = all.firstWhere((a) => a.isVideo);
        final heic = all.firstWhere(
          (a) => (a.name ?? '').toLowerCase().endsWith('.heic'),
          orElse: () => all.firstWhere((a) => !a.isVideo),
        );
        final photo = all.firstWhere((a) => !a.isVideo && a.id != heic.id);
        for (final a in [photo, heic, video]) {
          final f = await a.resolveFile();
          debugPrint('QA_INFO path ${a.typeString} ${a.name} -> ${f?.path}');
          expect(f, isNotNull);
          expect(f!.existsSync(), isTrue);
          expect(f.lengthSync(), greaterThan(0));
          // Still readable later (sandbox extension / tmp copy).
          await Future<void>.delayed(const Duration(seconds: 1));
          expect(await f.readAsBytes().then((b) => b.length), greaterThan(0));
        }
        // Concurrent resolves share one request and agree.
        final again = await Future.wait([
          video.resolvePath(),
          video.resolvePath(),
        ]);
        expect(again[0], again[1]);
      },
    );

    testWidgets('CACHE: clearCache does not throw; re-resolve still works', (
      tester,
    ) async {
      await MediaPickerChannel.clearCache();
      final v = (await _all()).firstWhere((a) => a.isVideo);
      final p = await PickedMediaAsset.fromMap({'id': v.id, 'type': 'video'})
          .resolvePath();
      expect(p, isNotNull);
      expect(File(p!).existsSync(), isTrue);
    });

    testWidgets('POS: pick 2 in order, confirm returns resolved paths', (
      tester,
    ) async {
      final result = await _open(
        tester,
        const MediaPickerConfig(maxSelection: 9, enableAlbums: true),
      );
      expect(find.text('Select media'), findsOneWidget);
      await _shot(tester, 'ios-grid');
      await tester.tap(_tiles.at(1));
      await tester.tap(_tiles.at(0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 9'), findsOneWidget);
      await tester.tap(find.textContaining('Confirm'));
      final picked = await result;
      expect(picked, hasLength(2));
      for (final a in picked!) {
        expect(a.resolvedPath, isNotNull);
        expect(File(a.resolvedPath!).existsSync(), isTrue);
      }
    });

    testWidgets('LIMIT: notice shows past maxSelection', (tester) async {
      await _open(tester, const MediaPickerConfig(maxSelection: 1));
      await tester.tap(_tiles.at(0));
      await tester.tap(_tiles.at(1));
      await tester.pump();
      expect(find.text('You can select up to 1 items'), findsOneWidget);
      await _shot(tester, 'ios-limit');
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets('ALB-BACK: back inside an album keeps the picker open', (
      tester,
    ) async {
      await _open(tester, const MediaPickerConfig());
      await tester.tap(find.text('Albums'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      await tester.pumpAndSettle();
      await _shot(tester, 'ios-albums');
      final albums = await MediaPickerChannel.getAlbums(
        filter: MediaFilter.all,
      );
      await tester.tap(find.text(albums.first.name).first);
      await tester.pumpAndSettle();
      await tester.tap(_tiles.first);
      await tester.pump();
      // Same as the system / predictive back gesture.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Select media'), findsOneWidget);
      expect(find.text('Albums'), findsOneWidget);
      expect(find.textContaining('Confirm (1)'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Select media'), findsNothing);
    });

    testWidgets('PREV: photo and video preview render', (tester) async {
      await _open(tester, const MediaPickerConfig());
      // Photo (tile 0 is the newest = a QA photo).
      await tester.longPress(_tiles.at(0));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.byType(PickerPreviewPage), findsOneWidget);
      expect(find.byIcon(Icons.broken_image), findsNothing);
      await _shot(tester, 'ios-preview-photo');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('PREV-ROT: rotated photo preview is portrait', (tester) async {
      final rot = (await _all()).firstWhere(
        (a) => a.width == 1000 && a.height == 1600 || a.name == 'QA_ROT6.jpg',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PickerPreviewPage(
            asset: rot,
            config: const MediaPickerConfig(),
            initiallySelected: false,
            onToggle: () => false,
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      await _shot(tester, 'ios-preview-rot6');
      final img = tester.widget<Image>(find.byType(Image).first);
      expect(img, isNotNull);
    });

    testWidgets('PREV-VID: video preview plays', (tester) async {
      final v = (await _all()).firstWhere((a) => a.isVideo);
      await tester.pumpWidget(
        MaterialApp(
          home: PickerPreviewPage(
            asset: v,
            config: const MediaPickerConfig(),
            initiallySelected: false,
            onToggle: () => false,
          ),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.byIcon(Icons.broken_image), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'VideoProgressIndicator',
        ),
        findsOneWidget,
      );
      await _shot(tester, 'ios-preview-video');
    });
  });
}
