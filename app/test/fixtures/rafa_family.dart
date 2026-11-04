import 'package:related/claims/claim_service.dart';
import 'package:related/claims/household_builder.dart';
import 'package:related/data/database.dart';

/// An invented family (design section 4, paper test parts A and B), built
/// through [HouseholdBuilder] by one account, so the rows are what the app
/// would write.
///
/// Two different men are named Rafa. [rafa] is Kito's father with four
/// houses; [rafaElder] is Rafa's grandfather. Names are never identities.
class RafaFamily {
  const RafaFamily({
    required this.me,
    required this.tembo,
    required this.kito,
    required this.pima,
    required this.lumo,
    required this.rafa,
    required this.rafaElder,
    required this.deko,
    required this.zawadi,
    required this.nuru,
    required this.seko,
    required this.aunt,
    required this.auntHusbandA,
    required this.auntHusbandB,
    required this.auntChildA,
    required this.auntChildB,
    required this.rafaHouse1,
    required this.rafaHouse2,
    required this.rafaHouse3,
    required this.rafaHouse4,
    required this.kitoHouse,
    required this.temboHouse,
    required this.dekoHouseRafa,
    required this.dekoHouseSeko,
    required this.rafaElderHouse,
    required this.auntFathersHouse,
    required this.auntHouseA,
    required this.auntHouseB,
  });

  /// The founder, "Me", son of [tembo].
  final String me;
  final String tembo;

  /// Son of [rafa] in his house 2, and father of [tembo] and [aunt].
  final String kito;

  /// Kito's full brother, in house 2.
  final String pima;

  /// Rafa's only known child in house 4.
  final String lumo;

  /// Kito's father, with four houses.
  final String rafa;

  /// Rafa's grandfather, also named Rafa and a different person. His own
  /// father is a placeholder ("someone we forgot").
  final String rafaElder;

  /// Rafa's father, with two houses.
  final String deko;

  /// Wife of Rafa's house 2 and mother of Kito and Pima.
  final String zawadi;

  /// Rafa's full brother: in [dekoHouseRafa].
  final String nuru;

  /// Rafa's brother through the father only: in [dekoHouseSeko].
  final String seko;

  /// Kito's daughter and Tembo's sister. A child in [kitoHouse], and a wife
  /// of [auntHouseA] and of [auntHouseB]. She has no name in the fixture.
  final String aunt;

  /// The two brothers whose houses the aunt married into, both children of
  /// [auntFathersHouse].
  final String auntHusbandA;
  final String auntHusbandB;

  /// The aunt's child in [auntHouseA] and in [auntHouseB].
  final String auntChildA;
  final String auntChildB;

  /// Rafa's houses by ordinal. 2 holds Zawadi, Kito and Pima; 4 holds Lumo
  /// with no wife known; 1 and 3 are empty and have no wife.
  final String rafaHouse1;
  final String rafaHouse2;
  final String rafaHouse3;
  final String rafaHouse4;

  /// Kito's house: [tembo] and [aunt] are born to it.
  final String kitoHouse;

  /// Tembo's house: [me] is born to it.
  final String temboHouse;

  /// Deko's first house: Rafa and Nuru.
  final String dekoHouseRafa;

  /// Deko's second house: Seko.
  final String dekoHouseSeko;

  /// [rafaElder]'s house: Deko.
  final String rafaElderHouse;

  /// The house of the placeholder father of [auntHusbandA] and
  /// [auntHusbandB].
  final String auntFathersHouse;

  /// The aunt's first marriage, to [auntHusbandA], with [auntChildA].
  final String auntHouseA;

  /// The aunt's later marriage, to [auntHusbandB], with [auntChildB].
  final String auntHouseB;
}

/// Fills [db] with the Rafa family, written by the account `fixture`.
Future<RafaFamily> buildRafaFamily(AppDatabase db) async {
  const String account = 'fixture';
  final b = HouseholdBuilder(
    db,
    ClaimService(db, accountId: account),
    accountId: account,
  );

  // Rafa and his four houses. Only house 2 has a wife claim and children
  // beyond house 4's Lumo.
  final String rafa = await b.addPerson(name: 'Rafa', sex: Sex.male);
  final String rafaHouse1 = await b.addHouse(husbandId: rafa, ordinal: 1);
  final String rafaHouse2 = await b.addHouse(husbandId: rafa, ordinal: 2);
  final String rafaHouse3 = await b.addHouse(husbandId: rafa, ordinal: 3);
  final String rafaHouse4 = await b.addHouse(husbandId: rafa, ordinal: 4);
  final String zawadi = await b.addPerson(
    name: "Zawadi Bora",
    sex: Sex.female,
  );
  await b.addWife(wifeId: zawadi, houseId: rafaHouse2);
  final String kito = await b.addPerson(name: 'Kito', sex: Sex.male);
  await b.placeChild(
    personId: kito,
    houseId: rafaHouse2,
    basis: Basis.bornTo,
  );
  final String pima = await b.addPerson(name: 'Pima', sex: Sex.male);
  await b.placeChild(personId: pima, houseId: rafaHouse2, basis: Basis.bornTo);
  final String lumo = await b.addPerson(name: 'Lumo', sex: Sex.male);
  await b.placeChild(
    personId: lumo,
    houseId: rafaHouse4,
    basis: Basis.bornTo,
  );

  // Rafa's father Deko, with two houses (the wives are not recorded).
  final String deko = await b.addPerson(name: 'Deko', sex: Sex.male);
  final String dekoHouseRafa = await b.addHouse(husbandId: deko);
  final String dekoHouseSeko = await b.addHouse(husbandId: deko);
  await b.placeChild(
    personId: rafa,
    houseId: dekoHouseRafa,
    basis: Basis.bornTo,
  );
  final String nuru = await b.addPerson(name: 'Nuru', sex: Sex.male);
  await b.placeChild(
    personId: nuru,
    houseId: dekoHouseRafa,
    basis: Basis.bornTo,
  );
  final String seko = await b.addPerson(name: 'Seko', sex: Sex.male);
  await b.placeChild(
    personId: seko,
    houseId: dekoHouseSeko,
    basis: Basis.bornTo,
  );

  // Deko's father, another man named Rafa, whose own father is forgotten.
  final String rafaElder = await b.addPerson(name: 'Rafa', sex: Sex.male);
  final String rafaElderHouse = await b.addHouse(husbandId: rafaElder);
  await b.placeChild(
    personId: deko,
    houseId: rafaElderHouse,
    basis: Basis.bornTo,
  );
  await b.ensureFatherHouse(rafaElder);

  // Kito's house, Tembo's house, and the founder.
  final String kitoHouse = await b.addHouse(husbandId: kito);
  final String tembo = await b.addPerson(name: 'Tembo', sex: Sex.male);
  await b.placeChild(personId: tembo, houseId: kitoHouse, basis: Basis.bornTo);
  final String aunt = await b.addPerson(sex: Sex.female);
  await b.placeChild(personId: aunt, houseId: kitoHouse, basis: Basis.bornTo);
  final String temboHouse = await b.addHouse(husbandId: tembo);
  final String me = await b.addPerson(name: 'Me', sex: Sex.male);
  await b.placeChild(personId: me, houseId: temboHouse, basis: Basis.bornTo);

  // The aunt, wife in a house of A and later in a house of B. A and B are
  // brothers: both born to the same house of an unnamed father.
  final String auntHusbandA = await b.addPerson(sex: Sex.male);
  final String auntFathersHouse = await b.ensureFatherHouse(auntHusbandA);
  final String auntHusbandB = await b.addPerson(sex: Sex.male);
  await b.placeChild(
    personId: auntHusbandB,
    houseId: auntFathersHouse,
    basis: Basis.bornTo,
  );
  final String auntHouseA = await b.addHouse(husbandId: auntHusbandA);
  await b.addWife(wifeId: aunt, houseId: auntHouseA);
  final String auntChildA = await b.addPerson();
  await b.placeChild(
    personId: auntChildA,
    houseId: auntHouseA,
    basis: Basis.bornTo,
  );
  final String auntHouseB = await b.addHouse(husbandId: auntHusbandB);
  await b.addWife(wifeId: aunt, houseId: auntHouseB);
  final String auntChildB = await b.addPerson();
  await b.placeChild(
    personId: auntChildB,
    houseId: auntHouseB,
    basis: Basis.bornTo,
  );

  return RafaFamily(
    me: me,
    tembo: tembo,
    kito: kito,
    pima: pima,
    lumo: lumo,
    rafa: rafa,
    rafaElder: rafaElder,
    deko: deko,
    zawadi: zawadi,
    nuru: nuru,
    seko: seko,
    aunt: aunt,
    auntHusbandA: auntHusbandA,
    auntHusbandB: auntHusbandB,
    auntChildA: auntChildA,
    auntChildB: auntChildB,
    rafaHouse1: rafaHouse1,
    rafaHouse2: rafaHouse2,
    rafaHouse3: rafaHouse3,
    rafaHouse4: rafaHouse4,
    kitoHouse: kitoHouse,
    temboHouse: temboHouse,
    dekoHouseRafa: dekoHouseRafa,
    dekoHouseSeko: dekoHouseSeko,
    rafaElderHouse: rafaElderHouse,
    auntFathersHouse: auntFathersHouse,
    auntHouseA: auntHouseA,
    auntHouseB: auntHouseB,
  );
}
