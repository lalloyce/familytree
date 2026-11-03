import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:related/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<void> insertPerson(String id, {String? nameKey, Sex? sex}) {
    return db
        .into(db.persons)
        .insert(
          PersonsCompanion.insert(
            id: id,
            createdBy: 'account-1',
            nameKey: Value(nameKey),
            sex: Value(sex),
          ),
        );
  }

  Future<void> insertClaim(String id) {
    return db
        .into(db.claims)
        .insert(
          ClaimsCompanion.insert(
            id: id,
            kind: ClaimKind.belongsToHouse,
            subjectId: 'person-1',
            assertedBy: 'account-1',
            createdAt: DateTime.utc(2026, 11, 3),
            objectId: const Value('house-1'),
            basis: const Value(Basis.bornTo),
          ),
        );
  }

  test('inserts and reads a person with an apostrophe, non-ASCII and a '
      '200-character name', () async {
    final names = {
      'p-1': "Atieno Nyang'or",
      'p-2': 'Ouma Ọkọ̀',
      'p-3': 'x' * 200,
    };
    for (final e in names.entries) {
      await insertPerson(e.key, nameKey: e.value, sex: Sex.female);
    }

    for (final e in names.entries) {
      final PersonRow row = await (db.select(
        db.persons,
      )..where((p) => p.id.equals(e.key))).getSingle();
      expect(row.nameKey, e.value);
      expect(row.sex, Sex.female);
      expect(row.isPlaceholder, isFalse);
      expect(row.deletedAt, isNull);
    }
    expect((names['p-3'] ?? '').length, 200);
  });

  test('a person with null name, null sex reads back with nulls', () async {
    await insertPerson('p-1');

    final PersonRow row = await db.select(db.persons).getSingle();
    expect(row.nameKey, isNull);
    expect(row.sex, isNull);
  });

  test('inserting two claims with the same id throws', () async {
    await insertClaim('claim-1');

    await expectLater(
      insertClaim('claim-1'),
      throwsA(predicate((e) => e.toString().contains('UNIQUE'))),
    );
  });

  test(
    'a claim reads back with an auto local sequence and status active',
    () async {
      await insertClaim('claim-1');
      await insertClaim('claim-2');

      final List<ClaimRow> rows = await (db.select(
        db.claims,
      )..orderBy([(c) => OrderingTerm.asc(c.localSeq)])).get();
      expect(rows.map((r) => r.id), ['claim-1', 'claim-2']);
      expect(rows[1].localSeq, greaterThan(rows[0].localSeq));
      expect(rows[0].status, 'active');
      expect(rows[0].kind, ClaimKind.belongsToHouse);
      expect(rows[0].basis, Basis.bornTo);
      expect(rows[0].baseClaimId, isNull);
    },
  );

  test('a claim status other than active or superseded is rejected', () async {
    await expectLater(
      db
          .into(db.claims)
          .insert(
            ClaimsCompanion.insert(
              id: 'claim-1',
              kind: ClaimKind.sire,
              subjectId: 'person-1',
              assertedBy: 'account-1',
              createdAt: DateTime.utc(2026, 11, 3),
              status: const Value('deleted'),
            ),
          ),
      throwsA(predicate((e) => e.toString().contains('CHECK'))),
    );
  });
}
