import '../claims/claim_service.dart';
import '../data/database.dart';

/// One ancestor on the father line, reached through [houseId].
class AncestorStep {
  const AncestorStep({
    required this.personId,
    required this.houseId,
    required this.depth,
    required this.disputed,
    this.basis,
  });

  /// The ancestor: the husband of [houseId].
  final String personId;

  /// The house through which this ancestor was reached. Empty for the
  /// starting person's own step (see [ancestorsOf]).
  final String houseId;

  /// 1 for the father, 2 for the grandfather, and so on. 0 only for the
  /// starting person's own step.
  final int depth;

  /// True when this person's own parentage cannot be followed as a single
  /// chain: accounts disagree about it, or the walk reached a person it had
  /// already visited. The list ends with this step.
  final bool disputed;

  /// The basis of the `belongsToHouse` claim by which the previous person in
  /// the chain (the child, or the starting person at depth 1) belongs to
  /// [houseId]. Null for the depth 0 sentinel.
  final Basis? basis;
}

/// The father line of [personId], from the father upward. Follows only
/// `belongsToHouse` claims (any basis) and then each house's `husbandId`;
/// wives are never followed.
///
/// Decision E: where a person's parentage is disputed or cyclic, the chain
/// stops at that person with `disputed: true`. A person with competing active
/// claims is disputed, and so is one the walk has already visited. Agreeing
/// claims are followed, taking the earliest to arrive. Stopping at [maxDepth]
/// steps sets no flag: a cap is not a dispute.
///
/// A house row that does not exist ends the walk silently, which is
/// indistinguishable from "no known father".
///
/// A starting person with competing claims returns one step for themselves,
/// with an empty `houseId` and depth 0. A starting person with no claim, or
/// who does not exist, returns an empty list.
///
/// The contest rule comes from [activeClaimViews]; it is not re-derived here.
/// `deletedAt` is ignored, because nothing sets it yet.
Future<List<AncestorStep>> ancestorsOf(
  AppDatabase db,
  String personId, {
  int maxDepth = 60,
}) async {
  final views = await activeClaimViews(db, ClaimKind.belongsToHouse);
  final byPerson = <String, List<ClaimView>>{};
  for (final v in views) {
    if (v.claim.objectId != null) {
      byPerson.putIfAbsent(v.claim.subjectId, () => []).add(v);
    }
  }
  final husbandOf = <String, String>{
    for (final h in await db.select(db.houses).get()) h.id: h.husbandId,
  };

  bool disputedPerson(String id) =>
      byPerson[id]?.any((v) => v.competing) ?? false;

  if (disputedPerson(personId)) {
    return [
      AncestorStep(personId: personId, houseId: '', depth: 0, disputed: true),
    ];
  }

  final steps = <AncestorStep>[];
  final visited = <String>{personId};
  String current = personId;
  while (steps.length < maxDepth) {
    // A non-competing person has one distinct (house, basis, subject)
    // content, so every candidate names the same house and "first by
    // arrival" cannot matter.
    final ClaimRow? claim = byPerson[current]?.first.claim;
    final String? houseId = claim?.objectId;
    final String? father = houseId == null ? null : husbandOf[houseId];
    if (houseId == null || father == null) {
      break;
    }
    final bool disputed = !visited.add(father) || disputedPerson(father);
    steps.add(
      AncestorStep(
        personId: father,
        houseId: houseId,
        depth: steps.length + 1,
        disputed: disputed,
        basis: claim!.basis,
      ),
    );
    if (disputed) {
      break;
    }
    current = father;
  }
  return steps;
}
