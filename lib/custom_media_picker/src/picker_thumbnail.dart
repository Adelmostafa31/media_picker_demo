import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'picker_channel.dart';

/// Loads a native-generated thumbnail through the channel with an
/// in-memory LRU cache. Takes raw id/type so it also serves album covers.
class PickerAssetThumbnail extends StatefulWidget {
  final String assetId;
  final String assetType; // 'image' | 'video'
  final int size;
  final Color placeholderColor;

  const PickerAssetThumbnail({
    super.key,
    required this.assetId,
    required this.assetType,
    required this.size,
    required this.placeholderColor,
  });

  @override
  State<PickerAssetThumbnail> createState() => _PickerAssetThumbnailState();
}

class _PickerAssetThumbnailState extends State<PickerAssetThumbnail> {
  Uint8List? _bytes;

  static String _keyOf(PickerAssetThumbnail w) => '${w.assetId}_${w.size}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PickerAssetThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_keyOf(oldWidget) != _keyOf(widget)) _load();
  }

  Future<void> _load() async {
    final key = _keyOf(widget);
    final cached = PickerThumbnailCache.get(key);
    // Synchronous path: no setState needed, build reads _bytes directly.
    _bytes = cached;
    if (cached != null) return;
    try {
      final bytes = await MediaPickerChannel.getThumbnail(
        id: widget.assetId,
        type: widget.assetType,
        size: widget.size,
      );
      if (bytes == null) return;
      PickerThumbnailCache.put(key, bytes);
      // The tile may have been recycled for another asset while this request
      // was in flight; only apply the bytes if they are still ours.
      if (!mounted || _keyOf(widget) != key) return;
      setState(() => _bytes = bytes);
    } catch (_) {
      // Keep the placeholder; a recreated tile (scrolled back) asks again.
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) return ColoredBox(color: widget.placeholderColor);
    return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
  }
}
