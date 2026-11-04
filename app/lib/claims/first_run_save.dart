import '../data/database.dart';
import 'household_builder.dart';

/// What was said on the first-run screen, already trimmed. A slot that is not
/// known is null or empty.
class FirstRunAnswers {
  const FirstRunAnswers({
    this.name,
    this.sex,
    this.fatherName,
    this.houseNumber,
    this.siblingNames = const [],
  });

  final String? name;
  final Sex? sex;
  final String? fatherName;

  /// The father's house number. Below one counts as not known.
  final int? houseNumber;

  /// One entry per brother or sister in the house, each already non-empty.
  final List<String> siblingNames;
}

/// Writes the household described by [answers] through [builder] and returns
/// the id of "me". Wrap the call in [HouseholdBuilder.atomically] so that a
/// failure part-way leaves nothing behind.
///
/// Order: me, the father (a fresh placeholder when he is not named), his
/// house, me placed in it as born to it, then each sibling placed likewise.
Future<String> saveFirstRun(
  HouseholdBuilder builder,
  FirstRunAnswers answers,
) async {
  final String me = await builder.addPerson(
    name: answers.name,
    sex: answers.sex,
  );
  final String? fatherName = answers.fatherName;
  final String father = fatherName == null || fatherName.isEmpty
      ? await builder.addPlaceholder(sex: Sex.male)
      : await builder.addPerson(name: fatherName, sex: Sex.male);
  final int? number = answers.houseNumber;
  final String house = await builder.addHouse(
    husbandId: father,
    ordinal: number != null && number > 0 ? number : null,
  );
  await builder.placeChild(personId: me, houseId: house, basis: Basis.bornTo);

  for (final String name in answers.siblingNames) {
    final String sibling = await builder.addPerson(name: name);
    await builder.placeChild(
      personId: sibling,
      houseId: house,
      basis: Basis.bornTo,
    );
  }
  return me;
}
