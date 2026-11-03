/// The seeded fuzz for spike 2: three devices, random offline periods,
/// random reconnect order, duplicate pushes, mid-push drops and one poison
/// row. Everything is drawn from one Random(seed), so a seed replays.
library;

import 'dart:math';

import 'device.dart';
import 'fake_network.dart';
import 'fake_server.dart';
import 'model.dart';

const a1 = 'A1 zero lost writes';
const a2 = 'A2 contested facts kept as competing accounts, never overwritten';
const a3 = 'A3 merge then undo returns the pre-merge view';
const a4 = 'A4 a failing push does not block later pushes';
const assertionNames = [a1, a2, a3, a4];

class FuzzConfig {
  const FuzzConfig({
    required this.seed,
    this.ops = 1000,
    this.mode = ServerMode.correct,
    this.blockingQueue = false,
  });
  final int seed;
  final int ops;
  final ServerMode mode;
  final bool blockingQueue;

  String get replay =>
      'dart run bin/fuzz.dart --seed $seed --ops $ops --mode ${mode.name}'
      '${blockingQueue ? ' --blocking' : ''}';
}

class FuzzResult {
  FuzzResult(this.config);
  final FuzzConfig config;
  final Map<String, List<String>> failures = {
    for (final a in assertionNames) a: [],
  };
  final Map<String, Object> stats = {};

  bool get passed => failures.values.every((f) => f.isEmpty);
  bool failed(String assertion) => failures[assertion]!.isNotEmpty;

  String summary() {
    final b = StringBuffer(
      'seed ${config.seed} mode=${config.mode.name}'
      '${config.blockingQueue ? ' blockingQueue' : ''}: '
      '${passed ? 'PASS' : 'FAIL'}\n',
    );
    for (final a in assertionNames) {
      final f = failures[a]!;
      b.writeln(
        '  ${f.isEmpty ? 'pass' : 'FAIL'}  $a'
        '${f.isEmpty ? '' : ' (${f.length} violations; first: ${f.first})'}',
      );
    }
    b.write('  stats: $stats');
    if (!passed) b.write('\n  REPLAY: ${config.replay}');
    return b.toString();
  }
}

Future<FuzzResult> runFuzz(FuzzConfig cfg) async {
  final watch = Stopwatch()..start();
  final res = FuzzResult(cfg);
  final rng = Random(cfg.seed);
  final server = FakeServer(mode: cfg.mode);

  String uuid() {
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}'
        '-${h.substring(16, 20)}-${h.substring(20)}';
  }

  // Device clocks disagree on purpose; d2's runs backwards. Display only.
  var tick = 0;
  final clocks = <int Function()>[
    () => 1700000000 + (tick++),
    () => 1700000000 + 259200 + (tick++),
    () => 1700000000 - (tick++),
  ];
  // d0 and d2 are two phones of the same person (account A); d1 is B.
  const accounts = ['acct-A', 'acct-B', 'acct-A'];
  final nets = [for (var i = 0; i < 3; i++) FakeNetwork(server, rng)];
  final devices = [
    for (var i = 0; i < 3; i++)
      Device(
        id: 'd$i',
        accountId: accounts[i],
        transport: nets[i],
        newId: uuid,
        clock: clocks[i],
        blockingQueue: cfg.blockingQueue,
      ),
  ];
  final houses = [for (var i = 0; i < 12; i++) 'house-$i'];
  final authored = <String, ClaimRow>{};
  final d0Order = <String>[]; // ids written on d0, in order
  T pick<T>(List<T> xs) => xs[rng.nextInt(xs.length)];
  String aName() =>
      pick(['Ochieng', 'Winyo', 'Manyi', 'Juma', 'Wade', 'Owala', 'Obuolo']) +
      pick(['', ' Jr', 'h', 'o']);

  Future<ClaimRow> write(Device d, ClaimRow r) async {
    authored[r.id] = r;
    if (d.id == 'd0') d0Order.add(r.id);
    return d.write(r);
  }

  final hist = <String, int>{};
  void count(String k) => hist[k] = (hist[k] ?? 0) + 1;
  String? poisonId;
  var d0Claims = 0;

  // Start: d0 records ten people; everyone syncs cleanly.
  for (var i = 0; i < 10; i++) {
    final id = uuid();
    await write(
      devices[0],
      devices[0].draft(RowKind.person, id, rowId: id, body: aName()),
    );
  }
  for (final n in nets) {
    n
      ..online = true
      ..faults = FaultRates.none;
  }
  for (final d in [...devices, ...devices]) {
    await d.sync();
  }
  for (final n in nets) {
    n
      ..online = rng.nextBool()
      ..faults = const FaultRates();
  }

  Future<void> assertClaim(Device d, List<String> persons) async {
    final kind = rng.nextDouble() < 0.6
        ? RowKind.belongsToHouse
        : RowKind.wifeOfHouse;
    final subject = pick(persons);
    final house = pick(houses);
    final standing = await d.standingClaims(
      kind,
      kind == RowKind.belongsToHouse ? subject : house,
    );
    final own = standing.where((r) => r.assertedBy == d.accountId).toList();
    final others = standing.where((r) => r.assertedBy != d.accountId).toList();
    final x = rng.nextDouble();
    final base = own.isNotEmpty && x < 0.5
        ? own
              .last
              .id // replacing my own current claim
        : others.isNotEmpty && x < 0.75
        ? pick(others)
              .id // replacing someone else's claim (decision D)
        : null;
    final row = d.draft(
      kind,
      subject,
      objectId: house,
      basis: kind == RowKind.belongsToHouse
          ? pick(['bornTo', 'joined'])
          : 'married',
      baseClaimId: base,
    );
    if (d.id == 'd0' && ++d0Claims == 5) {
      poisonId = row.id;
      server.poisonIds.add(row.id);
    }
    await write(d, row);
  }

  Future<void> operate(Device d) async {
    final persons = await d.canonicalPersons();
    final c = rng.nextDouble();
    if (persons.length < 2 || c < 0.15) {
      count('addPerson');
      final id = uuid();
      await write(d, d.draft(RowKind.person, id, rowId: id, body: aName()));
    } else if (c < 0.80) {
      if (c < 0.60) {
        count('assertClaim');
        await assertClaim(d, persons);
      } else {
        count('editName');
        await write(d, d.draft(RowKind.nameEdit, pick(persons), body: aName()));
      }
    } else if (c < 0.90) {
      count('merge');
      final a = pick(persons);
      final b = pick(persons.where((p) => p != a).toList());
      await write(d, d.draft(RowKind.merge, a, objectId: b));
    } else {
      final merges = await d.undoableMerges();
      if (merges.isEmpty) {
        count('undo (none visible, asserted a claim instead)');
        await assertClaim(d, persons);
      } else {
        count('undoMerge');
        await write(d, d.draft(RowKind.unmerge, pick(merges).id));
      }
    }
  }

  var opsDone = 0, syncs = 0, toggles = 0;
  while (opsDone < cfg.ops) {
    final r = rng.nextDouble();
    if (r < 0.06) {
      toggles++;
      final n = pick(nets);
      n.online = !n.online;
    } else if (r < 0.26) {
      final online = [
        for (var i = 0; i < 3; i++)
          if (nets[i].online) i,
      ];
      if (online.isNotEmpty) {
        syncs++;
        await devices[pick(online)].sync();
      }
    } else {
      opsDone++;
      await operate(pick(devices));
    }
  }

  final outboxes = <String, List<String>>{};
  Future<bool> outboxesHoldOnly(bool Function(String id) allowed) async {
    for (final d in devices) {
      outboxes[d.id] = await d.outboxIds();
    }
    return outboxes.values.every((o) => o.every(allowed));
  }

  /// Everyone online with no injected faults; sync rounds in random order
  /// until [done], then one pull each so every device sees the last pushes.
  Future<void> drain(Future<bool> Function() done) async {
    for (final n in nets) {
      n
        ..online = true
        ..faults = FaultRates.none;
    }
    for (var round = 0; round < 40; round++) {
      for (final d in [...devices]..shuffle(rng)) {
        await d.sync();
      }
      if (await done()) break;
    }
    for (final d in devices) {
      await d.pull();
    }
  }

  // Phase 1: the poison row still fails.
  await drain(() => outboxesHoldOnly((id) => id == poisonId));
  await outboxesHoldOnly((_) => true);

  // A4: the stuck row is the only row left; everything after it got through.
  final a4f = res.failures[a4]!;
  if (poisonId == null) {
    a4f.add('no poison row was created');
  } else {
    if (server[poisonId!] != null) a4f.add('poison row reached the server');
    final rest = outboxes['d0']!.where((id) => id != poisonId).toList();
    if (rest.isNotEmpty) {
      a4f.add('${rest.length} d0 rows still queued behind the poison row');
    }
    final after = d0Order.sublist(d0Order.indexOf(poisonId!) + 1);
    final missing = after.where((id) => server[id] == null).length;
    if (missing > 0) {
      a4f.add('$missing of ${after.length} later d0 rows not on the server');
    }
    res.stats['d0RowsAfterPoison'] = after.length;
  }

  // Phase 2: the server is fixed; everything drains.
  server.poisonActive = false;
  await drain(() => outboxesHoldOnly((_) => false));

  // Epilogue for A3: merge then undo with nothing in between, across devices.
  Future<void> syncAll() async {
    for (var i = 0; i < 2; i++) {
      for (final d in devices) {
        await d.sync();
      }
    }
  }

  final a3f = res.failures[a3]!;
  Future<ClaimRow?> mergeOn(Device d) async {
    final targets = await d.mergeTargets();
    final ps = await d.canonicalPersons();
    final bs = ps.where((p) => !targets.contains(p)).toList();
    if (bs.length < 2) return null;
    final b = pick(bs);
    final a = pick(ps.where((p) => p != b).toList());
    return write(d, d.draft(RowKind.merge, a, objectId: b));
  }

  Future<void> undoOn(Device d, ClaimRow m) async {
    final ms = await d.undoableMerges();
    if (!ms.any((x) => x.id == m.id)) {
      a3f.add('epilogue: ${d.id} cannot see merge ${m.id} as undoable');
      return;
    }
    await write(d, d.draft(RowKind.unmerge, m.id));
  }

  Future<List<String>> views() async => [
    renderView(server.rows),
    for (final d in devices) renderView(await d.allRows()),
  ];

  final before = await views();
  final m1 = await mergeOn(devices[1]);
  if (m1 == null) {
    a3f.add('epilogue: no two persons to merge');
  } else {
    await syncAll();
    if (server[m1.id]?.status != Status.effective) {
      a3f.add('epilogue merge was not effective');
    }
    final during = await views();
    if (during[0] == before[0]) a3f.add('epilogue merge changed nothing');
    await undoOn(devices[2], m1);
    await syncAll();
    final after = await views();
    for (var i = 0; i < after.length; i++) {
      if (after[i] != before[0]) {
        a3f.add(
          'epilogue: ${i == 0 ? 'server' : 'd${i - 1}'} view after undo '
          'differs from before merge: ${firstDiff(before[0], after[i])}',
        );
      }
    }
  }

  // Epilogue 2: claims and a name edit made while merged stay where they
  // were made; the result must equal the log with the merge pair removed.
  final m2 = await mergeOn(devices[0]);
  if (m2 != null) {
    await syncAll();
    final kept = m2.subjectId;
    await write(
      devices[1],
      devices[1].draft(
        RowKind.belongsToHouse,
        kept,
        objectId: pick(houses),
        basis: 'bornTo',
      ),
    );
    await write(
      devices[2],
      devices[2].draft(RowKind.nameEdit, kept, body: aName()),
    );
    await syncAll();
    await undoOn(devices[0], m2);
    await syncAll();
  }

  // ------------------------------------------------------------ A1
  final a1f = res.failures[a1]!;
  for (final r in authored.values) {
    if (server[r.id] == null) {
      a1f.add('lost ${r.kind.name} ${r.id} from ${r.deviceId}');
    }
  }
  final serverState = {
    for (final r in server.rows) r.id: '${r.content}|${r.status}|${r.seq}',
  };
  for (final d in devices) {
    final ob = await d.outboxIds();
    if (ob.isNotEmpty) a1f.add('${d.id} outbox still holds ${ob.length}');
    final mine = {
      for (final r in await d.allRows())
        r.id: '${r.content}|${r.status}|${r.seq}',
    };
    for (final e in serverState.entries) {
      if (mine[e.key] == null) {
        a1f.add('${d.id} is missing ${e.key}');
      } else if (mine[e.key] != e.value) {
        a1f.add('${d.id} differs on ${e.key}');
      }
    }
    for (final id in mine.keys) {
      if (!serverState.containsKey(id)) a1f.add('${d.id} has unsynced $id');
    }
  }

  // ------------------------------------------------------------ A2
  final a2f = res.failures[a2]!;
  for (final r in authored.values) {
    final s = server[r.id];
    if (s != null && s.content != r.content) {
      a2f.add('server rewrote ${r.kind.name} ${r.id}');
    }
  }
  for (final d in devices) {
    a2f.addAll(d.contentMismatches);
  }
  final claims = server.rows.where((r) => r.isClaim).toList();
  for (final x in claims.where((r) => r.status == Status.superseded)) {
    final ownReplacement = claims.any(
      (s) =>
          s.assertedBy == x.assertedBy &&
          s.baseClaimId == x.id &&
          contestKey(s) == contestKey(x),
    );
    if (!ownReplacement) {
      a2f.add(
        'claim ${x.id} by ${x.assertedBy} superseded without a replacement '
        'by the same asserter',
      );
    }
  }
  final byKey = <String, List<ClaimRow>>{};
  for (final c in claims) {
    (byKey[contestKey(c)!] ??= []).add(c);
  }
  var contested = 0, selfDiffer = 0;
  for (final e in byKey.entries) {
    final asserters = {for (final c in e.value) c.assertedBy};
    for (final who in asserters) {
      final standing = e.value.where(
        (c) => c.assertedBy == who && c.status == Status.active,
      );
      if (standing.isEmpty) {
        a2f.add('${e.key}: account of $who no longer stands');
      }
      if (standing.length > 1) selfDiffer++;
    }
    final activeBy = {
      for (final c in e.value)
        if (c.status == Status.active) c.assertedBy,
    };
    if (activeBy.length > 1) contested++;
  }
  final serverRows = server.rows.toList();
  if (renderView(serverRows) !=
      renderView(serverRows.map((r) => r.withDeviceTime(0)))) {
    a2f.add('the view depends on device clocks');
  }

  // ------------------------------------------------------------ A3
  // For every merge later undone, replaying the log without the pair must
  // give the same view. Pairs with another merge or undo touching the same
  // people in between are skipped: their outcome depended on the merged
  // state at arrival (they become review tasks).
  final byId = {for (final r in serverRows) r.id: r};
  final arrival = [...serverRows]..sort((x, y) => x.seq!.compareTo(y.seq!));
  String replayWithout(Set<String> drop) {
    final s = FakeServer(mode: cfg.mode)..poisonActive = false;
    for (final r in arrival) {
      if (!drop.contains(r.id)) s.push([authored[r.id] ?? r]);
    }
    return renderView(s.rows);
  }

  Set<String> people(ClaimRow r) => r.kind == RowKind.merge
      ? {r.subjectId, r.objectId!}
      : (byId[r.subjectId] == null ? {} : people(byId[r.subjectId]!));
  var pairs = 0, skipped = 0;
  final full = renderView(serverRows);
  if (replayWithout({}) != full) {
    a3f.add('replaying the whole log does not reproduce the server view');
  }
  for (final u in serverRows.where(
    (r) => r.kind == RowKind.unmerge && r.status == Status.effective,
  )) {
    final m = byId[u.subjectId]!;
    final ps = people(m);
    final interferes = serverRows.any(
      (r) =>
          (r.kind == RowKind.merge || r.kind == RowKind.unmerge) &&
          r.id != m.id &&
          r.id != u.id &&
          r.seq! > m.seq! &&
          r.seq! < u.seq! &&
          people(r).intersection(ps).isNotEmpty,
    );
    if (interferes) {
      skipped++;
      continue;
    }
    pairs++;
    // Counterfactual: a fresh server of the same kind receives every row in
    // the same arrival order, minus this merge and its undo.
    final without = replayWithout({m.id, u.id});
    if (without != full) {
      a3f.add(
        'merge ${m.id} plus undo left a trace: ${firstDiff(without, full)}',
      );
    }
  }

  for (final d in devices) {
    await d.close();
  }
  res.stats.addAll({
    'ops': hist,
    'rows': serverRows.length,
    'claims': claims.length,
    'superseded': server.supersessions,
    'lateBase': server.lateBaseSupersessions,
    'ownReplaceKeptByContest': server.ownReplaceKeptByContest,
    'contestedKeys': contested,
    'selfDifferKeys': selfDiffer,
    'conflictedMerges': server.conflictedMerges,
    'undoPairsChecked': pairs,
    'undoPairsSkipped': skipped,
    'syncs': syncs,
    'toggles': toggles,
    'midPushDrops': nets.fold<int>(0, (s, n) => s + n.midPushDrops),
    'duplicatePushes': nets.fold<int>(0, (s, n) => s + n.duplicatePushes),
    'pullDrops': nets.fold<int>(0, (s, n) => s + n.pullDrops),
    'duplicateAcks': server.duplicateAcks,
    'poisonFailures': server.poisonFailures,
    'ms': watch.elapsedMilliseconds,
  });
  return res;
}
