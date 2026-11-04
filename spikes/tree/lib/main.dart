// Spike 4: tree at scale. Throwaway.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'bench.dart';
import 'chain.dart';
import 'diagram_view.dart';
import 'gen.dart';
import 'layout.dart';

/// `--dart-define=AUTORUN_BENCH=true` runs the benchmark at start-up, prints
/// the result and exits. Used for the host run.
const bool kAutorun = bool.fromEnvironment('AUTORUN_BENCH');

/// With AUTORUN_BENCH, also write the result to this file name inside the
/// system temp directory (desktop only; a sandboxed macOS app gets its own).
const String kBenchOut = String.fromEnvironment('BENCH_OUT');

void main() => runApp(const TreeSpikeApp());

class TreeSpikeApp extends StatelessWidget {
  const TreeSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tree spike',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.data});

  /// Injectable for tests; defaults to the 3,000-person dataset.
  final Dataset? data;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late final Dataset data = widget.data ?? generate();
  final ScrollController _chain = ScrollController();
  bool _diagram = false;
  int _focusHouse = 0;
  bool _running = false;
  String? _result;
  String? _layoutKey;
  Future<LayoutResult>? _layoutFuture;

  @override
  void initState() {
    super.initState();
    _focusHouse = pickBenchHouse(data).clamp(0, data.houses.length - 1);
    if (kAutorun) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _runBenchmark();
        debugPrint('BENCH_DONE');
        exit(0);
      });
    }
  }

  @override
  void dispose() {
    _chain.dispose();
    super.dispose();
  }

  Future<LayoutResult> _layoutFor(double scale) {
    final key = '$_focusHouse@$scale';
    if (key != _layoutKey) {
      _layoutKey = key;
      _layoutFuture =
          layoutFocusedInIsolate(data, _focusHouse, textScale: scale);
    }
    return _layoutFuture!;
  }

  int _houseFor(int personId) {
    final hs = data.husbandHouses[personId];
    if (hs.isNotEmpty) return hs.first;
    final fh = data.people[personId].fatherHouse;
    if (fh != null) return fh;
    return data.wifeHouses[personId].first;
  }

  Future<void> _runBenchmark() async {
    if (_running) return;
    setState(() {
      _running = true;
      _diagram = false;
      _result = null;
    });
    await WidgetsBinding.instance.endOfFrame;

    // 1. Layout off the main thread.
    final layout = await runLayoutBench(data);

    // 2. Frame timings over the fixed scripted scroll of the 3,000-row chain.
    final recorder = FrameRecorder()..start();
    await runScriptedScroll(_chain, this);
    final frames = await recorder.stop();

    // 3. Does the wrap estimate agree with the real font?
    final focused = layoutFocusedHouse(data, pickBenchHouse(data));
    final whole = layoutWholeTree(data);
    final json = resultJson(
      layout: layout,
      frames: frames,
      ratioFocused1: estimatorRatio(focused, 1.0),
      ratioWhole1: estimatorRatio(whole, 1.0),
      ratioWhole2: estimatorRatio(whole, 2.0),
    );
    final text = humanSummary(json);
    // One line per run so a log grep finds it.
    debugPrint('BENCH_RESULT $text');
    if (kBenchOut.isNotEmpty) {
      File('${Directory.systemTemp.path}/$kBenchOut').writeAsStringSync(text);
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Scaffold(
      appBar: AppBar(title: const Text('Tree spike: 3,000 people')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Chain')),
                    ButtonSegment(value: true, label: Text('Diagram')),
                  ],
                  selected: {_diagram},
                  onSelectionChanged: (s) =>
                      setState(() => _diagram = s.first),
                ),
                FilledButton(
                  onPressed: _running ? null : _runBenchmark,
                  child: Text(_running ? 'Running...' : 'Run benchmark'),
                ),
              ],
            ),
          ),
          if (_result != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SelectableText(_result!,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 11)),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: _diagram
                ? FutureBuilder<LayoutResult>(
                    future: _layoutFor(scale),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: Text('Laying out...'));
                      }
                      return DiagramView(layout: snap.data!);
                    },
                  )
                : ChainList(
                    data: data,
                    controller: _chain,
                    onSelect: (id) => setState(() {
                      _focusHouse = _houseFor(id);
                      _diagram = true;
                    }),
                  ),
          ),
        ],
      ),
    );
  }
}
