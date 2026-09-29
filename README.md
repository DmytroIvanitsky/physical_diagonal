# physical_diagonal

Device and current-window physical screen diagonal (inches), with a
configurable tablet-layout threshold.

Migrating from 0.1.1: `PhysicalDiagonal.platformVersion` is gone. See
"Migrating from 0.1.1" below.

## Install

```yaml
dependencies:
  physical_diagonal: ^2.0.0
```

## Usage

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PhysicalDiagonal.ensureInitialized();
  runApp(
    PhysicalMetricsScope(
      tabletThreshold: 7.0,
      child: const MyApp(),
    ),
  );
}

// anywhere below the scope:
if (context.physical.isTabletLayout) { ... }
```

`ensureInitialized()` is blocking and must complete before `runApp`; this
avoids a null/placeholder first frame. It never throws — on platform-channel
failure it falls back to a logical-pixel estimate.

See `example/` for a full app (threshold slider, live metrics card,
layout that switches between `Row`/`Column` on `isTabletLayout`).

## Migrating from 0.1.1

0.1.1's API (`PhysicalDiagonal.platformVersion`, a single async diagonal
value) is removed entirely — this is a breaking rewrite, not an incremental
update. Replace:

```dart
// 0.1.1
final diagonal = await PhysicalDiagonal.platformVersion;
```

with:

```dart
// 2.0.0
await PhysicalDiagonal.ensureInitialized();
// then, under a PhysicalMetricsScope:
final diagonal = context.physical.deviceDiagonal;
```

## Platform requirements

- iOS deployment target: 13.0 (raised from 12.0 — required by the
  `UIWindowScene` APIs this version depends on for window-resize tracking).
- Android `minSdk`: 21.
- Supports both CocoaPods and Swift Package Manager on iOS.

## Known limitations

- iOS hardware-diagonal table is a static machine-identifier list.
  Unlisted future devices fall back to `UIDevice.userInterfaceIdiom`
  (phone/pad), which is coarser than a real inch value — extend the
  `switch` in `PhysicalDiagonalPlugin.swift` as new identifiers ship.
- Android `DisplayMetrics.xdpi`/`ydpi` accuracy depends on OEM reporting;
  not independently corrected here (historically ~5% off on some devices).
- Interactive resize/fold behavior (Split View, Stage Manager, Android
  foldables) was verified by static code review during development, not
  against physical hardware. Test on real devices before shipping.
- `context.physical` falls back to a zero-value `PhysicalMetrics` outside
  a `PhysicalMetricsScope` in release builds (the `assert` is stripped);
  guard against `deviceDiagonal == 0` if that matters to your layout logic.
- No automated tests (unit/widget) ship in this release.

See CHANGELOG.md for the full defect history this version addresses.
