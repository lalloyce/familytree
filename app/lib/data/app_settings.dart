import 'database.dart';

const String _selfPersonKey = 'selfPersonId';

/// Local settings, kept in the device's own `app_settings` table. They are never
/// synced.
extension AppSettingsAccess on AppDatabase {
  /// The id of the person who is "me" on this device, or null before first
  /// run. In M1 this is the only record of who "me" is; from M2 it comes from
  /// the link between the account and its person.
  Future<String?> selfPersonId() async {
    final AppSettingRow? row = await (select(
      appSettings,
    )..where((s) => s.key.equals(_selfPersonKey))).getSingleOrNull();
    return row?.value;
  }

  /// Records [id] as the person who is "me", replacing any earlier one.
  Future<void> setSelfPersonId(String id) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: _selfPersonKey, value: id),
    );
  }
}
