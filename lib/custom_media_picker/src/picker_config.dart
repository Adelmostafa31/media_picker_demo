import 'package:flutter/widgets.dart';

/// How the picker is presented.
enum LayoutStyle { sheet, fullScreen }

/// How assets are listed.
enum ListStyle { grid, listView }

/// Which media types are shown.
enum MediaFilter { all, onlyImages, onlyVideos }

/// Leading icon when [LayoutStyle.fullScreen] is used.
enum FullScreenLeading { back, close }

/// Every color used by the picker. Feed your own theme tokens here.
class MediaPickerColors {
  final Color background;
  final Color appBar;
  final Color title;
  final Color text;
  final Color secondaryText;
  final Color icon;

  /// Filled circle + number when an item is selected.
  final Color selectedBadge;
  final Color selectedBadgeText;

  /// Border of the empty circle when an item is NOT selected.
  final Color unselectedBadgeBorder;

  /// Dim overlay drawn on top of a selected tile.
  final Color selectionOverlay;

  final Color confirmButton;
  final Color confirmButtonDisabled;
  final Color confirmButtonText;

  /// Chip behind the video duration label on tiles.
  final Color videoBadgeBackground;
  final Color videoBadgeText;

  /// Shown while a thumbnail is loading.
  final Color tilePlaceholder;
  final Color divider;

  // ---- Recent / Albums tab bar ----

  /// Background of the tab bar row. Transparent by default so it
  /// inherits [background].
  final Color tabBarBackground;
  final Color tabSelectedText;
  final Color tabUnselectedText;

  /// Underline under the active tab.
  final Color tabIndicator;

  const MediaPickerColors({
    this.background = const Color(0xFFFFFFFF),
    this.appBar = const Color(0xFFFFFFFF),
    this.title = const Color(0xFF1C1C1E),
    this.text = const Color(0xFF1C1C1E),
    this.secondaryText = const Color(0xFF8E8E93),
    this.icon = const Color(0xFF1C1C1E),
    this.selectedBadge = const Color(0xFF25D366),
    this.selectedBadgeText = const Color(0xFFFFFFFF),
    this.unselectedBadgeBorder = const Color(0xFFFFFFFF),
    this.selectionOverlay = const Color(0x4D000000),
    this.confirmButton = const Color(0xFF25D366),
    this.confirmButtonDisabled = const Color(0xFFBDBDBD),
    this.confirmButtonText = const Color(0xFFFFFFFF),
    this.videoBadgeBackground = const Color(0x99000000),
    this.videoBadgeText = const Color(0xFFFFFFFF),
    this.tilePlaceholder = const Color(0xFFE0E0E0),
    this.divider = const Color(0x1F000000),
    this.tabBarBackground = const Color(0x00000000),
    this.tabSelectedText = const Color(0xFF1C1C1E),
    this.tabUnselectedText = const Color(0xFF8E8E93),
    this.tabIndicator = const Color(0xFF25D366),
  });

  MediaPickerColors copyWith({
    Color? background,
    Color? appBar,
    Color? title,
    Color? text,
    Color? secondaryText,
    Color? icon,
    Color? selectedBadge,
    Color? selectedBadgeText,
    Color? unselectedBadgeBorder,
    Color? selectionOverlay,
    Color? confirmButton,
    Color? confirmButtonDisabled,
    Color? confirmButtonText,
    Color? videoBadgeBackground,
    Color? videoBadgeText,
    Color? tilePlaceholder,
    Color? divider,
    Color? tabBarBackground,
    Color? tabSelectedText,
    Color? tabUnselectedText,
    Color? tabIndicator,
  }) {
    return MediaPickerColors(
      background: background ?? this.background,
      appBar: appBar ?? this.appBar,
      title: title ?? this.title,
      text: text ?? this.text,
      secondaryText: secondaryText ?? this.secondaryText,
      icon: icon ?? this.icon,
      selectedBadge: selectedBadge ?? this.selectedBadge,
      selectedBadgeText: selectedBadgeText ?? this.selectedBadgeText,
      unselectedBadgeBorder:
          unselectedBadgeBorder ?? this.unselectedBadgeBorder,
      selectionOverlay: selectionOverlay ?? this.selectionOverlay,
      confirmButton: confirmButton ?? this.confirmButton,
      confirmButtonDisabled:
          confirmButtonDisabled ?? this.confirmButtonDisabled,
      confirmButtonText: confirmButtonText ?? this.confirmButtonText,
      videoBadgeBackground: videoBadgeBackground ?? this.videoBadgeBackground,
      videoBadgeText: videoBadgeText ?? this.videoBadgeText,
      tilePlaceholder: tilePlaceholder ?? this.tilePlaceholder,
      divider: divider ?? this.divider,
      tabBarBackground: tabBarBackground ?? this.tabBarBackground,
      tabSelectedText: tabSelectedText ?? this.tabSelectedText,
      tabUnselectedText: tabUnselectedText ?? this.tabUnselectedText,
      tabIndicator: tabIndicator ?? this.tabIndicator,
    );
  }
}

/// The single source of truth for everything customizable in the picker.
///
/// All sizes are plain doubles so you can plug in your own size tokens,
/// and all colors live in [MediaPickerColors] so you can plug in your
/// theme tokens (per theme, per size class).
class MediaPickerConfig {
  // ---- Layout ----
  final LayoutStyle layoutStyle;

  /// Sheet heights as fractions of the screen (0..1).
  final double sheetInitialHeight;
  final double sheetMinHeight;
  final double sheetMaxHeight;
  final double sheetCornerRadius;
  final bool showSheetDragHandle;

  /// Leading icon in fullScreen mode (ignored if [customLeading] is set).
  final FullScreenLeading fullScreenLeading;

  /// Fully custom leading widget for fullScreen mode.
  final Widget? customLeading;

  // ---- Tabs (Recent / Albums) ----

  /// Shows the Recent / Albums tab bar. Set false for the old
  /// single-feed behavior.
  final bool enableAlbums;

  /// Localizable tab labels, e.g. 'الحديثة' / 'الألبومات'.
  final String recentTabLabel;
  final String albumsTabLabel;

  /// Base style for tab labels; the color is overridden by
  /// [MediaPickerColors.tabSelectedText] / [tabUnselectedText].
  final TextStyle? tabLabelStyle;
  final double tabBarHeight;
  final double tabIndicatorHeight;

  // ---- List ----
  final ListStyle listStyle;

  /// Number of items per row in grid mode. Tile width/height and
  /// spacing are computed automatically from this + [gridSpacing].
  final int gridCrossAxisCount;
  final double gridSpacing;

  /// width / height of each grid tile. 1 = square (WhatsApp style).
  final double gridChildAspectRatio;

  final double listTileHeight;
  final double listThumbnailSize;
  final double listThumbnailRadius;

  // ---- Behavior ----
  final MediaFilter mediaFilter;

  /// 0 = unlimited.
  final int maxSelection;

  /// Assets fetched per page (infinite scroll).
  final int pageSize;

  /// Pixel size requested from the native side for tile thumbnails.
  final int thumbnailSize;

  /// Long-press a tile to open a full preview (video uses video_player).
  final bool enablePreview;

  /// Resolve real file paths for the selected assets before popping,
  /// so `asset.resolvedPath` / `asset.resolveFile()` are ready to use.
  final bool resolvePathsOnConfirm;

  // ---- Texts & styles ----
  final String? title;
  final TextStyle? titleStyle;
  final TextStyle? itemTitleStyle;
  final TextStyle? itemSubtitleStyle;
  final TextStyle? videoDurationStyle;
  final TextStyle? confirmTextStyle;
  final String emptyText;
  final TextStyle? emptyTextStyle;

  /// Builds the confirm button label, e.g. (n) => 'إرسال ($n)'.
  final String Function(int selectedCount)? confirmLabelBuilder;

  // ---- Sizes of small pieces ----
  final double selectionBadgeSize;
  final double confirmButtonHeight;
  final double confirmButtonRadius;

  // ---- Colors ----
  final MediaPickerColors colors;

  // ---- Callbacks ----
  final VoidCallback? onSelectionLimitReached;
  final VoidCallback? onPermissionDenied;

  const MediaPickerConfig({
    this.layoutStyle = LayoutStyle.sheet,
    this.sheetInitialHeight = 0.65,
    this.sheetMinHeight = 0.4,
    this.sheetMaxHeight = 0.95,
    this.sheetCornerRadius = 16,
    this.showSheetDragHandle = true,
    this.fullScreenLeading = FullScreenLeading.close,
    this.customLeading,
    this.enableAlbums = true,
    this.recentTabLabel = 'Recent',
    this.albumsTabLabel = 'Albums',
    this.tabLabelStyle,
    this.tabBarHeight = 44,
    this.tabIndicatorHeight = 2,
    this.listStyle = ListStyle.grid,
    this.gridCrossAxisCount = 3,
    this.gridSpacing = 4,
    this.gridChildAspectRatio = 1,
    this.listTileHeight = 72,
    this.listThumbnailSize = 56,
    this.listThumbnailRadius = 8,
    this.mediaFilter = MediaFilter.all,
    this.maxSelection = 0,
    this.pageSize = 60,
    this.thumbnailSize = 256,
    this.enablePreview = true,
    this.resolvePathsOnConfirm = true,
    this.title,
    this.titleStyle,
    this.itemTitleStyle,
    this.itemSubtitleStyle,
    this.videoDurationStyle,
    this.confirmTextStyle,
    this.emptyText = 'No media found',
    this.emptyTextStyle,
    this.confirmLabelBuilder,
    this.selectionBadgeSize = 22,
    this.confirmButtonHeight = 48,
    this.confirmButtonRadius = 12,
    this.colors = const MediaPickerColors(),
    this.onSelectionLimitReached,
    this.onPermissionDenied,
  });

  MediaPickerConfig copyWith({
    LayoutStyle? layoutStyle,
    double? sheetInitialHeight,
    double? sheetMinHeight,
    double? sheetMaxHeight,
    double? sheetCornerRadius,
    bool? showSheetDragHandle,
    FullScreenLeading? fullScreenLeading,
    Widget? customLeading,
    bool? enableAlbums,
    String? recentTabLabel,
    String? albumsTabLabel,
    TextStyle? tabLabelStyle,
    double? tabBarHeight,
    double? tabIndicatorHeight,
    ListStyle? listStyle,
    int? gridCrossAxisCount,
    double? gridSpacing,
    double? gridChildAspectRatio,
    double? listTileHeight,
    double? listThumbnailSize,
    double? listThumbnailRadius,
    MediaFilter? mediaFilter,
    int? maxSelection,
    int? pageSize,
    int? thumbnailSize,
    bool? enablePreview,
    bool? resolvePathsOnConfirm,
    String? title,
    TextStyle? titleStyle,
    TextStyle? itemTitleStyle,
    TextStyle? itemSubtitleStyle,
    TextStyle? videoDurationStyle,
    TextStyle? confirmTextStyle,
    String? emptyText,
    TextStyle? emptyTextStyle,
    String Function(int)? confirmLabelBuilder,
    double? selectionBadgeSize,
    double? confirmButtonHeight,
    double? confirmButtonRadius,
    MediaPickerColors? colors,
    VoidCallback? onSelectionLimitReached,
    VoidCallback? onPermissionDenied,
  }) {
    return MediaPickerConfig(
      layoutStyle: layoutStyle ?? this.layoutStyle,
      sheetInitialHeight: sheetInitialHeight ?? this.sheetInitialHeight,
      sheetMinHeight: sheetMinHeight ?? this.sheetMinHeight,
      sheetMaxHeight: sheetMaxHeight ?? this.sheetMaxHeight,
      sheetCornerRadius: sheetCornerRadius ?? this.sheetCornerRadius,
      showSheetDragHandle: showSheetDragHandle ?? this.showSheetDragHandle,
      fullScreenLeading: fullScreenLeading ?? this.fullScreenLeading,
      customLeading: customLeading ?? this.customLeading,
      enableAlbums: enableAlbums ?? this.enableAlbums,
      recentTabLabel: recentTabLabel ?? this.recentTabLabel,
      albumsTabLabel: albumsTabLabel ?? this.albumsTabLabel,
      tabLabelStyle: tabLabelStyle ?? this.tabLabelStyle,
      tabBarHeight: tabBarHeight ?? this.tabBarHeight,
      tabIndicatorHeight: tabIndicatorHeight ?? this.tabIndicatorHeight,
      listStyle: listStyle ?? this.listStyle,
      gridCrossAxisCount: gridCrossAxisCount ?? this.gridCrossAxisCount,
      gridSpacing: gridSpacing ?? this.gridSpacing,
      gridChildAspectRatio: gridChildAspectRatio ?? this.gridChildAspectRatio,
      listTileHeight: listTileHeight ?? this.listTileHeight,
      listThumbnailSize: listThumbnailSize ?? this.listThumbnailSize,
      listThumbnailRadius: listThumbnailRadius ?? this.listThumbnailRadius,
      mediaFilter: mediaFilter ?? this.mediaFilter,
      maxSelection: maxSelection ?? this.maxSelection,
      pageSize: pageSize ?? this.pageSize,
      thumbnailSize: thumbnailSize ?? this.thumbnailSize,
      enablePreview: enablePreview ?? this.enablePreview,
      resolvePathsOnConfirm:
          resolvePathsOnConfirm ?? this.resolvePathsOnConfirm,
      title: title ?? this.title,
      titleStyle: titleStyle ?? this.titleStyle,
      itemTitleStyle: itemTitleStyle ?? this.itemTitleStyle,
      itemSubtitleStyle: itemSubtitleStyle ?? this.itemSubtitleStyle,
      videoDurationStyle: videoDurationStyle ?? this.videoDurationStyle,
      confirmTextStyle: confirmTextStyle ?? this.confirmTextStyle,
      emptyText: emptyText ?? this.emptyText,
      emptyTextStyle: emptyTextStyle ?? this.emptyTextStyle,
      confirmLabelBuilder: confirmLabelBuilder ?? this.confirmLabelBuilder,
      selectionBadgeSize: selectionBadgeSize ?? this.selectionBadgeSize,
      confirmButtonHeight: confirmButtonHeight ?? this.confirmButtonHeight,
      confirmButtonRadius: confirmButtonRadius ?? this.confirmButtonRadius,
      colors: colors ?? this.colors,
      onSelectionLimitReached:
          onSelectionLimitReached ?? this.onSelectionLimitReached,
      onPermissionDenied: onPermissionDenied ?? this.onPermissionDenied,
    );
  }
}
