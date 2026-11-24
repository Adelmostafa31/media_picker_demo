// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'camera_config.dart';
import 'camera_controls.dart';

/// Default capture button. Tap = [CameraControls.capture]; in photo mode,
/// holding it records a video when `holdShutterToRecord` allows.
class DefaultShutterButton extends StatelessWidget {
  final CameraControls controls;
  final double size;

  const DefaultShutterButton({
    super.key,
    required this.controls,
    this.size = 76,
  });

  bool get _canHoldToRecord =>
      controls.config.holdShutterToRecord &&
      controls.config.allowsVideo &&
      controls.mode == CaptureMode.photo;

  @override
  Widget build(BuildContext context) {
    final c = controls.config.colors;
    final recording = controls.isRecording;
    final video = controls.mode == CaptureMode.video || recording;
    final max = controls.config.maxVideoDuration;
    final progress = recording && max != null && max > Duration.zero
        ? controls.recordingElapsed.inMilliseconds / max.inMilliseconds
        : null;

    return Semantics(
      button: true,
      label: recording
          ? controls.config.videoLabel
          : (video ? controls.config.videoLabel : controls.config.photoLabel),
      child: GestureDetector(
        onTap: controls.isBusy && !recording ? null : controls.capture,
        onLongPressStart: _canHoldToRecord
            ? (_) => controls.startRecording()
            : null,
        onLongPressEnd: _canHoldToRecord
            ? (_) => controls.stopRecording()
            : null,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: ExcludeSemantics(
                  child: CircularProgressIndicator(
                    value: progress ?? 1,
                    strokeWidth: 4,
                    color: recording ? c.shutterRecording : c.shutter,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: recording ? size * 0.38 : size * 0.78,
                height: recording ? size * 0.38 : size * 0.78,
                decoration: BoxDecoration(
                  color: video ? c.shutterRecording : c.shutter,
                  borderRadius: BorderRadius.circular(recording ? 8 : size),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
