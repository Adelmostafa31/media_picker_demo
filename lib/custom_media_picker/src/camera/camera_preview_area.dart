import 'package:camera/camera.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'camera_session.dart';

/// Live preview filling its box (cropped, never stretched), with pinch to
/// zoom, tap to focus and the self-timer countdown.
class CameraPreviewArea extends StatefulWidget {
  final CameraSession session;

  const CameraPreviewArea({super.key, required this.session});

  @override
  State<CameraPreviewArea> createState() => _CameraPreviewAreaState();
}

class _CameraPreviewAreaState extends State<CameraPreviewArea> {
  double _zoomAtStart = 1;
  Offset? _focus;
  int _focusTick = 0;

  CameraSession get s => widget.session;

  void _onTap(TapUpDetails d, BoxConstraints box) {
    if (!s.config.enableTapToFocus) return;
    final p = Offset(
      (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0),
      (d.localPosition.dy / box.maxHeight).clamp(0.0, 1.0),
    );
    s.focusAt(p);
    final tick = ++_focusTick;
    setState(() => _focus = d.localPosition);
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted && tick == _focusTick) setState(() => _focus = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = s.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.expand();
    }
    final c = s.config.colors;
    // previewSize is reported in landscape; the screen is portrait.
    final size = controller.value.previewSize;
    final aspect = size == null ? 3 / 4 : size.height / size.width;

    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        onTapUp: (d) => _onTap(d, box),
        onScaleStart: (_) => _zoomAtStart = s.zoom,
        onScaleUpdate: s.config.enableZoom
            ? (d) {
                if (d.pointerCount > 1) s.setZoom(_zoomAtStart * d.scale);
              }
            : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: box.maxWidth,
                  height: box.maxWidth / aspect,
                  child: CameraPreview(controller),
                ),
              ),
            ),
            if (s.config.overlayBuilder != null)
              s.config.overlayBuilder!(context, s),
            if (_focus case final f?)
              PositionedDirectional(
                start: f.dx - 32,
                top: f.dy - 32,
                child: IgnorePointer(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      border: Border.all(color: c.focusRing, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            if (s.zoom > s.minZoom + 0.05)
              PositionedDirectional(
                bottom: 12,
                start: 0,
                end: 0,
                child: Center(
                  child: Text(
                    '${s.zoom.toStringAsFixed(1)}x',
                    style: TextStyle(color: c.text, fontSize: 13),
                  ),
                ),
              ),
            if (s.countdown case final n?)
              Center(
                child:
                    s.config.countdownBuilder?.call(context, n) ??
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '$n',
                        style: TextStyle(
                          color: c.text,
                          fontSize: 96,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
