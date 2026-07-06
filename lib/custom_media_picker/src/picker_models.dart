import 'dart:io';

import 'picker_channel.dart';

enum PickedMediaType { image, video }

/// A gallery asset. The real file path is resolved lazily (or on confirm
/// when `resolvePathsOnConfirm` is true) because on iOS getting the
/// original file may require copying/downloading (iCloud).
class PickedMediaAsset {
  /// MediaStore _ID (Android) or PHAsset localIdentifier (iOS).
  final String id;
  final PickedMediaType type;
  final int durationMs;
  final int width;
  final int height;

  /// Unix seconds.
  final int dateAdded;
  final String? name;
  final int? sizeBytes;

  String? _resolvedPath;

  PickedMediaAsset({
    required this.id,
    required this.type,
    this.durationMs = 0,
    this.width = 0,
    this.height = 0,
    this.dateAdded = 0,
    this.name,
    this.sizeBytes,
  });

  bool get isVideo => type == PickedMediaType.video;
  String get typeString => isVideo ? 'video' : 'image';

  /// Non-null after [resolvePath] completed (or after confirm when
  /// `resolvePathsOnConfirm` is enabled).
  String? get resolvedPath => _resolvedPath;

  factory PickedMediaAsset.fromMap(Map<dynamic, dynamic> map) {
    return PickedMediaAsset(
      id: map['id'].toString(),
      type: map['type'] == 'video'
          ? PickedMediaType.video
          : PickedMediaType.image,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      dateAdded: (map['dateAdded'] as num?)?.toInt() ?? 0,
      name: map['name'] as String?,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt(),
    );
  }

  /// Resolves (and caches) the absolute file path of the original asset.
  Future<String?> resolvePath() async {
    _resolvedPath ??=
        await MediaPickerChannel.getOriginalPath(id: id, type: typeString);
    return _resolvedPath;
  }

  Future<File?> resolveFile() async {
    final p = await resolvePath();
    return p == null ? null : File(p);
  }

  /// "1:05" / "1:02:33" style label for video tiles.
  String get durationLabel {
    final total = durationMs ~/ 1000;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }

  String get sizeLabel {
    final b = sizeBytes;
    if (b == null || b <= 0) return '';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
