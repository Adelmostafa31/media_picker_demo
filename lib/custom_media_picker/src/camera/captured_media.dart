import 'dart:io';

import '../picker_models.dart';

/// A photo or video taken with [CustomMediaPicker.capture].
class CapturedMedia {
  /// Absolute path of the file in the app's temporary storage. Move or copy
  /// it if you need to keep it; the OS may clear temporary files.
  final String path;
  final PickedMediaType type;

  /// Recording length for videos; [Duration.zero] for photos.
  final Duration duration;

  /// Id of the gallery copy (MediaStore id on Android, PHAsset
  /// localIdentifier on iOS) when `CameraConfig.saveToGallery` succeeded.
  final String? galleryId;

  const CapturedMedia({
    required this.path,
    required this.type,
    this.duration = Duration.zero,
    this.galleryId,
  });

  bool get isVideo => type == PickedMediaType.video;
  File get file => File(path);

  CapturedMedia withGalleryId(String? id) =>
      CapturedMedia(path: path, type: type, duration: duration, galleryId: id);

  @override
  String toString() => 'CapturedMedia(${type.name}, $path)';
}
