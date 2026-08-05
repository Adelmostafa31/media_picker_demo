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
