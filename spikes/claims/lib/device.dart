/// One phone in spike 2: an in-memory Drift database, an outbox, and the
/// push and pull client. Throwaway.
///
/// The device holds its own unsent rows (status pending) and what the server
/// sent. It applies no contest or merge rules itself; statuses come from the
/// server.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'model.dart';

/// Drift database with no generated code, as in spike 1.
class DeviceDb extends GeneratedDatabase {
  DeviceDb(super.executor);

  factory DeviceDb.memory() => DeviceDb(NativeDatabase.memory());

  static const ddl = [
    '''create table row (
         id text primary key, kind text not null, subject_id text not null,
         object_id text, body text, asserted_by text not null, basis text,
         base_claim_id text, device_id text not null,
         device_time integer not null, status text not null,
         seq integer, version integer)''',
    'create index row_kind on row (kind, status)',
    // Local only. ord keeps the order the user made the writes in.
    '''create table outbox (
         ord integer primary key autoincrement,
         row_id text not null unique, attempts integer not null default 0)''',
    'create table sync_state (key text primary key, value text not null)',
  ];

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      for (final s in ddl) {
        await customStatement(s);
      }
    },
  );
}

ClaimRow _fromQuery(QueryRow q) {
  final d = q.data;
  return ClaimRow(
    id: d['id'] as String,
    kind: RowKind.values.byName(d['kind'] as String),
    subjectId: d['subject_id'] as String,
    objectId: d['object_id'] as String?,
    body: d['body'] as String?,
    assertedBy: d['asserted_by'] as String,
    basis: d['basis'] as String?,
    baseClaimId: d['base_claim_id'] as String?,
    deviceId: d['device_id'] as String,
    deviceTime: d['device_time'] as int,
    status: d['status'] as String,
    seq: d['seq'] as int?,
    version: d['version'] as int?,
  );
}

const _upsert = '''
  insert into row (id, kind, subject_id, object_id, body, asserted_by, basis,
    base_claim_id, device_id, device_time, status, seq, version)
  values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  on conflict (id) do update set
    kind = excluded.kind, subject_id = excluded.subject_id,
    object_id = excluded.object_id, body = excluded.body,
    asserted_by = excluded.asserted_by, basis = excluded.basis,
    base_claim_id = excluded.base_claim_id, device_id = excluded.device_id,
    device_time = excluded.device_time, status = excluded.status,
    seq = excluded.seq, version = excluded.version''';

List<Object?> _args(ClaimRow r) => [
  r.id,
  r.kind.name,
  r.subjectId,
  r.objectId,
  r.body,
  r.assertedBy,
  r.basis,
  r.baseClaimId,
  r.deviceId,
  r.deviceTime,
  r.status,
  r.seq,
  r.version,
];

class Device {
  Device({
    required this.id,
    required this.accountId,
    required this.transport,
    required this.newId,
    required this.clock,
    this.blockingQueue = false,
  });

  final String id;
  final String accountId;
  final SyncTransport transport;
  final String Function() newId;
  final int Function() clock;

  /// Negative control: a strict in-order queue that stops at the first
  /// failing push, the behaviour design edge case 13 warns about.
  final bool blockingQueue;

  final db = DeviceDb.memory();

  /// Rows the server sent whose fixed fields differ from this device's copy.
  final List<String> contentMismatches = [];

  /// A row is retried alone, ahead of newer rows, once it has failed this
  /// many times with a server error.
  static const suspectAfter = 2;
  static const batchSize = 20;

  // ---------------------------------------------------------------- writes

  ClaimRow draft(
    RowKind kind,
    String subjectId, {
    String? objectId,
    String? body,
    String? basis,
    String? baseClaimId,
    String? rowId,
  }) => ClaimRow(
    id: rowId ?? newId(),
    kind: kind,
    subjectId: subjectId,
    objectId: objectId,
    body: body,
    assertedBy: accountId,
    basis: basis,
    baseClaimId: baseClaimId,
    deviceId: id,
    deviceTime: clock(),
  );

  /// Store a new row locally and queue it. Works offline.
  Future<ClaimRow> write(ClaimRow r) async {
    await db.transaction(() async {
      await db.customStatement(_upsert, _args(r));
      await db.customStatement('insert into outbox (row_id) values (?)', [
        r.id,
      ]);
    });
    return r;
  }

  // ---------------------------------------------------------------- reads

  Future<List<ClaimRow>> _select(
    String where, [
    List<Object?> args = const [],
  ]) async {
    final q = await db
        .customSelect(
          'select * from row where $where',
          variables: [for (final a in args) Variable(a)],
        )
        .get();
    return q.map(_fromQuery).toList();
  }

  Future<List<ClaimRow>> allRows() => _select('1 = 1 order by id');

  /// Person ids the viewer would pick from: not currently merged away.
  Future<List<String>> canonicalPersons() async {
    final q = await db.customSelect('''
      select id from row where kind = 'person' and id not in (
        select m.object_id from row m where m.kind = 'merge'
          and m.status = 'effective' and m.id not in (
            select u.subject_id from row u
            where u.kind = 'unmerge' and u.status = 'effective'))
      order by id''').get();
    return [for (final r in q) r.data['id'] as String];
  }

  /// Persons something is aliased to; a merge into them as b would conflict.
  Future<Set<String>> mergeTargets() async {
    final q = await db.customSelect('''
      select m.subject_id as id from row m where m.kind = 'merge'
        and m.status = 'effective' and m.id not in (
          select u.subject_id from row u
          where u.kind = 'unmerge' and u.status = 'effective')''').get();
    return {for (final r in q) r.data['id'] as String};
  }

  /// Claims standing on a contest key as this device sees them: confirmed
  /// active claims plus its own unsent ones.
  Future<List<ClaimRow>> standingClaims(RowKind kind, String keyId) => _select(
    "kind = ? and ${kind == RowKind.belongsToHouse ? 'subject_id' : 'object_id'} = ? "
    "and status in ('active', 'pending') order by coalesce(seq, 1 << 40), id",
    [kind.name, keyId],
  );

  Future<List<ClaimRow>> undoableMerges() => _select('''
    kind = 'merge' and status = 'effective' and id not in (
      select subject_id from row where kind = 'unmerge'
      and status in ('effective', 'pending')) order by seq''');

  Future<List<String>> outboxIds() async {
    final q = await db
        .customSelect('select row_id from outbox order by ord')
        .get();
    return [for (final r in q) r.data['row_id'] as String];
  }

  // ---------------------------------------------------------------- sync

  Future<void> sync() async {
    await push();
    await pull();
  }

  Future<List<ClaimRow>> _queued(String where, int limit) async {
    final q = await db
        .customSelect(
          'select r.* from outbox o join row r on r.id = o.row_id '
          'where $where order by o.ord limit $limit',
        )
        .get();
    return q.map(_fromQuery).toList();
  }

  Future<void> _bump(List<ClaimRow> rows) async {
    for (final r in rows) {
      await db.customStatement(
        'update outbox set attempts = attempts + 1 where row_id = ?',
        [r.id],
      );
    }
  }

  Future<void> _settle(PushResult res) async {
    await db.transaction(() async {
      for (final item in res.items) {
        if (item.outcome == Outcome.failed) {
          await db.customStatement(
            'update outbox set attempts = attempts + 1 where row_id = ?',
            [item.id],
          );
        } else {
          await db.customStatement('delete from outbox where row_id = ?', [
            item.id,
          ]);
        }
      }
    });
  }

  /// Returns false when the connection is gone and the round should stop.
  Future<bool> _send(List<ClaimRow> batch) async {
    try {
      await _settle(await transport.push(batch));
      return true;
    } on NetworkError {
      return false; // not the rows' fault; no attempt counted
    } on ServerError {
      await _bump(batch);
      return true;
    }
  }

  /// Push the outbox.
  ///
  /// Rows that keep failing with a server error ("suspects") are sent one at
  /// a time, oldest first, before anything newer. A suspect that still fails
  /// stays queued and newer rows go past it. Only a genuinely stuck row is
  /// ever overtaken; every other row keeps the order it was written in.
  Future<void> push() async {
    if (blockingQueue) return _pushBlocking();
    for (final s in await _queued('o.attempts >= $suspectAfter', 1 << 30)) {
      if (!await _send([s])) return;
    }
    for (var i = 0; i < 50; i++) {
      final batch = await _queued('o.attempts < $suspectAfter', batchSize);
      if (batch.isEmpty) return;
      try {
        await _settle(await transport.push(batch));
      } on NetworkError {
        return;
      } on ServerError {
        await _bump(batch);
        return;
      }
    }
  }

  Future<void> _pushBlocking() async {
    for (var i = 0; i < 50; i++) {
      final batch = await _queued('1 = 1', batchSize);
      if (batch.isEmpty) return;
      try {
        await _settle(await transport.push(batch));
      } on NetworkError {
        return;
      } on ServerError {
        return; // head of line stays stuck
      }
    }
  }

  Future<String?> _cursor() async {
    final q = await db
        .customSelect("select value from sync_state where key = 'cursor'")
        .getSingleOrNull();
    return q?.data['value'] as String?;
  }

  /// Pull pages until the server has no more. Each page and its cursor are
  /// stored in one transaction, so a dropped response or a crash resumes
  /// from the last stored page.
  Future<void> pull() async {
    for (var page = 0; page < 10000; page++) {
      final PullResult p;
      try {
        p = await transport.pull(await _cursor());
      } on NetworkError {
        return;
      }
      await db.transaction(() async {
        for (final r in p.rows) {
          final mine = await _select('id = ?', [r.id]);
          if (mine.isNotEmpty && mine.single.content != r.content) {
            contentMismatches.add(
              '$id holds ${mine.single.content}, server sent ${r.content}',
            );
          }
          await db.customStatement(_upsert, _args(r));
        }
        await db.customStatement(
          "insert into sync_state (key, value) values ('cursor', ?) "
          'on conflict (key) do update set value = excluded.value',
          [p.nextCursor],
        );
      });
      if (!p.hasMore) return;
    }
  }

  Future<void> close() => db.close();
}
