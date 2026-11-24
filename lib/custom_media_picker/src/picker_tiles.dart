// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'picker_config.dart';
import 'picker_models.dart';
import 'picker_thumbnail.dart';

/// Screen-reader label for an asset tile, e.g. "Video 1:05".
String assetSemanticLabel(PickedMediaAsset a, MediaPickerConfig config) =>
    a.isVideo ? '${config.videoLabel} ${a.durationLabel}' : config.photoLabel;

/// Circle in the tile corner showing the 1-based selection order.
class PickerSelectionBadge extends StatelessWidget {
  final int selectionIndex; // -1 = not selected
  final MediaPickerConfig config;

  const PickerSelectionBadge({
    super.key,
    required this.selectionIndex,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final c = config.colors;
    final selected = selectionIndex >= 0;
    final size = config.selectionBadgeSize;
    return ExcludeSemantics(
      child: Container(
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
      ),
    );
  }
}

class PickerVideoDurationChip extends StatelessWidget {
  final PickedMediaAsset asset;
  final MediaPickerConfig config;

  const PickerVideoDurationChip({
    super.key,
    required this.asset,
    required this.config,
  });

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
            style:
                config.videoDurationStyle ??
                TextStyle(color: c.videoBadgeText, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Wraps a tile so screen readers announce it as a selectable item.
class _TileSemantics extends StatelessWidget {
  final PickedMediaAsset asset;
  final MediaPickerConfig config;
  final int selectionIndex;
  final Widget child;

  const _TileSemantics({
    required this.asset,
    required this.config,
    required this.selectionIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selectionIndex >= 0,
      label: assetSemanticLabel(asset, config),
      value: selectionIndex >= 0 ? '${selectionIndex + 1}' : null,
      child: child,
    );
  }
}

class PickerGridTile extends StatelessWidget {
  final PickedMediaAsset asset;
  final int selectionIndex;
  final MediaPickerConfig config;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const PickerGridTile({
    super.key,
    required this.asset,
    required this.selectionIndex,
    required this.config,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = config.colors;
    return _TileSemantics(
      asset: asset,
      config: config,
      selectionIndex: selectionIndex,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PickerAssetThumbnail(
              assetId: asset.id,
              assetType: asset.typeString,
              size: config.thumbnailSize,
              placeholderColor: c.tilePlaceholder,
            ),
            if (selectionIndex >= 0)
              IgnorePointer(child: ColoredBox(color: c.selectionOverlay)),
            if (asset.isVideo)
              PositionedDirectional(
                start: 4,
                bottom: 4,
                // Already part of the tile's semantic label.
                child: ExcludeSemantics(
                  child: PickerVideoDurationChip(asset: asset, config: config),
                ),
              ),
            PositionedDirectional(
              end: 4,
              top: 4,
              child: PickerSelectionBadge(
                selectionIndex: selectionIndex,
                config: config,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Divider-separated row used by the list layout and the album list.
class _PickerRow extends StatelessWidget {
  final MediaPickerConfig config;
  final bool showDivider;
  final Widget thumbnail;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PickerRow({
    required this.config,
    required this.showDivider,
    required this.thumbnail,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = config.colors;
    final subtitle = this.subtitle;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: config.listTileHeight,
        decoration: showDivider
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: c.divider, width: 1)),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(config.listThumbnailRadius),
              child: SizedBox.square(
                dimension: config.listThumbnailSize,
                child: thumbnail,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        config.itemTitleStyle ??
                        TextStyle(color: c.text, fontSize: 14),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 2),
                      child: Text(
                        subtitle,
                        style:
                            config.itemSubtitleStyle ??
                            TextStyle(color: c.secondaryText, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}

class PickerListTile extends StatelessWidget {
  final PickedMediaAsset asset;
  final int selectionIndex;
  final MediaPickerConfig config;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const PickerListTile({
    super.key,
    required this.asset,
    required this.selectionIndex,
    required this.config,
    required this.showDivider,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (asset.isVideo) asset.durationLabel,
      if (asset.sizeLabel.isNotEmpty) asset.sizeLabel,
    ].join(' · ');
    return _TileSemantics(
      asset: asset,
      config: config,
      selectionIndex: selectionIndex,
      child: _PickerRow(
        config: config,
        showDivider: showDivider,
        onTap: onTap,
        onLongPress: onLongPress,
        title:
            asset.name ??
            (asset.isVideo ? config.videoLabel : config.photoLabel),
        subtitle: subtitle,
        thumbnail: PickerAssetThumbnail(
          assetId: asset.id,
          assetType: asset.typeString,
          size: config.thumbnailSize,
          placeholderColor: config.colors.tilePlaceholder,
        ),
        trailing: PickerSelectionBadge(
          selectionIndex: selectionIndex,
          config: config,
        ),
      ),
    );
  }
}

class PickerAlbumRow extends StatelessWidget {
  final MediaAlbum album;
  final MediaPickerConfig config;
  final bool showDivider;
  final VoidCallback onTap;

  const PickerAlbumRow({
    super.key,
    required this.album,
    required this.config,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = config.colors;
    final coverId = album.coverAssetId;
    return _PickerRow(
      config: config,
      showDivider: showDivider,
      onTap: onTap,
      title: album.name.isEmpty ? config.unknownAlbumLabel : album.name,
      subtitle: '${album.count}',
      thumbnail: coverId == null
          ? ColoredBox(color: c.tilePlaceholder)
          : PickerAssetThumbnail(
              assetId: coverId,
              assetType: album.coverAssetType,
              size: config.thumbnailSize,
              placeholderColor: c.tilePlaceholder,
            ),
      // chevron_right mirrors automatically in RTL.
      trailing: Icon(Icons.chevron_right, color: c.secondaryText, size: 20),
    );
  }
}
