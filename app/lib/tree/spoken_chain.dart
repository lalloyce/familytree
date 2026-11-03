import '../data/database.dart';
import 'ancestors.dart';

const String _forgotten = 'someone we forgot';
const String _unnamed = 'unnamed';

/// One line of the spoken chain: a person and, unless the line ends the
/// chain, their father.
class ChainLine {
  const ChainLine({
    required this.personId,
    required this.text,
    required this.disputed,
    required this.placeholder,
  });

  /// The person the line is about.
  final String personId;

  /// What is read aloud, for example "Manyi, son of Winyo, house 2".
  final String text;

  /// True only on an "accounts differ" line, which ends the chain.
  final bool disputed;

  /// True when [personId] is a placeholder, a stand-in for someone not known.
  final bool placeholder;
}

/// The father line of [personId] as spoken lines: the person first, then each
/// ancestor in order.
///
/// The line for each person names them and their father. The word follows
/// the sex of the person on that line: son, daughter, or child when unknown.
/// The house suffix is the ordinal of the house the father was reached
/// through, left out when it has none. Where the person belongs to that house
/// on the basis `joined`, the line reads "belongs to {father}'s house"
/// instead (decision F).
///
/// A person with no known father reads "of someone we forgot". When the last
/// ancestor is a placeholder, that has just been said, so it gets no line of
/// its own; a placeholder anywhere else does, named "someone we forgot".
/// Where accounts differ about a person's parentage, or it loops back, the
/// chain ends with "{name}, accounts differ" (decision E).
///
/// Names and house ordinals come from one query each for the whole chain.
Future<List<ChainLine>> spokenChain(AppDatabase db, String personId) async {
  final List<AncestorStep> found = await ancestorsOf(db, personId);

  // The depth 0 sentinel stands for the starting person: nothing to follow.
  final bool sentinel = found.isNotEmpty && found.first.depth == 0;
  final List<AncestorStep> steps = sentinel ? const [] : found;
  final bool disputedEnd =
      sentinel || (steps.isNotEmpty && steps.last.disputed);
  // steps[i] is the father of people[i].
  final List<String> people = [personId, for (final s in steps) s.personId];

  final Map<String, PersonRow> persons = {
    for (final p in await (db.select(
      db.persons,
    )..where((p) => p.id.isIn(people))).get())
      p.id: p,
  };
  final Map<String, int?> ordinals = {
    for (final h in await (db.select(
      db.houses,
    )..where((h) => h.id.isIn(steps.map((s) => s.houseId)))).get())
      h.id: h.ordinal,
  };

  bool isPlaceholder(String id) => persons[id]?.isPlaceholder ?? false;
  String nameOf(String id) {
    final PersonRow? p = persons[id];
    if (p != null && p.isPlaceholder) {
      return _forgotten;
    }
    final String name = p?.nameKey?.trim() ?? '';
    return name.isEmpty ? _unnamed : name;
  }

  final int last = people.length - 1;
  // The ancestor at the end has already been told as "of someone we forgot".
  final bool dropLast = !disputedEnd && last > 0 && isPlaceholder(people[last]);

  final lines = <ChainLine>[];
  for (int i = 0; i <= last; i++) {
    if (i == last && dropLast) {
      break;
    }
    final String id = people[i];
    final String name = nameOf(id);
    final String text;
    if (i == last && disputedEnd) {
      text = '$name, accounts differ';
    } else if (i < steps.length && steps[i].basis == Basis.joined) {
      text = "$name, belongs to ${nameOf(steps[i].personId)}'s house";
    } else {
      final String word = switch (persons[id]?.sex) {
        Sex.male => 'son',
        Sex.female => 'daughter',
        null => 'child',
      };
      final String father = i < steps.length
          ? nameOf(steps[i].personId)
          : _forgotten;
      final int? ordinal = i < steps.length ? ordinals[steps[i].houseId] : null;
      text = ordinal == null
          ? '$name, $word of $father'
          : '$name, $word of $father, house $ordinal';
    }
    lines.add(
      ChainLine(
        personId: id,
        text: text,
        disputed: i == last && disputedEnd,
        placeholder: isPlaceholder(id),
      ),
    );
  }
  return lines;
}
