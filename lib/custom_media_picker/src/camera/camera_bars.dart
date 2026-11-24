// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'camera_config.dart';
import 'camera_controls.dart';
import 'camera_shutter.dart';

String formatRecording(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

IconData flashIcon(CameraFlash flash) => switch (flash) {
  CameraFlash.off => Icons.flash_off,
  CameraFlash.auto => Icons.flash_auto,
  CameraFlash.on => Icons.flash_on,
  CameraFlash.torch => Icons.highlight,
};

/// Default top row: close, recording time, timer and flash.
class DefaultCameraTopBar extends StatelessWidget {
  final CameraControls controls;

  const DefaultCameraTopBar({super.key, required this.controls});

  @override
  Widget build(BuildContext context) {
    final config = controls.config;
    final c = config.colors;
    final l10n = MaterialLocalizations.of(context);
    final showTimer = config.timerOptions.where((t) => t > 0).isNotEmpty;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.closeButtonTooltip,
            onPressed: controls.isRecording ? null : controls.close,
            icon: Icon(Icons.close, color: c.icon),
          ),
          const Spacer(),
          if (controls.isRecording)
            config.recordingIndicatorBuilder?.call(context, controls) ??
                DefaultRecordingIndicator(controls: controls),
          const Spacer(),
          if (showTimer && !controls.isRecording)
            TextButton.icon(
              onPressed: controls.cycleTimer,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: Icon(
                Icons.timer_outlined,
                color: c.icon,
                size: 20,
                semanticLabel: config.timerLabel,
              ),
              label: Text(
                controls.timerSeconds == 0 ? '' : '${controls.timerSeconds}s',
                style: TextStyle(color: c.text),
              ),
            ),
          if (config.flashModes.isNotEmpty)
            IconButton(
              tooltip: config.flashLabel,
              onPressed: controls.cycleFlash,
              icon: Icon(flashIcon(controls.flash), color: c.icon),
            ),
        ],
      ),
    );
  }
}

/// Default red dot + elapsed time shown while recording.
class DefaultRecordingIndicator extends StatelessWidget {
  final CameraControls controls;

  const DefaultRecordingIndicator({super.key, required this.controls});

  @override
  Widget build(BuildContext context) {
    final c = controls.config.colors;
    final max = controls.config.maxVideoDuration;
    final text =
        formatRecording(controls.recordingElapsed) +
        (max == null ? '' : ' / ${formatRecording(max)}');
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: c.barBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 10, color: c.recordingIndicator),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: c.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Default PHOTO / VIDEO selector.
class DefaultCameraModeSwitcher extends StatelessWidget {
  final CameraControls controls;

  const DefaultCameraModeSwitcher({super.key, required this.controls});

  @override
  Widget build(BuildContext context) {
    final config = controls.config;
    if (config.effectiveModes.length < 2) return const SizedBox(height: 36);
    final c = config.colors;
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final m in config.effectiveModes)
            Semantics(
              selected: controls.mode == m,
              button: true,
              child: TextButton(
                onPressed: controls.isRecording
                    ? null
                    : () => controls.setMode(m),
                child: Text(
                  m == CaptureMode.photo
                      ? config.photoLabel
                      : config.videoLabel,
                  style:
                      (config.modeTextStyle ??
                              const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ))
                          .copyWith(
                            color: controls.mode == m
                                ? c.modeSelected
                                : c.modeUnselected,
                          ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Default bottom area: mode switcher, shutter, lens switch.
class DefaultCameraBottomBar extends StatelessWidget {
  final CameraControls controls;

  const DefaultCameraBottomBar({super.key, required this.controls});

  @override
  Widget build(BuildContext context) {
    final config = controls.config;
    final c = config.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!controls.isRecording)
          config.modeSwitcherBuilder?.call(context, controls) ??
              DefaultCameraModeSwitcher(controls: controls),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: SizedBox()),
            config.shutterBuilder?.call(context, controls) ??
                DefaultShutterButton(controls: controls),
            Expanded(
              child: controls.canSwitchLens && !controls.isRecording
                  ? Center(
                      child: IconButton(
                        tooltip: config.switchCameraLabel,
                        onPressed: controls.isBusy ? null : controls.switchLens,
                        icon: Icon(
                          Icons.flip_camera_ios_outlined,
                          color: c.icon,
                          size: 30,
                        ),
                      ),
                    )
                  : const SizedBox(),
            ),
          ],
        ),
      ],
    );
  }
}
