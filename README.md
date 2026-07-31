# Custom Media Picker

A Flutter package that lets you pick images and videos from the device gallery using a custom UI instead of relying on a 3rd-party picker package. It uses native Android and iOS access through platform channels and supports previews, selection limits, and theming.

## Features

- Image and video selection
- Grid or list layouts
- Bottom sheet or full-screen picker
- Filtering by media type
- Selection limits and callback hooks
- Customizable color tokens
- Full-image and video preview support

## Demo

| Android | iOS |
| :---: | :---: |
| ![Custom Media Picker running on Android](https://raw.githubusercontent.com/Adelmostafa31/media_picker_demo/main/doc/demo_android.gif) | ![Custom Media Picker running on iOS](https://raw.githubusercontent.com/Adelmostafa31/media_picker_demo/main/doc/demo_ios.gif) |

## Platform support

| Platform | Supported | Backing API |
| --- | --- | --- |
| Android | ✅ API 21+ | `MediaStore` |
| iOS | ✅ 12+ | `PhotoKit` (`PHAsset`) |
| Web / desktop | ❌ | no native implementation — `CustomMediaPicker.pick` returns `null` |

## Installation

```bash
flutter pub add custom_media_picker
```

or add it directly to your `pubspec.yaml`:

```yaml
dependencies:
  custom_media_picker: ^0.1.2
```

> **⚠️ This package is not a plugin — the native setup below is required.**
> `custom_media_picker` ships the Dart UI plus the native handler *sources*, but
> it does not auto-register anything. Until you complete
> [Native setup](#native-setup) the `custom_media_picker` method channel has no
> receiver, every permission call resolves to `denied`, and the picker closes
> immediately without ever showing the OS permission dialog.

## Native setup

Both platforms need three things: the **permission declaration**, the **handler
source**, and the **channel registration**.

### Android

**1. Declare the permissions** in `android/app/src/main/AndroidManifest.xml`,
directly inside `<manifest>` and above `<application>`:

```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />
<uses-permission
    android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
```

**2. Copy the handler.** Take `android/app/src/main/kotlin/.../MediaPickerHandler.kt`
from this repository into your app's Kotlin source folder (next to
`MainActivity.kt`) and change the first line to your own package:

```kotlin
package com.yourcompany.yourapp
```

**3. Register the channel** in `MainActivity.kt`. Forwarding
`onRequestPermissionsResult` is mandatory — without it the permission dialog's
answer never reaches the handler and `requestPermission()` never completes:

```kotlin
class MainActivity : FlutterActivity() {
    private var mediaPickerHandler: MediaPickerHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mediaPickerHandler = MediaPickerHandler(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MediaPickerHandler.CHANNEL,
        ).setMethodCallHandler(mediaPickerHandler)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (mediaPickerHandler?.onRequestPermissionsResult(
                requestCode, grantResults) == true
        ) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
```

### iOS

**1. Declare the usage description** in `ios/Runner/Info.plist`. iOS will not
show the permission dialog without it, and the app will not appear under
*Settings → Privacy → Photos*, so the user cannot grant access manually either:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Photos access is needed to pick images and videos from your gallery.</string>
```

**2. Copy the handler.** Paste the contents of `lib/MediaPickerHandler.swift`
from this repository into your `ios/Runner/AppDelegate.swift`, below the
`AppDelegate` class. Keeping it in `AppDelegate.swift` means the code is already
part of the Runner target — no *Add Files to Runner…* step in Xcode.

**3. Register the channel** in `AppDelegate.swift`. Use whichever variant
matches the template your app was generated from:

```swift
// Flutter 3.35+ (scene-based Runner, has didInitializeImplicitFlutterEngine)
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let mediaPickerHandler = MediaPickerHandler()

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: MediaPickerHandler.channelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      self?.mediaPickerHandler.handle(call, result: result)
    }
  }
}
```

```swift
// Older Runner templates (window.rootViewController is the FlutterViewController)
@main
@objc class AppDelegate: FlutterAppDelegate {
  private let mediaPickerHandler = MediaPickerHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: MediaPickerHandler.channelName,
      binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.mediaPickerHandler.handle(call, result: result)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## Permissions reference

| Platform | Declaration | Applies to |
| --- | --- | --- |
| Android 13+ (API 33) | `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO` | full gallery read |
| Android 14+ (API 34) | `READ_MEDIA_VISUAL_USER_SELECTED` | partial ("Select photos") access |
| Android ≤ 12 (API 32) | `READ_EXTERNAL_STORAGE` with `maxSdkVersion="32"` | legacy gallery read |
| iOS | `NSPhotoLibraryUsageDescription` | full + limited photo library access |

`CustomMediaPicker.pick` requests access on your behalf and calls
`config.onPermissionDenied` when the user refuses. Nothing is written to the
gallery, so `NSPhotoLibraryAddUsageDescription` and `WRITE_EXTERNAL_STORAGE`
are **not** needed.

## Usage

```dart
import 'package:custom_media_picker/custom_media_picker.dart';

final assets = await CustomMediaPicker.pick(
  context,
  config: MediaPickerConfig(
    layoutStyle: LayoutStyle.sheet,
    listStyle: ListStyle.grid,
    gridCrossAxisCount: 3,
    maxSelection: 9,
    mediaFilter: MediaFilter.all,
    title: 'Select media',
    onPermissionDenied: () => debugPrint('Photos permission denied'),
  ),
);

if (assets != null) {
  for (final asset in assets) {
    // Already resolved when config.resolvePathsOnConfirm is true (the default);
    // otherwise call `await asset.resolvePath()`.
    debugPrint(asset.resolvedPath);
  }
}
```

`pick` returns `null` when the user dismisses the picker **or** when permission
was denied.

### Handling permission yourself

`MediaPickerChannel` exposes the permission calls if you want to show your own
rationale before the system dialog, or offer a way back after a refusal:

```dart
final status = await MediaPickerChannel.checkPermission();
// 'granted' | 'limited' | 'notDetermined' | 'denied'

if (status == 'notDetermined') {
  // The system dialog can still be shown.
  await MediaPickerChannel.requestPermission();
} else if (status == 'denied') {
  // iOS never prompts twice, and Android stops after two refusals —
  // Settings is the only way back.
  await MediaPickerChannel.openAppSettings();
}
```

`limited` (iOS 14+ "Selected Photos", Android 14+ partial access) is a working
state: the picker shows the subset the user granted.

## Example app

The repository includes a demo app in `example/` showing many configuration
options, theme presets, selection workflows, and a complete permission request
flow with a Settings fallback. It has the native setup above already applied, so
it is the fastest place to see a working integration.

```bash
cd example
flutter pub get
flutter run
```

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| Picker closes instantly, no permission dialog | Native setup skipped — the method channel has no receiver, so every call falls back to `denied`. |
| iOS: app missing from *Settings → Privacy → Photos* | `NSPhotoLibraryUsageDescription` missing from `Info.plist`. |
| Android: request returns `denied` without a dialog | Permissions missing from `AndroidManifest.xml`, or the user refused twice — send them to Settings via `openAppSettings()`. |
| Android: `requestPermission()` never returns | `onRequestPermissionsResult` not forwarded from `MainActivity`. |
| Gallery is empty after granting | Status is `limited`; the user picked a subset. Call `openAppSettings()` to let them widen it. |

## Notes

- Android 14+ partial access is supported through the native media picker flow.
- iOS can resolve assets from iCloud when needed — the first `resolvePath()` on
  an iCloud asset may take a moment while it downloads.
- The package is designed to work as a reusable library while keeping the example
  app and native integrations in the same repository.

## 👨‍💻 Maintainer

**Adel Mostafa**

Senior Flutter Developer

- 🌐 Portfolio: https://adel-mostafa.vercel.app
- 🐙 GitHub: https://github.com/Adelmostafa31
- 💼 LinkedIn: https://linkedin.com/in/adel-mostafa

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
