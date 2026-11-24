import 'dart:async';

import 'package:custom_media_picker/custom_media_picker/src/picker_feed.dart';
import 'package:custom_media_picker/custom_media_picker.dart';
import 'package:flutter_test/flutter_test.dart';

PickedMediaAsset _asset(String id) =>
    PickedMediaAsset(id: id, type: PickedMediaType.image);

List<PickedMediaAsset> _page(Iterable<String> ids) => ids.map(_asset).toList();

void main() {
  group('PagedAssets', () {
    test('appends pages and stops when a page is short', () async {
      final feed = PagedAssets(pageSize: 2);
      await feed.loadNext((p) async => _page(['a$p', 'b$p']), onChange: () {});
      await feed.loadNext((p) async => _page(['a$p']), onChange: () {});

      expect(feed.items.map((a) => a.id), ['a0', 'b0', 'a1']);
      expect(feed.hasMore, isFalse);
      expect(feed.loading, isFalse);
    });

    test('drops a page that lands after reset (stale sort)', () async {
      final feed = PagedAssets(pageSize: 2);
      final slow = Completer<List<PickedMediaAsset>>();
      final pending = feed.loadNext((_) => slow.future, onChange: () {});

      feed.reset();
      await feed.loadNext(
        (_) async => _page(['new1', 'new2']),
        onChange: () {},
      );
      slow.complete(_page(['old1', 'old2']));

      expect(await pending, isFalse);
      expect(feed.items.map((a) => a.id), ['new1', 'new2']);
    });

    test('de-duplicates ids that shift across page boundaries', () async {
      final feed = PagedAssets(pageSize: 2);
      await feed.loadNext((_) async => _page(['a', 'b']), onChange: () {});
      await feed.loadNext((_) async => _page(['b', 'c']), onChange: () {});

      expect(feed.items.map((a) => a.id), ['a', 'b', 'c']);
    });

    test('marks failure instead of pretending the feed is empty', () async {
      final feed = PagedAssets(pageSize: 2);
      await feed.loadNext(
        (_) => Future.error(StateError('x')),
        onChange: () {},
      );

      expect(feed.failed, isTrue);
      expect(feed.loading, isFalse);
      expect(feed.hasMore, isTrue);
    });
  });
}
