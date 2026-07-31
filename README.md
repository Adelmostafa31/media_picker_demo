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

## Installation

Add the package to your project:

```bash
flutter pub add custom_media_picker
```

or add it directly to your `pubspec.yaml`:

```yaml
dependencies:
  custom_media_picker: ^0.1.0
```

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
  ),
);

if (assets != null) {
  for (final asset in assets) {
    print(asset.path);
  }
}
```

## Example app

The repository includes a demo app showing many configuration options, theme presets, and selection workflows.

## Notes

- Android 14+ partial access is supported through the native media picker flow.
- iOS can resolve assets from iCloud when needed.
- The package is designed to work as a reusable library while keeping the example app and native integrations in the same repository.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
