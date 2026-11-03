import '../claims/claim_service.dart';
import '../data/database.dart';
import 'display_name.dart';

/// One house of a husband, as the house view shows it.
class HouseRowModel {
  const HouseRowModel({
    this.ordinal,
    this.wifeName,
    this.wifeSameAsElsewhere = false,
    this.wifeAccountsDiffer = false,
    this.wifeIsPlaceholder = false,
    this.childLines = const [],
  });

  /// The house's number among its husband's houses, or null when not known.
  final int? ordinal;

  /// The wife's display name. Null when no wife is known, and also when
  /// accounts differ about who she is ([wifeAccountsDiffer]).
  final String? wifeName;

  /// True when the wife is also the wife of another house, or a child in
  /// any house: the view tags her "same person".
  final bool wifeSameAsElsewhere;

  /// True when accounts name different women as the wife of this house.
  final bool wifeAccountsDiffer;

  /// True when the wife is a placeholder: the view outlines her name.
  final bool wifeIsPlaceholder;

  /// One line per child, in claim arrival order, for example
  /// "Manyi, born to this house".
  final List<String> childLines;
}

/// A husband and his houses.
class HouseViewModel {
  const HouseViewModel({
    required this.husbandName,
    required this.houses,
    this.husbandIsPlaceholder = false,
  });

  final String husbandName;

  /// True when the husband is a placeholder: the view outlines his name.
  final bool husbandIsPlaceholder;

  /// Ordinal ascending with unknown ordinals last, ties by house id.
  final List<HouseRowModel> houses;
}

/// The houses of [husbandId], with each house's wife and children as display
/// text.
///
/// The wife comes from the active `wifeOfHouse` claims on the house: one
/// woman is her name, none is null, and two different women make
/// `wifeAccountsDiffer`. A child is a person with an active `belongsToHouse`
/// claim to the house, listed once even where several accounts claim them
/// there; the earliest claim to arrive gives the basis. A `joined` basis reads
/// "belongs to" (decision F). A person who has any other role gets ", same
/// person", and one whose own placement competes gets ", accounts differ". The
/// dispute signal comes from [activeClaimViews]; it is not re-derived here.
///
/// Queries are batched: houses, both claim kinds and the people, once each,
/// however many houses there are. `deletedAt` is ignored, because nothing sets
/// it yet.
Future<HouseViewModel> buildHouseViewModel(
  AppDatabase db,
  String husbandId,
) async {
  final houses = await (db.select(
    db.houses,
  )..where((h) => h.husbandId.equals(husbandId))).get();
  houses.sort((a, b) {
    final int? x = a.ordinal;
    final int? y = b.ordinal;
    if (x != y) {
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    }
    return a.id.compareTo(b.id);
  });
  final Set<String> houseIds = {for (final h in houses) h.id};

  final wifeViews = await activeClaimViews(db, ClaimKind.wifeOfHouse);
  final placeViews = await activeClaimViews(db, ClaimKind.belongsToHouse);

  // Wife claims by house, for these houses; and every house each woman is
  // claimed as a wife of, anywhere.
  final wivesByHouse = <String, List<ClaimView>>{};
  final wifeHouses = <String, Set<String>>{};
  for (final v in wifeViews) {
    final String? houseId = v.claim.objectId;
    if (houseId == null) {
      continue;
    }
    wifeHouses.putIfAbsent(v.claim.subjectId, () => {}).add(houseId);
    if (houseIds.contains(houseId)) {
      wivesByHouse.putIfAbsent(houseId, () => []).add(v);
    }
  }

  // Placements by house, for these houses; every house each person is placed
  // in, anywhere; and whose own placement competes.
  final placementsByHouse = <String, List<ClaimView>>{};
  final placedHouses = <String, Set<String>>{};
  final placementCompetes = <String>{};
  for (final v in placeViews) {
    final String? houseId = v.claim.objectId;
    if (houseId == null) {
      continue;
    }
    placedHouses.putIfAbsent(v.claim.subjectId, () => {}).add(houseId);
    if (v.competing) {
      placementCompetes.add(v.claim.subjectId);
    }
    if (houseIds.contains(houseId)) {
      placementsByHouse.putIfAbsent(houseId, () => []).add(v);
    }
  }

  final needed = <String>{
    husbandId,
    for (final vs in wivesByHouse.values)
      for (final v in vs) v.claim.subjectId,
    for (final vs in placementsByHouse.values)
      for (final v in vs) v.claim.subjectId,
  };
  final Map<String, PersonRow> persons = {
    for (final p in await (db.select(
      db.persons,
    )..where((p) => p.id.isIn(needed))).get())
      p.id: p,
  };
  String nameOf(String id) => displayName(persons[id]);

  HouseRowModel rowOf(HouseRow house) {
    final wives = wivesByHouse[house.id] ?? const <ClaimView>[];
    final bool differ = wives.any((v) => v.competing);
    final String? wifeId = differ || wives.isEmpty
        ? null
        : wives.first.claim.subjectId;

    // Each child once, by the earliest claim to arrive in this house.
    final children = <String, ClaimView>{};
    for (final v in placementsByHouse[house.id] ?? const <ClaimView>[]) {
      children.putIfAbsent(v.claim.subjectId, () => v);
    }

    return HouseRowModel(
      ordinal: house.ordinal,
      wifeName: wifeId == null ? null : nameOf(wifeId),
      wifeSameAsElsewhere:
          wifeId != null &&
          ((wifeHouses[wifeId]?.any((h) => h != house.id) ?? false) ||
              (placedHouses[wifeId]?.isNotEmpty ?? false)),
      wifeAccountsDiffer: differ,
      wifeIsPlaceholder:
          wifeId != null && (persons[wifeId]?.isPlaceholder ?? false),
      childLines: [
        for (final MapEntry(key: id, value: view) in children.entries)
          [
            nameOf(id),
            view.claim.basis == Basis.bornTo
                ? 'born to this house'
                : 'belongs to this house',
            if ((wifeHouses[id]?.isNotEmpty ?? false) ||
                (placedHouses[id]?.any((h) => h != house.id) ?? false))
              'same person',
            if (placementCompetes.contains(id)) 'accounts differ',
          ].join(', '),
      ],
    );
  }

  return HouseViewModel(
    husbandName: nameOf(husbandId),
    husbandIsPlaceholder: persons[husbandId]?.isPlaceholder ?? false,
    houses: [for (final h in houses) rowOf(h)],
  );
}
