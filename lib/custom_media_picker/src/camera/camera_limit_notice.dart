// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'camera_config.dart';

/// Toast shown on the camera screens when a capture is refused because
/// `CameraConfig.maxSelection` is reached. Announced by screen readers.
class CameraLimitNotice extends StatelessWidget {
  final bool visible;
  final CameraConfig config;

  const CameraLimitNotice({
    super.key,
    required this.visible,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final c = config.colors;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: !visible
            ? const SizedBox.shrink()
            : Semantics(
                liveRegion: true,
                child:
                    config.selectionLimitNoticeBuilder?.call(
                      context,
                      config.maxSelection,
                    ) ??
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: c.barBackground.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        config.selectionLimitText(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.text, fontSize: 14),
                      ),
                    ),
              ),
      ),
    );
  }
}
