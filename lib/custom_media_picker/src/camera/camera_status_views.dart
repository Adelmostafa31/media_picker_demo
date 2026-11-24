// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'camera_config.dart';

/// Default "camera access is off" screen.
class DefaultCameraPermissionView extends StatelessWidget {
  final CameraConfig config;
  final VoidCallback onOpenSettings;
  final VoidCallback onClose;

  const DefaultCameraPermissionView({
    super.key,
    required this.config,
    required this.onOpenSettings,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final c = config.colors;
    return CameraMessageView(
      config: config,
      icon: Icons.no_photography_outlined,
      title: config.permissionTitle,
      message: config.permissionMessage,
      onClose: onClose,
      action: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: c.accent),
        onPressed: onOpenSettings,
        child: Text(config.openSettingsLabel),
      ),
    );
  }
}

/// Centered icon + text (+ optional button) with a close button; used for
/// permission, no-camera and error states.
class CameraMessageView extends StatelessWidget {
  final CameraConfig config;
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final VoidCallback onClose;

  const CameraMessageView({
    super.key,
    required this.config,
    required this.icon,
    required this.title,
    required this.onClose,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final c = config.colors;
    final message = this.message;
    final action = this.action;
    return ColoredBox(
      color: c.background,
      child: SafeArea(
        child: Stack(
          children: [
            PositionedDirectional(
              top: 4,
              start: 4,
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: onClose,
                icon: Icon(Icons.close, color: c.icon),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: c.icon, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.text.withValues(alpha: 0.8)),
                      ),
                    ],
                    if (action != null) ...[const SizedBox(height: 20), action],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
