import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'picker_config.dart';
import 'picker_models.dart';

/// Dart <-> native bridge. Channel name must match the Kotlin/Swift side.
class MediaPickerChannel {
  MediaPickerChannel._();

  static const MethodChannel _channel = MethodChannel('custom_media_picker');

  static const EventChannel _changesChannel =
      EventChannel('custom_media_picker/gallery_changes');

  /// The native side only ships for Android and iOS; every other platform has
  /// no plugin registered, so touching the channels there fails.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Emits whenever the OS reports a change in the user's photo library.
  ///
  /// Returns an empty stream on unsupported platforms: activating an event
  /// channel with no native implementation throws a MissingPluginException
  /// that `EventChannel` reports through `FlutterError.reportError`, so it
  /// cannot be caught by the subscriber.
  static Stream<void> get galleryChanges => isSupported
      ? _changesChannel.receiveBroadcastStream().map((_) {})
      : const Stream<void>.empty();

  static String _filterToType(MediaFilter f) {
    switch (f) {
      case MediaFilter.onlyImages:
        return 'image';
      case MediaFilter.onlyVideos:
        return 'video';
      case MediaFilter.all:
        return 'all';
    }
  }

  /// Non-interactive check — returns the current permission status without
  /// showing a system dialog.
  ///
  /// One of 'granted', 'limited', 'notDetermined' or 'denied'.
  /// 'notDetermined' means the OS dialog has never been shown, so
  /// [requestPermission] will present it; 'denied' on iOS means the user
  /// already refused once and only Settings can change it — see
  /// [openAppSettings].
  static Future<String> checkPermission() async {
    try {
      final res = await _channel.invokeMethod<String>('checkPermission');
      return res ?? 'denied';
    } on PlatformException {
      return 'denied';
    } on MissingPluginException {
      return 'denied';
    }
  }

  /// Shows the system photo/video access dialog when the status is still
  /// undetermined, and returns 'granted', 'limited' (iOS 14+/Android 14
  /// partial) or 'denied'.
  static Future<String> requestPermission() async {
    try {
      final res = await _channel.invokeMethod<String>('requestPermission');
      return res ?? 'denied';
    } on PlatformException {
      return 'denied';
    } on MissingPluginException {
      return 'denied';
    }
  }

  /// Opens this app's page in the system Settings so the user can flip the
  /// photo/video toggle after a hard denial. Returns false when the native
  /// side is unavailable.
  static Future<bool> openAppSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openAppSettings');
      return res ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Pass [albumId] to fetch a single album's assets ("Albums" tab);
  /// leave it null for the global newest-first feed ("Recent" tab).
  static Future<List<PickedMediaAsset>> getAssets({
    required MediaFilter filter,
    required int page,
    required int pageSize,
    String? albumId,
  }) async {
    final raw = await _channel.invokeMethod<List<dynamic>>('getAssets', {
      'type': _filterToType(filter),
      'page': page,
      'pageSize': pageSize,
      'albumId': albumId,
    });
    if (raw == null) return const [];
    return raw
        .map((e) => PickedMediaAsset.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  /// Albums (buckets / PHAssetCollections) that contain at least one
  /// asset matching [filter], newest cover first.
  static Future<List<MediaAlbum>> getAlbums({
    required MediaFilter filter,
  }) async {
    final raw = await _channel.invokeMethod<List<dynamic>>('getAlbums', {
      'type': _filterToType(filter),
    });
    if (raw == null) return const [];
    return raw
        .map((e) => MediaAlbum.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  /// JPEG bytes of a square thumbnail (native side decodes + scales).
  static Future<Uint8List?> getThumbnail({
    required String id,
    required String type,
    required int size,
  }) {
    return _channel.invokeMethod<Uint8List>('getThumbnail', {
      'id': id,
      'type': type,
      'size': size,
    });
  }

  /// Absolute path of the original file (may copy to cache/tmp on
  /// first call — iOS iCloud assets, Android scoped-storage fallback).
  static Future<String?> getOriginalPath({
    required String id,
    required String type,
  }) {
    return _channel.invokeMethod<String>('getOriginalPath', {
      'id': id,
      'type': type,
    });
  }
}

/// Simple in-memory LRU cache so scrolling back doesn't re-hit native.
class PickerThumbnailCache {
  PickerThumbnailCache._();

  static final Map<String, Uint8List> _cache = <String, Uint8List>{};

  /// Tune this to your memory budget (256px JPEG ≈ 15–40 KB each).
  static int maxEntries = 300;

  static Uint8List? get(String key) {
    final v = _cache.remove(key);
    if (v != null) _cache[key] = v; // move to end = most recently used
    return v;
  }

  static void put(String key, Uint8List bytes) {
    if (_cache.length >= maxEntries && _cache.isNotEmpty) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = bytes;
  }

  static void clear() => _cache.clear();
}
