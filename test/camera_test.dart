import 'dart:async';
import 'dart:io';
import 'dart:math' show Point;

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:custom_media_picker/custom_media_picker.dart';
import 'package:custom_media_picker/custom_media_picker/src/camera/camera_session.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// In-memory camera: two lenses, writes real temp files for captures.
class FakeCamera extends CameraPlatform with MockPlatformInterfaceMixin {
  FakeCamera({this.denyCamera = false, this.denyAudio = false});

  bool denyCamera;
  bool denyAudio;
  final created = <MediaSettings>[];
  final opened = <CameraLensDirection>[];
  FlashMode? flash;
  DeviceOrientation? lockedOrientation;
  double? zoom;
  Point<double>? focus;
  int _nextId = 0;
  final _init = StreamController<CameraInitializedEvent>.broadcast();
  // Never emits, never closes: `.first` must not fail.
  final _errors = StreamController<CameraErrorEvent>.broadcast();
  late final Directory dir = Directory.systemTemp.createTempSync('cam');

  static const cams = [
    CameraDescription(
      name: 'back',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    ),
    CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 270,
    ),
  ];

  @override
  Future<List<CameraDescription>> availableCameras() async => cams;

  @override
  Future<int> createCameraWithSettings(
    CameraDescription description,
    MediaSettings? mediaSettings,
  ) async {
    created.add(mediaSettings!);
    opened.add(description.lensDirection);
    if (denyAudio && mediaSettings.enableAudio) {
      throw CameraException('AudioAccessDenied', 'no mic');
    }
    if (denyCamera) throw CameraException('CameraAccessDenied', 'no');
    return ++_nextId;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    scheduleMicrotask(
      () => _init.add(
        CameraInitializedEvent(
          cameraId,
          1920,
          1080,
          ExposureMode.auto,
          true,
          FocusMode.auto,
          true,
        ),
      ),
    );
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _init.stream.where((e) => e.cameraId == cameraId);
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errors.stream;
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Widget buildPreview(int cameraId) => const ColoredBox(color: Colors.blue);
  @override
  Future<void> dispose(int cameraId) async {}
  @override
  Future<double> getMinZoomLevel(int cameraId) async => 1;
  @override
  Future<double> getMaxZoomLevel(int cameraId) async => 8;
  @override
  Future<void> setZoomLevel(int cameraId, double zoom) async =>
      this.zoom = zoom;
  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async => flash = mode;
  @override
  Future<void> setFocusPoint(int cameraId, Point<double>? point) async =>
      focus = point;
  @override
  Future<void> setExposurePoint(int cameraId, Point<double>? point) async {}
  @override
  Future<void> lockCaptureOrientation(
    int cameraId,
    DeviceOrientation orientation,
  ) async => lockedOrientation = orientation;

  @override
  Future<XFile> takePicture(int cameraId) async {
    final f = File('${dir.path}/p${DateTime.now().microsecondsSinceEpoch}.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    return XFile(f.path);
  }

  @override
  Future<void> prepareForVideoRecording() async {}
  @override
  Future<void> startVideoCapturing(VideoCaptureOptions options) async {}
  @override
  Future<XFile> stopVideoRecording(int cameraId) async {
    final f = File('${dir.path}/v${DateTime.now().microsecondsSinceEpoch}.mp4')
      ..writeAsBytesSync([4, 5, 6]);
    return XFile(f.path);
  }
}

/// Recording clock the test moves by hand.
class FakeStopwatch implements Stopwatch {
  static Duration now = Duration.zero;
  Duration _start = Duration.zero;
  bool _running = false;
  @override
  void start() {
    _start = now;
    _running = true;
  }

  @override
  void stop() => _running = false;
  @override
  Duration get elapsed => _running ? now - _start : now - _start;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Like pumpAndSettle, but bounded: the video review spinner never stops in
/// tests (video_player has no platform here).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

late FakeCamera cam;
const _channel = MethodChannel('custom_media_picker');

Future<Future<CapturedMedia?>> openCamera(
  WidgetTester tester, [
  CameraConfig config = const CameraConfig(),
]) async {
  late Future<CapturedMedia?> result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              result = CustomMediaPicker.capture(context, config: config),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  setUp(() {
    cam = FakeCamera();
    CameraPlatform.instance = cam;
    FakeStopwatch.now = Duration.zero;
    CameraSession.newStopwatch = FakeStopwatch.new;
  });
  tearDown(() {
    CameraSession.newStopwatch = Stopwatch.new;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  testWidgets('photo: shutter → review → Use returns the photo', (
    tester,
  ) async {
    final result = await openCamera(
      tester,
      const CameraConfig(timerOptions: []),
    );
    expect(find.byType(DefaultShutterButton), findsOneWidget);
    await tester.tap(find.byType(DefaultShutterButton));
    await tester.pumpAndSettle();
    expect(find.text('Retake'), findsOneWidget);
    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();
    final media = await result;
    expect(media!.isVideo, isFalse);
    expect(File(media.path).existsSync(), isTrue);
  });

  testWidgets('retake deletes the file and returns to the camera', (
    tester,
  ) async {
    await openCamera(tester);
    await tester.tap(find.byType(DefaultShutterButton));
    await tester.pumpAndSettle();
    final shot = cam.dir.listSync().single;
    await tester.tap(find.text('Retake'));
    await tester.pumpAndSettle();
    expect(shot.existsSync(), isFalse);
    expect(find.byType(DefaultShutterButton), findsOneWidget);
  });

  testWidgets('video mode: tap starts, tap stops, returns duration', (
    tester,
  ) async {
    final result = await openCamera(tester);
    await tester.tap(find.text('VIDEO'));
    await tester.pump();
    await tester.tap(find.byType(DefaultShutterButton));
    await tester.pump();
    FakeStopwatch.now = const Duration(seconds: 3);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('00:03'), findsOneWidget);
    // Mode switcher and close are hidden/disabled while recording.
    expect(find.text('PHOTO'), findsNothing);
    await tester.tap(find.byType(DefaultShutterButton));
    await settle(tester);
    await tester.tap(find.text('Use'));
    await settle(tester);
    final media = await result;
    expect(media!.isVideo, isTrue);
    expect(media.duration, const Duration(seconds: 3));
  });

  testWidgets('hold shutter in photo mode records a video', (tester) async {
    await openCamera(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DefaultShutterButton)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(DefaultRecordingIndicator), findsOneWidget);
    await gesture.up();
    await settle(tester);
    expect(find.text('Retake'), findsOneWidget);
    expect(cam.dir.listSync().single.path, endsWith('.mp4'));
  });

  testWidgets('maxVideoDuration stops recording by itself', (tester) async {
    await openCamera(
      tester,
      const CameraConfig(
        initialMode: CaptureMode.video,
        maxVideoDuration: Duration(seconds: 5),
      ),
    );
    await tester.tap(find.byType(DefaultShutterButton));
    await tester.pump();
    FakeStopwatch.now = const Duration(seconds: 5);
    await tester.pump(const Duration(milliseconds: 250));
    await settle(tester);
    expect(find.text('Retake'), findsOneWidget);
  });

  testWidgets('self-timer counts down before taking the photo', (tester) async {
    await openCamera(tester);
    await tester.tap(find.byIcon(Icons.timer_outlined));
    await tester.pump();
    expect(find.text('3s'), findsOneWidget);
    await tester.tap(find.byType(DefaultShutterButton));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2'), findsOneWidget);
    expect(cam.dir.listSync(), isEmpty);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Retake'), findsOneWidget);
  });

  testWidgets('captures are locked to portrait by default', (tester) async {
    await openCamera(tester);
    expect(cam.lockedOrientation, DeviceOrientation.portraitUp);
  });

  testWidgets('forcePortrait: false follows the device rotation', (
    tester,
  ) async {
    await openCamera(tester, const CameraConfig(forcePortrait: false));
    expect(cam.lockedOrientation, isNull);
  });

  testWidgets('flash cycles through config.flashModes', (tester) async {
    await openCamera(tester);
    expect(cam.flash, FlashMode.off);
    await tester.tap(find.byTooltip('Flash'));
    await tester.pumpAndSettle();
    expect(cam.flash, FlashMode.auto);
    await tester.tap(find.byTooltip('Flash'));
    await tester.pumpAndSettle();
    expect(cam.flash, FlashMode.always);
  });

  testWidgets('switch camera opens the other lens', (tester) async {
    await openCamera(tester);
    await tester.tap(find.byTooltip('Switch camera'));
    await tester.pumpAndSettle();
    expect(cam.opened, [CameraLensDirection.back, CameraLensDirection.front]);
  });

  testWidgets('camera denied shows the permission view', (tester) async {
    cam.denyCamera = true;
    var denied = 0;
    final result = await openCamera(
      tester,
      CameraConfig(onPermissionDenied: () => denied++),
    );
    expect(find.text('Camera access is off'), findsOneWidget);
    expect(denied, 1);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('resume after a denial does not ask again (no prompt loop)', (
    tester,
  ) async {
    cam.denyCamera = true;
    await openCamera(tester);
    expect(cam.created, hasLength(1));
    // The system permission dialog pauses and resumes the app.
    for (final s in [AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(s);
      await tester.pumpAndSettle();
    }
    expect(cam.created, hasLength(1));
    expect(find.text('Camera access is off'), findsOneWidget);
  });

  testWidgets('back from Settings after granting reopens the camera', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (_) async => true);
    cam.denyCamera = true;
    await openCamera(tester);
    await tester.tap(find.text('Open Settings'));
    cam.denyCamera = false; // user granted it in Settings
    for (final s in [AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(s);
      await tester.pumpAndSettle();
    }
    expect(find.byType(DefaultShutterButton), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('microphone denied still opens the camera, silent video', (
    tester,
  ) async {
    cam.denyAudio = true;
    await openCamera(tester);
    expect(find.byType(DefaultShutterButton), findsOneWidget);
    expect(cam.created.last.enableAudio, isFalse);
  });

  testWidgets('every part can be replaced by a builder', (tester) async {
    final result = await openCamera(
      tester,
      CameraConfig(
        topBarBuilder: (_, c) => const Text('my top'),
        bottomBarBuilder: (_, c) =>
            ElevatedButton(onPressed: c.capture, child: const Text('snap')),
        overlayBuilder: (_, c) => const Text('grid'),
        reviewBuilder: (_, media, retake, use) =>
            TextButton(onPressed: use, child: Text('keep ${media.type.name}')),
      ),
    );
    expect(find.text('my top'), findsOneWidget);
    expect(find.text('grid'), findsOneWidget);
    expect(find.byType(DefaultShutterButton), findsNothing);
    await tester.tap(find.text('snap'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('keep image'));
    await tester.pumpAndSettle();
    expect(await result, isNotNull);
  });

  testWidgets('saveToGallery adds the id; failure still returns media', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          expect(call.method, 'saveToGallery');
          expect((call.arguments as Map)['album'], 'QA');
          return 'gallery-42';
        });
    var result = await openCamera(
      tester,
      const CameraConfig(saveToGallery: true, galleryAlbum: 'QA'),
    );
    await tester.tap(find.byType(DefaultShutterButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();
    expect((await result)!.galleryId, 'gallery-42');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _channel,
          (_) async => throw PlatformException(code: 'PERMISSION'),
        );
    Object? failure;
    result = await openCamera(
      tester,
      CameraConfig(
        saveToGallery: true,
        showReview: false,
        onSaveToGalleryFailed: (e) => failure = e,
      ),
    );
    await tester.tap(find.byType(DefaultShutterButton));
    await tester.pumpAndSettle();
    final media = await result;
    expect(media, isNotNull);
    expect(media!.galleryId, isNull);
    expect(failure, isA<PlatformException>());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('back while recording stops instead of closing', (tester) async {
    await openCamera(
      tester,
      const CameraConfig(initialMode: CaptureMode.video),
    );
    await tester.tap(find.byType(DefaultShutterButton));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Retake'), findsOneWidget);
  });

  group('selection limit', () {
    const full = CameraConfig(maxSelection: 2, selectedCount: 2);

    testWidgets('photo at the limit: Use shows the notice and stays', (
      tester,
    ) async {
      var reached = 0;
      final result = await openCamera(
        tester,
        CameraConfig(
          maxSelection: 2,
          selectedCount: 2,
          onSelectionLimitReached: () => reached++,
        ),
      );
      var done = false;
      result.then((_) => done = true);
      await tester.tap(find.byType(DefaultShutterButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use'));
      await tester.pump();
      expect(find.text('You can select up to 2 items'), findsOneWidget);
      expect(find.text('Retake'), findsOneWidget);
      expect(reached, 1);
      expect(done, isFalse);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('You can select up to 2 items'), findsNothing);
    });

    testWidgets('video at the limit is refused the same way', (tester) async {
      await openCamera(
        tester,
        const CameraConfig(
          maxSelection: 2,
          selectedCount: 2,
          initialMode: CaptureMode.video,
        ),
      );
      await tester.tap(find.byType(DefaultShutterButton));
      await tester.pump();
      FakeStopwatch.now = const Duration(seconds: 2);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byType(DefaultShutterButton));
      await settle(tester);
      await tester.tap(find.text('Use'));
      await tester.pump();
      expect(find.text('You can select up to 2 items'), findsOneWidget);
      expect(find.text('Retake'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('without review the capture is discarded, camera stays', (
      tester,
    ) async {
      await openCamera(
        tester,
        const CameraConfig(
          maxSelection: 1,
          selectedCount: 1,
          showReview: false,
        ),
      );
      await tester.tap(find.byType(DefaultShutterButton));
      await tester.pump();
      await tester.pump();
      expect(find.text('You can select up to 1 items'), findsOneWidget);
      expect(find.byType(DefaultShutterButton), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(cam.dir.listSync(), isEmpty);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('below the limit captures are accepted', (tester) async {
      final result = await openCamera(
        tester,
        const CameraConfig(maxSelection: 2, selectedCount: 1),
      );
      await tester.tap(find.byType(DefaultShutterButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use'));
      await tester.pumpAndSettle();
      expect(await result, isNotNull);
    });

    testWidgets('custom notice widget and controls.isAtSelectionLimit', (
      tester,
    ) async {
      bool? atLimit;
      await openCamera(
        tester,
        CameraConfig(
          maxSelection: 2,
          selectedCount: 2,
          selectionLimitMessage: (_) => 'ignored',
          selectionLimitNoticeBuilder: (_, max) => Text('full: $max'),
          topBarBuilder: (_, c) {
            atLimit = c.isAtSelectionLimit;
            return const SizedBox();
          },
        ),
      );
      expect(atLimit, isTrue);
      await tester.tap(find.byType(DefaultShutterButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use'));
      await tester.pump();
      expect(find.text('full: 2'), findsOneWidget);
      expect(find.text('ignored'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    test('isAtSelectionLimit', () {
      expect(full.isAtSelectionLimit, isTrue);
      expect(
        const CameraConfig(
          maxSelection: 0,
          selectedCount: 9,
        ).isAtSelectionLimit,
        isFalse,
      );
      expect(
        const CameraConfig(
          maxSelection: 3,
          selectedCount: 2,
        ).isAtSelectionLimit,
        isFalse,
      );
    });
  });
}
