# physical_diagonal

Device and current-window physical screen diagonal (inches), with a
configurable tablet-layout threshold.

Migrating from 0.1.1: `PhysicalDiagonal.platformVersion` is gone. See
"Migrating from 0.1.1" below.

## What's new in 2.0.2

- **New iOS models.** The hardware table now covers the iPhone 17 family
  (17, 17 Pro, 17 Pro Max, iPhone Air, 17e), the iPhone 18 Pro / 18 Pro Max,
  the **iPhone Duo** (foldable, dual-display), and the latest iPad mini,
  iPad (A16), iPad Air and iPad Pro (M4/M5) generations.
  Full list: [Supported iOS devices](#supported-ios-devices).
- **iPhone Duo.** One identifier, two screens: the plugin reports the
  7.6" inner display when the screen's short side exceeds 550 pt, and the
  5.4" outer display otherwise. Window tracking keeps working on top of it.
- **Better simulator support.** In the iOS Simulator the plugin resolves the
  *simulated* device (via `SIMULATOR_MODEL_IDENTIFIER`) instead of the host
  Mac's architecture, on both Intel (`x86_64`) and Apple Silicon (`arm64`)
  hosts. A simulated iPhone 17 Pro Max reports 6.9", a simulated iPad Pro 13"
  reports 13.0".

See CHANGELOG.md for the full history.

## Install

```yaml
dependencies:
  physical_diagonal: ^2.0.3
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

## Supported iOS devices

The iOS diagonal comes from a static machine-identifier table in
`PhysicalDiagonalPlugin.swift`.

| Diagonal | Devices (identifiers) |
|---|---|
| 4.7" | iPhone SE 2nd / 3rd gen (`iPhone12,8`, `iPhone14,6`) |
| 5.4" | iPhone 12 mini, 13 mini (`iPhone13,1`, `iPhone14,4`) |
| 6.1" | iPhone 12, 12 Pro, 13, 13 Pro, 14, 14 Pro, 15, 15 Pro, 16, 16e, 17e |
| 6.3" | iPhone 16 Pro, 17, 17 Pro, 18 Pro (`iPhone17,1`, `iPhone18,1`, `iPhone18,3`, `iPhone19,1`, `iPhone19,2`) |
| 6.5" | iPhone Air (`iPhone18,4`) |
| 6.7" | iPhone 12 Pro Max, 13 Pro Max, 14 Plus, 14 Pro Max, 15 Plus, 15 Pro Max, 16 Plus |
| 6.9" | iPhone 16 Pro Max, 17 Pro Max, 18 Pro Max (`iPhone17,2`, `iPhone18,2`, `iPhone19,3`) |
| 5.4" / 7.6" | **iPhone Duo** (`iPhone19,4`) — outer / inner display |
| 8.3" | iPad mini 6th gen, iPad mini (A17 Pro) |
| 10.2" | iPad 8th / 9th gen |
| 10.9" | iPad Air 4th / 5th gen, iPad 10th gen, iPad (A16) |
| 11.0" | iPad Pro 11" (M1 / M2 / M4 / M5), iPad Air 11" (M2 / M3 / M4) |
| 12.9" | iPad Pro 12.9" (M1 / M2) |
| 13.0" | iPad Air 13" (M2 / M3 / M4), iPad Pro 13" (M4 / M5) |

Identifiers not in the table fall back to `UIDevice.userInterfaceIdiom`:
11.0" for iPad, 6.1" for iPhone. The table starts at the iPhone 12 / SE 2nd
gen and iPad 8th gen generations, so older devices use that fallback too.

## iPhone Duo

The Duo is a single machine identifier (`iPhone19,4`) with two displays of
different size, so the table alone can't resolve it. The plugin checks the
short side of the active screen bounds:

| Display | Logical size | Reported diagonal |
|---|---|---|
| Outer | 466 × 678 pt | 5.4" |
| Inner | 626 × 890 pt | 7.6" |

Rule: short side > 550 pt → 7.6", otherwise 5.4". With the default
`tabletThreshold` of 7.0, `isTabletLayout` is `false` on the outer display
and `true` on the inner display. `deviceDiagonal` is re-read on every
`didChangeMetrics`, so it updates when the device is folded or unfolded.

## iOS Simulator

The simulator process reports the host architecture
(`x86_64` or `arm64`) as its machine identifier, which says nothing about the
simulated device. When that happens the plugin reads the
`SIMULATOR_MODEL_IDENTIFIER` environment variable instead and looks that up in
the same hardware table. Result: the simulated device's real diagonal, on
Intel and Apple Silicon Macs alike. If the simulated identifier is not in the
table, the idiom fallback above applies.

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
// 2.0.0+
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
  foldables, iPhone Duo) was verified by static code review during
  development, not against physical hardware. Test on real devices before
  shipping.
- `context.physical` falls back to a zero-value `PhysicalMetrics` outside
  a `PhysicalMetricsScope` in release builds (the `assert` is stripped);
  guard against `deviceDiagonal == 0` if that matters to your layout logic.
- No automated tests (unit/widget) ship in this release.

See CHANGELOG.md for the full defect history this version addresses.

## LLM / Agent Context

- **Initialization**: `await PhysicalDiagonal.ensureInitialized();` before `runApp`. It never throws; on platform-channel failure it falls back to a logical-pixel estimate. No try/catch needed.
- **Live metrics (use this in widgets)**: wrap the app in `PhysicalMetricsScope(tabletThreshold: ...)` and read `context.physical`. It returns `PhysicalMetrics` with `deviceDiagonal`, `windowDiagonal`, `tabletThreshold` (Type: double) and `isTabletLayout` (Type: bool). It updates on window resize, rotation and folding.
- **Static snapshot**: `PhysicalDiagonal.metrics` returns the same type with startup values and the default `tabletThreshold` of 7.0. It never updates. Use it only outside the widget tree.
- **Failure modes**: accessing `PhysicalDiagonal.metrics` before initialization, or `context.physical` outside a `PhysicalMetricsScope`, throws `AssertionError` in debug and returns zero values in release.
- **Negative Constraints**:
  - Do NOT use `MediaQuery` for physical calculations.
  - Do NOT access `PhysicalDiagonal.metrics` before `ensureInitialized()` completes.
  - Do NOT calculate PPI/DPI manually; rely on the native platform channel output.
  - Do NOT cache `deviceDiagonal` / `windowDiagonal` in long-lived state; they change at runtime.

## Canonical Implementation

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PhysicalDiagonal.ensureInitialized(); // never throws
  runApp(
    const PhysicalMetricsScope(
      tabletThreshold: 7.0,
      child: MyApp(),
    ),
  );
}

// In any widget below the scope (live, rebuilds on resize/fold):
@override
Widget build(BuildContext context) {
  final physical = context.physical;
  return physical.isTabletLayout ? const TabletLayout() : const PhoneLayout();
}

// Outside the widget tree (startup snapshot, default threshold 7.0):
final bool isTablet = PhysicalDiagonal.metrics.isTabletLayout;
```