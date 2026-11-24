import 'dart:typed_data';

import 'package:custom_media_picker/custom_media_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PickedMediaAsset', () {
    test('durationLabel formats minutes and hours', () {
      PickedMediaAsset v(int ms) => PickedMediaAsset(
        id: '1',
        type: PickedMediaType.video,
        durationMs: ms,
      );
      expect(v(0).durationLabel, '0:00');
      expect(v(65000).durationLabel, '1:05');
      expect(v(3753000).durationLabel, '1:02:33');
    });

    test('sizeLabel picks a unit and hides unknown sizes', () {
      PickedMediaAsset s(int? b) =>
          PickedMediaAsset(id: '1', type: PickedMediaType.image, sizeBytes: b);
      expect(s(null).sizeLabel, '');
      expect(s(0).sizeLabel, '');
      expect(s(2048).sizeLabel, '2 KB');
      expect(s(3 * 1024 * 1024).sizeLabel, '3.0 MB');
    });

    test('fromMap tolerates missing and mistyped fields', () {
      final a = PickedMediaAsset.fromMap({
        'id': 42,
        'type': 'video',
        'durationMs': 1500.0,
        'dateAdded': 100,
        'name': 7,
      });
      expect(a.id, '42');
      expect(a.isVideo, isTrue);
      expect(a.durationMs, 1500);
      expect(a.dateTaken, 100); // falls back to dateAdded
      expect(a.name, isNull);
    });

    test('equality is by id', () {
      final a = PickedMediaAsset(id: 'x', type: PickedMediaType.image);
      final b = PickedMediaAsset(id: 'x', type: PickedMediaType.video);
      expect(a, b);
      expect({a, b}, hasLength(1));
    });
  });

  test('MediaPermissionStatus.parse maps unknown values to denied', () {
    expect(MediaPermissionStatus.parse('granted').hasAccess, isTrue);
    expect(MediaPermissionStatus.parse('limited').hasAccess, isTrue);
    expect(
      MediaPermissionStatus.parse('permanentlyDenied'),
      MediaPermissionStatus.permanentlyDenied,
    );
    expect(MediaPermissionStatus.parse(null), MediaPermissionStatus.denied);
    expect(MediaPermissionStatus.parse('???').hasAccess, isFalse);
  });

  group('PickerThumbnailCache', () {
    tearDown(() {
      PickerThumbnailCache.clear();
      PickerThumbnailCache.maxEntries = 300;
    });

    test('evicts least recently used entries', () {
      PickerThumbnailCache.maxEntries = 2;
      PickerThumbnailCache.put('a', Uint8List(1));
      PickerThumbnailCache.put('b', Uint8List(1));
      PickerThumbnailCache.get('a'); // a is now most recent
      PickerThumbnailCache.put('c', Uint8List(1));

      expect(PickerThumbnailCache.get('a'), isNotNull);
      expect(PickerThumbnailCache.get('b'), isNull);
      expect(PickerThumbnailCache.get('c'), isNotNull);
    });

    test('shrinking maxEntries trims on the next put', () {
      for (final k in ['a', 'b', 'c', 'd']) {
        PickerThumbnailCache.put(k, Uint8List(1));
      }
      PickerThumbnailCache.maxEntries = 2;
      PickerThumbnailCache.put('e', Uint8List(1));
      expect(PickerThumbnailCache.length, 2);
    });
  });
}
