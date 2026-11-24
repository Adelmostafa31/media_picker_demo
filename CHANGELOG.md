## 0.2.0

**Upgrading from 0.1.x** — existing code keeps compiling and working:

* Now a Flutter plugin: the Android/iOS code registers itself. A
  `MediaPickerHandler` you pasted into `MainActivity`/`AppDelegate` in 0.1.x
  keeps working, but it shadows the plugin's fixes — delete it and its channel
  registration.
* `MediaPickerChannel.checkPermission()`/`requestPermission()` still return the
  0.1.x strings (now deprecated). The new `checkPermissionStatus()`/
  `requestPermissionStatus()` return `MediaPermissionStatus`, which tells
  `denied` (Android can still ask) apart from `permanentlyDenied`.
* Requires Flutter 3.50 / Dart 3.14, Android API 24, iOS 15. Apps on older
  Flutter keep resolving 0.1.3.

**Fixes**

* Android: the Recent feed was not sorted on some devices (MIUI / Android 16
  ignored the sort columns), so "New to old" showed the gallery in storage
  order.
* Android: rotated photos (e.g. iPhone HEIC) showed sideways in the grid and
  upside down in the preview.
* System/predictive back inside an album now returns to the album list instead
  of closing the picker and dropping the selection.
* Changing the sort while a page loads no longer mixes old and new results.
* Recycled tiles no longer show another asset's thumbnail.
* Confirm no longer hangs when a path fails; unresolved assets are dropped and
  reported through `MediaPickerConfig.onAssetsUnavailable`.
* Preview no longer spins forever on errors or leaks a video controller.
* Date range calendar no longer repeats or skips a day across DST changes and
  follows the locale's first day of week and month names.
* Paging has a stable tie-breaker and de-duplicates by id.
* Copied originals are written atomically, so a killed copy can't be served
  later; copies older than a day are purged, or call `clearCache()`.
* Concurrent permission requests share one dialog, and a request can no longer
  hang when the activity is destroyed while the dialog is open.
* Load failures show an error with a retry button instead of "No media found".
* `initialSelection` is capped at `maxSelection`.
* iOS hides the Hidden album and no longer downloads iCloud originals for grid
  thumbnails.
* `galleryChanges` is now implemented on both platforms.
* Screen readers no longer read a video's duration twice.
* The date range sheet's close / previous / next month buttons have
  screen-reader labels.

**New**

* Tapping past `maxSelection` now shows a notice inside the picker and the
  preview (an app's own SnackBar is hidden under the modal sheet). Customize it
  with `selectionLimitMessage` (text) or `selectionLimitNoticeBuilder` (your own
  widget), or turn it off with `showSelectionLimitMessage: false`.

## 0.1.3

* Added a sort control to the Recent tab: old → new, new → old (default once
  enabled), or a custom date range. New `MediaPickerConfig.enableSort`
  toggle — defaults to `false`, so the sort row is opt-in.
* The "Custom range" option opens the picker's own date range sheet instead
  of Flutter's stock `showDateRangePicker` dialog, so it can page months
  horizontally, drop the edit-mode pen icon, and drop the "Select range"
  title. `dateRangeStartLabel`/`dateRangeEndLabel`/`dateRangeSaveLabel` on
  `MediaPickerConfig` control its header/button text.
* New `MediaPickerColors` tokens for the sort sheet accent and full styling
  of the date range sheet (`sortAccent`, `dateRangeSurface`,
  `dateRangeHeaderText`, `dateRangeSelectedFill`, `dateRangeRangeFill`,
  `dateRangeRangeText`). The sheet's action bar has no fill of its own — it
  sits directly on `dateRangeSurface`. `dateRangeSelectedFill` and
  `dateRangeRangeFill` are now nullable and, when left unset, automatically
  track `confirmButton` (the range fill at 50% opacity) instead of a fixed
  hex, so they follow whatever brand color you already use for the confirm
  button; pass either explicitly to override.
* `MediaPickerChannel.getAssets` gained `ascending`/`startDateSec`/
  `endDateSec` parameters. Native `getAssets` on both platforms accepts the
  matching `ascending`/`startDate`/`endDate` arguments; defaults reproduce
  the previous newest-first, unfiltered behavior exactly, so copy the
  updated `MediaPickerHandler.kt` / `MediaPickerHandler.swift` to use the
  new sort modes.

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
