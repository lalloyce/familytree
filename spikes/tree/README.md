# Spike 4: tree at scale

Throwaway. Design section 10, spike 4: "3,000 synthetic nodes on the weakest phone available. Layout under 1 second off the main thread and 95th-percentile frame time under 16 ms."

**Status: written and tested. Measured on the founder's Mac only, as a proxy. Every number below is labelled "host proxy, NOT a weak-phone result". Weak-phone result: awaiting phone.**

No phone has been named and no Android emulator is installed, so the design's measurement has not been taken. Nothing in this file declares the threshold passed.

## What was built

- `lib/gen.dart`: seeded, deterministic generator. Exactly 3,000 people. Houses follow design section 4: each husband has 1 to 4 houses (weights 50, 30, 15, 5 percent), each house has one wife and 0 to 6 children (uniform). Exactly 20 women are wife in two houses under two different husbands (they head two houses; every married woman is also a child in her father's house). Every person except a root has a father house. Roots are the founders and the wives who married into a founder's house with no recorded parents; for seed 1 there are 13. The generator adds a founder if the tree dies out early, so the count is exact.
- `lib/layout.dart`: pure Dart, no `dart:ui`, so it runs in an isolate.
  - `layoutFocusedHouse` is the design's diagram: the focused house, one generation up (the parents of the husband and of the wife) and one generation down (the children). Three rows. Names wrap, nothing is truncated. A woman who heads two houses carries the text tag "same person".
  - `layoutWholeTree` is a stress variant that lays out every person (4,027 placements: each man once, each house's wife, each daughter). The design never draws this; it exists so the "3,000 nodes" threshold can be tested literally.
  - `layoutFocusedInIsolate` and `layoutWholeTreeInIsolate` run them with `Isolate.run`. The closure captures the whole dataset, so the whole 3,000-person dataset is copied into the isolate. That is the worst case for transfer cost; a real app would pass only the neighbourhood.
  - Node heights come from a greedy word-wrap estimate (average glyph 0.6 of the font size), because `TextPainter` is not available off the main thread. `bench.dart` checks the estimate against the real font and reports the worst real/estimated ratio.
- `lib/chain.dart`: the spoken chain. `ChainLine` is a row whose text wraps and is never ellipsised; `ChainList` is a `ListView.builder` of 3,000 of them ("Manyi, son of Winyo, house 2"). Tapping a row focuses that person's house and switches to the diagram.
- `lib/diagram_view.dart`: draws a `LayoutResult`. Plain bordered boxes, no blur, shadow or animation. Kind and basis are words in the caption.
- `lib/bench.dart`, `lib/main.dart`: the benchmark and a two-view app (Chain, Diagram) with a "Run benchmark" button.

Not built: placeholder nodes ("someone we forgot", dashed outline), empty-house text, disputed links, the remembered diagram choice. The synthetic data has none of them.

## Run

```
source scripts/env.sh
cd spikes/tree
flutter pub get
flutter analyze
flutter test                         # 14 tests
flutter build apk --profile          # build/app/outputs/flutter-apk/app-profile.apk (not committed)
```

Host proxy benchmark (macOS desktop, profile mode, window must be visible and in front):

```
flutter run -d macos --profile --dart-define=AUTORUN_BENCH=true     # prints BENCH_RESULT, then exits
# or build once and launch the app yourself:
flutter build macos --profile --dart-define=AUTORUN_BENCH=true --dart-define=BENCH_OUT=bench_result.txt
open -n build/macos/Build/Products/Profile/tree_spike.app
# the sandboxed app writes ~/Library/Containers/spike.tree.treeSpike/Data/tmp/bench_result.txt
```

## What the benchmark does

1. Layout: 40 runs of the focused layout in a fresh isolate, then 40 runs of the whole-tree stress layout. Two times are recorded per run. End to end is from the call to the result being back on the main isolate (isolate spawn, dataset copy in, compute, copy out). Compute is the time inside the layout function, measured in the isolate.
2. Frames: `SchedulerBinding.addTimingsCallback` records every `FrameTiming` while a fixed script scrolls the 3,000-row chain: down at 2,400 dp/s for 8 s, down at 6,000 dp/s for 4 s, up at 3,000 dp/s for 4 s. Position is a function of elapsed time, one `jumpTo` per frame. The first 30 frames are dropped. Reported per frame: total span (vsync start to raster finish), build, raster.
3. Estimator check: the worst ratio of real text height (`TextPainter`, platform default font) to the layout's estimated height, at text scale 1.0 and 2.0.

Percentiles are nearest-rank on the sorted values.

## Host proxy numbers (NOT a weak-phone result)

Machine, as read from the tool on this host: Apple M4, 10 logical CPUs (`sysctl hw.ncpu`), 17,179,869,184 bytes memory (`sysctl hw.memsize`), macOS 27.2 (build 26B123, from the app's own `Platform.operatingSystemVersion`). Flutter 3.47.9, Dart 3.13.7. Profile mode, Impeller (Metal) as logged by the engine. Viewport 800 x 600 dp at device pixel ratio 2.0. About 959 frames arrived in the 16 s script, so the display was delivering about 60 frames per second (the display's refresh rate was not read separately).

Three completed runs of the built profile app, launched with `open -n` so the window is in front. All times in milliseconds.

| Measure | Run A | Run B | Run C |
|---|---|---|---|
| Focused layout, end to end, min / median / p95 / max (40 runs) | 0.427 / 0.475 / 0.848 / 1.040 | 0.437 / 0.531 / 1.014 / 1.230 | 0.430 / 0.497 / 2.447 / 2.992 |
| Focused layout, compute in isolate, min / median / p95 / max | 0.002 / 0.004 / 0.006 / 0.010 | 0.002 / 0.004 / 0.019 / 0.022 | 0.003 / 0.003 / 0.007 / 0.012 |
| Whole-tree layout (4,027 nodes), end to end, min / median / p95 / max | 1.136 / 1.290 / 2.056 / 2.218 | 1.126 / 1.252 / 2.195 / 2.569 | 1.086 / 1.275 / 1.906 / 2.791 |
| Whole-tree layout, compute in isolate, min / median / p95 / max | 0.594 / 0.654 / 1.189 / 1.483 | 0.572 / 0.648 / 0.838 / 1.430 | 0.568 / 0.647 / 0.970 / 1.721 |
| Chain scroll, frames recorded | 958 | 959 | 959 |
| Chain scroll, total span, min / median / p95 / max | 1.302 / 2.814 / 3.517 / 5.840 | 1.180 / 2.797 / 3.567 / 5.627 | 1.340 / 2.829 / 3.635 / 6.115 |
| Chain scroll, build p95 / raster p95 | 2.095 / 1.409 | 2.196 / 1.394 | 2.194 / 1.434 |
| Frames over 16 ms | 0 | 0 | 0 |
| Estimator: worst real / estimated height (focused scale 1.0; whole tree scale 1.0; whole tree scale 2.0) | 1.004; 1.004; 0.993 | same | same |

The focused layout has 12 nodes in the benchmark house (the house with the most children whose husband and wife both have recorded parents). It costs microseconds because the design draws only one house. Dataset size matters only for the copy into the isolate.

The estimator is about 0.4 percent optimistic for the worst node on this Mac's system font at scale 1.0. The widget lets a node grow past its estimated height (`minHeight`), so a short estimate means a slightly off row gap, not clipped text. It has not been checked against Roboto on Android.

### Other host runs, not used above

- First attempt through `flutter run` (VM service attached): focused layout end to end p95 1.198 ms and max 65.07 ms; whole-tree layout first run 107.417 ms (also its max); 950 frames, total span p95 2.160 ms, max 25.009 ms, 1 frame over 16 ms. Outliers of tens of milliseconds happen on this host and are not explained; the three runs above did not show them.
- Second attempt through `flutter run`: only 146 frames in the scripted scroll (the window was probably not being redrawn at full rate); total span p95 2.925 ms. Not a valid frame sample. A third attempt produced no output.
- Two of five launches with `open -n` produced no result within 100 s, so the three above are the ones that completed. Cause not investigated; a window that is not in front is the likely reason.

## Phone procedure (founder, same benchmark on the weakest phone)

Do this on the weakest Android phone the pilot will use. The benchmark must run in profile mode; debug mode numbers are meaningless.

1. Phone: enable Developer options and USB debugging. Battery above 50 percent, battery saver off, phone at room temperature, all other apps closed, screen on and not locked. Leave the system font size at its default for the first set.
2. Computer:
   ```
   source scripts/env.sh
   cd spikes/tree
   flutter pub get
   flutter devices                       # copy the phone's id from the second column
   flutter run --profile -d <device>
   ```
3. Tap **Run benchmark**. Do not touch the phone for about 30 seconds. The list scrolls by itself. The result appears in a box under the buttons (the text is selectable) and in the terminal as `BENCH_RESULT`. It starts with the line `device run (record the device model by hand)`.
4. Run it three times. Quit the app between runs (`q` in the terminal, then `flutter run` again). Let the phone cool for a minute between runs.
5. Repeat the three runs with the system font size at its largest (Settings, Display, Font size).
6. Record by hand: phone model, Android version, RAM, and the date. Useful commands:
   ```
   adb -s <device> shell getprop ro.product.model
   adb -s <device> shell getprop ro.build.version.release
   adb -s <device> shell grep MemTotal /proc/meminfo
   ```
7. The two numbers the design asks about: `layout_ms.focused_end_to_end` (compare max, then p95, against 1,000 ms) and `scroll_frames_ms.total_span.p95` (compare against 16 ms). Also read `whole_tree_end_to_end` for the stress variant and `frames_over_16ms`. Paste the whole result block into this README under a new heading with the phone model.

Without a cable: `flutter build apk --profile`, then `adb -s <device> install -r build/app/outputs/flutter-apk/app-profile.apk`, open "tree_spike" and tap **Run benchmark**. The result is on screen; `adb -s <device> logcat -s flutter` shows `BENCH_RESULT`.

To run it with no taps: add `--dart-define=AUTORUN_BENCH=true` to `flutter run`. The app prints the result and exits.

## Build record

`flutter build apk --profile` succeeded: `build/app/outputs/flutter-apk/app-profile.apk`, 64.6 MB (build output, not committed). It was not installed or run on any device. `flutter devices` also lists an Android "Smart TV" (android-arm, API 30) over adb; it is not a phone, was not named for this spike, and was not used.

## What was not tested

- Any phone. Any Android device or emulator. iOS.
- Frame timing while scrolling or panning the diagram view (only the chain list was scrolled).
- Frame timing at system text scale 2.0 (layout and wrapping are tested at 2.0 by unit and widget tests; frames are not timed).
- Frames dropped on the main thread while the isolate is laying out (layout time and frame time were measured in separate phases).
- The wrap estimate against Roboto and other Android fonts.
- Layout from a real database. The dataset is in memory and generated at start-up (about 5 ms in a `flutter test` run on this host).
- Memory use, thermal throttling, low-memory behaviour, battery state.
- Placeholders, empty houses and disputed links in the tree.

## Interpretation notes

- Because the diagram draws only the focused house plus one generation each way, its layout cost does not grow with the dataset. The spike's real risks are the chain list (3,000 rows with wrapping text) and the copy of data into the isolate. The whole-tree variant is the literal reading of "3,000 nodes".
- Host numbers cannot be scaled to a phone by a factor. Do not use them to predict a pass or a fail.

Weak-phone result: awaiting phone.
