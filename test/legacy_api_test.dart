// Code written against 0.1.x must keep compiling and behaving the same.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:custom_media_picker/custom_media_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('custom_media_picker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void nativeReplies(String status) {
    messenger.setMockMethodCallHandler(channel, (call) async => status);
  }

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('checkPermission still returns the 0.1.x strings', () async {
    for (final s in ['granted', 'limited', 'notDetermined', 'denied']) {
      nativeReplies(s);
      final String status = await MediaPickerChannel.checkPermission();
      expect(status, s);
    }
  });

  test('permanentlyDenied maps to the old "denied"', () async {
    nativeReplies('permanentlyDenied');
    expect(await MediaPickerChannel.checkPermission(), 'denied');
    expect(await MediaPickerChannel.requestPermission(), 'denied');
    expect(
      await MediaPickerChannel.requestPermissionStatus(),
      MediaPermissionStatus.permanentlyDenied,
    );
  });

  test('MediaAlbum keeps a non-null name', () {
    const album = MediaAlbum(id: '1', name: 'Camera', count: 3);
    final String name = album.name;
    expect(name, 'Camera');
    expect(MediaAlbum.fromMap({'id': 2, 'count': 1}).name, '');
  });
}
