// Spike 1: leak and revocation.
//
// Question: can a viewer who lacks a quiet claim learn that it exists?
//
// Run from spikes/leak with the private cluster up:
//   ./pg.sh start && dart test leak_test.dart -r expanded; ./pg.sh stop
// Run the main assertions against a canary instead of the real server:
//   LEAK_CANARY=canary_pull dart test leak_test.dart -r expanded
//
// Every check below is a function that returns a list of failures. The real
// tests expect that list to be empty. The canary tests run the same functions
// against deliberately leaky servers and expect the list to be non-empty, so a
// check that cannot fail would show up as a failing canary test.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:leak_spike/harness.dart';
import 'package:postgres/postgres.dart' show ServerException;
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Fixed identities. Everything except the quiet claim and its sire is the same
// UUID in both worlds.

const accR = '0000000a-0000-4000-8000-000000000001'; // recorder
const accX = '0000000a-0000-4000-8000-000000000002'; // in the quiet audience
const accB = '0000000a-0000-4000-8000-000000000003'; // the viewer under test
const accP = '0000000a-0000-4000-8000-000000000004'; // turns on the hide setting
const perR = '0000000b-0000-4000-8000-000000000001';
const perX = '0000000b-0000-4000-8000-000000000002';
const perB = '0000000b-0000-4000-8000-000000000003';
const perP = '0000000b-0000-4000-8000-000000000004';

final winyo = deriveId(accR, 'person-winyo');
final manyi = deriveId(accR, 'person-manyi');
final sire = deriveId(accR, 'person-sire'); // world A only
final quietClaim = deriveId(accR, 'claim-quiet-sire'); // world A only
final origin = deriveId(accR, 'person-origin');
final bChild = deriveId(accB, 'person-b-child');

// Ids that exist in no world. Fixed so both worlds send identical bytes.
const randomClaim = '5d0c6f1e-93a4-4b7e-a1c2-7e9f0b3d4a61';
const randomPerson = 'c2e8a7d4-1f36-4c59-8b0e-6a4d2f91e37b';

const quietStrings = ['QUIET-SIRE-BODY', 'QUIET-SIRE-NAME'];

/// Canary files to load on top of the real server for the main, hide and
/// revocation groups. Empty means the real server.
final envCanaries = {
  for (final c in (Platform.environment['LEAK_CANARY'] ?? '').split(','))
    if (c.trim().isNotEmpty) c.trim(),
};

// ---------------------------------------------------------------------------
// Write helpers. Client-side ids are derived from (account, nonce).

String at(int minute) => DateTime.utc(2026, 1, 1, 0, minute).toIso8601String();

Map<String, Object?> personOp(String acc, String nonce, String name) => {
  'op': 'person',
  'id': deriveId(acc, nonce),
  'nonce': nonce,
  'name_key': name,
  'is_placeholder': false,
};

Map<String, Object?> claimOp(
  String acc,
  String nonce, {
  required String kind,
  required String subject,
  String? object,
  String? body,
  String? basis,
  String? base,
  String scope = 'family',
  List<String>? audience,
  required int minute,
  String? forcedId,
}) => {
  'op': 'claim',
  'id': forcedId ?? deriveId(acc, nonce),
  'nonce': nonce,
  'kind': kind,
  'subject_id': subject,
  'object_id': object,
  'body': body,
  'basis': basis,
  'base_claim_id': base,
  'scope': scope,
  'created_at': at(minute),
  'audience': ?audience,
};

const ok = 'RESULT {"ok": true}';

Future<void> mustOk(Viewer v, Map<String, Object?> op) async {
  final r = await v.submit(op);
  if (r != ok) throw StateError('legitimate write refused: $op -> $r');
}

Future<void> seedAll(Server s) async {
  await s.seedAccount(accR, perR, 'Juma');
  await s.seedAccount(accX, perX, 'Wade');
  await s.seedAccount(accB, perB, 'Olembo');
  await s.seedAccount(accP, perP, 'Owala');
}

/// The ordinary family every world shares: R records Winyo and Manyi, then
/// each account asserts its own person as a child of Winyo. All family scope.
/// (A writer may only name persons it can see, and an account's own person is
/// visible to others only once a visible claim names it.)
List<Future<void> Function()> familySteps(Viewer r, Viewer x, Viewer b, Viewer p) => [
  () => mustOk(r, personOp(accR, 'person-winyo', 'Winyo')),
  () => mustOk(r, personOp(accR, 'person-manyi', 'Manyi')),
  for (final (i, (v, acc, n, child)) in [
    (r, accR, 'c-manyi', manyi), (r, accR, 'c-r', perR), (x, accX, 'c-x', perX),
    (b, accB, 'c-b', perB), (p, accP, 'c-p', perP),
  ].indexed)
    () => mustOk(v, claimOp(acc, 'claim-$n',
        kind: 'child_of', subject: child, object: winyo, basis: 'born to', minute: i)),
];

/// Forged writes as B against a target claim id and a target person id.
/// [tag] makes each probe's own nonce distinct.
Map<String, Map<String, Object?>> probeOps(String tag, String claimT, String personT) => {
  // Change the audience of the target claim.
  'share': {'op': 'share', 'claim_id': claimT, 'audience': [accB]},
  // A new claim based on the target claim.
  'base': claimOp(accB, 'probe-base-$tag',
      kind: 'child_of', subject: perB, object: winyo, basis: 'born to',
      base: claimT, minute: 40),
  // A new claim that reuses the target claim's id.
  'same_claim_id': claimOp(accB, 'probe-id-$tag',
      kind: 'child_of', subject: perB, object: winyo, basis: 'born to',
      minute: 41, forcedId: claimT),
  // A new claim naming the target person as object.
  'object_person': claimOp(accB, 'probe-obj-$tag',
      kind: 'child_of', subject: perB, object: personT, basis: 'born to', minute: 42),
  // A new claim naming the target person as subject.
  'subject_person': claimOp(accB, 'probe-subj-$tag',
      kind: 'child_of', subject: personT, object: winyo, basis: 'born to', minute: 43),
  // A new person that reuses the target person's id.
  'same_person_id': {
    'op': 'person', 'id': personT, 'nonce': 'probe-person-$tag',
    'name_key': 'Probe', 'is_placeholder': false,
  },
};

Map<String, dynamic> j(String s) => jsonDecode(s) as Map<String, dynamic>;

// ---------------------------------------------------------------------------
// Main scenario (brief step 2).

class MainObs {
  final payloads = <String>[]; // every payload B received, in order
  late Uint8List wire; // server-to-B bytes after the handshake
  late Map<String, List<String>> device; // B's Drift tables
  late Uint8List deviceImage; // B's Drift database file image
  final probes = <String, String>{}; // forged-write responses
  late Map<String, int> counts; // row counts from every endpoint
  late Map<String, List<String>> tableRows; // rows visible from every table, sorted
  late Map<String, List<String>> tableRowsNatural; // same, server's natural order
  late String xFull; // X's full payload (non-vacuity)
  late String crossPull; // B asking pull_view for X's view
  List<String> stats = const []; // catalog statistics as seen by B
}

Future<MainObs> runMain({
  required bool withQuiet,
  Set<String> canaries = const {},
  bool statsProbe = false,
}) async {
  final server = await Server.build(canaries: canaries);
  try {
    await seedAll(server);
    final r = await server.viewer(accR);
    final x = await server.viewer(accX);
    final b = await server.viewer(accB, recordWire: true);
    final bSide = await server.viewer(accB); // unrecorded, for A-only probes
    final p = await server.viewer(accP);
    final device = DeviceDb.memory();
    final o = MainObs();
    var cursor = '0';

    Future<void> bPull() async {
      final p = await b.pull(cursor);
      o.payloads.add(p);
      await device.apply(p);
      cursor = j(p)['cursor'] as String;
    }

    final steps = <(bool, Future<void> Function())>[
      for (final s in familySteps(r, x, b, p)) (false, s),
      // The quiet claim and the person only it references. World A only.
      (true, () => mustOk(r, personOp(accR, 'person-sire', 'QUIET-SIRE-NAME'))),
      (true, () => mustOk(r, claimOp(accR, 'claim-quiet-sire',
          kind: 'sire', subject: manyi, object: sire, body: 'QUIET-SIRE-BODY',
          scope: 'audience', audience: [accX], minute: 10))),
      // A quiet note B is entitled to, so B's payload exercises the audience path.
      (false, () => mustOk(r, personOp(accR, 'person-origin', 'SHARED-ORIGIN-NAME'))),
      (false, () => mustOk(r, claimOp(accR, 'claim-shared-origin',
          kind: 'origin_note', subject: perB, object: origin, body: 'SHARED-ORIGIN-BODY',
          scope: 'audience', audience: [accX, accB], minute: 11))),
      // Another writer, with a visible base claim.
      (false, () => mustOk(x, claimOp(accX, 'claim-x-manyi',
          kind: 'child_of', subject: manyi, object: winyo, basis: 'born to',
          base: deriveId(accR, 'claim-c-manyi'), minute: 12))),
      // B's own legitimate writes.
      (false, () => mustOk(b, personOp(accB, 'person-b-child', 'Akinyi'))),
      (false, () => mustOk(b, claimOp(accB, 'claim-b-child',
          kind: 'child_of', subject: bChild, object: perB, basis: 'born to', minute: 13))),
    ];

    // B pulls once before anything and once after every step. In world B the
    // quiet steps are skipped but B still pulls at that point.
    await bPull();
    for (final (quietOnly, run) in steps) {
      if (!quietOnly || withQuiet) await run();
      await bPull();
    }

    o.xFull = await x.pull('0');
    o.payloads.add(await b.pull('0'));

    // Forged writes aimed at the quiet claim's id and the sire's id. In world
    // B those ids exist nowhere. In world A the same probes are also aimed at
    // ids that exist nowhere, on a separate unrecorded session.
    for (final e in probeOps('q', quietClaim, sire).entries) {
      o.probes['quiet:${e.key}'] = await b.submit(e.value);
    }
    if (withQuiet) {
      for (final e in probeOps('r', randomClaim, randomPerson).entries) {
        o.probes['random:${e.key}'] = await bSide.submit(e.value);
      }
    }

    // B names X as the viewer. Unrecorded session, compared separately.
    try {
      final res = await bSide.conn.execute(
        r'select pull_view($1::uuid, $2)::text',
        parameters: [accX, '0'],
      );
      o.crossPull = 'RESULT ${res.first.first}';
    } on ServerException catch (e) {
      o.crossPull = 'ERROR ${renderServerException(e)}';
    }

    // State after the probes: a refused probe must leave nothing behind.
    await bPull();
    o.payloads.add(await b.pull('0'));

    final full = j(await b.pull('0'));
    final delta = j(await b.pull(cursor));
    o.counts = {
      for (final e in (await b.tableCounts()).entries) 'table:${e.key}': e.value,
      'pull_full:claims': (full['claims'] as List).length,
      'pull_full:removed_claims': (full['removed_claims'] as List).length,
      'pull_full:persons': (full['persons'] as List).length,
      'pull_delta:claims': (delta['claims'] as List).length,
      'pull_delta:removed_claims': (delta['removed_claims'] as List).length,
      'pull_delta:persons': (delta['persons'] as List).length,
    };
    o.tableRows = await b.tableRows();
    o.tableRowsNatural = await b.tableRows(natural: true);
    o.device = await device.dump();
    o.deviceImage = await device.fileImage();
    await device.close();
    o.wire = b.wire!.bytesAfterHandshake();

    if (statsProbe) {
      // Writers disconnect so their statistics are flushed, then B reads the
      // catalog statistics a plain SQL role can always read.
      await r.close();
      await x.close();
      await p.close();
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      final s = await bSide.raw(
        "select relname, n_tup_ins, n_live_tup from pg_stat_user_tables "
        "where schemaname = 'spike' order by relname",
      );
      o.stats = [for (final row in s) row.join(' ')];
    }
    return o;
  } finally {
    await server.close();
  }
}

// The checks. Each returns failures; empty means it holds.

List<String> checkPayloads(MainObs a, MainObs b) {
  final f = <String>[];
  if (a.payloads.length != b.payloads.length) {
    f.add('pull count ${a.payloads.length} vs ${b.payloads.length}');
  }
  for (var i = 0; i < a.payloads.length && i < b.payloads.length; i++) {
    final x = utf8.encode(a.payloads[i]), y = utf8.encode(b.payloads[i]);
    if (!_bytesEqual(x, y)) f.add('pull #$i bytes differ:\n  A ${a.payloads[i]}\n  B ${b.payloads[i]}');
  }
  return f;
}

List<String> checkWire(MainObs a, MainObs b) => _bytesEqual(a.wire, b.wire)
    ? []
    : ['wire bytes differ: A ${a.wire.length} bytes, B ${b.wire.length} bytes'];

List<String> checkDevice(MainObs a, MainObs b) {
  final f = <String>[];
  for (final t in {...a.device.keys, ...b.device.keys}) {
    final x = a.device[t], y = b.device[t];
    if (x == null || y == null || x.length != y.length) {
      f.add('device table $t: ${x?.length} vs ${y?.length} rows');
      continue;
    }
    for (var i = 0; i < x.length; i++) {
      if (x[i] != y[i]) f.add('device table $t row $i:\n  A ${x[i]}\n  B ${y[i]}');
    }
  }
  return f;
}

List<String> checkDeviceImage(MainObs a, MainObs b) =>
    _bytesEqual(a.deviceImage, b.deviceImage)
        ? []
        : ['device file image differs: A ${a.deviceImage.length} B ${b.deviceImage.length} bytes'];

/// Direct search for the quiet claim's text and ids in everything B holds.
List<String> checkNoQuietTrace(MainObs a) {
  final f = <String>[];
  final needles = [...quietStrings, quietClaim, sire];
  final sources = <String, List<int>>{
    'payloads': utf8.encode(a.payloads.join('\n')),
    'wire': a.wire,
    'device image': a.deviceImage,
    'device tables': utf8.encode(jsonEncode(a.device)),
    'table rows': utf8.encode(jsonEncode(a.tableRows)),
  };
  for (final s in sources.entries) {
    for (final n in needles) {
      if (containsBytes(s.value, utf8.encode(n))) f.add('$n found in ${s.key}');
    }
  }
  return f;
}

List<String> checkProbes(MainObs a, MainObs b) {
  final f = <String>[];
  for (final k in probeOps('q', quietClaim, sire).keys) {
    final aq = a.probes['quiet:$k'], ar = a.probes['random:$k'], bq = b.probes['quiet:$k'];
    if (aq != ar) f.add('$k: quiet id vs random id in world A:\n  $aq\n  $ar');
    if (aq != bq) f.add('$k: quiet id in world A vs world B:\n  $aq\n  $bq');
  }
  return f;
}

List<String> checkCounts(MainObs a, MainObs b) => [
  for (final k in {...a.counts.keys, ...b.counts.keys})
    if (a.counts[k] != b.counts[k]) '$k: ${a.counts[k]} vs ${b.counts[k]}',
];

List<String> checkTableRows(MainObs a, MainObs b) => [
  for (final t in Viewer.tables)
    if (jsonEncode(a.tableRows[t]) != jsonEncode(b.tableRows[t]))
      '$t rows differ:\n  A ${a.tableRows[t]}\n  B ${b.tableRows[t]}',
];

/// Same rows, in the order the server returned them with no ORDER BY.
List<String> checkTableRowsNatural(MainObs a, MainObs b) => [
  for (final t in Viewer.tables)
    if (jsonEncode(a.tableRowsNatural[t]) != jsonEncode(b.tableRowsNatural[t]))
      '$t natural-order rows differ:\n  A ${a.tableRowsNatural[t]}\n  B ${b.tableRowsNatural[t]}',
];

bool _bytesEqual(List<int> x, List<int> y) {
  if (x.length != y.length) return false;
  for (var i = 0; i < x.length; i++) {
    if (x[i] != y[i]) return false;
  }
  return true;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  if (envCanaries.isNotEmpty) {
    print('NOTE: main, hide and revocation groups run against canary $envCanaries');
  }

  group('main: viewer B, world A (quiet claim to X) vs world B (none)', () {
    late MainObs a, b;
    setUpAll(() async {
      a = await runMain(withQuiet: true, canaries: envCanaries, statsProbe: true);
      b = await runMain(withQuiet: false, canaries: envCanaries, statsProbe: true);
    });

    test('non-vacuity: X receives the quiet claim and its sire in A only', () {
      expect(a.xFull, contains(quietClaim));
      expect(a.xFull, contains('QUIET-SIRE-NAME'));
      expect(b.xFull, isNot(contains(quietClaim)));
    });

    test('pull payload bytes identical, every pull', () {
      print('pulls compared: ${a.payloads.length} vs ${b.payloads.length}');
      expect(checkPayloads(a, b), isEmpty);
    });

    test('pull_view refuses a viewer id other than the session viewer', () {
      print('B pulling as X: ${a.crossPull}');
      expect(a.crossPull, startsWith('ERROR '));
      expect(a.crossPull, isNot(contains(quietClaim)));
      expect(a.crossPull, b.crossPull);
    });

    test('server-to-B wire bytes identical after the handshake', () {
      expect(checkWire(a, b), isEmpty);
    });

    test('B device: Drift table contents identical', () {
      expect(checkDevice(a, b), isEmpty);
    });

    test('B device: Drift file image identical', () {
      expect(checkDeviceImage(a, b), isEmpty);
    });

    test('no quiet text or id anywhere B can see in world A', () {
      expect(checkNoQuietTrace(a), isEmpty);
    });

    test('forged writes: quiet id == random id == missing id in world B', () {
      expect(checkProbes(a, b), isEmpty);
      // Not required, but shows what the response is.
      for (final v in a.probes.values) {
        expect(v, 'RESULT {"ok": false, "code": "rejected"}');
      }
    });

    test('row counts from every endpoint identical', () {
      expect(checkCounts(a, b), isEmpty);
    });

    test('rows visible from every table endpoint identical', () {
      expect(checkTableRows(a, b), isEmpty);
    });

    test('rows visible from every table endpoint identical in natural order (no ORDER BY)', () {
      expect(checkTableRowsNatural(a, b), isEmpty);
    });

    test('measurement (not an app endpoint): catalog statistics seen by a SQL role', () {
      print('pg_stat_user_tables as B, world A:\n  ${a.stats.join('\n  ')}');
      print('pg_stat_user_tables as B, world B:\n  ${b.stats.join('\n  ')}');
      print('catalog statistics differ: ${jsonEncode(a.stats) != jsonEncode(b.stats)}');
    });
  });

  group('canaries: the same checks must fail against a leaky server', () {
    test('canary_pull (pull adds persons named by hidden claims) is detected', () async {
      final a = await runMain(withQuiet: true, canaries: {'canary_pull'});
      final b = await runMain(withQuiet: false, canaries: {'canary_pull'});
      final found = {
        'payloads': checkPayloads(a, b),
        'wire': checkWire(a, b),
        'device': checkDevice(a, b),
        'device image': checkDeviceImage(a, b),
        'quiet trace': checkNoQuietTrace(a),
        'counts': checkCounts(a, b),
      };
      found.forEach((k, v) => print('canary_pull $k: ${v.length} failure(s)${v.isEmpty ? '' : '; first: ${v.first}'}'));
      print('canary_pull natural-order rows: ${checkTableRowsNatural(a, b).length} failure(s)');
      for (final e in found.entries) {
        expect(e.value, isNotEmpty, reason: '${e.key} check did not detect canary_pull');
      }
    });

    test('canary_write (distinguishing error for a missing claim) is detected', () async {
      final a = await runMain(withQuiet: true, canaries: {'canary_write'});
      final b = await runMain(withQuiet: false, canaries: {'canary_write'});
      final probes = checkProbes(a, b);
      final wire = checkWire(a, b);
      print('canary_write probes: ${probes.length} failure(s); first: ${probes.firstOrNull}');
      print('canary_write wire: ${wire.length} failure(s)');
      print('canary_write natural-order rows: ${checkTableRowsNatural(a, b).length} failure(s)');
      expect(probes, isNotEmpty);
      expect(wire, isNotEmpty);
    });

    test('canary_rls (person rule opened to everyone) is detected', () async {
      final a = await runMain(withQuiet: true, canaries: {'canary_rls'});
      final b = await runMain(withQuiet: false, canaries: {'canary_rls'});
      final counts = checkCounts(a, b);
      final rows = checkTableRows(a, b);
      final trace = checkNoQuietTrace(a);
      print('canary_rls counts: $counts');
      print('canary_rls table rows: ${rows.length} failure(s); quiet trace: $trace');
      print('canary_rls natural-order rows: ${checkTableRowsNatural(a, b).length} failure(s)');
      expect(counts, isNotEmpty);
      expect(rows, isNotEmpty);
      expect(trace, isNotEmpty);
    });
  });

  group('standing hide: P hides quiet details before any exist', () {
    // Payloads and counts at three points: before P turns the setting on (0),
    // after (1), and after R adds a quiet note about P shared to X (2).
    final bFull = <String>[], xFull = <String>[];
    final bDelta = <String>[], xDelta = <String>[];
    final bCounts = <Map<String, int>>[], xCounts = <Map<String, int>>[];
    final bRows = <String>[], xRows = <String>[];
    late String rAfter, xControl;
    final hiddenPerson = deriveId(accR, 'person-hidden');
    final hiddenNote = deriveId(accR, 'claim-hidden-note');
    final controlNote = deriveId(accR, 'claim-control-note');

    setUpAll(() async {
      final server = await Server.build(canaries: envCanaries);
      try {
        await seedAll(server);
        final r = await server.viewer(accR);
        final x = await server.viewer(accX);
        final b = await server.viewer(accB);
        final p = await server.viewer(accP);
        for (final s in familySteps(r, x, b, p)) {
          await s();
        }
        final bCur = j(await b.pull('0'))['cursor'] as String;
        final xCur = j(await x.pull('0'))['cursor'] as String;

        Future<void> snap() async {
          bFull.add(await b.pull('0'));
          xFull.add(await x.pull('0'));
          bDelta.add(await b.pull(bCur));
          xDelta.add(await x.pull(xCur));
          bCounts.add(await b.tableCounts());
          xCounts.add(await x.tableCounts());
          bRows.add(jsonEncode(await b.tableRows()));
          xRows.add(jsonEncode(await x.tableRows()));
        }

        await snap(); // 0
        await mustOk(p, {'op': 'privacy', 'hide_quiet_details': true});
        await snap(); // 1
        await mustOk(r, personOp(accR, 'person-hidden', 'HIDDEN-NOTE-PERSON'));
        await mustOk(r, claimOp(accR, 'claim-hidden-note',
            kind: 'joined_via', subject: perP, object: hiddenPerson,
            body: 'HIDDEN-NOTE-BODY', scope: 'audience', audience: [accX], minute: 20));
        await snap(); // 2

        rAfter = await r.pull('0');
        // Control: the same kind of note about R, who has no hide setting,
        // does reach X. So it is the setting that withheld the note about P.
        await mustOk(r, claimOp(accR, 'claim-control-note',
            kind: 'joined_via', subject: perR, body: 'CONTROL-NOTE-BODY',
            scope: 'audience', audience: [accX], minute: 21));
        xControl = await x.pull('0');
      } finally {
        await server.close();
      }
    });

    test('non-vacuity: R holds the note; an unhidden note does reach X', () {
      expect(rAfter, contains(hiddenNote));
      expect(xControl, contains(controlNote));
    });

    test('B: full payload bytes identical at all three points', () {
      expect(bFull[1], bFull[0]);
      expect(bFull[2], bFull[0]);
    });

    test('B: delta payload bytes identical after the setting and after the note', () {
      expect(bDelta[2], bDelta[1]);
      expect(bDelta[1], bDelta[0]);
    });

    test('B: row counts and visible rows from every table identical', () {
      expect(bCounts[1], bCounts[0]);
      expect(bCounts[2], bCounts[0]);
      expect(bRows[2], bRows[0]);
    });

    test('X (in the audience) also learns nothing: setting withholds the note', () {
      expect(xFull[1], xFull[0]);
      expect(xFull[2], xFull[0]);
      expect(xDelta[2], xDelta[0]);
      expect(xCounts[2], xCounts[0]);
      expect(xRows[2], xRows[0]);
      expect(xFull[2], isNot(contains('HIDDEN-NOTE')));
    });
  });

  group('revocation: B removed from an audience that included B', () {
    final revoked = deriveId(accR, 'claim-revoked');
    final revokedPerson = deriveId(accR, 'person-revoked');
    final markers = ['REVOKED-ORIGIN-BODY', 'REVOKED-ORIGIN-NAME'];
    late Map<String, List<String>> before, after, control;
    late Map<String, dynamic> delta;
    late String xAfter;
    final probes = <String, String>{};
    final fileTraces = <String, List<String>>{};
    final pragmas = <String, String>{};

    Future<List<String>> traces(File f) async {
      final found = <String>[];
      for (final suffix in ['', '-wal', '-journal']) {
        final g = File('${f.path}$suffix');
        if (!g.existsSync()) continue;
        final bytes = g.readAsBytesSync();
        for (final m in [...markers, revoked, revokedPerson]) {
          if (containsBytes(bytes, utf8.encode(m))) found.add('$m in ${g.uri.pathSegments.last}');
        }
      }
      return found;
    }

    setUpAll(() async {
      // Control world: the note was never made.
      var server = await Server.build(canaries: envCanaries);
      try {
        await seedAll(server);
        final r = await server.viewer(accR);
        final x = await server.viewer(accX);
        final b = await server.viewer(accB);
        final p = await server.viewer(accP);
        for (final s in familySteps(r, x, b, p)) {
          await s();
        }
        final dev = DeviceDb.memory();
        await dev.apply(await b.pull('0'));
        control = await dev.dump();
        await dev.close();
      } finally {
        await server.close();
      }

      server = await Server.build(canaries: envCanaries);
      final tmp = await Directory.systemTemp.createTemp('leak_spike_rev_');
      try {
        await seedAll(server);
        final r = await server.viewer(accR);
        final x = await server.viewer(accX);
        final b = await server.viewer(accB);
        final p = await server.viewer(accP);
        for (final s in familySteps(r, x, b, p)) {
          await s();
        }
        await mustOk(r, personOp(accR, 'person-revoked', 'REVOKED-ORIGIN-NAME'));
        await mustOk(r, claimOp(accR, 'claim-revoked',
            kind: 'origin_note', subject: manyi, object: revokedPerson,
            body: 'REVOKED-ORIGIN-BODY', scope: 'audience', audience: [accX, accB],
            minute: 30));

        final mem = DeviceDb.memory();
        final fileOff = File('${tmp.path}/default.db');
        final fileOn = File('${tmp.path}/secure.db');
        final devOff = DeviceDb.file(fileOff, secureDelete: false);
        final devOn = DeviceDb.file(fileOn, secureDelete: true);
        final first = await b.pull('0');
        for (final d in [mem, devOff, devOn]) {
          await d.apply(first);
        }
        before = await mem.dump();
        final cursor = j(first)['cursor'] as String;

        await mustOk(r, {'op': 'share', 'claim_id': revoked, 'audience': [accX]});

        final next = await b.pull(cursor);
        delta = j(next);
        for (final d in [mem, devOff, devOn]) {
          await d.apply(next);
        }
        after = await mem.dump();
        xAfter = await x.pull('0');

        // B knows the id from before. Forged writes against it must look the
        // same as against an id that never existed.
        for (final e in probeOps('rv', revoked, revokedPerson).entries) {
          probes['revoked:${e.key}'] = await b.submit(e.value);
        }
        for (final e in probeOps('rr', randomClaim, randomPerson).entries) {
          probes['random:${e.key}'] = await b.submit(e.value);
        }

        for (final (name, d) in [('default', devOff), ('secure_delete', devOn)]) {
          final jm = await d.customSelect('PRAGMA journal_mode').getSingle();
          final sd = await d.customSelect('PRAGMA secure_delete').getSingle();
          pragmas[name] = 'journal_mode=${jm.data.values.first} '
              'secure_delete=${sd.data.values.first}';
        }
        await mem.close();
        await devOff.close();
        await devOn.close();
        fileTraces['default'] = await traces(fileOff);
        fileTraces['secure_delete'] = await traces(fileOn);
      } finally {
        await server.close();
        tmp.deleteSync(recursive: true);
      }
    });

    test('non-vacuity: before revocation B holds the claim and its person', () {
      expect(jsonEncode(before), contains(revoked));
      expect(jsonEncode(before), contains('REVOKED-ORIGIN-NAME'));
    });

    test('next pull lists the claim id as removed and drops its person', () {
      expect(delta['removed_claims'], [revoked]);
      expect(delta['claims'], isEmpty);
      final ids = [for (final p in delta['persons'] as List) (p as Map)['id']];
      expect(ids, isNot(contains(revokedPerson)));
    });

    test('after applying, no table on B device holds any of the rows', () {
      final all = jsonEncode(after);
      for (final n in [...markers, revoked, revokedPerson]) {
        expect(all, isNot(contains(n)), reason: n);
      }
    });

    test('after applying, claim and person contents equal a never-shared world', () {
      // Normalised: SQLite rowid stripped (local storage slot, shifted because
      // B did once hold the row) and sync_state not compared (B's own cursor
      // moved twice for the grant and the revoke; B already knew both).
      List<String> strip(List<String> rows) => [
        for (final r in rows) jsonEncode((jsonDecode(r) as Map)..remove('_rowid_')),
      ]..sort();
      expect(strip(after['claim']!), strip(control['claim']!));
      expect(strip(after['person']!), strip(control['person']!));
    });

    test('X keeps the claim: revocation is per viewer', () {
      expect(xAfter, contains(revoked));
    });

    test('forged writes after revocation: revoked id == random id', () {
      for (final k in probeOps('x', '', '').keys) {
        expect(probes['revoked:$k'], probes['random:$k'], reason: k);
      }
    });

    test('device file with secure_delete ON keeps no bytes of the revoked rows', () {
      print('pragmas: $pragmas');
      expect(fileTraces['secure_delete'], isEmpty);
    });

    test('control: device file with the SQLite default keeps revoked bytes', () {
      // Non-vacuity for the secure_delete test above: the same steps without
      // secure_delete must leave traces, or that test proves nothing.
      print('pragmas: $pragmas');
      print('revoked bytes left in default file: ${fileTraces['default']}');
      expect(fileTraces['default'], isNotEmpty);
    });
  });
}
