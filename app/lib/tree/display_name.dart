import '../data/database.dart';

/// What a placeholder, or a father who is not known, is called.
const String forgottenName = 'someone we forgot';

/// What a person with no name is called.
const String unnamedName = 'unnamed';

/// The name shown for [person]: [forgottenName] for a placeholder, the
/// trimmed `nameKey` otherwise, and [unnamedName] when it is blank or the
/// person row is missing.
String displayName(PersonRow? person) {
  if (person != null && person.isPlaceholder) {
    return forgottenName;
  }
  final String name = person?.nameKey?.trim() ?? '';
  return name.isEmpty ? unnamedName : name;
}
