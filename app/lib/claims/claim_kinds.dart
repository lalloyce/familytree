import '../data/database.dart';

/// The key under which claims of [kind] contest each other. Claims of one
/// kind that share a key cannot all be true, so they are compared together.
///
/// A person belongs to one house, so `belongsToHouse` contests by person. A
/// house has one wife per seat, so `wifeOfHouse` contests by house. Every
/// other kind contests per subject.
///
/// Throws [ArgumentError] for `wifeOfHouse` without a house. Every kind is
/// listed so that a new [ClaimKind] forces a decision here.
String contestKey(ClaimKind kind, String subjectId, String? objectId) {
  switch (kind) {
    case ClaimKind.belongsToHouse:
      return subjectId;
    case ClaimKind.wifeOfHouse:
      if (objectId == null) {
        throw ArgumentError.notNull('objectId');
      }
      return objectId;
    case ClaimKind.sire:
    case ClaimKind.joinedVia:
    case ClaimKind.originNote:
    case ClaimKind.samePerson:
      return '$kind:$subjectId';
  }
}

/// [contestKey] for a stored row, which must never throw: a `wifeOfHouse` row
/// with no house (it could arrive from sync) gets a key of its own, so it
/// competes with nothing.
String contestKeyOfRow(ClaimRow claim) {
  if (claim.kind == ClaimKind.wifeOfHouse && claim.objectId == null) {
    return 'orphan:${claim.id}';
  }
  return contestKey(claim.kind, claim.subjectId, claim.objectId);
}

typedef ClaimContent = (String, String?, Basis?, String?);

/// What a claim says, apart from who said it. Two accounts with equal content
/// agree.
ClaimContent claimContent(ClaimRow claim) =>
    (claim.subjectId, claim.objectId, claim.basis, claim.body);
