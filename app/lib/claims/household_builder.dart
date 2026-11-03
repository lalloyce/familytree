import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import 'claim_service.dart';

/// Builds people, houses and the claims that place them, for one account.
///
/// A person with no known father gets a fresh placeholder husband and a fresh
/// house of their own, never a shared "unknown" house, so two orphans are
/// never siblings. A name is never an identity: every person has a new id.
class HouseholdBuilder {
  HouseholdBuilder(this._db, this._claims, {required this.accountId});

  final AppDatabase _db;
  final ClaimService _claims;
  final String accountId;

  /// Runs [body] in one database transaction: everything it writes commits
  /// together, or none of it does when it throws. Transactions nest, so the
  /// builder's own methods can be called inside.
  Future<T> atomically<T>(Future<T> Function() body) => _db.transaction(body);

  /// Adds a person and returns their id. [name] becomes `nameKey`, the primary
  /// display name; it may be null.
  Future<String> addPerson({String? name, Sex? sex}) {
    return _insertPerson(name: name, sex: sex, isPlaceholder: false);
  }

  /// Adds an unnamed stand-in for someone not known, and returns its id.
  Future<String> addPlaceholder({Sex? sex}) {
    return _insertPerson(sex: sex, isPlaceholder: true);
  }

  Future<String> addHouse({required String husbandId, int? ordinal}) async {
    final String id = const Uuid().v4();
    await _db
        .into(_db.houses)
        .insert(
          HousesCompanion.insert(
            id: id,
            husbandId: husbandId,
            createdBy: accountId,
            ordinal: Value(ordinal),
          ),
        );
    return id;
  }

  /// Records that [personId] belongs to [houseId]. This account's own earlier
  /// placement of the person is replaced; an identical one writes nothing.
  Future<void> placeChild({
    required String personId,
    required String houseId,
    required Basis basis,
  }) async {
    // Read and write in one transaction, so a concurrent identical call
    // sees this one's claim instead of racing it.
    await _db.transaction(() async {
      final List<ClaimRow> own = await _ownActive(
        ClaimKind.belongsToHouse,
        personId,
      );
      if (own.any((c) => c.objectId == houseId && c.basis == basis)) {
        return;
      }
      await _claims.assertClaim(
        kind: ClaimKind.belongsToHouse,
        subjectId: personId,
        objectId: houseId,
        basis: basis,
        baseClaimId: own.isEmpty ? null : own.last.id,
      );
    });
  }

  /// Records that [wifeId] is a wife of [houseId]. A woman may be a wife of
  /// several houses. An identical claim by this account writes nothing.
  Future<void> addWife({
    required String wifeId,
    required String houseId,
  }) async {
    await _db.transaction(() async {
      final List<ClaimRow> own = await _ownActive(
        ClaimKind.wifeOfHouse,
        wifeId,
      );
      if (own.any((c) => c.objectId == houseId)) {
        return;
      }
      await _claims.assertClaim(
        kind: ClaimKind.wifeOfHouse,
        subjectId: wifeId,
        objectId: houseId,
      );
    });
  }

  /// Returns the house [personId] belongs to, creating one when no account
  /// has placed them. The new house has a fresh placeholder husband and holds
  /// only this person. When claims disagree, the earliest to arrive wins here;
  /// the disagreement itself stays visible through the claims.
  Future<String> ensureFatherHouse(String personId) {
    // One transaction from the first read to the last write, so concurrent
    // calls for one person cannot each create a house.
    return _db.transaction(() async {
      final views = await _claims.activeClaims(
        ClaimKind.belongsToHouse,
        subjectId: personId,
      );
      for (final v in views) {
        final String? houseId = v.claim.objectId;
        if (houseId != null) {
          return houseId;
        }
      }
      final String husbandId = await addPlaceholder(sex: Sex.male);
      final String houseId = await addHouse(husbandId: husbandId);
      await placeChild(
        personId: personId,
        houseId: houseId,
        basis: Basis.bornTo,
      );
      return houseId;
    });
  }

  Future<String> _insertPerson({
    String? name,
    Sex? sex,
    required bool isPlaceholder,
  }) async {
    final String id = const Uuid().v4();
    await _db
        .into(_db.persons)
        .insert(
          PersonsCompanion.insert(
            id: id,
            createdBy: accountId,
            isPlaceholder: Value(isPlaceholder),
            nameKey: Value(name),
            sex: Value(sex),
          ),
        );
    return id;
  }

  /// This account's active claims of [kind] about [subjectId], oldest first.
  Future<List<ClaimRow>> _ownActive(ClaimKind kind, String subjectId) async {
    final views = await _claims.activeClaims(kind, subjectId: subjectId);
    return [
      for (final v in views)
        if (v.claim.assertedBy == accountId) v.claim,
    ];
  }
}
