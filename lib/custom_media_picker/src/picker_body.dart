import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'picker_channel.dart';
import 'picker_config.dart';
import 'picker_models.dart';
import 'picker_preview.dart';

/// Shared body used by both the sheet and the full-screen layouts.
/// Handles paging, selection state, grid/list rendering and confirm.
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
  final List<PickedMediaAsset> _assets = [];
  final List<PickedMediaAsset> _selected = [];

  int _page = 0;
  bool _loading = false;
  bool _hasMore = true;
  bool _confirming = false;

  MediaPickerConfig get config => widget.config;
  MediaPickerColors get c => widget.config.colors;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final items = await MediaPickerChannel.getAssets(
        filter: config.mediaFilter,
        page: _page,
        pageSize: config.pageSize,
      );
      if (!mounted) return;
      setState(() {
        _assets.addAll(items);
        _hasMore = items.length == config.pageSize;
        _page++;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasMore = false;
      });
    }
  }

  int _selectionIndexOf(PickedMediaAsset a) =>
      _selected.indexWhere((e) => e.id == a.id);

  /// Toggles selection. Returns whether the asset is selected AFTER the
  /// call (used by the preview page to stay in sync with the max limit).
  bool _toggle(PickedMediaAsset a) {
    final i = _selectionIndexOf(a);
    if (i >= 0) {
      setState(() => _selected.removeAt(i));
      return false;
    }
    if (config.maxSelection > 0 && _selected.length >= config.maxSelection) {
      config.onSelectionLimitReached?.call();
      return false;
    }
    setState(() => _selected.add(a));
    return true;
  }

  Future<void> _openPreview(PickedMediaAsset a) async {
    if (!config.enablePreview) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
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
    if (config.resolvePathsOnConfirm) {
      setState(() => _confirming = true);
      for (final a in _selected) {
        await a.resolvePath();
      }
      if (!mounted) return;
    }
    Navigator.of(context).pop(List<PickedMediaAsset>.from(_selected));
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showHeader) _buildHeader(),
        Expanded(child: _buildList()),
        _buildConfirmBar(),
      ],
    );
  }

  Widget _buildHeader() {
    final count = _selected.length;
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
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            decoration: BoxDecoration(
              color: c.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  config.title ?? 'Select media',
                  style: config.titleStyle ??
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

  Widget _buildList() {
    if (_assets.isEmpty) {
      if (_loading) {
        return Center(
          child: CircularProgressIndicator(color: c.confirmButton),
        );
      }
      return Center(
        child: Text(
          config.emptyText,
          style: config.emptyTextStyle ??
              TextStyle(color: c.secondaryText, fontSize: 14),
        ),
      );
    }
    return config.listStyle == ListStyle.grid ? _buildGrid() : _buildListView();
  }

  void _maybeLoadMore(int index) {
    if (index >= _assets.length - 12 && _hasMore && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
    }
  }

  Widget _buildGrid() {
    return GridView.builder(
      controller: widget.scrollController,
      padding: EdgeInsets.all(config.gridSpacing),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: config.gridCrossAxisCount,
        crossAxisSpacing: config.gridSpacing,
        mainAxisSpacing: config.gridSpacing,
        childAspectRatio: config.gridChildAspectRatio,
      ),
      itemCount: _assets.length,
      itemBuilder: (context, index) {
        _maybeLoadMore(index);
        final asset = _assets[index];
        return _GridTile(
          asset: asset,
          selectionIndex: _selectionIndexOf(asset),
          config: config,
          onTap: () => _toggle(asset),
          onLongPress:
              config.enablePreview ? () => _openPreview(asset) : null,
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      controller: widget.scrollController,
      itemCount: _assets.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: c.divider),
      itemBuilder: (context, index) {
        _maybeLoadMore(index);
        final asset = _assets[index];
        return _ListTileItem(
          asset: asset,
          selectionIndex: _selectionIndexOf(asset),
          config: config,
          onTap: () => _toggle(asset),
          onLongPress:
              config.enablePreview ? () => _openPreview(asset) : null,
        );
      },
    );
  }

  Widget _buildConfirmBar() {
    final count = _selected.length;
    final enabled = count > 0 && !_confirming;
    final label = config.confirmLabelBuilder?.call(count) ??
        (count > 0 ? 'Confirm ($count)' : 'Confirm');
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.confirmButtonText,
                    ),
                  )
                : Text(
                    label,
                    style: config.confirmTextStyle ??
                        TextStyle(
                          color: c.confirmButtonText,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
          ),
        ),
      ),
    );
  }
}

// =========================================================== tile widgets

class _SelectionBadge extends StatelessWidget {
  final int selectionIndex; // -1 = not selected
  final MediaPickerConfig config;

  const _SelectionBadge({required this.selectionIndex, required this.config});

  @override
  Widget build(BuildContext context) {
    final c = config.colors;
    final selected = selectionIndex >= 0;
    final size = config.selectionBadgeSize;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? c.selectedBadge : const Color(0x33000000),
        border: Border.all(
          color: selected ? c.selectedBadge : c.unselectedBadgeBorder,
          width: 1.5,
        ),
      ),
      child: selected
          ? Center(
              child: Text(
                '${selectionIndex + 1}',
                style: TextStyle(
                  color: c.selectedBadgeText,
                  fontSize: size * 0.55,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );
  }
}

class _VideoDurationChip extends StatelessWidget {
  final PickedMediaAsset asset;
  final MediaPickerConfig config;

  const _VideoDurationChip({required this.asset, required this.config});

  @override
  Widget build(BuildContext context) {
    final c = config.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: c.videoBadgeBackground,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam, size: 12, color: c.videoBadgeText),
          const SizedBox(width: 3),
          Text(
            asset.durationLabel,
            style: config.videoDurationStyle ??
                TextStyle(color: c.videoBadgeText, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  final PickedMediaAsset asset;
  final int selectionIndex;
  final MediaPickerConfig config;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _GridTile({
    required this.asset,
    required this.selectionIndex,
    required this.config,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = config.colors;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PickerAssetThumbnail(
            asset: asset,
            size: config.thumbnailSize,
            placeholderColor: c.tilePlaceholder,
          ),
          if (selectionIndex >= 0)
            IgnorePointer(child: Container(color: c.selectionOverlay)),
          if (asset.isVideo)
            PositionedDirectional(
              start: 4,
              bottom: 4,
              child: _VideoDurationChip(asset: asset, config: config),
            ),
          PositionedDirectional(
            end: 4,
            top: 4,
            child: _SelectionBadge(
              selectionIndex: selectionIndex,
              config: config,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListTileItem extends StatelessWidget {
  final PickedMediaAsset asset;
  final int selectionIndex;
  final MediaPickerConfig config;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ListTileItem({
    required this.asset,
    required this.selectionIndex,
    required this.config,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = config.colors;
    final subtitleParts = <String>[
      if (asset.isVideo) asset.durationLabel,
      if (asset.sizeLabel.isNotEmpty) asset.sizeLabel,
    ];
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        height: config.listTileHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(config.listThumbnailRadius),
                child: SizedBox(
                  width: config.listThumbnailSize,
                  height: config.listThumbnailSize,
                  child: PickerAssetThumbnail(
                    asset: asset,
                    size: config.thumbnailSize,
                    placeholderColor: c.tilePlaceholder,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name ?? (asset.isVideo ? 'Video' : 'Photo'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: config.itemTitleStyle ??
                          TextStyle(color: c.text, fontSize: 14),
                    ),
                    if (subtitleParts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitleParts.join(' · '),
                          style: config.itemSubtitleStyle ??
                              TextStyle(
                                color: c.secondaryText,
                                fontSize: 12,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _SelectionBadge(
                selectionIndex: selectionIndex,
                config: config,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================= thumbnail widget

/// Loads a native-generated thumbnail through the channel with an
/// in-memory LRU cache. Never fetches the same (id, size) twice while
/// it's still cached.
class PickerAssetThumbnail extends StatefulWidget {
  final PickedMediaAsset asset;
  final int size;
  final Color placeholderColor;

  const PickerAssetThumbnail({
    super.key,
    required this.asset,
    required this.size,
    required this.placeholderColor,
  });

  @override
  State<PickerAssetThumbnail> createState() => _PickerAssetThumbnailState();
}

class _PickerAssetThumbnailState extends State<PickerAssetThumbnail> {
  Uint8List? _bytes;

  String get _cacheKey => '${widget.asset.id}_${widget.size}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PickerAssetThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id ||
        oldWidget.size != widget.size) {
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    final cached = PickerThumbnailCache.get(_cacheKey);
    if (cached != null) {
      setState(() => _bytes = cached);
      return;
    }
    try {
      final bytes = await MediaPickerChannel.getThumbnail(
        id: widget.asset.id,
        type: widget.asset.typeString,
        size: widget.size,
      );
      if (bytes == null || !mounted) return;
      PickerThumbnailCache.put(_cacheKey, bytes);
      setState(() => _bytes = bytes);
    } catch (_) {
      // keep placeholder
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      return ColoredBox(color: widget.placeholderColor);
    }
    return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
  }
}
