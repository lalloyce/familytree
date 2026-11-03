/// The fake sync server for spike 2. Plain Dart, in memory. Throwaway.
///
/// Rules (design section 8, plan decisions C and D, plan Task 8):
/// - Pushes are idempotent by row id. A row seen before is acknowledged as a
///   duplicate and changes nothing.
/// - Arrival order is the only ordering authority. Each new row gets the next
///   [ClaimRow.seq]. Device clocks are never read.
/// - Claims: look at the active claims with the same contest key. If exactly
///   one exists, it was asserted by the same account, and the new claim names
///   it as base, it becomes superseded. In every other case the new claim is
///   inserted active next to the existing ones (a competing account).
/// - Late base (spike finding): if an active claim by the same asserter on the
///   same key already names the arriving claim as its base, the arriving
///   claim was replaced before it reached the server and is stored superseded.
/// - Names: every edit is kept; the current name is the last by arrival.
/// - Merge(a, b) aliases b to a when neither is an alias and nothing is
///   aliased to b. Otherwise it is stored as conflicted (a review task).
/// - Unmerge deletes the alias of an effective, unreversed merge and is
///   stored as a reversing event. No reference is rewritten.
/// - Pull returns rows by change version, so a status change is re-sent.
library;

import 'model.dart';

/// [correct] is the server under test. The others are deliberately broken
/// negative controls that the fuzz must fail against.
enum ServerMode {
  correct,

  /// A new claim on a contested key supersedes every active claim (last
  /// write wins on a contested fact).
  overwriteOnConflict,

  /// Batches longer than two rows: the second half is acknowledged as
  /// accepted but silently not stored.
  dropBatchTail,

  /// An effective merge rewrites the merged-away person's claims to the kept
  /// person, so undo cannot restore them.
  rewriteOnMerge,

  /// Not broken: the rule the controller ruled Task 8 will use. The same
  /// asserter naming their own active claim as base supersedes it even when
  /// other accounts' claims also stand on the key. [correct] is the Task 8
  /// text ("exactly one active"), kept as the compared baseline.
  supersedeOwnUnderContest,

  /// Broken, built on [supersedeOwnUnderContest]: a claim whose base is on
  /// the server but no longer active (a stale base) supersedes the
  /// asserter's current active claim on the key, which it never named.
  staleBaseSupersedesHead,
}

class FakeServer {
  FakeServer({this.mode = ServerMode.correct, this.pageSize = 50});

  final ServerMode mode;
  final int pageSize;

  final Map<String, ClaimRow> _rows = {};
  final List<String> _changeLog = []; // index i holds the row with version i+1
  final Map<String, String> _alias = {}; // b -> a
  final Map<String, String> _aliasEvent = {}; // b -> merge row id
  int _seq = 0;

  /// Rows whose push always fails with a server error while [poisonActive].
  final Set<String> poisonIds = {};
  bool poisonActive = true;

  // Counters for the report.
  int supersessions = 0;
  int lateBaseSupersessions = 0;
  int lateBaseViaInactive = 0; // the naming row was itself already superseded
  int staleBase = 0; // base is on the server but not active
  int ownReplaceKeptByContest = 0;
  int conflictedMerges = 0;
  int duplicateAcks = 0;
  int poisonFailures = 0;

  Iterable<ClaimRow> get rows => _rows.values;
  ClaimRow? operator [](String id) => _rows[id];

  PushResult push(List<ClaimRow> batch) {
    final out = <ItemResult>[];
    final keep = mode == ServerMode.dropBatchTail && batch.length > 2
        ? (batch.length + 1) ~/ 2
        : batch.length;
    for (var i = 0; i < batch.length; i++) {
      final row = batch[i];
      final seen = _rows[row.id];
      if (seen != null) {
        if (seen.content != row.content && mode != ServerMode.rewriteOnMerge) {
          // Same id, different content: a client bug. Never overwrite.
          out.add(ItemResult(row.id, Outcome.failed, reason: 'id conflict'));
        } else {
          duplicateAcks++;
          out.add(ItemResult(row.id, Outcome.duplicate));
        }
        continue;
      }
      if (poisonActive && poisonIds.contains(row.id)) {
        // Rows before this one in the batch are already stored, as when a
        // handler crashes part-way through a non-transactional batch.
        poisonFailures++;
        throw ServerError('internal error');
      }
      if (i >= keep) {
        out.add(ItemResult(row.id, Outcome.accepted)); // the lie
        continue;
      }
      _accept(row);
      out.add(ItemResult(row.id, Outcome.accepted));
    }
    return PushResult(out);
  }

  PullResult pull(String? cursor) {
    final from = cursor == null ? 0 : int.parse(cursor);
    final to = (from + pageSize).clamp(0, _changeLog.length);
    final page = <ClaimRow>[];
    for (var i = from; i < to; i++) {
      final r = _rows[_changeLog[i]]!;
      if (r.version == i + 1)
        page.add(r); // skip entries a later change replaced
    }
    return PullResult(page, '$to', to < _changeLog.length);
  }

  void _store(ClaimRow r) {
    _changeLog.add(r.id);
    _rows[r.id] = r.withServer(status: r.status, version: _changeLog.length);
  }

  void _setStatus(String id, String status) =>
      _store(_rows[id]!.withServer(status: status));

  void _accept(ClaimRow incoming) {
    final seq = ++_seq;
    switch (incoming.kind) {
      case RowKind.person:
      case RowKind.nameEdit:
        _store(incoming.withServer(status: Status.applied, seq: seq));
      case RowKind.belongsToHouse:
      case RowKind.wifeOfHouse:
        _acceptClaim(incoming, seq);
      case RowKind.merge:
        _acceptMerge(incoming, seq);
      case RowKind.unmerge:
        final m = _rows[incoming.subjectId];
        final ok =
            m != null &&
            m.kind == RowKind.merge &&
            m.status == Status.effective &&
            _aliasEvent[m.objectId] == m.id;
        if (ok) {
          _alias.remove(m.objectId);
          _aliasEvent.remove(m.objectId);
        }
        _store(
          incoming.withServer(
            status: ok ? Status.effective : Status.conflicted,
            seq: seq,
          ),
        );
    }
  }

  void _acceptClaim(ClaimRow c, int seq) {
    final key = contestKey(c);
    final active = _rows.values
        .where((r) => r.status == Status.active && contestKey(r) == key)
        .toList();
    if (mode == ServerMode.overwriteOnConflict) {
      for (final r in active) {
        _setStatus(r.id, Status.superseded);
      }
    } else if (active.length == 1 &&
        active.single.assertedBy == c.assertedBy &&
        c.baseClaimId == active.single.id) {
      _setStatus(active.single.id, Status.superseded);
      supersessions++;
    } else if (active.any(
      (r) => r.id == c.baseClaimId && r.assertedBy == c.assertedBy,
    )) {
      if (mode == ServerMode.supersedeOwnUnderContest ||
          mode == ServerMode.staleBaseSupersedesHead) {
        _setStatus(c.baseClaimId!, Status.superseded);
        supersessions++;
      } else {
        // The asserter replaced their own standing claim, but the key is
        // contested, so Task 8's "exactly one" rule keeps both active.
        ownReplaceKeptByContest++;
      }
    }
    final base = c.baseClaimId == null ? null : _rows[c.baseClaimId];
    if (base != null && base.status != Status.active) {
      // Stale base: the claim the asserter saw has moved on. It competes.
      staleBase++;
      if (mode == ServerMode.staleBaseSupersedesHead) {
        final own = active.where((r) => r.assertedBy == c.assertedBy).toList()
          ..sort((x, y) => x.seq!.compareTo(y.seq!));
        if (own.isNotEmpty) _setStatus(own.last.id, Status.superseded);
      }
    }
    // Late base: any row by the same asserter on the same key, whatever its
    // status, that already names this claim as base. Covers chains P<-Q<-R
    // where Q was itself superseded before P arrived.
    final namers = _rows.values
        .where(
          (r) =>
              r.isClaim &&
              contestKey(r) == key &&
              r.assertedBy == c.assertedBy &&
              r.baseClaimId == c.id,
        )
        .toList();
    final replacedAlready = namers.isNotEmpty;
    if (replacedAlready) {
      lateBaseSupersessions++;
      if (namers.every((r) => r.status != Status.active)) lateBaseViaInactive++;
    }
    _store(
      c.withServer(
        status: replacedAlready ? Status.superseded : Status.active,
        seq: seq,
      ),
    );
  }

  void _acceptMerge(ClaimRow m, int seq) {
    final a = m.subjectId, b = m.objectId!;
    final ok =
        a != b &&
        !_alias.containsKey(a) &&
        !_alias.containsKey(b) &&
        !_alias.containsValue(b);
    if (ok) {
      _alias[b] = a;
      _aliasEvent[b] = m.id;
      if (mode == ServerMode.rewriteOnMerge) {
        final moved = _rows.values
            .where((r) => r.isClaim && r.subjectId == b)
            .map((r) => r.id)
            .toList();
        for (final id in moved) {
          _store(_rows[id]!.withSubject(a));
        }
      }
    } else {
      conflictedMerges++;
    }
    _store(
      m.withServer(status: ok ? Status.effective : Status.conflicted, seq: seq),
    );
  }
}
