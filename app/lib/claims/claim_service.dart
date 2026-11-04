import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import 'claim_kinds.dart';

/// An active claim and whether other accounts disagree with it.
class ClaimView {
  const ClaimView({required this.claim, required this.competing});

  final ClaimRow claim;

  /// True when active claims on the same contest key hold more than one
  /// distinct content. Accounts that agree do not compete.
  final bool competing;
}

/// Active claims of [kind], oldest arrival first, with `competing` set.
///
/// `competing` is computed over every active claim on the same contest key.
/// [subjectId] and [objectId] only narrow the rows returned, never that
/// computation.
Future<List<ClaimView>> activeClaimViews(
  AppDatabase db,
  ClaimKind kind, {
  String? subjectId,
  String? objectId,
}) async {
  final List<ClaimRow> active = await _activeOfKind(db, kind);

  final contents = <String, Set<ClaimContent>>{};
  for (final c in active) {
    contents.putIfAbsent(contestKeyOfRow(c), () => {}).add(claimContent(c));
  }

  return [
    for (final c in active)
      if ((subjectId == null || c.subjectId == subjectId) &&
          (objectId == null || c.objectId == objectId))
        ClaimView(
          claim: c,
          competing: contents[contestKeyOfRow(c)]!.length > 1,
        ),
  ];
}

Future<List<ClaimRow>> _activeOfKind(AppDatabase db, ClaimKind kind) {
  return (db.select(db.claims)
        ..where(
          (c) => c.kind.equalsValue(kind) & c.status.equals(claimStatusActive),
        )
        ..orderBy([(c) => OrderingTerm.asc(c.localSeq)]))
      .get();
}

/// Writes claims for one account. Claims are append-only: a row is never
/// edited except for its `status`. Order is [ClaimRow.localSeq]; the device
/// clock is recorded in `createdAt` but never used to order or supersede.
class ClaimService {
  ClaimService(this._db, {required this.accountId, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final String accountId;
  final DateTime Function() _now;

  /// Records a claim by this account and returns the inserted row. Throws
  /// [ArgumentError] for a `wifeOfHouse` claim without [objectId].
  ///
  /// [baseClaimId] names the claim being replaced. It supersedes that claim
  /// only when the claim is active, of the same kind, asserted by this
  /// account, and on the same contest key or about the same subject (decision
  /// D). The subject rule lets an account move a wife from one house to
  /// another, although a `wifeOfHouse` claim contests by house. Any other base
  /// is stale: nothing is superseded and the new claim stands beside the
  /// existing ones.
  Future<ClaimRow> assertClaim({
    required ClaimKind kind,
    required String subjectId,
    String? objectId,
    Basis? basis,
    String? body,
    String? baseClaimId,
  }) async {
    final String key = contestKey(kind, subjectId, objectId);
    return _db.transaction(() async {
      if (baseClaimId != null) {
        for (final c in await _activeOfKind(_db, kind)) {
          if (c.id == baseClaimId &&
              c.assertedBy == accountId &&
              (contestKeyOfRow(c) == key || c.subjectId == subjectId)) {
            await (_db.update(
              _db.claims,
            )..where((t) => t.id.equals(c.id))).write(
              const ClaimsCompanion(status: Value(claimStatusSuperseded)),
            );
          }
        }
      }
      return _db
          .into(_db.claims)
          .insertReturning(
            ClaimsCompanion.insert(
              id: const Uuid().v4(),
              kind: kind,
              subjectId: subjectId,
              assertedBy: accountId,
              createdAt: _now(),
              objectId: Value(objectId),
              basis: Value(basis),
              body: Value(body),
              baseClaimId: Value(baseClaimId),
            ),
          );
    });
  }

  Future<List<ClaimView>> activeClaims(
    ClaimKind kind, {
    String? subjectId,
    String? objectId,
  }) => activeClaimViews(_db, kind, subjectId: subjectId, objectId: objectId);
}
