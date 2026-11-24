import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../picker_channel.dart';
import 'camera_bars.dart';
import 'camera_config.dart';
import 'camera_limit_notice.dart';
import 'camera_preview_area.dart';
import 'camera_review.dart';
import 'camera_session.dart';
import 'camera_status_views.dart';
import 'captured_media.dart';

/// Full-screen camera opened by [CustomMediaPicker.capture]. Pops with the
/// accepted [CapturedMedia], or null when closed.
class CameraCapturePage extends StatefulWidget {
  final CameraConfig config;

  const CameraCapturePage({super.key, this.config = const CameraConfig()});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage>
    with WidgetsBindingObserver {
  late final CameraSession _session = CameraSession(
    config: widget.config,
    onCaptured: _onCaptured,
    onClose: _close,
  );
  CapturedMedia? _review;
  bool _saving = false;
  bool _limitNotice = false;
  bool _wentToSettings = false;
  Timer? _limitTimer;

  CameraConfig get config => widget.config;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session.start();
  }

  @override
  void dispose() {
    _limitTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _session.dispose();
    super.dispose();
  }

  // The camera must be released in the background and reopened on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final s = _session;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (s.controller != null) s.pause();
      return;
    }
    if (state != AppLifecycleState.resumed || _review != null) return;
    if (s.isStarting || s.controller != null) return;
    switch (s.phase) {
      case CameraPhase.starting:
        s.start();
      case CameraPhase.permissionDenied:
        // Only retry after a trip to Settings; resuming from the permission
        // dialog itself must not ask again.
        if (_wentToSettings) {
          _wentToSettings = false;
          s.start();
        }
      case CameraPhase.ready || CameraPhase.noCamera || CameraPhase.error:
        break;
    }
  }

  void _openSettings() {
    _wentToSettings = true;
    MediaPickerChannel.openAppSettings();
  }

  void _onCaptured(CapturedMedia media) {
    if (!mounted) return;
    if (config.showReview) {
      setState(() => _review = media);
    } else {
      _accept(media);
    }
  }

  void _retake() {
    final media = _review;
    if (media != null) CameraSession.discard(media);
    setState(() => _review = null);
    if (_session.controller == null) _session.start();
  }

  /// Refuses [media] when the selection limit is reached. Returns true when
  /// it was refused.
  bool _refuseAtLimit(CapturedMedia media) {
    if (!config.isAtSelectionLimit) return false;
    config.onSelectionLimitReached?.call();
    // Without a review screen there's nothing to come back to.
    if (!config.showReview) CameraSession.discard(media);
    if (config.showSelectionLimitMessage) {
      _limitTimer?.cancel();
      setState(() => _limitNotice = true);
      _limitTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _limitNotice = false);
      });
    }
    return true;
  }

  Future<void> _accept(CapturedMedia media) async {
    if (_saving || _refuseAtLimit(media)) return;
    var result = media;
    if (config.saveToGallery) {
      setState(() => _saving = true);
      try {
        final id = await MediaPickerChannel.saveToGallery(
          path: media.path,
          type: media.isVideo ? 'video' : 'image',
          album: config.galleryAlbum,
        );
        result = media.withGalleryId(id);
      } catch (e) {
        config.onSaveToGalleryFailed?.call(e);
      }
      if (!mounted) return;
      setState(() => _saving = false);
    }
    Navigator.of(context).pop(result);
  }

  void _close() {
    final media = _review;
    if (media != null) CameraSession.discard(media);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilt on every session change so canPop follows isRecording.
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) => PopScope<Object?>(
        // Back while recording stops the recording instead of losing it.
        canPop: !_session.isRecording,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _session.isRecording) _session.stopRecording();
        },
        child: Scaffold(
          backgroundColor: config.colors.background,
          body: Stack(
            fit: StackFit.expand,
            children: [
              _buildBody(context),
              // Above the review buttons / shutter so it never hides them.
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 140,
                child: Center(
                  child: CameraLimitNotice(
                    visible: _limitNotice,
                    config: config,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final review = _review;
    if (review != null) {
      return config.reviewBuilder?.call(
            context,
            review,
            _retake,
            () => _accept(review),
          ) ??
          DefaultCameraReview(
            config: config,
            media: review,
            onRetake: _retake,
            onUse: () => _accept(review),
            busy: _saving,
          );
    }
    switch (_session.phase) {
      case CameraPhase.permissionDenied:
        return config.permissionDeniedBuilder?.call(
              context,
              _openSettings,
              _close,
            ) ??
            DefaultCameraPermissionView(
              config: config,
              onOpenSettings: _openSettings,
              onClose: _close,
            );
      case CameraPhase.noCamera:
        return CameraMessageView(
          config: config,
          icon: Icons.no_photography_outlined,
          title: config.noCameraText,
          onClose: _close,
        );
      case CameraPhase.error:
        return CameraMessageView(
          config: config,
          icon: Icons.error_outline,
          title: config.errorText,
          onClose: _close,
          action: TextButton(
            onPressed: _session.start,
            child: Text(
              config.retryLabel,
              style: TextStyle(color: config.colors.accent),
            ),
          ),
        );
      case CameraPhase.starting:
        return config.loadingBuilder?.call(context) ??
            Center(
              child: CircularProgressIndicator(color: config.colors.accent),
            );
      case CameraPhase.ready:
        return _buildCamera(context);
    }
  }

  Widget _buildCamera(BuildContext context) {
    final s = _session;
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreviewArea(session: s),
        SafeArea(
          child: Column(
            children: [
              config.topBarBuilder?.call(context, s) ??
                  DefaultCameraTopBar(controls: s),
              const Spacer(),
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 16),
                child:
                    config.bottomBarBuilder?.call(context, s) ??
                    DefaultCameraBottomBar(controls: s),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
