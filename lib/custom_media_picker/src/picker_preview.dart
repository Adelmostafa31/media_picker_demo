import 'dart:io';
import 'dart:typed_data';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
// The ONLY external dependency, used solely for video playback here.
// If you never enable preview for videos you can delete this file and
// set `enablePreview: false` in the config.
import 'package:video_player/video_player.dart';

import 'picker_channel.dart';
import 'picker_config.dart';
import 'picker_models.dart';

/// Full-screen preview opened by long-pressing a tile.
/// Images: pinch-zoom via InteractiveViewer.
/// Videos: playback via video_player, tap to play/pause.
class PickerPreviewPage extends StatefulWidget {
  final PickedMediaAsset asset;
  final MediaPickerConfig config;
  final bool initiallySelected;

  /// Toggles selection in the parent; returns the NEW selected state
  /// (false also when the max-selection limit blocked the add).
  final bool Function() onToggle;

  const PickerPreviewPage({
    super.key,
    required this.asset,
    required this.config,
    required this.initiallySelected,
    required this.onToggle,
  });

  @override
  State<PickerPreviewPage> createState() => _PickerPreviewPageState();
}

class _PickerPreviewPageState extends State<PickerPreviewPage> {
  String? _path;
  Uint8List? _decodedImage;
  bool _failed = false;
  late bool _selected = widget.initiallySelected;
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    VideoPlayerController? controller;
    try {
      final path = await widget.asset.resolvePath();
      if (!mounted) return;
      if (path == null) {
        setState(() => _failed = true);
        return;
      }
      if (widget.asset.isVideo) {
        controller = VideoPlayerController.file(File(path));
        await controller.initialize();
        if (!mounted) {
          await controller.dispose();
          return;
        }
        _controller = controller;
        controller.play();
      } else if (_needsNativeDecode(path)) {
        _decodedImage = await MediaPickerChannel.getThumbnail(
          id: widget.asset.id,
          type: widget.asset.typeString,
          size: _nativePreviewSize,
        ).catchError((Object _) => null);
        if (!mounted) return;
      }
      setState(() => _path = path);
    } catch (_) {
      // Channel error, unreadable file or unsupported codec.
      if (controller != null && !identical(controller, _controller)) {
        await controller.dispose();
      }
      if (mounted) setState(() => _failed = true);
    }
  }

  static const _nativePreviewSize = 2048;

  /// Flutter's Android decoder renders HEIC/HEIF with the wrong EXIF rotation,
  /// so those are shown from a natively decoded, correctly rotated copy.
  static bool _needsNativeDecode(String path) {
    if (!Platform.isAndroid) return false;
    final p = path.toLowerCase();
    return p.endsWith('.heic') || p.endsWith('.heif');
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config.colors;
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0x66000000),
        elevation: 0,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(Icons.close, color: Color(0xFFFFFFFF)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: MaterialLocalizations.of(context)
                .selectedRowCountTitle(_selected ? 1 : 0),
            onPressed: () {
              final nowSelected = widget.onToggle();
              setState(() => _selected = nowSelected);
            },
            icon: Icon(
              _selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: _selected ? c.selectedBadge : const Color(0xFFFFFFFF),
              size: 26,
            ),
          ),
        ],
      ),
      body: _buildBody(c),
    );
  }

  Widget _buildBody(MediaPickerColors c) {
    if (_failed) {
      return const Center(
        child: Icon(Icons.broken_image, color: Color(0xFF666666), size: 48),
      );
    }
    final path = _path;
    if (path == null) {
      return Center(child: CircularProgressIndicator(color: c.confirmButton));
    }

    if (!widget.asset.isVideo) {
      return InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: switch (_decodedImage) {
            // MediaStore may cap the size; scale up to fill like Image.file.
            final bytes? => SizedBox.expand(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
            null => Image.file(File(path)),
          },
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return Center(child: CircularProgressIndicator(color: c.confirmButton));
    }
    return GestureDetector(
      onTap: _togglePlay,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio == 0
                  ? 16 / 9
                  : controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          AnimatedBuilder(
            animation: controller,
            builder: (_, _) => controller.value.isPlaying
                ? const SizedBox.shrink()
                : const Icon(
                    Icons.play_circle_fill,
                    color: Color(0xCCFFFFFF),
                    size: 64,
                  ),
          ),
          PositionedDirectional(
            start: 16,
            end: 16,
            bottom: 24,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: c.confirmButton,
                bufferedColor: const Color(0x55FFFFFF),
                backgroundColor: const Color(0x33FFFFFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
