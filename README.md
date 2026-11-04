# Related

Related is a cross-platform app (Flutter) for relatives to pool oral family history. Each person records their own household: houses, wives, children, and people the family has forgotten. They invite only relatives they personally know. Where accounts disagree, the app keeps both and shows who said what and on what basis.

The design is written down in [docs/2026-11-03-lineage-app-design.md](docs/2026-11-03-lineage-app-design.md). This project is built in the open: design, plan, spike results and open questions are all in [docs/](docs/).

## Status

Early. There is no release and no server.

- **Phase 0 (done):** five spikes in [spikes/](spikes/) that test the risky ideas (claims and merging, tree layout at scale, invites, quiet-link leaks, encrypted storage), written up in [docs/spike-results.md](docs/spike-results.md). Numbers measured on a laptop are labelled as such. Measurements on a weak phone are not done yet.
- **Milestone 1 (done):** a local-only app in [app/](app/) with a Drift (SQLite) database, append-only claims, a spoken-chain view, a house view and first-run entry of your own household.
- **Next:** milestones M2 to M6 (accounts, sync, invites, quiet links, merge and disputes, a pilot) are planned after the spike results have been reviewed. See [docs/NOTES.md](docs/NOTES.md) for the current state and open questions.

The M1 database is not encrypted. Do not enter real family data you would not want read off the phone. Encryption comes later.

## Repository layout

| Path | What it holds |
|---|---|
| `app/` | The Flutter app (package `related`) and its tests |
| `spikes/` | Phase 0 experiments, each with its own README |
| `docs/` | Design, build plan, project notes, spike results, paper-test script |
| `scripts/` | Shell helpers for local toolchain setup |

## Getting started

You need the Flutter SDK (the app is developed on 3.47.9, stable; `app/pubspec.yaml` requires Dart `^3.13.7`). The Android toolchain is only needed to run on an Android device or emulator.

```sh
cd app
flutter pub get
flutter analyze
flutter test
```

`scripts/env.sh` sets `JAVA_HOME`, `ANDROID_HOME` and `PATH` for one shell, using Homebrew locations on macOS. Copy it and change the paths for your machine; it does not edit any shell profile.

The generated Drift file `app/lib/data/database.g.dart` is committed, so a fresh checkout compiles without running code generation. After changing a Drift table, run `dart run build_runner build` in `app/`.

## Privacy and data

- No real person appears in this repository. Names in tests, fixtures, docs and examples are invented.
- Real family data, credentials, signing keys and environment configuration never go in the repository. See [docs/ENVIRONMENTS.md](docs/ENVIRONMENTS.md).

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first, especially the rules about data.

## History

An earlier Node and React family-tree prototype lived in this repository. It was removed when this project replaced it; it remains in the git history.

## License

Related is licensed under the [GNU Affero General Public License v3.0](LICENSE). If you run a modified version as a network service, the license requires you to offer its source to the people who use it.
