// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'picker_config.dart';

/// Short "You can select up to N items" bar shown above the confirm button
/// when the selection limit blocks a tap. Announced by screen readers.
/// `MediaPickerConfig.selectionLimitNoticeBuilder` replaces its content.
class PickerLimitNotice extends StatelessWidget {
  final bool visible;
  final MediaPickerConfig config;

  const PickerLimitNotice({
    super.key,
    required this.visible,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      alignment: AlignmentDirectional.bottomCenter,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child:
                  config.selectionLimitNoticeBuilder?.call(
                    context,
                    config.maxSelection,
                  ) ??
                  _DefaultNotice(config: config),
            ),
    );
  }
}

class _DefaultNotice extends StatelessWidget {
  final MediaPickerConfig config;

  const _DefaultNotice({required this.config});

  @override
  Widget build(BuildContext context) {
    final c = config.colors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.videoBadgeBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        config.selectionLimitText(),
        textAlign: TextAlign.center,
        style: TextStyle(color: c.videoBadgeText, fontSize: 13),
      ),
    );
  }
}
