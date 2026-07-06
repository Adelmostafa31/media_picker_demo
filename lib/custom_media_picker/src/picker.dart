import 'package:flutter/material.dart';

import 'picker_body.dart';
import 'picker_channel.dart';
import 'picker_config.dart';
import 'picker_models.dart';

/// Public entry point.
///
/// ```dart
/// final assets = await CustomMediaPicker.pick(context,
///   config: MediaPickerConfig(maxSelection: 9));
/// ```
///
/// Returns the selected assets in selection order, or `null` if the
/// user dismissed the picker / permission was denied.
class CustomMediaPicker {
  CustomMediaPicker._();

  static Future<List<PickedMediaAsset>?> pick(
    BuildContext context, {
    MediaPickerConfig config = const MediaPickerConfig(),
  }) async {
    final status = await MediaPickerChannel.requestPermission();
    if (status == 'denied') {
      config.onPermissionDenied?.call();
      return null;
    }
    if (!context.mounted) return null;

    if (config.layoutStyle == LayoutStyle.fullScreen) {
      return Navigator.of(context, rootNavigator: true)
          .push<List<PickedMediaAsset>>(
        MaterialPageRoute(
          builder: (_) => FullScreenPickerPage(config: config),
        ),
      );
    }

    return showModalBottomSheet<List<PickedMediaAsset>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0x00000000),
      builder: (_) => SheetPicker(config: config),
    );
  }
}

/// WhatsApp-style draggable sheet presentation.
class SheetPicker extends StatelessWidget {
  final MediaPickerConfig config;

  const SheetPicker({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: config.sheetInitialHeight,
      minChildSize: config.sheetMinHeight,
      maxChildSize: config.sheetMaxHeight,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(config.sheetCornerRadius),
          ),
          child: ColoredBox(
            color: config.colors.background,
            child: PickerBody(
              config: config,
              scrollController: scrollController,
              showHeader: true,
            ),
          ),
        );
      },
    );
  }
}

/// Full-screen presentation with configurable leading icon.
class FullScreenPickerPage extends StatelessWidget {
  final MediaPickerConfig config;

  const FullScreenPickerPage({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final c = config.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.appBar,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: config.customLeading ??
            IconButton(
              icon: Icon(
                config.fullScreenLeading == FullScreenLeading.close
                    ? Icons.close
                    : Icons.arrow_back,
                color: c.icon,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
        title: Text(
          config.title ?? 'Select media',
          style: config.titleStyle ??
              TextStyle(
                color: c.title,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
      body: SafeArea(
        child: PickerBody(config: config, showHeader: false),
      ),
    );
  }
}
