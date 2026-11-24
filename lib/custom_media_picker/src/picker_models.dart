import 'dart:io';

import 'picker_channel.dart';

enum PickedMediaType { image, video }

int _int(Object? v) => v is num ? v.toInt() : 0;

/// A gallery asset. The real file path is resolved lazily (or on confirm
/// when `resolvePathsOnConfirm` is true) because getting the original file
/// may require copying or downloading it (iCloud, scoped storage).
///
/// Two assets are equal when they have the same [id].
class PickedMediaAsset {
  /// MediaStore _ID (Android) or PHAsset localIdentifier (iOS).
  final String id;
  final PickedMediaType type;
  final int durationMs;
  final int width;
  final int height;

  /// Unix seconds when the file was added to the device (Android). On iOS,
  /// which has no such date, this equals [dateTaken].
  final int dateAdded;

  /// Unix seconds when the photo/video was captured — falls back to
  /// [dateAdded] when the OS doesn't know. The date range filter uses this.
  final int dateTaken;

  final String? name;
  final int? sizeBytes;

  Future<String?>? _pathFuture;
  String? _resolvedPath;

  PickedMediaAsset({
    required this.id,
    required this.type,
    this.durationMs = 0,
    this.width = 0,
    this.height = 0,
    this.dateAdded = 0,
    int? dateTaken,
    this.name,
    this.sizeBytes,
  }) : dateTaken = dateTaken ?? dateAdded;

  bool get isVideo => type == PickedMediaType.video;
  String get typeString => isVideo ? 'video' : 'image';

  /// Non-null after [resolvePath] completed with a path (or after confirm
  /// when `resolvePathsOnConfirm` is enabled).
  String? get resolvedPath => _resolvedPath;

  factory PickedMediaAsset.fromMap(Map<Object?, Object?> map) {
    final dateAdded = _int(map['dateAdded']);
    final taken = map['dateTaken'];
    return PickedMediaAsset(
      id: map['id'].toString(),
      type: map['type'] == 'video'
          ? PickedMediaType.video
          : PickedMediaType.image,
      durationMs: _int(map['durationMs']),
      width: _int(map['width']),
      height: _int(map['height']),
      dateAdded: dateAdded,
      dateTaken: taken is num ? taken.toInt() : dateAdded,
      name: map['name'] is String ? map['name'] as String : null,
      sizeBytes: map['sizeBytes'] is num
          ? (map['sizeBytes'] as num).toInt()
          : null,
    );
  }

  /// Resolves (and caches) the absolute file path of the original asset.
  ///
  /// Concurrent calls share one native request, so e.g. the preview and the
  /// confirm button never copy the same large video twice. A failed or null
  /// result is not cached, so a later call can retry.
  Future<String?> resolvePath() {
    final done = _resolvedPath;
    if (done != null) return Future.value(done);
    return _pathFuture ??=
        MediaPickerChannel.getOriginalPath(id: id, type: typeString)
            .then((p) {
              _resolvedPath = p;
              return p;
            })
            .whenComplete(() => _pathFuture = null);
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

  @override
  bool operator ==(Object other) => other is PickedMediaAsset && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PickedMediaAsset($typeString, $id)';
}

/// A gallery album — a MediaStore bucket (Android) or a
/// PHAssetCollection (iOS). Shown in the "Albums" tab.
class MediaAlbum {
  /// bucket_id (Android) or PHAssetCollection.localIdentifier (iOS).
  final String id;

  /// Empty when the OS reports no name; the picker then shows
  /// `MediaPickerConfig.unknownAlbumLabel`.
  final String name;

  /// Number of assets matching the active `MediaFilter`.
  final int count;

  /// Newest asset in the album, used as the cover thumbnail.
  final String? coverAssetId;
  final String coverAssetType; // 'image' | 'video'

  const MediaAlbum({
    required this.id,
    required this.name,
    required this.count,
    this.coverAssetId,
    this.coverAssetType = 'image',
  });

  factory MediaAlbum.fromMap(Map<Object?, Object?> map) {
    final name = map['name'];
    return MediaAlbum(
      id: map['id'].toString(),
      name: name is String ? name : '',
      count: _int(map['count']),
      coverAssetId: map['coverId']?.toString(),
      coverAssetType: map['coverType'] == 'video' ? 'video' : 'image',
    );
  }

  @override
  bool operator ==(Object other) => other is MediaAlbum && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
