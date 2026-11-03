import '../claims/claim_service.dart';
import '../data/database.dart';

/// A house of the same husband as the focus person's own house, and the
/// people who belong to it.
class SiblingHouse {
  const SiblingHouse({
    required this.houseId,
    required this.ordinal,
    required this.personIds,
  });

  final String houseId;

  /// The house's number among its husband's houses, or null when not known.
  final int? ordinal;

  /// Who belongs to the house, in claim arrival order. Empty for a house with
  /// no known children.
  final List<String> personIds;
}

/// The people who share a person's house, and the husband's other houses.
class SiblingGroups {
  const SiblingGroups({required this.sameHouse, required this.otherHouses});

  static const SiblingGroups empty = SiblingGroups(
    sameHouse: [],
    otherHouses: [],
  );

  /// Everyone else who belongs to the person's own house, on any basis, in
  /// claim arrival order. Wives are never counted.
  final List<String> sameHouse;

  /// The other houses of the same husband, ordinal ascending with unknown
  /// ordinals last, including houses with no children.
  final List<SiblingHouse> otherHouses;
}

/// The siblings of [personId], grouped by house. Returns ids only.
///
/// The person's own house is the one in their earliest-arriving active
/// `belongsToHouse` claim; a person with none gets empty groups. Disputed
/// placement is not resolved here: the contest rule lives in
/// [activeClaimViews] and the arrival order is all this needs.
///
/// Houses have no arrival order, so [SiblingGroups.otherHouses] sorts by
/// ordinal (null last) and then by house id, which keeps the order stable.
/// A person with competing placements can appear in more than one group, and
/// the id-only return carries no dispute signal. The person is never listed
/// as their own sibling. `deletedAt` is ignored,
/// because nothing sets it yet.
Future<SiblingGroups> siblingsOf(AppDatabase db, String personId) async {
  final views = await activeClaimViews(db, ClaimKind.belongsToHouse);

  // People by house, each person once, in claim arrival order.
  final byHouse = <String, List<String>>{};
  String? ownHouseId;
  for (final v in views) {
    final String? houseId = v.claim.objectId;
    if (houseId == null) {
      continue;
    }
    if (v.claim.subjectId == personId) {
      ownHouseId ??= houseId;
      continue;
    }
    final List<String> members = byHouse.putIfAbsent(houseId, () => []);
    if (!members.contains(v.claim.subjectId)) {
      members.add(v.claim.subjectId);
    }
  }
  if (ownHouseId == null) {
    return SiblingGroups.empty;
  }

  final houses = await db.select(db.houses).get();
  final String? husbandId = [
    for (final h in houses)
      if (h.id == ownHouseId) h.husbandId,
  ].firstOrNull;
  final others = [
    for (final h in houses)
      if (husbandId != null && h.husbandId == husbandId && h.id != ownHouseId)
        h,
  ];
  others.sort((a, b) {
    final int? x = a.ordinal;
    final int? y = b.ordinal;
    if (x != y) {
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    }
    return a.id.compareTo(b.id);
  });

  return SiblingGroups(
    sameHouse: List.unmodifiable(byHouse[ownHouseId] ?? const <String>[]),
    otherHouses: [
      for (final h in others)
        SiblingHouse(
          houseId: h.id,
          ordinal: h.ordinal,
          personIds: List.unmodifiable(byHouse[h.id] ?? const <String>[]),
        ),
    ],
  );
}
