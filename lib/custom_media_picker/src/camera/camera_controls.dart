// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'camera_config.dart';

/// State of the camera screen and the actions a custom UI part can trigger.
///
/// Passed to every `CameraConfig.*Builder`. It is a [Listenable]: the
/// default screen rebuilds builders on every change, and you can listen to
/// it yourself (e.g. with [ListenableBuilder]) inside long-lived widgets.
abstract class CameraControls implements Listenable {
  CameraConfig get config;

  // ---- State ----
  CaptureMode get mode;
  CameraLens get lens;
  CameraFlash get flash;

  /// Seconds of the selected self-timer (0 = off).
  int get timerSeconds;

  /// Seconds left while the self-timer counts down, otherwise null.
  int? get countdown;

  bool get isRecording;

  /// Length of the current recording.
  Duration get recordingElapsed;

  /// True while a photo is being taken or a recording is being finalized.
  bool get isBusy;

  double get zoom;
  double get minZoom;
  double get maxZoom;

  /// More than one camera is available and switching is enabled.
  bool get canSwitchLens;

  /// The microphone was denied, so videos are recorded without sound.
  bool get audioUnavailable;

  /// `config.maxSelection` is already reached: a capture can be taken but
  /// won't be accepted. Use it to disable or restyle your own controls.
  bool get isAtSelectionLimit;

  // ---- Actions ----

  /// What a tap on the shutter does: take a photo in photo mode, start or
  /// stop recording in video mode.
  Future<void> capture();

  Future<void> takePhoto();
  Future<void> startRecording();
  Future<void> stopRecording();

  Future<void> switchLens();
  Future<void> setFlash(CameraFlash flash);

  /// Next value of `config.flashModes`.
  Future<void> cycleFlash();

  void setMode(CaptureMode mode);
  void setTimer(int seconds);

  /// Next value of `config.timerOptions`.
  void cycleTimer();

  Future<void> setZoom(double zoom);

  /// Closes the camera without a result.
  void close();
}
