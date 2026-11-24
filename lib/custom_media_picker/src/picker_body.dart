import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'picker_channel.dart';
import 'picker_config.dart';
import 'picker_date_range.dart';
import 'picker_feed.dart';
import 'picker_limit_notice.dart';
import 'picker_models.dart';
import 'picker_preview.dart';
import 'picker_sort.dart';
import 'picker_tiles.dart';

/// Shared body used by both the sheet and the full-screen layouts.
/// Handles the Recent/Albums tabs, paging, selection state,
/// grid/list rendering and confirm.
class PickerBody extends StatefulWidget {
  final MediaPickerConfig config;
  final ScrollController? scrollController;
  final bool showHeader;

  const PickerBody({
    super.key,
    required this.config,
    this.scrollController,
    this.showHeader = true,
  });

  @override
  State<PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends State<PickerBody> {
  late final PagedAssets _recent = PagedAssets(pageSize: config.pageSize);
  PagedAssets? _albumFeed; // feed of the currently opened album

  final List<PickedMediaAsset> _selected = [];

  List<MediaAlbum> _albums = const [];
  bool _albumsLoading = false;
  bool _albumsFetched = false;
  bool _albumsFailed = false;

  int _tab = 0; // 0 = Recent, 1 = Albums
  MediaAlbum? _openAlbum;

  bool _confirming = false;

  /// Visible while the selection-limit notice is shown.
  bool _limitNotice = false;
  Timer? _limitNoticeTimer;

  late MediaSortOrder _sortOrder;
  DateTimeRange? _dateRange;

  MediaPickerConfig get config => widget.config;
  MediaPickerColors get c => widget.config.colors;

  @override
  void initState() {
    super.initState();
    _sortOrder = config.initialSortOrder;
    final initial = config.initialSelection ?? const [];
    final room = config.remainingSelection;
    // Never start above the limit, otherwise the header shows e.g. "12 / 9".
    _selected.addAll(room == null ? initial : initial.take(room));
    _loadMore(_recent);
  }

  @override
  void dispose() {
    _limitNoticeTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------- loading

  Future<void> _loadMore(PagedAssets feed) async {
    // Sorting only applies to the global Recent feed, never to an album.
    final isRecent = feed.albumId == null;
    final range = isRecent ? _dateRange : null;
    final ascending = isRecent && _sortOrder == MediaSortOrder.oldestFirst;
    await feed.loadNext(
      (page) => MediaPickerChannel.getAssets(
        filter: config.mediaFilter,
        page: page,
        pageSize: config.pageSize,
        albumId: feed.albumId,
        ascending: ascending,
        startDateSec: range == null ? null : _toSec(range.start),
        endDateSec: range == null ? null : _toSec(_endOfDay(range.end)),
        // Names are only shown by the list layout and are slow on iOS.
        includeNames: config.listStyle == ListStyle.listView,
      ),
      onChange: () {
        if (mounted) setState(() {});
      },
    );
  }

  static int _toSec(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59);

  Future<void> _loadAlbums({bool force = false}) async {
    if (_albumsLoading || (_albumsFetched && !force)) return;
    setState(() {
      _albumsLoading = true;
      _albumsFailed = false;
    });
    try {
      final albums = await MediaPickerChannel.getAlbums(
        filter: config.mediaFilter,
      );
      if (!mounted) return;
      setState(() {
        _albums = albums;
        _albumsFetched = true;
        _albumsLoading = false;
      });
    } catch (e, s) {
      debugPrintStack(
        label: 'custom_media_picker: getAlbums failed: $e',
        stackTrace: s,
      );
      if (!mounted) return;
      setState(() {
        _albumsFailed = true;
        _albumsLoading = false;
      });
    }
  }

  // ------------------------------------------------------------------ sort

  void _reloadRecent() {
    _recent.reset();
    _loadMore(_recent);
  }

  void _applySort(MediaSortOrder order) {
    if (order == _sortOrder && order != MediaSortOrder.dateRange) return;
    setState(() {
      _sortOrder = order;
      if (order != MediaSortOrder.dateRange) _dateRange = null;
    });
    _reloadRecent();
  }

  Future<void> _pickDateRange() async {
    final result = await showMediaDateRangePicker(
      context: context,
      config: config,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialRange: _dateRange,
    );
    if (result == null || !mounted) return;
    setState(() {
      _dateRange = result;
      _sortOrder = MediaSortOrder.dateRange;
    });
    _reloadRecent();
  }

  Future<void> _showSortSheet() async {
    final choice = await showPickerSortSheet(
      context: context,
      config: config,
      current: _sortOrder,
    );
    if (choice == null || !mounted) return;
    if (choice == MediaSortOrder.dateRange) {
      await _pickDateRange();
    } else {
      _applySort(choice);
    }
  }

  void _onTabChanged(int i) {
    if (_tab == i) return;
    setState(() => _tab = i);
    if (i == 1) _loadAlbums();
  }

  void _openAlbumFeed(MediaAlbum album) {
    final feed = PagedAssets(albumId: album.id, pageSize: config.pageSize);
    setState(() {
      _openAlbum = album;
      _albumFeed = feed;
    });
    _loadMore(feed);
  }

  void _closeAlbumFeed() {
    setState(() {
      _openAlbum = null;
      _albumFeed = null;
    });
  }

  // ------------------------------------------------------------ selection

  int _selectionIndexOf(PickedMediaAsset a) => _selected.indexOf(a);

  /// Toggles selection. Returns whether the asset is selected AFTER the
  /// call (used by the preview page to stay in sync with the max limit).
  bool _toggle(PickedMediaAsset a) {
    final i = _selectionIndexOf(a);
    if (i >= 0) {
      setState(() => _selected.removeAt(i));
      return false;
    }
    final room = config.remainingSelection;
    if (room != null && _selected.length >= room) {
      _showLimitNotice();
      config.onSelectionLimitReached?.call();
      return false;
    }
    setState(() => _selected.add(a));
    return true;
  }

  void _showLimitNotice() {
    if (!config.showSelectionLimitMessage) return;
    _limitNoticeTimer?.cancel();
    setState(() => _limitNotice = true);
    _limitNoticeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _limitNotice = false);
    });
  }

  Future<void> _openPreview(PickedMediaAsset a) async {
    if (!config.enablePreview) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => PickerPreviewPage(
          asset: a,
          config: config,
          initiallySelected: _selectionIndexOf(a) >= 0,
          onToggle: () => _toggle(a),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _confirm() async {
    if (_selected.isEmpty || _confirming) return;
    var result = List<PickedMediaAsset>.of(_selected);
    if (config.resolvePathsOnConfirm) {
      setState(() => _confirming = true);
      try {
        final paths = await Future.wait(
          result.map((a) => a.resolvePath().catchError((Object _) => null)),
        );
        final unavailable = [
          for (var i = 0; i < result.length; i++)
            if (paths[i] == null) result[i],
        ];
        if (unavailable.isNotEmpty) {
          config.onAssetsUnavailable?.call(unavailable);
          result = [
            for (var i = 0; i < result.length; i++)
              if (paths[i] != null) result[i],
          ];
        }
      } finally {
        if (mounted) setState(() => _confirming = false);
      }
      if (!mounted) return;
    }
    Navigator.of(context).pop(result);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    // System/predictive back inside an album returns to the album list
    // instead of closing the picker and dropping the selection.
    return PopScope<Object?>(
      canPop: _openAlbum == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _openAlbum != null) _closeAlbumFeed();
      },
      child: Column(
        children: [
          if (widget.showHeader) _buildHeader(),
          if (config.enableAlbums) _buildTabBar(),
          Expanded(child: _buildContent()),
          PickerLimitNotice(visible: _limitNotice, config: config),
          _buildConfirmBar(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_tab == 0) {
      return Column(
        children: [
          if (config.enableSort)
            PickerSortRow(
              config: config,
              sortOrder: _sortOrder,
              dateRange: _dateRange,
              onTap: _showSortSheet,
              onClearRange: () => _applySort(MediaSortOrder.newestFirst),
            ),
          Expanded(child: _buildFeed(_recent)),
        ],
      );
    }
    final album = _openAlbum;
    final albumFeed = _albumFeed;
    if (album == null || albumFeed == null) return _buildAlbumList();
    return Column(
      children: [
        _buildAlbumHeader(album),
        Expanded(child: _buildFeed(albumFeed)),
      ],
    );
  }

  Widget _buildHeader() {
    // Total, including items held outside the picker (camera captures).
    final count = _selected.length + config.externalSelectedCount;
    final countLabel = config.maxSelection > 0
        ? '$count / ${config.maxSelection}'
        : (count > 0 ? '$count' : '');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (config.showSheetDragHandle)
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsetsDirectional.only(top: 8, bottom: 4),
            decoration: BoxDecoration(
              color: c.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  config.title ?? 'Select media',
                  style:
                      config.titleStyle ??
                      TextStyle(
                        color: c.title,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (countLabel.isNotEmpty)
                Text(
                  countLabel,
                  style: TextStyle(color: c.secondaryText, fontSize: 13),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- tabs

  Widget _buildTabBar() {
    final labels = [config.recentTabLabel, config.albumsTabLabel];
    final baseStyle =
        config.tabLabelStyle ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
    return Container(
      height: config.tabBarHeight,
      color: c.tabBarBackground,
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = _tab == i;
          return Expanded(
            child: Semantics(
              selected: selected,
              button: true,
              child: InkWell(
                onTap: () => _onTabChanged(i),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          labels[i],
                          style: baseStyle.copyWith(
                            color: selected
                                ? c.tabSelectedText
                                : c.tabUnselectedText,
                          ),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: config.tabIndicatorHeight,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: selected
                            ? c.tabIndicator
                            : const Color(0x00000000),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // --------------------------------------------------------------- albums

  Widget _buildAlbumList() {
    if (_albumsLoading && _albums.isEmpty) return _buildSpinner();
    if (_albumsFailed && _albums.isEmpty) {
      return _buildError(() => _loadAlbums(force: true));
    }
    if (_albums.isEmpty) return _buildEmpty();
    return ListView.builder(
      controller: widget.scrollController,
      itemCount: _albums.length,
      itemBuilder: (context, index) {
        final album = _albums[index];
        return PickerAlbumRow(
          key: ValueKey(album.id),
          album: album,
          config: config,
          showDivider: index < _albums.length - 1,
          onTap: () => _openAlbumFeed(album),
        );
      },
    );
  }

  Widget _buildAlbumHeader(MediaAlbum album) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          BackButton(color: c.icon, onPressed: _closeAlbumFeed),
          Expanded(
            child: Text(
              album.name.isEmpty ? config.unknownAlbumLabel : album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  config.itemTitleStyle ??
                  TextStyle(
                    color: c.title,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Text(
              '${album.count}',
              style: TextStyle(color: c.secondaryText, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- feeds

  Widget _buildSpinner() =>
      Center(child: CircularProgressIndicator(color: c.confirmButton));

  Widget _buildEmpty() => Center(
    child: Text(
      config.emptyText,
      style:
          config.emptyTextStyle ??
          TextStyle(color: c.secondaryText, fontSize: 14),
    ),
  );

  Widget _buildError(VoidCallback onRetry) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          config.errorText,
          textAlign: TextAlign.center,
          style:
              config.emptyTextStyle ??
              TextStyle(color: c.secondaryText, fontSize: 14),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text(
            config.retryLabel,
            style: TextStyle(color: c.confirmButton),
          ),
        ),
      ],
    ),
  );

  Widget _buildFeed(PagedAssets feed) {
    if (feed.isEmpty) {
      if (feed.loading) return _buildSpinner();
      if (feed.failed) {
        return _buildError(() {
          feed.hasMore = true;
          _loadMore(feed);
        });
      }
      return _buildEmpty();
    }
    return config.listStyle == ListStyle.grid
        ? _buildGrid(feed)
        : _buildListView(feed);
  }

  /// Schedules at most one load per frame when a tile near the end is built.
  void _maybeLoadMore(PagedAssets feed, int index) {
    if (feed.loadScheduled || feed.loading || !feed.hasMore) return;
    if (index < feed.items.length - 12) return;
    feed.loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      feed.loadScheduled = false;
      if (mounted) _loadMore(feed);
    });
  }

  Widget _buildGrid(PagedAssets feed) {
    return GridView.builder(
      controller: widget.scrollController,
      padding: EdgeInsets.all(config.gridSpacing),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: config.gridCrossAxisCount,
        crossAxisSpacing: config.gridSpacing,
        mainAxisSpacing: config.gridSpacing,
        childAspectRatio: config.gridChildAspectRatio,
      ),
      itemCount: feed.items.length,
      itemBuilder: (context, index) {
        _maybeLoadMore(feed, index);
        final asset = feed.items[index];
        return PickerGridTile(
          key: ValueKey(asset.id),
          asset: asset,
          selectionIndex: _selectionIndexOf(asset),
          config: config,
          onTap: () => _toggle(asset),
          onLongPress: config.enablePreview ? () => _openPreview(asset) : null,
        );
      },
    );
  }

  Widget _buildListView(PagedAssets feed) {
    return ListView.builder(
      controller: widget.scrollController,
      itemCount: feed.items.length,
      itemBuilder: (context, index) {
        _maybeLoadMore(feed, index);
        final asset = feed.items[index];
        return PickerListTile(
          key: ValueKey(asset.id),
          asset: asset,
          selectionIndex: _selectionIndexOf(asset),
          config: config,
          showDivider: index < feed.items.length - 1,
          onTap: () => _toggle(asset),
          onLongPress: config.enablePreview ? () => _openPreview(asset) : null,
        );
      },
    );
  }

  // -------------------------------------------------------------- confirm

  Widget _buildConfirmBar() {
    final count = _selected.length;
    final enabled = count > 0 && !_confirming;
    final label =
        config.confirmLabelBuilder?.call(count) ??
        (count > 0 ? '${config.confirmLabel} ($count)' : config.confirmLabel);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 12),
        child: Semantics(
          button: true,
          enabled: enabled,
          label: label,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: enabled ? _confirm : null,
            child: Container(
              height: config.confirmButtonHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: enabled || _confirming
                    ? c.confirmButton
                    : c.confirmButtonDisabled,
                borderRadius: BorderRadius.circular(config.confirmButtonRadius),
              ),
              child: _confirming
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.confirmButtonText,
                      ),
                    )
                  : Text(
                      label,
                      style:
                          config.confirmTextStyle ??
                          TextStyle(
                            color: c.confirmButtonText,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
