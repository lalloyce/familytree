# Environments and configuration

The repository holds code, invented test data and example configuration. It never holds anything that belongs to a real environment: real family data, credentials, signing keys, or the addresses of running services.

## Environments today

| Environment | What it is | Where its data lives |
|---|---|---|
| Tests | `flutter test`, using an in-memory database (`AppDatabase.memory()`) and invented fixtures | Nowhere; discarded after each test |
| Local development | The app on your own device or emulator, using the local file `related.sqlite` | On that device only. Not committed |

There is no server yet. When M2 adds one, it will add a staging and a production environment. Both will follow the rules below from the start.

## Rules

1. **Real data stays out.** Fixtures and examples use invented names. The synthetic tree generator produces fake people. Real family data lives only in the app on a person's own device, or in the git-ignored `private/` folder on a maintainer's machine.
2. **Configuration is injected, not committed.** Environment values (such as a server address) are passed to the app at build time with Flutter's `--dart-define-from-file`, from a file in `config/` that is git-ignored:

   ```sh
   cp config/example.json config/dev.json   # then edit config/dev.json
   flutter run --dart-define-from-file=../config/dev.json
   ```

   Only `config/example.json`, which holds placeholders, is tracked. The app does not read any configuration yet; the file shows the convention for M2.
3. **Secrets live in a secret store, never in the repository.** Use your CI provider's secret storage for pipeline values and a password manager or keychain for personal ones. Android signing keys go in `key.properties` and keystores, which are git-ignored.
4. **One environment, one set of values.** Do not point a development build at production, and do not copy production data into development or test.
5. **Git-ignored by default:** `.env` and `.env.*` (except `.env.example`), `config/*` (except `config/example.json`), `private/`, `*.private.md`, `*.sqlite` and `*.db` files, keystores and signing properties.

## If something sensitive was committed

Do not just delete it in a new commit; it stays in history. Tell the maintainer privately so the value can be rotated (for credentials) or the history can be rewritten (for personal data).
