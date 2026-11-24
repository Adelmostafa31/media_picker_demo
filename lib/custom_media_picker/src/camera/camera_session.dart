import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../picker_models.dart';
import 'camera_config.dart';
import 'camera_controls.dart';
import 'captured_media.dart';

/// Where the camera screen is.
enum CameraPhase { starting, ready, permissionDenied, noCamera, error }

/// Owns the [CameraController] and implements [CameraControls] for the UI.
class CameraSession extends ChangeNotifier implements CameraControls {
  CameraSession({
    required this.config,
    required this.onCaptured,
    required this.onClose,
  }) : _mode = config.startMode,
       _lens = config.initialLens,
       _flash = config.initialFlash,
       _timerSeconds = config.timerOptions.isEmpty
           ? 0
           : config.timerOptions.first;

  @override
  final CameraConfig config;

  /// Swapped in tests to control the recording clock.
  @visibleForTesting
  static Stopwatch Function() newStopwatch = Stopwatch.new;

  /// Called with every finished photo or video.
  final void Function(CapturedMedia media) onCaptured;
  final VoidCallback onClose;

  CameraController? _controller;
  CameraController? get controller => _controller;
  List<CameraDescription> _cameras = const [];

  CameraPhase phase = CameraPhase.starting;
  Object? lastError;

  CaptureMode _mode;
  CameraLens _lens;
  CameraFlash _flash;
  int _timerSeconds;
  int? _countdown;
  bool _recording = false;
  bool _busy = false;
  bool _audioDenied = false;
  bool _disposed = false;
  Duration _elapsed = Duration.zero;
  double _zoom = 1, _minZoom = 1, _maxZoom = 1;
  Timer? _ticker;
  Stopwatch? _stopwatch;

  // ---------------------------------------------------------------- state

  @override
  CaptureMode get mode => _mode;
  @override
  CameraLens get lens => _lens;
  @override
  CameraFlash get flash => _flash;
  @override
  int get timerSeconds => _timerSeconds;
  @override
  int? get countdown => _countdown;
  @override
  bool get isRecording => _recording;
  @override
  Duration get recordingElapsed => _elapsed;
  @override
  bool get isBusy => _busy;
  @override
  double get zoom => _zoom;
  @override
  double get minZoom => _minZoom;
  @override
  double get maxZoom => _maxZoom;
  @override
  bool get audioUnavailable => _audioDenied;
  @override
  bool get isAtSelectionLimit => config.isAtSelectionLimit;
  @override
  bool get canSwitchLens =>
      config.enableLensSwitch &&
      _cameras.map((c) => c.lensDirection).toSet().length > 1;

  bool get isReady =>
      phase == CameraPhase.ready && (_controller?.value.isInitialized ?? false);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  // ------------------------------------------------------------ lifecycle

  bool _starting = false;

  /// A [start] is in progress (e.g. waiting on the permission dialog).
  bool get isStarting => _starting;

  Future<void> start() async {
    // The permission dialog pauses and resumes the app; a second start then
    // would ask again while the first request is still open.
    if (_starting) return;
    _starting = true;
    phase = CameraPhase.starting;
    _changed();
    try {
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        phase = CameraPhase.noCamera;
        _changed();
        return;
      }
      await _open(_cameraFor(_lens));
    } on CameraException catch (e) {
      _fail(e);
    } finally {
      _starting = false;
    }
  }

  CameraDescription _cameraFor(CameraLens lens) {
    final wanted = lens == CameraLens.front
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    return _cameras.firstWhere(
      (c) => c.lensDirection == wanted,
      orElse: () => _cameras.first,
    );
  }

  Future<void> _open(CameraDescription description) async {
    final old = _controller;
    _controller = null;
    await old?.dispose();
    final controller = CameraController(
      description,
      _preset(config.resolution),
      enableAudio: config.enableAudio && config.allowsVideo && !_audioDenied,
    );
    try {
      await controller.initialize();
    } on CameraException catch (e) {
      await controller.dispose();
      // No microphone: keep the camera, record silent video.
      if (_isAudioDenial(e) && !_audioDenied) {
        _audioDenied = true;
        return _open(description);
      }
      rethrow;
    }
    if (_disposed) {
      await controller.dispose();
      return;
    }
    _controller = controller;
    _lens = description.lensDirection == CameraLensDirection.front
        ? CameraLens.front
        : CameraLens.back;
    try {
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();
    } on CameraException {
      _minZoom = _maxZoom = 1;
    }
    _zoom = _minZoom;
    await _applyFlash(_flash);
    phase = CameraPhase.ready;
    _changed();
  }

  /// Releases the camera (app in background). [start] opens it again.
  Future<void> pause() async {
    if (_recording) await stopRecording();
    final c = _controller;
    _controller = null;
    phase = CameraPhase.starting;
    _changed();
    await c?.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _fail(CameraException e) {
    lastError = e;
    if (_isCameraDenial(e)) {
      phase = CameraPhase.permissionDenied;
      config.onPermissionDenied?.call();
    } else {
      phase = CameraPhase.error;
      config.onError?.call(e);
    }
    _changed();
  }

  static bool _isCameraDenial(CameraException e) =>
      e.code.startsWith('CameraAccess') || e.code == 'cameraPermission';

  static bool _isAudioDenial(CameraException e) =>
      e.code.startsWith('AudioAccess');

  static ResolutionPreset _preset(CameraResolution r) => switch (r) {
    CameraResolution.low => ResolutionPreset.low,
    CameraResolution.medium => ResolutionPreset.medium,
    CameraResolution.high => ResolutionPreset.high,
    CameraResolution.veryHigh => ResolutionPreset.veryHigh,
    CameraResolution.ultraHigh => ResolutionPreset.ultraHigh,
    CameraResolution.max => ResolutionPreset.max,
  };

  // -------------------------------------------------------------- actions

  @override
  Future<void> capture() async {
    if (_recording) return stopRecording();
    return _mode == CaptureMode.video ? startRecording() : takePhoto();
  }

  /// Runs the self-timer. Returns false when the session went away.
  Future<bool> _runCountdown() async {
    for (var s = _timerSeconds; s > 0; s--) {
      _countdown = s;
      _changed();
      await Future<void>.delayed(const Duration(seconds: 1));
      if (_disposed || !isReady) {
        _countdown = null;
        return false;
      }
    }
    _countdown = null;
    _changed();
    return true;
  }

  @override
  Future<void> takePhoto() async {
    final c = _controller;
    if (!config.allowsPhoto || !isReady || _busy || _recording) return;
    if (c == null || _countdown != null) return;
    _busy = true;
    _changed();
    try {
      if (!await _runCountdown()) return;
      final file = await c.takePicture();
      onCaptured(CapturedMedia(path: file.path, type: PickedMediaType.image));
    } on CameraException catch (e) {
      config.onError?.call(e);
    } finally {
      _busy = false;
      _changed();
    }
  }

  @override
  Future<void> startRecording() async {
    final c = _controller;
    if (!config.allowsVideo || !isReady || _busy || _recording) return;
    if (c == null || _countdown != null) return;
    _busy = true;
    _changed();
    try {
      if (!await _runCountdown()) return;
      await c.startVideoRecording();
      _recording = true;
      _elapsed = Duration.zero;
      _stopwatch = newStopwatch()..start();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        _elapsed = _stopwatch?.elapsed ?? Duration.zero;
        final max = config.maxVideoDuration;
        if (max != null && _elapsed >= max) {
          stopRecording();
        } else {
          _changed();
        }
      });
    } on CameraException catch (e) {
      config.onError?.call(e);
    } finally {
      _busy = false;
      _changed();
    }
  }

  @override
  Future<void> stopRecording() async {
    final c = _controller;
    if (!_recording || c == null) return;
    _ticker?.cancel();
    _stopwatch?.stop();
    final length = _stopwatch?.elapsed ?? _elapsed;
    _recording = false;
    _busy = true;
    _changed();
    try {
      final file = await c.stopVideoRecording();
      onCaptured(
        CapturedMedia(
          path: file.path,
          type: PickedMediaType.video,
          duration: length,
        ),
      );
    } on CameraException catch (e) {
      config.onError?.call(e);
    } finally {
      _busy = false;
      _elapsed = Duration.zero;
      _changed();
    }
  }

  @override
  Future<void> switchLens() async {
    if (!canSwitchLens || _recording || _busy) return;
    final next = _lens == CameraLens.back ? CameraLens.front : CameraLens.back;
    _busy = true;
    _changed();
    try {
      await _open(_cameraFor(next));
    } on CameraException catch (e) {
      _fail(e);
    } finally {
      _busy = false;
      _changed();
    }
  }

  @override
  Future<void> setFlash(CameraFlash flash) async {
    _flash = flash;
    _changed();
    await _applyFlash(flash);
  }

  Future<void> _applyFlash(CameraFlash flash) async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.setFlashMode(switch (flash) {
        CameraFlash.off => FlashMode.off,
        CameraFlash.auto => FlashMode.auto,
        CameraFlash.on => FlashMode.always,
        CameraFlash.torch => FlashMode.torch,
      });
    } on CameraException {
      // Front cameras often have no flash; keep the UI state anyway.
    }
  }

  @override
  Future<void> cycleFlash() async {
    final modes = config.flashModes;
    if (modes.isEmpty) return;
    final i = modes.indexOf(_flash);
    await setFlash(modes[(i + 1) % modes.length]);
  }

  @override
  void setMode(CaptureMode mode) {
    if (_recording || !config.effectiveModes.contains(mode)) return;
    _mode = mode;
    _changed();
  }

  @override
  void setTimer(int seconds) {
    _timerSeconds = seconds < 0 ? 0 : seconds;
    _changed();
  }

  @override
  void cycleTimer() {
    final options = config.timerOptions;
    if (options.isEmpty) return;
    final i = options.indexOf(_timerSeconds);
    setTimer(options[(i + 1) % options.length]);
  }

  @override
  Future<void> setZoom(double zoom) async {
    final c = _controller;
    if (c == null || !config.enableZoom) return;
    _zoom = zoom.clamp(_minZoom, _maxZoom);
    _changed();
    try {
      await c.setZoomLevel(_zoom);
    } on CameraException {
      // Ignore: zoom is best effort.
    }
  }

  /// Focus and meter at [point] (0..1 in preview coordinates).
  Future<void> focusAt(Offset point) async {
    final c = _controller;
    if (c == null || !config.enableTapToFocus) return;
    try {
      await c.setFocusPoint(point);
      await c.setExposurePoint(point);
    } on CameraException {
      // Not every lens supports metering points.
    }
  }

  /// Deletes a capture the user threw away.
  static Future<void> discard(CapturedMedia media) async {
    try {
      await File(media.path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  @override
  void close() => onClose();
}
