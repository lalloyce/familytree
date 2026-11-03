// Spike 5 app: open the encrypted database at start-up, then draw the first
// frame. On a first run it adds 3,000 synthetic people after the first frame,
// so later runs open a realistic database.
//
// With --dart-define=AUTORUN=true it writes one result line to
// <application support dir>/cold_start_result.txt after the first frame and
// exits. The line holds first_frame_epoch_us so a shell script can subtract
// its own launch time (see README).

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'cold_start.dart';
import 'database.dart';
import 'secure_key_store.dart';

const autorun = bool.fromEnvironment('AUTORUN');

Future<void> main() async {
  final sinceMain = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  final dbFile = File(p.join(dir.path, 'lineage.db'));

  final result = await coldStart(keys: SecureKeyStore(), dbFile: dbFile);
  final dbReadyMs = sinceMain.elapsedMicroseconds / 1000;

  SchedulerBinding.instance.addPostFrameCallback((_) async {
    // Runs after the first frame has been built and handed to the raster
    // thread, so it is slightly before the frame is on screen.
    final firstFrameMs = sinceMain.elapsedMicroseconds / 1000;
    final line =
        'COLD_START_RESULT state=${result.state.name} '
        'reason=${result.reason?.name ?? '-'} people=${result.peopleCount} '
        'key_read_ms=${(result.keyRead.inMicroseconds / 1000).toStringAsFixed(1)} '
        'cold_start_ms=${(result.total.inMicroseconds / 1000).toStringAsFixed(1)} '
        'main_to_db_ready_ms=${dbReadyMs.toStringAsFixed(1)} '
        'main_to_first_frame_ms=${firstFrameMs.toStringAsFixed(1)} '
        'process_to_first_frame_ms=${_processAgeMs() ?? '-'} '
        'first_frame_epoch_us=${DateTime.now().microsecondsSinceEpoch}';
    debugPrint(line);
    if (result.state != StartState.returning && result.peopleCount == 0) {
      await _seed(result.db);
    }
    if (autorun) {
      await File(p.join(dir.path, 'cold_start_result.txt'))
          .writeAsString('$line\n', mode: FileMode.append, flush: true);
      await result.db.close();
      exit(0);
    }
  });

  runApp(CryptoSpikeApp(result: result, dbReadyMs: dbReadyMs));
}

/// Linux and Android only: milliseconds since this process started, from
/// /proc/self/stat field 22 (start time in clock ticks after boot) and
/// /proc/uptime. Assumes 100 clock ticks per second (USER_HZ); not verified
/// on the phone, so the README procedure also records `am start -W`.
String? _processAgeMs() {
  try {
    final stat = File('/proc/self/stat').readAsStringSync();
    final fields = stat.substring(stat.lastIndexOf(')') + 2).split(' ');
    final startTicks = int.parse(fields[22 - 3]);
    final uptimeS = double.parse(
      File('/proc/uptime').readAsStringSync().split(' ').first,
    );
    return ((uptimeS - startTicks / 100) * 1000).toStringAsFixed(0);
  } catch (_) {
    return null;
  }
}

Future<void> _seed(SpikeDb db) => db.batch((b) {
  for (var i = 0; i < 3000; i++) {
    b.insert(
      db.people,
      PeopleCompanion.insert(
        id: 'person-$i',
        name: 'Person $i, child of house ${i ~/ 5}',
        note: Value('note for $i' * 3),
      ),
    );
  }
});

class CryptoSpikeApp extends StatelessWidget {
  const CryptoSpikeApp({
    super.key,
    required this.result,
    required this.dbReadyMs,
  });

  final StartResult result;
  final double dbReadyMs;

  @override
  Widget build(BuildContext context) {
    final message = switch (result.state) {
      StartState.firstRun =>
        'New install. A key was created and the '
            'database is encrypted.',
      StartState.returning =>
        'Database opened with the stored key. '
            '${result.peopleCount} people.',
      StartState.resyncNeeded =>
        'The saved data on this phone could not be '
            'opened. Sign in to download your family again. Anything that was '
            'not yet sent is lost.',
    };
    return MaterialApp(
      title: 'Spike 5',
      home: Scaffold(
        appBar: AppBar(title: const Text('Spike 5: encrypted start')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 12),
              Text(
                'State: ${result.state.name}'
                '${result.reason == null ? '' : ' (${result.reason!.name})'}',
              ),
              Text(
                'Database ready ${dbReadyMs.toStringAsFixed(1)} ms '
                'after main()',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
