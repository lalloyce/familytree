import 'package:flutter_test/flutter_test.dart';
import 'package:related/data/app_settings.dart';
import 'package:related/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  test('an empty database has no self person', () async {
    expect(await db.selfPersonId(), isNull);
  });

  test('the self person is read back after it is set', () async {
    await db.setSelfPersonId('person-1');
    expect(await db.selfPersonId(), 'person-1');
  });

  test('setting the self person twice keeps the last', () async {
    await db.setSelfPersonId('person-1');
    await db.setSelfPersonId('person-2');
    expect(await db.selfPersonId(), 'person-2');
    expect(await db.select(db.appSettings).get(), hasLength(1));
  });
}
