import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'picker_config.dart';
import 'picker_models.dart';

/// Photo/video library access as reported by the OS.
enum MediaPermissionStatus {
  /// Full library access.
  granted,

  /// Access to a user-selected subset (iOS 14+ / Android 14+), or to only
  /// one of images/videos on Android 13.
  limited,

  /// The system dialog has never been shown; [MediaPickerChannel.requestPermission]
  /// will present it.
  notDetermined,

  /// Refused, but Android will still show the dialog again.
  denied,

  /// Refused for good (always the case on iOS after a refusal, and on
  /// Android after "Don't ask again"). Only Settings can change it — see
  /// [MediaPickerChannel.openAppSettings].
  permanentlyDenied;

  /// True for [granted] and [limited] — the picker can show media.
  bool get hasAccess => this == granted || this == limited;

  /// The 0.1.x string for this status.
  String get _legacyName => switch (this) {
    permanentlyDenied => 'denied',
    _ => name,
  };

  static MediaPermissionStatus parse(String? raw) => switch (raw) {
    'granted' => granted,
    'limited' => limited,
    'notDetermined' => notDetermined,
    'permanentlyDenied' => permanentlyDenied,
    _ => denied,
  };
}

/// Dart <-> native bridge. Channel names must match the plugin classes.
class MediaPickerChannel {
  MediaPickerChannel._();

  static const MethodChannel _channel = MethodChannel('custom_media_picker');

  static const EventChannel _changesChannel = EventChannel(
    'custom_media_picker/gallery_changes',
  );

  /// The native side only ships for Android and iOS; every other platform has
  /// no plugin registered, so touching the channels there fails.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Emits (debounced on the native side) whenever the OS reports a change in
  /// the user's photo library. On iOS it only emits once access is granted.
  ///
  /// Empty on unsupported platforms: activating an event channel with no
  /// native implementation reports an uncatchable MissingPluginException.
  static Stream<void> get galleryChanges => isSupported
      ? _changesChannel.receiveBroadcastStream().map((_) {})
      : const Stream<void>.empty();

  static String _filterToType(MediaFilter f) => switch (f) {
    MediaFilter.onlyImages => 'image',
    MediaFilter.onlyVideos => 'video',
    MediaFilter.all => 'all',
  };

  static Future<T?> _invoke<T>(String method, [Object? args]) async {
    if (!isSupported) return null;
    return _channel.invokeMethod<T>(method, args);
  }

  /// Current status, without showing any system dialog.
  static Future<MediaPermissionStatus> checkPermissionStatus() async {
    try {
      return MediaPermissionStatus.parse(
        await _invoke<String>('checkPermission'),
      );
    } on PlatformException {
      return MediaPermissionStatus.denied;
    } on MissingPluginException {
      return MediaPermissionStatus.denied;
    }
  }

  /// Shows the system dialog when the OS still allows it and returns the
  /// resulting status. Concurrent calls share the same dialog and answer.
  static Future<MediaPermissionStatus> requestPermissionStatus() =>
      _pendingRequest ??= _requestPermission().whenComplete(() {
        _pendingRequest = null;
      });

  static Future<MediaPermissionStatus>? _pendingRequest;

  static Future<MediaPermissionStatus> _requestPermission() async {
    try {
      return MediaPermissionStatus.parse(
        await _invoke<String>('requestPermission'),
      );
    } on PlatformException {
      return MediaPermissionStatus.denied;
    } on MissingPluginException {
      return MediaPermissionStatus.denied;
    }
  }

  /// 0.1.x API: `'granted' | 'limited' | 'notDetermined' | 'denied'`.
  /// `permanentlyDenied` is reported as `'denied'`, as before.
  @Deprecated(
    'Use checkPermissionStatus(), which returns a MediaPermissionStatus and '
    'tells denied apart from permanentlyDenied. Removed in 1.0.0.',
  )
  static Future<String> checkPermission() async =>
      (await checkPermissionStatus())._legacyName;

  /// 0.1.x API: `'granted' | 'limited' | 'denied'`.
  @Deprecated(
    'Use requestPermissionStatus(), which returns a MediaPermissionStatus and '
    'tells denied apart from permanentlyDenied. Removed in 1.0.0.',
  )
  static Future<String> requestPermission() async =>
      (await requestPermissionStatus())._legacyName;

  /// Opens this app's page in the system Settings. Returns false when the
  /// native side is unavailable.
  static Future<bool> openAppSettings() async {
    try {
      return await _invoke<bool>('openAppSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Pass [albumId] to fetch a single album's assets ("Albums" tab); leave it
  /// null for the global feed ("Recent" tab). [ascending] and the
  /// [startDateSec]/[endDateSec] window (unix seconds, inclusive, on the
  /// capture date) are used by the Recent feed's sort control.
  /// [includeNames] can be false when file names aren't displayed — looking
  /// them up is slow on iOS.
  static Future<List<PickedMediaAsset>> getAssets({
    required MediaFilter filter,
    required int page,
    required int pageSize,
    String? albumId,
    bool ascending = false,
    int? startDateSec,
    int? endDateSec,
    bool includeNames = true,
  }) async {
    final raw = await _invoke<List<Object?>>('getAssets', {
      'type': _filterToType(filter),
      'page': page,
      'pageSize': pageSize,
      'albumId': albumId,
      'ascending': ascending,
      'startDate': startDateSec,
      'endDate': endDateSec,
      'includeNames': includeNames,
    });
    if (raw == null) return const [];
    return [
      for (final e in raw)
        if (e is Map) PickedMediaAsset.fromMap(e),
    ];
  }

  /// Albums (buckets / PHAssetCollections) that contain at least one asset
  /// matching [filter], newest cover first.
  static Future<List<MediaAlbum>> getAlbums({
    required MediaFilter filter,
  }) async {
    final raw = await _invoke<List<Object?>>('getAlbums', {
      'type': _filterToType(filter),
    });
    if (raw == null) return const [];
    return [
      for (final e in raw)
        if (e is Map) MediaAlbum.fromMap(e),
    ];
  }

  /// JPEG bytes of a square thumbnail (native side decodes + scales).
  static Future<Uint8List?> getThumbnail({
    required String id,
    required String type,
    required int size,
  }) => _invoke<Uint8List>('getThumbnail', {
    'id': id,
    'type': type,
    'size': size,
  });

  /// Absolute path of a readable copy of the original file. The native side
  /// may copy it into the app's cache (iCloud assets, scoped storage); copies
  /// older than a day are purged automatically, or call [clearCache].
  static Future<String?> getOriginalPath({
    required String id,
    required String type,
  }) => _invoke<String>('getOriginalPath', {'id': id, 'type': type});

  /// Adds the file at [path] to the device gallery and returns the new
  /// asset's id (MediaStore id / PHAsset localIdentifier). [type] is
  /// `'image'` or `'video'`; [album] puts it in a named album (iOS) or
  /// sub-folder (Android). Throws a [PlatformException] with code
  /// `PERMISSION` when the OS refuses access.
  static Future<String?> saveToGallery({
    required String path,
    required String type,
    String? album,
  }) => _invoke<String>('saveToGallery', {
    'path': path,
    'type': type,
    'album': album,
  });

  /// Deletes every file copy the plugin made in the app's cache/tmp folder.
  /// Paths returned earlier stop being valid.
  static Future<void> clearCache() async {
    try {
      await _invoke<void>('clearCache');
    } on PlatformException {
      // Nothing to clean up, or not cleanable — not worth surfacing.
    } on MissingPluginException {
      // Unsupported platform.
    }
  }
}

/// Simple in-memory LRU cache so scrolling back doesn't re-hit native.
class PickerThumbnailCache {
  PickerThumbnailCache._();

  static final Map<String, Uint8List> _cache = <String, Uint8List>{};

  /// Tune this to your memory budget (256px JPEG ≈ 15–40 KB each).
  /// Lowering it trims the cache on the next [put].
  static int maxEntries = 300;

  static int get length => _cache.length;

  static Uint8List? get(String key) {
    final v = _cache.remove(key);
    if (v != null) _cache[key] = v; // move to end = most recently used
    return v;
  }

  static void put(String key, Uint8List bytes) {
    _cache.remove(key);
    while (_cache.isNotEmpty && _cache.length >= maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    if (maxEntries > 0) _cache[key] = bytes;
  }

  static void clear() => _cache.clear();
}
