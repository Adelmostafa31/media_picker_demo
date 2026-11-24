import 'picker_models.dart';

/// Loads one page: (page index) -> assets.
typedef PageLoader = Future<List<PickedMediaAsset>> Function(int page);

/// One independently-paged asset feed (Recent, or a single album).
///
/// Every [reset] starts a new generation; a page that was requested under an
/// older generation is discarded when it lands, so a slow response for the
/// previous sort can never leak into the new one. Pages are de-duplicated by
/// asset id, because offsets shift when the library changes between pages.
class PagedAssets {
  PagedAssets({this.albumId, required this.pageSize});

  /// Null = the global "Recent" feed.
  final String? albumId;
  final int pageSize;

  final List<PickedMediaAsset> items = [];
  final Set<String> _ids = {};
  int _page = 0;
  int _generation = 0;
  bool hasMore = true;
  bool loading = false;
  bool failed = false;

  /// Set while a load-more is scheduled for the next frame.
  bool loadScheduled = false;

  bool get isEmpty => items.isEmpty;

  /// Clears items and paging so the next [loadNext] starts again at page 0.
  void reset() {
    _generation++;
    items.clear();
    _ids.clear();
    _page = 0;
    hasMore = true;
    loading = false;
    failed = false;
    loadScheduled = false;
  }

  /// Fetches the next page with [load]. Returns false when nothing was
  /// requested (already loading / exhausted) or the response was stale.
  /// [onChange] is called whenever the observable state changed.
  Future<bool> loadNext(
    PageLoader load, {
    required void Function() onChange,
  }) async {
    if (loading || !hasMore) return false;
    final generation = _generation;
    loading = true;
    failed = false;
    onChange();
    try {
      final page = await load(_page);
      if (generation != _generation) return false;
      for (final asset in page) {
        if (_ids.add(asset.id)) items.add(asset);
      }
      hasMore = page.length >= pageSize;
      _page++;
      return true;
    } catch (_) {
      if (generation != _generation) return false;
      failed = true;
      return false;
    } finally {
      if (generation == _generation) {
        loading = false;
        onChange();
      }
    }
  }
}
