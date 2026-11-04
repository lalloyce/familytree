import 'package:flutter_test/flutter_test.dart';
import 'package:related/data/database.dart';
import 'package:related/tree/display_name.dart';

PersonRow person({String? name, bool placeholder = false}) => PersonRow(
  id: 'p',
  isPlaceholder: placeholder,
  nameKey: name,
  createdBy: 'a',
);

void main() {
  test('a placeholder reads "someone we forgot", whatever its name', () {
    expect(displayName(person(placeholder: true)), 'someone we forgot');
    expect(
      displayName(person(placeholder: true, name: 'Ghost')),
      'someone we forgot',
    );
    expect(forgottenName, 'someone we forgot');
  });

  test('a blank, absent or missing person reads "unnamed"', () {
    expect(displayName(person()), 'unnamed');
    expect(displayName(person(name: '   ')), 'unnamed');
    expect(displayName(null), 'unnamed');
    expect(unnamedName, 'unnamed');
  });

  test("a name is trimmed and otherwise kept as it is", () {
    expect(displayName(person(name: "  Zawadi Bora ")), "Zawadi Bora");
  });
}
