import 'package:related/claims/claim_service.dart';
import 'package:related/claims/household_builder.dart';
import 'package:related/data/database.dart';

/// The founder's family (design section 4, paper test parts A and B), built
/// through [HouseholdBuilder] by one account, so the rows are what the app
/// would write.
///
/// Two different men are named Winyo. [winyo] is Manyi's father with four
/// houses; [winyoElder] is Winyo's grandfather. Names are never identities.
class WinyoFamily {
  const WinyoFamily({
    required this.me,
    required this.juma,
    required this.manyi,
    required this.wade,
    required this.owala,
    required this.winyo,
    required this.winyoElder,
    required this.ochieng,
    required this.atieno,
    required this.obuolo,
    required this.olembo,
    required this.aunt,
    required this.auntHusbandA,
    required this.auntHusbandB,
    required this.auntChildA,
    required this.auntChildB,
    required this.winyoHouse1,
    required this.winyoHouse2,
    required this.winyoHouse3,
    required this.winyoHouse4,
    required this.manyiHouse,
    required this.jumaHouse,
    required this.ochiengHouseWinyo,
    required this.ochiengHouseOlembo,
    required this.winyoElderHouse,
    required this.auntFathersHouse,
    required this.auntHouseA,
    required this.auntHouseB,
  });

  /// The founder, "Me", son of [juma].
  final String me;
  final String juma;

  /// Son of [winyo] in his house 2, and father of [juma] and [aunt].
  final String manyi;

  /// Manyi's full brother, in house 2.
  final String wade;

  /// Winyo's only known child in house 4.
  final String owala;

  /// Manyi's father, with four houses.
  final String winyo;

  /// Winyo's grandfather, also named Winyo and a different person. His own
  /// father is a placeholder ("someone we forgot").
  final String winyoElder;

  /// Winyo's father, with two houses.
  final String ochieng;

  /// Wife of Winyo's house 2 and mother of Manyi and Wade.
  final String atieno;

  /// Winyo's full brother: in [ochiengHouseWinyo].
  final String obuolo;

  /// Winyo's brother through the father only: in [ochiengHouseOlembo].
  final String olembo;

  /// Manyi's daughter and Juma's sister. A child in [manyiHouse], and a wife
  /// of [auntHouseA] and of [auntHouseB]. She has no name in the fixture.
  final String aunt;

  /// The two brothers whose houses the aunt married into, both children of
  /// [auntFathersHouse].
  final String auntHusbandA;
  final String auntHusbandB;

  /// The aunt's child in [auntHouseA] and in [auntHouseB].
  final String auntChildA;
  final String auntChildB;

  /// Winyo's houses by ordinal. 2 holds Atieno, Manyi and Wade; 4 holds Owala
  /// with no wife known; 1 and 3 are empty and have no wife.
  final String winyoHouse1;
  final String winyoHouse2;
  final String winyoHouse3;
  final String winyoHouse4;

  /// Manyi's house: [juma] and [aunt] are born to it.
  final String manyiHouse;

  /// Juma's house: [me] is born to it.
  final String jumaHouse;

  /// Ochieng's first house: Winyo and Obuolo.
  final String ochiengHouseWinyo;

  /// Ochieng's second house: Olembo.
  final String ochiengHouseOlembo;

  /// [winyoElder]'s house: Ochieng.
  final String winyoElderHouse;

  /// The house of the placeholder father of [auntHusbandA] and
  /// [auntHusbandB].
  final String auntFathersHouse;

  /// The aunt's first marriage, to [auntHusbandA], with [auntChildA].
  final String auntHouseA;

  /// The aunt's later marriage, to [auntHusbandB], with [auntChildB].
  final String auntHouseB;
}

/// Fills [db] with the Winyo family, written by the account `fixture`.
Future<WinyoFamily> buildWinyoFamily(AppDatabase db) async {
  const String account = 'fixture';
  final b = HouseholdBuilder(
    db,
    ClaimService(db, accountId: account),
    accountId: account,
  );

  // Winyo and his four houses. Only house 2 has a wife claim and children
  // beyond house 4's Owala.
  final String winyo = await b.addPerson(name: 'Winyo', sex: Sex.male);
  final String winyoHouse1 = await b.addHouse(husbandId: winyo, ordinal: 1);
  final String winyoHouse2 = await b.addHouse(husbandId: winyo, ordinal: 2);
  final String winyoHouse3 = await b.addHouse(husbandId: winyo, ordinal: 3);
  final String winyoHouse4 = await b.addHouse(husbandId: winyo, ordinal: 4);
  final String atieno = await b.addPerson(
    name: "Atieno Nyang'or",
    sex: Sex.female,
  );
  await b.addWife(wifeId: atieno, houseId: winyoHouse2);
  final String manyi = await b.addPerson(name: 'Manyi', sex: Sex.male);
  await b.placeChild(
    personId: manyi,
    houseId: winyoHouse2,
    basis: Basis.bornTo,
  );
  final String wade = await b.addPerson(name: 'Wade', sex: Sex.male);
  await b.placeChild(personId: wade, houseId: winyoHouse2, basis: Basis.bornTo);
  final String owala = await b.addPerson(name: 'Owala', sex: Sex.male);
  await b.placeChild(
    personId: owala,
    houseId: winyoHouse4,
    basis: Basis.bornTo,
  );

  // Winyo's father Ochieng, with two houses (the wives are not recorded).
  final String ochieng = await b.addPerson(name: 'Ochieng', sex: Sex.male);
  final String ochiengHouseWinyo = await b.addHouse(husbandId: ochieng);
  final String ochiengHouseOlembo = await b.addHouse(husbandId: ochieng);
  await b.placeChild(
    personId: winyo,
    houseId: ochiengHouseWinyo,
    basis: Basis.bornTo,
  );
  final String obuolo = await b.addPerson(name: 'Obuolo', sex: Sex.male);
  await b.placeChild(
    personId: obuolo,
    houseId: ochiengHouseWinyo,
    basis: Basis.bornTo,
  );
  final String olembo = await b.addPerson(name: 'Olembo', sex: Sex.male);
  await b.placeChild(
    personId: olembo,
    houseId: ochiengHouseOlembo,
    basis: Basis.bornTo,
  );

  // Ochieng's father, another man named Winyo, whose own father is forgotten.
  final String winyoElder = await b.addPerson(name: 'Winyo', sex: Sex.male);
  final String winyoElderHouse = await b.addHouse(husbandId: winyoElder);
  await b.placeChild(
    personId: ochieng,
    houseId: winyoElderHouse,
    basis: Basis.bornTo,
  );
  await b.ensureFatherHouse(winyoElder);

  // Manyi's house, Juma's house, and the founder.
  final String manyiHouse = await b.addHouse(husbandId: manyi);
  final String juma = await b.addPerson(name: 'Juma', sex: Sex.male);
  await b.placeChild(personId: juma, houseId: manyiHouse, basis: Basis.bornTo);
  final String aunt = await b.addPerson(sex: Sex.female);
  await b.placeChild(personId: aunt, houseId: manyiHouse, basis: Basis.bornTo);
  final String jumaHouse = await b.addHouse(husbandId: juma);
  final String me = await b.addPerson(name: 'Me', sex: Sex.male);
  await b.placeChild(personId: me, houseId: jumaHouse, basis: Basis.bornTo);

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

  return WinyoFamily(
    me: me,
    juma: juma,
    manyi: manyi,
    wade: wade,
    owala: owala,
    winyo: winyo,
    winyoElder: winyoElder,
    ochieng: ochieng,
    atieno: atieno,
    obuolo: obuolo,
    olembo: olembo,
    aunt: aunt,
    auntHusbandA: auntHusbandA,
    auntHusbandB: auntHusbandB,
    auntChildA: auntChildA,
    auntChildB: auntChildB,
    winyoHouse1: winyoHouse1,
    winyoHouse2: winyoHouse2,
    winyoHouse3: winyoHouse3,
    winyoHouse4: winyoHouse4,
    manyiHouse: manyiHouse,
    jumaHouse: jumaHouse,
    ochiengHouseWinyo: ochiengHouseWinyo,
    ochiengHouseOlembo: ochiengHouseOlembo,
    winyoElderHouse: winyoElderHouse,
    auntFathersHouse: auntFathersHouse,
    auntHouseA: auntHouseA,
    auntHouseB: auntHouseB,
  );
}
