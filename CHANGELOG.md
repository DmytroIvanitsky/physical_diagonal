## 2.0.3

- Docs: README updated — supported iOS device table (iPhone 17/18 families, iPhone Duo, latest iPads), iPhone Duo display selection, iOS Simulator behavior.

## 2.0.2

- Add: Support for the latest iPhone and iPad models (including foldable dual-display configurations).
- Fix: Improved physical diagonal detection in iOS Simulator environments.

## 2.0.1

- Maintenance and package metadata updates.

## 2.0.0

Breaking rewrite. Nothing from 0.1.1 is backward compatible.

- **Breaking:** `PhysicalDiagonal.platformVersion` removed. Replaced by
  `PhysicalDiagonal.ensureInitialized()` (call before `runApp`) and the
  `PhysicalMetricsScope` widget / `context.physical` getter. See README for
  the new usage.
- Add: `windowDiagonal` — physical diagonal of the *current* window,
  distinct from `deviceDiagonal` (the full-screen diagonal). Tracks
  split-screen, multi-window, folding, and Stage Manager resizing.
- Add: `isTabletLayout` with a configurable `tabletThreshold`.
- Fix: Android now reads `computeCurrentWindowMetrics` for `windowDiagonal`
  and `computeMaximumWindowMetrics` for `deviceDiagonal` separately, guards
  `display.getRealMetrics` behind an SDK check (real API 30+, `minSdk` 21),
  and implements the full `ComponentCallbacks2` contract
  (`onTrimMemory` included) so window/orientation changes push live updates.
- Fix: Android namespace/package changed from the template default
  `com.example.physical_diagonal` to `dev.ivanitsky.physical_diagonal`.
  `namespace` is now declared in `build.gradle` (required by current AGP).
- Fix: iOS unrecognized machine identifiers no longer report a fixed phone
  diagonal (this inverted tablet detection for any iPad released after the
  table was written). Falls back to `UIDevice.userInterfaceIdiom`.
- Fix: iOS identifier table — four entries corrected against Apple's
  published identifiers (`iPhone14,3`, `iPhone14,5`, `iPhone14,7`,
  `iPad13,8`/`iPad13,9` previously mapped to the wrong physical size).
- Fix: iOS window-resize ratio computed from a `screenLogicalDiagonal`
  value read from the active `UIWindowScene` (with a `UIScreen.main`
  fallback), instead of a hardcoded points-per-inch constant.
- Add: Swift Package Manager support alongside CocoaPods
  (`ios/physical_diagonal/Package.swift`), ahead of the CocoaPods trunk
  read-only cutover (2026-12-02). iOS deployment target raised to 13.0 —
  required by the `UIWindowScene`/`connectedScenes` APIs this release
  depends on.
- Add: `example/` app demonstrating `ensureInitialized`, `PhysicalMetricsScope`,
  and a live threshold slider.

## 0.1.1

Adding proper documentation.

## 0.0.1

Physical diagonal of the screen helps to optimize design for
Tablets/bigger screens. Calculation relies on system pixel density
information, so it might be slightly inaccurate for Android devices
(about 5%).