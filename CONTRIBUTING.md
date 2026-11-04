# Contributing to Related

Thank you for helping. This guide is short on purpose. If something is unclear, open an issue and ask.

## Ground rules about data

This repository is public and the app handles family history, which is sensitive. These rules are not negotiable:

1. **No real people.** Do not commit real names, family chains, phone numbers, email addresses, photos, or anything that identifies a living or dead person. Tests, fixtures, docs and screenshots use invented names only. If you reproduce a bug from your own family's data, rewrite it with invented names first.
2. **No secrets.** Never commit passwords, tokens, API keys, signing keys, keystores or database files. See [docs/ENVIRONMENTS.md](docs/ENVIRONMENTS.md) for where configuration lives instead.
3. **No local paths or machine details** such as your home folder in docs or scripts. Use placeholders like `<repo-root>`.
4. **Keep private material in `private/`.** That folder is git-ignored. Check `git status` before you commit.

If you notice real personal data already in the repository, do not discuss it in a public issue. Contact the maintainer privately through their GitHub profile.

## Reporting security problems

Do not open a public issue for a vulnerability. Contact the maintainer privately through their GitHub profile and include steps to reproduce. Please do not share real family data in a report.

## Setting up

Follow [Getting started](README.md#getting-started) in the README. Before you send a change, run both of these from `app/` and make sure they are clean:

```sh
flutter analyze
flutter test
```

If you change code under `spikes/`, run that spike's tests as well (each spike has a README that says how).

## How the project makes decisions

The design document, [docs/2026-11-03-lineage-app-design.md](docs/2026-11-03-lineage-app-design.md), is the authority. The plan in `docs/superpowers/plans/` argues from it. If your change conflicts with either, say so in the issue or pull request and propose the change to the document. Do not work around it silently.

## Code style

- Match the surrounding code: naming, comment density and idiom.
- Claims are append-only. Only a claim's `status` is ever updated. Ordering uses `localSeq`, never the device clock.
- Screen wording is part of the design. The words "step" and "half" must not appear in user-facing strings under `app/lib/tree` or `app/lib/ui`. A test enforces this.
- Prefer small, focused files with one responsibility.

## Pull requests

- One concern per pull request. A small pull request is reviewed faster.
- Add or update tests with the change. For a bug, add the test that fails first.
- Describe what changed and why. Say what you did not verify, such as a device you could not test on.
- Be honest about results. Do not describe a laptop measurement as a phone result.
- Write commit messages that say what the commit does, in the imperative mood.

## License of contributions

Related is licensed under the [GNU Affero General Public License v3.0](LICENSE). By submitting a contribution you agree that it is licensed under the same license.
