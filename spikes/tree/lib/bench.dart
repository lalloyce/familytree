// Benchmark code for spike 4. The same code runs from the in-app button and
// from the AUTORUN_BENCH dart-define, so the host run and the phone run use
// one path.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'gen.dart';
import 'layout.dart';

/// Nearest-rank percentile of an ascending-sorted list.
double percentile(List<double> sorted, double p) {
  if (sorted.isEmpty) return double.nan;
  final rank = (p / 100 * sorted.length).ceil().clamp(1, sorted.length);
  return sorted[rank - 1];
}

class Stats {
  Stats(this.n, this.min, this.median, this.p95, this.max);

  factory Stats.of(List<double> values) {
    final s = [...values]..sort();
    return Stats(s.length, s.first, percentile(s, 50), percentile(s, 95),
        s.last);
  }

  final int n;
  final double min, median, p95, max;

  Map<String, Object> toJson() => {
        'n': n,
        'min': _r(min),
        'median': _r(median),
        'p95': _r(p95),
        'max': _r(max),
      };

  @override
  String toString() => 'n=$n min=${_r(min)} median=${_r(median)} '
      'p95=${_r(p95)} max=${_r(max)}';
}

double _r(double v) => (v * 1000).round() / 1000;

class LayoutBench {
  LayoutBench({
    required this.focusedEndToEnd,
    required this.focusedCompute,
    required this.wholeEndToEnd,
    required this.wholeCompute,
    required this.focusedNodes,
    required this.wholeNodes,
    required this.focusedFirstMs,
    required this.wholeFirstMs,
  });

  final Stats focusedEndToEnd; // ms, spawn + copy-in + compute + copy-out
  final Stats focusedCompute; // ms, inside the isolate only
  final Stats wholeEndToEnd;
  final Stats wholeCompute;
  final int focusedNodes;
  final int wholeNodes;
  final double focusedFirstMs; // first run, end to end
  final double wholeFirstMs;
}

/// The house with the most children whose husband and wife both have a
/// recorded father house. Deterministic.
int pickBenchHouse(Dataset d) {
  var best = -1;
  var bestKids = -1;
  for (final h in d.houses) {
    if (d.people[h.husbandId].fatherHouse == null ||
        d.people[h.wifeId].fatherHouse == null) {
      continue;
    }
    if (h.childIds.length > bestKids) {
      best = h.id;
      bestKids = h.childIds.length;
    }
  }
  return best;
}

Future<LayoutBench> runLayoutBench(Dataset d,
    {int runs = 40, double textScale = 1.0}) async {
  final house = pickBenchHouse(d);
  final fe = <double>[], fc = <double>[], we = <double>[], wc = <double>[];
  var fn = 0, wn = 0;
  final sw = Stopwatch();
  for (var i = 0; i < runs; i++) {
    sw.reset();
    sw.start();
    final r = await layoutFocusedInIsolate(d, house, textScale: textScale);
    sw.stop();
    fe.add(sw.elapsedMicroseconds / 1000);
    fc.add(r.computeMicros / 1000);
    fn = r.nodes.length;
  }
  for (var i = 0; i < runs; i++) {
    sw.reset();
    sw.start();
    final r = await layoutWholeTreeInIsolate(d, textScale: textScale);
    sw.stop();
    we.add(sw.elapsedMicroseconds / 1000);
    wc.add(r.computeMicros / 1000);
    wn = r.nodes.length;
  }
  return LayoutBench(
    focusedEndToEnd: Stats.of(fe),
    focusedCompute: Stats.of(fc),
    wholeEndToEnd: Stats.of(we),
    wholeCompute: Stats.of(wc),
    focusedNodes: fn,
    wholeNodes: wn,
    focusedFirstMs: fe.first,
    wholeFirstMs: we.first,
  );
}

class FrameStats {
  FrameStats(this.frames, this.total, this.build, this.raster, this.over16);

  final int frames;
  final Stats total; // ms, vsync start to raster finish
  final Stats build; // ms, UI thread
  final Stats raster; // ms, raster thread
  final int over16; // frames with total span over 16 ms
}

class FrameRecorder {
  final List<FrameTiming> _timings = [];

  void _onTimings(List<FrameTiming> t) => _timings.addAll(t);

  void start() => SchedulerBinding.instance.addTimingsCallback(_onTimings);

  /// Stops recording. [skip] drops the first frames (shader and image warm-up).
  Future<FrameStats?> stop({int skip = 30}) async {
    // Timings are delivered in batches; give the last batch time to arrive.
    await Future<void>.delayed(const Duration(seconds: 1));
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    final t = _timings.length > skip + 1 ? _timings.sublist(skip) : _timings;
    if (t.isEmpty) return null;
    double ms(Duration d) => d.inMicroseconds / 1000;
    final total = t.map((f) => ms(f.totalSpan)).toList();
    return FrameStats(
      t.length,
      Stats.of(total),
      Stats.of(t.map((f) => ms(f.buildDuration)).toList()),
      Stats.of(t.map((f) => ms(f.rasterDuration)).toList()),
      total.where((v) => v > 16).length,
    );
  }
}

/// The fixed scroll script: down at 2,400 dp/s for 8 s, down at 6,000 dp/s for
/// 4 s, then up at 3,000 dp/s for 4 s. Positions come from elapsed time, one
/// jumpTo per frame, so every device runs the same path.
const List<(double seconds, double velocity)> kScrollScript = [
  (8, 2400),
  (4, 6000),
  (4, -3000),
];

Future<void> runScriptedScroll(ScrollController c, TickerProvider vsync) {
  final done = Completer<void>();
  final total = kScrollScript.fold<double>(0, (a, s) => a + s.$1);
  c.jumpTo(0);
  late final Ticker ticker;
  ticker = vsync.createTicker((elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    var pos = 0.0;
    var left = t;
    for (final (secs, v) in kScrollScript) {
      final used = min(left, secs);
      pos += v * used;
      left -= used;
      if (left <= 0) break;
    }
    c.jumpTo(pos.clamp(0.0, c.position.maxScrollExtent));
    if (t >= total) {
      ticker.stop();
      if (!done.isCompleted) done.complete();
    }
  });
  ticker.start();
  return done.future.whenComplete(ticker.dispose);
}

/// Max over nodes of (real text height / estimated height) at [textScale],
/// using the platform default font. Above 1.0 means the estimate is optimistic
/// for that font.
double estimatorRatio(LayoutResult r, double textScale) {
  var worst = 0.0;
  const inner = kNodeWidth - 2 * kNodePad;
  for (final n in r.nodes) {
    double real(String s, double fs) {
      final tp = TextPainter(
        text: TextSpan(
            text: s, style: TextStyle(fontSize: fs, height: kLineHeight)),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.linear(textScale),
      )..layout(maxWidth: inner);
      return tp.height;
    }

    final realH =
        2 * kNodePad + real(n.name, kNameFont) + real(n.caption, kCaptionFont);
    final est = estimateNodeHeight(n.name, n.caption, textScale);
    worst = max(worst, realH / est);
  }
  return worst;
}

String buildModeName() => kReleaseMode
    ? 'release'
    : (kProfileMode ? 'profile' : (kDebugMode ? 'debug' : 'unknown'));

bool get isPhoneOs => Platform.isAndroid || Platform.isIOS;

/// The label every number carries when it did not come from a phone.
String get provenanceLabel => isPhoneOs
    ? 'device run (record the device model by hand)'
    : 'host proxy, NOT a weak-phone result';

String environmentLine() {
  final v = ui.PlatformDispatcher.instance.views.first;
  final logical = v.physicalSize / v.devicePixelRatio;
  return 'os=${Platform.operatingSystem} ${Platform.operatingSystemVersion} '
      'cores=${Platform.numberOfProcessors} mode=${buildModeName()} '
      'viewport=${logical.width.round()}x${logical.height.round()}dp '
      'dpr=${v.devicePixelRatio}';
}

Map<String, Object?> resultJson({
  required LayoutBench layout,
  required FrameStats? frames,
  required double ratioFocused1,
  required double ratioWhole1,
  required double ratioWhole2,
}) =>
    {
      'provenance': provenanceLabel,
      'environment': environmentLine(),
      'layout_ms': {
        'focused_end_to_end': layout.focusedEndToEnd.toJson(),
        'focused_end_to_end_first_run': _r(layout.focusedFirstMs),
        'focused_compute_in_isolate': layout.focusedCompute.toJson(),
        'focused_nodes': layout.focusedNodes,
        'whole_tree_end_to_end': layout.wholeEndToEnd.toJson(),
        'whole_tree_end_to_end_first_run': _r(layout.wholeFirstMs),
        'whole_tree_compute_in_isolate': layout.wholeCompute.toJson(),
        'whole_tree_nodes': layout.wholeNodes,
      },
      'scroll_frames_ms': frames == null
          ? null
          : {
              'frames': frames.frames,
              'total_span': frames.total.toJson(),
              'build': frames.build.toJson(),
              'raster': frames.raster.toJson(),
              'frames_over_16ms': frames.over16,
            },
      'estimator_real_over_estimated_max': {
        'focused_scale_1': _r(ratioFocused1),
        'whole_tree_scale_1': _r(ratioWhole1),
        'whole_tree_scale_2': _r(ratioWhole2),
      },
    };

String humanSummary(Map<String, Object?> j) {
  final enc = const JsonEncoder.withIndent('  ');
  return '${j['provenance']}\n${enc.convert(j)}';
}
