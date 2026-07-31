## 0.1.2

* Added `MediaPickerChannel.openAppSettings()` for recovering from a hard permission denial.
* `MediaPickerChannel.checkPermission()` now reports `notDetermined` separately from `denied`, and is implemented on both native sides (it previously always fell back to `denied`).
* Documented the required native setup in the README: manifest permissions, `NSPhotoLibraryUsageDescription`, handler placement, and channel registration. Without these the method channel has no receiver and the picker closes without ever prompting.
* Example app now ships the complete native integration and a permission request flow with a Settings fallback.

## 0.1.1

* Added maintainer information to the README.

## 0.1.0

* Initial release of the custom media picker package.
* Added native Android and iOS media access, custom picker UI, previews, and selection configuration.
