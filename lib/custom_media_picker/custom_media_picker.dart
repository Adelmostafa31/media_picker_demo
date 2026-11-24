/// Custom in-house media picker — no external picker packages.
///
/// Usage:
/// ```dart
/// import 'package:custom_media_picker/custom_media_picker.dart';
///
/// final assets = await CustomMediaPicker.pick(
///   context,
///   config: MediaPickerConfig(
///     layoutStyle: LayoutStyle.sheet,
///     listStyle: ListStyle.grid,
///     gridCrossAxisCount: 3,
///     maxSelection: 9,
///     mediaFilter: MediaFilter.all,
///   ),
/// );
/// ```
library;

export 'src/picker.dart';
export 'src/picker_body.dart' show PickerBody;
export 'src/picker_channel.dart'
    show MediaPermissionStatus, MediaPickerChannel, PickerThumbnailCache;
export 'src/picker_config.dart';
export 'src/picker_models.dart';
export 'src/picker_preview.dart' show PickerPreviewPage;
export 'src/picker_thumbnail.dart' show PickerAssetThumbnail;
export 'src/camera/camera_bars.dart'
    show
        DefaultCameraTopBar,
        DefaultCameraBottomBar,
        DefaultCameraModeSwitcher,
        DefaultRecordingIndicator,
        formatRecording,
        flashIcon;
export 'src/camera/camera_config.dart';
export 'src/camera/camera_controls.dart';
export 'src/camera/camera_limit_notice.dart' show CameraLimitNotice;
export 'src/camera/camera_page.dart' show CameraCapturePage;
export 'src/camera/camera_review.dart' show DefaultCameraReview;
export 'src/camera/camera_shutter.dart' show DefaultShutterButton;
export 'src/camera/camera_status_views.dart'
    show DefaultCameraPermissionView, CameraMessageView;
export 'src/camera/captured_media.dart';
