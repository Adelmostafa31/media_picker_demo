// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'camera_config.dart';
import 'captured_media.dart';

/// Default review screen: the photo, or the video looping, with Retake / Use.
class DefaultCameraReview extends StatefulWidget {
  final CameraConfig config;
  final CapturedMedia media;
  final VoidCallback onRetake;
  final VoidCallback onUse;

  /// True while the capture is being saved to the gallery.
  final bool busy;

  const DefaultCameraReview({
    super.key,
    required this.config,
    required this.media,
    required this.onRetake,
    required this.onUse,
    this.busy = false,
  });

  @override
  State<DefaultCameraReview> createState() => _DefaultCameraReviewState();
}

class _DefaultCameraReviewState extends State<DefaultCameraReview> {
  VideoPlayerController? _video;
  bool _videoFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.media.isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    final v = VideoPlayerController.file(widget.media.file);
    try {
      await v.initialize();
      await v.setLooping(true);
      if (!mounted) {
        await v.dispose();
        return;
      }
      setState(() => _video = v);
      await v.play();
    } catch (_) {
      await v.dispose();
      // Unplayable here (codec, no plugin): still let the user decide.
      if (mounted) setState(() => _videoFailed = true);
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final c = config.colors;
    final video = _video;
    final Widget content = widget.media.isVideo
        ? (video == null
              ? Center(
                  child: _videoFailed
                      ? Icon(Icons.videocam_outlined, color: c.icon, size: 64)
                      : CircularProgressIndicator(color: c.accent),
                )
              : Center(
                  child: AspectRatio(
                    aspectRatio: video.value.aspectRatio,
                    child: VideoPlayer(video),
                  ),
                ))
        : Image.file(widget.media.file, fit: BoxFit.contain);
    final style =
        config.buttonTextStyle ??
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

    return ColoredBox(
      color: c.background,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(child: SizedBox.expand(child: content)),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: widget.busy ? null : widget.onRetake,
                    child: Text(
                      config.retakeLabel,
                      style: style.copyWith(color: c.text),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: c.accent),
                    onPressed: widget.busy ? null : widget.onUse,
                    child: widget.busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(config.useLabel, style: style),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
