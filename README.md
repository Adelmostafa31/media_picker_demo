# Custom Media Picker — Demo Project

A runnable demo of the fully custom, package-free gallery picker
(images + videos, Android MediaStore + iOS PHPhotoKit via MethodChannel).
The only dependency is `video_player`, used exclusively for the
full-screen video preview.

## How to run

The zip ships all the important files (Dart code, `MainActivity.kt`,
`MediaPickerHandler.kt`, `AppDelegate.swift` with the iOS handler embedded,
`AndroidManifest.xml`, `Info.plist`). One command generates the remaining
boilerplate (Gradle files, Xcode project, launch assets, etc.):

```bash
cd media_picker_demo        # keep this folder name — it's the project name
flutter create .            # regenerates missing scaffolding, KEEPS existing files
flutter pub get
flutter run
```

> Do NOT pass `--overwrite` to `flutter create` — the default behavior
> (skip files that already exist) is exactly what we rely on: it fills in
> the missing platform boilerplate while preserving the wired-up
> `MainActivity.kt`, `AppDelegate.swift`, manifest and plist.

No Xcode steps needed for iOS: the native handler is embedded inside
`AppDelegate.swift`, which is already part of the Runner target.

## What the demo lets you test

- **Layout**: bottom sheet (WhatsApp style, draggable) vs full screen
  (with X / back leading).
- **List style**: grid (2–5 columns via slider) vs list view.
- **Media filter**: all / images only / videos only.
- **Max selection**: 0 (unlimited) to 10, with a snackbar on limit.
- **Themes**: 4 sample `MediaPickerColors` sets (light / dark /
  whatsapp / purple) to prove all colors are injectable tokens.
- **Results**: picked assets shown in selection order with numbered
  badges; tap any tile for its metadata + resolved file path.
- **Preview**: long-press any tile inside the picker — pinch-zoom for
  images, playable scrubber for videos.

## Where the picker code lives

```
lib/custom_media_picker/            # drop this folder into any app
android/.../MediaPickerHandler.kt   # + wiring in MainActivity.kt
ios/Runner/AppDelegate.swift        # handler class embedded at the bottom
```

To use it in your own app, see `CustomMediaPicker.pick(context, config: ...)`
in `lib/main.dart` for a complete example.

## Notes

- Android 14+: "Select photos" partial access is treated as `limited`
  and the picker proceeds with the user-selected subset.
- iOS: the first path resolution of an iCloud-only asset downloads it
  (spinner shows on the confirm button meanwhile).
- Files copied during path resolution use a `picker_` prefix in
  cacheDir (Android) / tmp (iOS) if you ever want to clean them up.
