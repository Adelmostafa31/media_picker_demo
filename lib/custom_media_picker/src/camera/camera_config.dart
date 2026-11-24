// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'camera_controls.dart';
import 'captured_media.dart';

/// What the shutter captures.
enum CaptureMode { photo, video }

/// Which camera to open.
enum CameraLens { back, front }

/// Flash behaviour. [torch] keeps the light on (useful for video).
enum CameraFlash { off, auto, on, torch }

/// Capture quality; maps to the platform's closest preset.
enum CameraResolution { low, medium, high, veryHigh, ultraHigh, max }

/// Builds a part of the camera UI. [controls] exposes the camera state and
/// actions (`capture()`, `switchLens()`, `setFlash()`, ...) and notifies on
/// every change, so the returned widget is rebuilt automatically.
typedef CameraPartBuilder = Widget Function(
  BuildContext context,
  CameraControls controls,
);

/// Colors of the default camera UI. Ignored by parts you replace with a
/// builder.
class CameraColors {
  final Color background;
  final Color icon;
  final Color text;
  final Color accent;
  final Color shutter;
  final Color shutterRecording;
  final Color barBackground;
  final Color modeSelected;
  final Color modeUnselected;
  final Color recordingIndicator;
  final Color focusRing;

  const CameraColors({
    this.background = const Color(0xFF000000),
    this.icon = const Color(0xFFFFFFFF),
    this.text = const Color(0xFFFFFFFF),
    this.accent = const Color(0xFF25D366),
    this.shutter = const Color(0xFFFFFFFF),
    this.shutterRecording = const Color(0xFFFF3B30),
    this.barBackground = const Color(0x66000000),
    this.modeSelected = const Color(0xFFFFD60A),
    this.modeUnselected = const Color(0xCCFFFFFF),
    this.recordingIndicator = const Color(0xFFFF3B30),
    this.focusRing = const Color(0xFFFFD60A),
  });
}

/// Configuration for [CustomMediaPicker.capture].
///
/// Everything has a default; colors and labels restyle the built-in UI,
/// and the `*Builder` callbacks replace any part of it with your own widget.
class CameraConfig {
  // ---- Capture ----

  /// Modes the user can switch between, in display order. With both, the
  /// shutter takes a photo on tap and records while held
  /// ([holdShutterToRecord]).
  final List<CaptureMode> modes;
  final CaptureMode initialMode;
  final CameraLens initialLens;
  final bool enableLensSwitch;
  final CameraResolution resolution;

  /// Record sound with videos. When the user denies the microphone, the
  /// camera still opens and records silent video.
  final bool enableAudio;

  /// Flash modes the flash button cycles through. Empty hides the button.
  final List<CameraFlash> flashModes;
  final CameraFlash initialFlash;

  /// Pinch to zoom on the preview.
  final bool enableZoom;

  /// Tap on the preview to focus and meter there.
  final bool enableTapToFocus;

  /// Self-timer options in seconds the timer button cycles through
  /// (0 = off). Empty or `[0]` hides the button.
  final List<int> timerOptions;

  /// Recording stops by itself at this length. Null = no limit.
  final Duration? maxVideoDuration;

  /// In photo mode, holding the shutter records a video (when [modes]
  /// contains [CaptureMode.video]).
  final bool holdShutterToRecord;

  /// Show a retake / use screen after capturing.
  final bool showReview;

  // ---- Selection limit ----

  /// Total number of items the user may end up with (0 = unlimited).
  /// Together with [selectedCount] this blocks accepting a capture once the
  /// limit is reached, e.g. picking 2 of 2 in the gallery and then opening
  /// the camera.
  final int maxSelection;

  /// Items the user already has (e.g. picked in the gallery).
  final int selectedCount;

  /// Show a notice when a capture is refused because of [maxSelection].
  final bool showSelectionLimitMessage;

  /// Notice text; receives [maxSelection]. Defaults to
  /// "You can select up to N items".
  final String Function(int max)? selectionLimitMessage;

  /// Replaces the default notice with your own widget.
  final Widget Function(BuildContext context, int max)?
  selectionLimitNoticeBuilder;

  /// A capture was refused because of [maxSelection].
  final VoidCallback? onSelectionLimitReached;

  // ---- Saving ----

  /// Also add the capture to the device gallery when the user accepts it.
  /// iOS needs `NSPhotoLibraryAddUsageDescription` in Info.plist; Android
  /// 9 and lower need WRITE_EXTERNAL_STORAGE granted.
  final bool saveToGallery;

  /// Album (iOS) or sub-folder of Pictures/Movies (Android) to save into.
  /// On iOS this needs full photo access, not just add-only.
  final String? galleryAlbum;

  // ---- Text ----
  final String photoLabel;
  final String videoLabel;
  final String retakeLabel;
  final String useLabel;
  final String switchCameraLabel;
  final String flashLabel;
  final String timerLabel;
  final String permissionTitle;
  final String permissionMessage;
  final String openSettingsLabel;
  final String noCameraText;
  final String errorText;
  final String retryLabel;
  final TextStyle? modeTextStyle;
  final TextStyle? buttonTextStyle;

  final CameraColors colors;

  // ---- Builders (each replaces one part of the default UI) ----

  /// Close / flash / timer row at the top.
  final CameraPartBuilder? topBarBuilder;

  /// The capture button.
  final CameraPartBuilder? shutterBuilder;

  /// Photo / Video selector above the shutter.
  final CameraPartBuilder? modeSwitcherBuilder;

  /// The whole bottom area (mode switcher, shutter, lens switch). When set,
  /// [shutterBuilder] and [modeSwitcherBuilder] are only used if you call
  /// them yourself.
  final CameraPartBuilder? bottomBarBuilder;

  /// Drawn over the camera preview, under the controls (grid lines,
  /// a face frame, a watermark, ...).
  final CameraPartBuilder? overlayBuilder;

  /// Elapsed-time badge shown while recording.
  final CameraPartBuilder? recordingIndicatorBuilder;

  /// Big countdown shown while the self-timer runs.
  final Widget Function(BuildContext context, int secondsLeft)?
  countdownBuilder;

  /// Review screen after a capture. Call `retake` to go back to the camera
  /// or `use` to accept.
  final Widget Function(
    BuildContext context,
    CapturedMedia media,
    VoidCallback retake,
    VoidCallback use,
  )?
  reviewBuilder;

  /// Shown when camera access is denied.
  final Widget Function(
    BuildContext context,
    VoidCallback openSettings,
    VoidCallback close,
  )?
  permissionDeniedBuilder;

  /// Shown while the camera starts.
  final WidgetBuilder? loadingBuilder;

  // ---- Callbacks ----
  final VoidCallback? onPermissionDenied;

  /// Any camera error that isn't a permission problem.
  final void Function(Object error)? onError;

  /// [saveToGallery] failed; the capture is still returned.
  final void Function(Object error)? onSaveToGalleryFailed;

  const CameraConfig({
    this.modes = const [CaptureMode.photo, CaptureMode.video],
    this.initialMode = CaptureMode.photo,
    this.initialLens = CameraLens.back,
    this.enableLensSwitch = true,
    this.resolution = CameraResolution.high,
    this.enableAudio = true,
    this.flashModes = const [CameraFlash.off, CameraFlash.auto, CameraFlash.on],
    this.initialFlash = CameraFlash.off,
    this.enableZoom = true,
    this.enableTapToFocus = true,
    this.timerOptions = const [0, 3, 10],
    this.maxVideoDuration,
    this.holdShutterToRecord = true,
    this.showReview = true,
    this.maxSelection = 0,
    this.selectedCount = 0,
    this.showSelectionLimitMessage = true,
    this.selectionLimitMessage,
    this.selectionLimitNoticeBuilder,
    this.onSelectionLimitReached,
    this.saveToGallery = false,
    this.galleryAlbum,
    this.photoLabel = 'PHOTO',
    this.videoLabel = 'VIDEO',
    this.retakeLabel = 'Retake',
    this.useLabel = 'Use',
    this.switchCameraLabel = 'Switch camera',
    this.flashLabel = 'Flash',
    this.timerLabel = 'Timer',
    this.permissionTitle = 'Camera access is off',
    this.permissionMessage =
        'Allow camera access in Settings to take photos and videos.',
    this.openSettingsLabel = 'Open Settings',
    this.noCameraText = 'No camera available on this device',
    this.errorText = "The camera couldn't start",
    this.retryLabel = 'Try again',
    this.modeTextStyle,
    this.buttonTextStyle,
    this.colors = const CameraColors(),
    this.topBarBuilder,
    this.shutterBuilder,
    this.modeSwitcherBuilder,
    this.bottomBarBuilder,
    this.overlayBuilder,
    this.recordingIndicatorBuilder,
    this.countdownBuilder,
    this.reviewBuilder,
    this.permissionDeniedBuilder,
    this.loadingBuilder,
    this.onPermissionDenied,
    this.onError,
    this.onSaveToGalleryFailed,
  });

  /// No more captures can be accepted ([selectedCount] >= [maxSelection]).
  bool get isAtSelectionLimit =>
      maxSelection > 0 && selectedCount >= maxSelection;

  String selectionLimitText() =>
      selectionLimitMessage?.call(maxSelection) ??
      'You can select up to $maxSelection items';

  /// [modes], or photo only when it is empty.
  List<CaptureMode> get effectiveModes =>
      modes.isEmpty ? const [CaptureMode.photo] : modes;

  bool get allowsPhoto => effectiveModes.contains(CaptureMode.photo);
  bool get allowsVideo => effectiveModes.contains(CaptureMode.video);

  /// [initialMode] if allowed, otherwise the first of [modes].
  CaptureMode get startMode =>
      effectiveModes.contains(initialMode) ? initialMode : effectiveModes.first;
}
