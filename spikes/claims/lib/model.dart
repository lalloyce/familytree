/// Shared types for spike 2: the synced row, the transport interface, the
/// contest key and the view a person would see. Throwaway.
library;

import 'dart:collection';
import 'dart:convert';

/// Every synced write in the spike is one append-only row. Contested facts
/// (belongsToHouse, wifeOfHouse) are claims in the design's sense. Person
/// creation, name edits, merges and undos travel through the same pipe so
/// that the spike measures one sync path, not five.
enum RowKind { person, belongsToHouse, wifeOfHouse, nameEdit, merge, unmerge }

/// Row status. Only the server sets anything other than [pending].
abstract final class Status {
  static const pending = 'pending'; // on the device, not yet confirmed
  static const active = 'active'; // a claim that stands
  static const superseded = 'superseded'; // replaced by its own asserter
  static const applied = 'applied'; // person, nameEdit
  static const effective = 'effective'; // merge or unmerge that took effect
  static const conflicted = 'conflicted'; // merge or unmerge that could not
}

/// One synced row.
///
/// Field use by kind:
/// - person: subjectId = person id (equals id), body = first name.
/// - belongsToHouse: subjectId = person, objectId = house, basis bornTo|joined.
/// - wifeOfHouse: subjectId = woman, objectId = house, basis married.
/// - nameEdit: subjectId = person, body = new name.
/// - merge: subjectId = person kept (a), objectId = person merged away (b).
/// - unmerge: subjectId = the merge row it reverses (reverses_event_id).
///
/// [deviceTime] is the device clock at creation, for display only. Nothing
/// orders by it. [seq] (arrival order) and [version] (change counter used by
/// the pull cursor) are assigned by the server.
class ClaimRow {
  const ClaimRow({
    required this.id,
    required this.kind,
    required this.subjectId,
    this.objectId,
    this.body,
    required this.assertedBy,
    this.basis,
    this.baseClaimId,
    required this.deviceId,
    required this.deviceTime,
    this.status = Status.pending,
    this.seq,
    this.version,
  });

  final String id;
  final RowKind kind;
  final String subjectId;
  final String? objectId;
  final String? body;
  final String assertedBy;
  final String? basis;
  final String? baseClaimId;
  final String deviceId;
  final int deviceTime;
  final String status;
  final int? seq;
  final int? version;

  bool get isClaim =>
      kind == RowKind.belongsToHouse || kind == RowKind.wifeOfHouse;

  ClaimRow withServer({required String status, int? seq, int? version}) =>
      ClaimRow(
        id: id,
        kind: kind,
        subjectId: subjectId,
        objectId: objectId,
        body: body,
        assertedBy: assertedBy,
        basis: basis,
        baseClaimId: baseClaimId,
        deviceId: deviceId,
        deviceTime: deviceTime,
        status: status,
        seq: seq ?? this.seq,
        version: version ?? this.version,
      );

  /// Only used by the deliberately broken server that rewrites references.
  ClaimRow withSubject(String s) => ClaimRow(
    id: id,
    kind: kind,
    subjectId: s,
    objectId: objectId,
    body: body,
    assertedBy: assertedBy,
    basis: basis,
    baseClaimId: baseClaimId,
    deviceId: deviceId,
    deviceTime: deviceTime,
    status: status,
    seq: seq,
    version: version,
  );

  ClaimRow withDeviceTime(int t) => ClaimRow(
    id: id,
    kind: kind,
    subjectId: subjectId,
    objectId: objectId,
    body: body,
    assertedBy: assertedBy,
    basis: basis,
    baseClaimId: baseClaimId,
    deviceId: deviceId,
    deviceTime: t,
    status: status,
    seq: seq,
    version: version,
  );

  /// The fields that must never change once written.
  String get content => jsonEncode([
    id,
    kind.name,
    subjectId,
    objectId,
    body,
    assertedBy,
    basis,
    baseClaimId,
    deviceId,
    deviceTime,
  ]);

  @override
  String toString() => 'ClaimRow($content, $status, seq=$seq, v=$version)';
}

enum Outcome { accepted, duplicate, failed }

class ItemResult {
  const ItemResult(this.id, this.outcome, {this.reason});
  final String id;
  final Outcome outcome;
  final String? reason;
}

/// Per-item results, in the order the items were sent.
class PushResult {
  const PushResult(this.items);
  final List<ItemResult> items;
}

/// One page of rows changed since the cursor, each in its current state.
class PullResult {
  const PullResult(this.rows, this.nextCursor, this.hasMore);
  final List<ClaimRow> rows;
  final String nextCursor; // opaque to the device; persisted after applying
  final bool hasMore;
}

/// The connection dropped. The request may or may not have been applied.
class NetworkError implements Exception {
  NetworkError(this.message);
  final String message;
  @override
  String toString() => 'NetworkError: $message';
}

/// The server answered with an error for the whole request.
class ServerError implements Exception {
  ServerError(this.message);
  final String message;
  @override
  String toString() => 'ServerError: $message';
}

/// The interface the app's sync module would code against. A PowerSync
/// adapter would implement the same two calls.
abstract interface class SyncTransport {
  /// Idempotent by row id. Throws [NetworkError] or [ServerError].
  Future<PushResult> push(List<ClaimRow> rows);

  /// Rows changed after [cursor] (null = from the start). Throws [NetworkError].
  Future<PullResult> pull(String? cursor);
}

/// Contest key (plan Task 8): belongsToHouse by subject, wifeOfHouse by house.
String? contestKey(ClaimRow r) => switch (r.kind) {
  RowKind.belongsToHouse => 'b:${r.subjectId}',
  RowKind.wifeOfHouse => 'w:${r.objectId}',
  _ => null,
};

/// The view a viewer would see, rendered as a canonical string so two views
/// compare by equality. Built only from confirmed rows (seq != null). Uses
/// arrival order (seq) and never [ClaimRow.deviceTime].
String renderView(Iterable<ClaimRow> all) {
  final rows = all.where((r) => r.seq != null).toList()
    ..sort((a, b) => a.seq!.compareTo(b.seq!));

  // Aliases: effective merges not reversed by an effective unmerge.
  final reversed = {
    for (final r in rows)
      if (r.kind == RowKind.unmerge && r.status == Status.effective)
        r.subjectId,
  };
  final alias = <String, String>{}; // b -> a
  for (final r in rows) {
    if (r.kind == RowKind.merge &&
        r.status == Status.effective &&
        !reversed.contains(r.id)) {
      alias[r.objectId!] = r.subjectId;
    }
  }
  String canon(String p) => alias[p] ?? p;

  // Names: last write wins by arrival order; history keeps every write.
  final name = <String, String>{};
  final history = <String, int>{};
  for (final r in rows) {
    if (r.kind == RowKind.person || r.kind == RowKind.nameEdit) {
      name[r.subjectId] = r.body!;
      history[r.subjectId] = (history[r.subjectId] ?? 0) + 1;
    }
  }

  final people = SplayTreeMap<String, Map<String, Object?>>();
  for (final r in rows) {
    if (r.kind == RowKind.person && canon(r.id) == r.id) {
      people[r.id] = {
        'name': name[r.id],
        'edits': history[r.id],
        'aliases': <List<Object?>>[],
        'belongsTo': <List<Object?>>[],
        'wifeOf': <List<Object?>>[],
      };
    }
  }
  final houses = SplayTreeMap<String, List<List<Object?>>>();
  for (final r in rows) {
    if (r.kind == RowKind.person && canon(r.id) != r.id) {
      (people[canon(r.id)]?['aliases'] as List?)?.add([r.id, name[r.id]]);
    }
    if (!r.isClaim || r.status != Status.active) continue;
    final who = canon(r.subjectId);
    final entry = [r.id, r.objectId, r.assertedBy, r.basis];
    final p = people[who] ??= {
      // A claim about a person row the viewer does not hold.
      'name': null,
      'edits': 0,
      'aliases': <List<Object?>>[],
      'belongsTo': <List<Object?>>[],
      'wifeOf': <List<Object?>>[],
    };
    if (r.kind == RowKind.belongsToHouse) {
      (p['belongsTo'] as List).add(entry);
    } else {
      (p['wifeOf'] as List).add(entry);
      (houses[r.objectId!] ??= []).add([r.id, who, r.assertedBy]);
    }
  }
  int cmp(List<Object?> a, List<Object?> b) =>
      (a[0] as String).compareTo(b[0] as String);
  for (final p in people.values) {
    for (final k in ['aliases', 'belongsTo', 'wifeOf']) {
      (p[k] as List<List<Object?>>).sort(cmp);
    }
    p['accountsDiffer'] = (p['belongsTo'] as List).length > 1;
  }
  final houseView = {
    for (final e in houses.entries)
      e.key: {
        'wives': e.value..sort(cmp),
        'accountsDiffer': e.value.length > 1,
      },
  };
  return const JsonEncoder.withIndent(' ')
      .convert({'people': people, 'houses': houseView});
}

/// First differing line of two rendered views, for failure messages.
String firstDiff(String a, String b) {
  final la = a.split('\n'), lb = b.split('\n');
  for (var i = 0; i < la.length || i < lb.length; i++) {
    final x = i < la.length ? la[i] : '<end>';
    final y = i < lb.length ? lb[i] : '<end>';
    if (x != y) return 'line $i: "$x" vs "$y"';
  }
  return 'identical';
}
