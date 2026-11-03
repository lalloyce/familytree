# Spike 3: offline invite

Throwaway, except `code.dart`, which graduates to M3.

Question: can an inviter hand over a relationship with no signal, can the invitee type it with no signal, and does the redeemer see nothing of the tree until someone confirms? Design doc section 9 ("Offline invite", "Redeeming an invite"), section 6 flows 3 and 4, section 10 spike 3.

**Status: the logic is simulated in Dart. The on-device airplane-mode matrix has not been run (no phone yet). See `matrix.md`. Row 3 is awaiting phone.**

## Layout

- `code.dart`, `code_test.dart`: the invite code. Standalone Dart, no Flutter. Graduates to M3.
- `lib/`: pure-Dart invite logic over an injectable network (`InviteNetwork`, with `FakeInviteNetwork` for tests): `TokenPool`, `Inviter.bindClaim`, `Redeemer` (typed-code entry, redeem queue). `lib/code.dart` is a symlink to `../code.dart`, because a package's `lib/` cannot import a file outside `lib/`. It is a git symlink: M3 must `git mv` the real `spikes/invite/code.dart` and `code_test.dart` to their M3 home and drop the symlink. On a Windows checkout without `core.symlinks` the symlink degrades to a text file containing the path.
- `test/`: the matrix simulation (`matrix_test.dart`) and unit tests (`invite_logic_test.dart`).
- `app/`: a minimal Flutter Android app with two screens (create invite, enter code) over the logic and the fake network.
- `matrix.md`: the five rows, the Dart results and the on-device procedure.

## Run

```
source scripts/env.sh
cd spikes/invite
dart pub get
dart test code_test.dart test/      # the repo-root path `dart test spikes/invite/...` finds no pubspec
cd app && flutter test && flutter build apk --debug
```

## Checksum note

An invite code is 8 token symbols plus 1 check symbol from a 31-symbol alphabet (digits 2 to 9, letters A to Z without I, L, O). Check = (sum over positions i from 0 of symbolIndex(i) x (i+1)) mod 31.

**Why single substitutions and adjacent swaps are always caught.** 31 is prime and the weights are 1 to 8, so no weight is 0 mod 31.
- Changing token symbol i by d (0 < d < 31) changes the sum by d x (i+1), never 0 mod 31, so the stored check no longer matches. Changing the check symbol alone also fails.
- Swapping neighbours a, b at weights w and w+1 changes the sum by (a - b), which is non-zero mod 31 when a and b differ. Swapping the last token symbol with the check symbol is caught unless the two are equal.

**Property tests run** (`code_test.dart`):
- Single substitution, one fixed code: all 9 positions (8 token + check) x 30 other symbols = **270 of 270 rejected**.
- The same over **500 codes** drawn with a fixed seed (`Random(20261103)`, eight random base-31 digits each, so spread over [0, 31^8)): **135,000 of 135,000 rejected**. The test asserts the codes' first-two-symbol prefixes take more than 100 distinct values, so a narrow range cannot pass unnoticed.
- Adjacent swap, one fixed code: **8 of 8** adjacent pairs differ and **8 of 8 rejected**. Over the 500 codes, **3,882** adjacent different-symbol swaps (the test computes this count from the generated codes), **3,882 rejected**.
- Exhaustive adjacent swap at token positions 0 to 6 (rest of the code fixed): all 31 x 30 ordered different pairs at each of the 7 positions = **6,510 of 6,510 rejected**.
- Swaps of two equal symbols are not tested: they do not change the code.

**What the checksum does not catch** (inferred from the formula, not tested): two or more wrong symbols can cancel (about 1 in 31 for random double errors), and swaps of non-adjacent symbols can pass. A code that passes the checksum can still be a token the server never issued. The server refuses those at redemption (tested).

**Token capacity.** A 5-byte token has 40 bits, but 8 base-31 symbols hold 31^8 = 852,891,037,441 values (about 39.6 bits), and 2^40 = 1,099,511,627,776 is larger. `encodeInviteCode` reduces the token modulo 31^8. The brief did not specify how 40 bits map to 31-symbol digits. The server must issue only tokens below 31^8 (`isCanonicalToken5`); `FakeInviteNetwork` does. Then encoding is one-to-one and `decodeInviteCode` returns the same bytes (tested). M3 should settle this with the real token format, for example by issuing 8-symbol values directly.

## Open decisions for the founder

Reviewer and implementer observations, not decisions.

- **(a) Flow 4 claim visibility.** After redeeming and before confirmation, the redeemer sees the inviter's name and the claim text ("cousin of Otieno through his father"), as design flow 4 says. Design section 9 says the redeemer sees nothing of the tree until confirmation, and the claim names a tree person. Options: show the inviter's name only until confirmation; show the claim with the named relative redacted; or as built. No test currently pins the choice.
- **(b) Token width.** 31^8 is about 39.6 bits, so the brief's 40-bit token is reduced modulo 31^8, which is not injective. M3 must issue 8-symbol values directly or make encode throw on a non-canonical token. M3 must also persist the token pool and the outbox atomically with `take()`, and must not clear the outbox after an `await` (a binding added during the upload would be lost).

## Findings for the design

- Flow 4 shows the redeemer the inviter and the claim before confirmation. A person who holds only a code therefore learns one relationship line. The tree stays hidden. Founder decision.
- Guessing: the token space is 31^8, about 8.5e11 values, and holding a code is not enough without confirmation (section 9). Rate limiting on redemption is not simulated here. [inference, not tested]
- The demo app keeps all state in memory. Persisting the pool, the outbox and the redeem queue in the encrypted database is M3 work.
