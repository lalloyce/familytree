# Spike 3: airplane-mode matrix

Design doc section 10, spike 3. Five rows. The Dart column is a simulation of the logic with a fake network (`test/matrix_test.dart`). The on-device column is for the founder to fill in on a physical Android phone. **No on-device cell has been run. Nothing in the on-device column is a pass.**

| # | Scenario | Dart simulation result | On-device result (founder, awaiting phone) |
|---|----------|------------------------|--------------------------------------------|
| 1 | Empty token pool at invite time | Simulated, passes: offline with an empty pool `bindClaim` returns `BindPoolEmpty`, no code, no link, nothing queued, no token spent, no network call. After signal the pool fills (20) and the same claim binds offline. A pool of 20 gives 20 distinct codes, the 21st is `BindPoolEmpty`. | awaiting phone |
| 2 | Redeem with no signal | Simulated, passes: a valid code entered offline is queued, `sync` returns false, and the screen holds only `saved, we will connect when you have signal`. No inviter name, no claim, no tree. | awaiting phone |
| 3 | App installed from a link where the install referrer is missing | **Awaiting phone.** Cannot be simulated in Dart: it needs an Android install from a link. The matrix test is present and marked skipped. | awaiting phone |
| 4 | Typed code with one wrong symbol | Simulated, passes: the code with any one of its 9 symbols changed is refused at entry, offline, with `That code has a typo. Check it and try again.`, stored nowhere, and no network call is made. The exhaustive substitution and swap checks are in `code_test.dart` (see README). | awaiting phone |
| 5 | Right symbols, then signal returns | Simulated, passes: the code is queued offline (lowercase and grouped input accepted). When signal returns, redemption completes. The redeemer then sees `waiting for the person who invited you to confirm`, the inviter's name and the claim line, and **no tree**. Self-confirm and a stranger's confirm are refused. After the named relative (or the inviter) confirms, the next sync shows the tree. A binding that reaches the server after the redemption also leaves the redeemer with nothing until confirmed. | awaiting phone |

## What the demo APK can and cannot show on a phone

Read this before running the rows.

- The demo app (`app/`) uses the in-memory fake network. It makes **no real network call**. Its **Signal** switch is a simulated network. Phone airplane mode does not change what the app does. Run each row with the Signal switch off, and also with airplane mode on, so the record says the app needed no radio.
- What an on-device run can show: the screens, the keyboard and text entry on a real phone, and that the offline path never needs the radio. It cannot show a real backend.
- State is in memory. Closing the app clears the pool, the queue and the saved code. A real invite needs these persisted. That is M3 work and is not tested here.
- The app has no link handling and no Play Install Referrer code. Row 3 cannot be run as the spec describes until that is built. See the row 3 procedure for what can be checked.

## Build and install

```
source scripts/env.sh
cd spikes/invite/app
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

(Row 3 uses a different install, see below.)

## Procedures

Record the result in the on-device column as `pass`, `fail` or `not run`, with the phone model, Android version and the date. Write what you saw if it differs from the expected result.

### Row 1: empty token pool at invite time

1. Fresh install, or force-stop and reopen the app so the pool is empty (state is in memory).
2. Turn phone airplane mode on. Leave the app's Signal switch **off**.
3. Open **Create invite** and tap **Create invite**.
4. Expected: the text `No invite codes are ready. Connect to the internet once to get more, then try again.` No typed code, no link. `Tokens in pool: 0`.
5. Switch Signal **on**, tap **Sync (needs signal)**. Expected: `Tokens in pool: 20`.
6. Switch Signal **off**, tap **Create invite**. Expected: a typed code like `XXXX-XXXX-X` and a link that contains the code and nothing else after `/i/`. `Tokens in pool: 19`.

### Row 2: redeem with no signal

1. Fill the pool as in row 1 steps 5 to 6 (Signal on, **Sync**, then **Create invite**). Note the typed code.
2. With Signal still on, tap **Sync (needs signal)** once more, so the inviter's binding is uploaded (`Bindings waiting to upload: 0`).
3. Switch Signal **off** and turn phone airplane mode on.
4. Open **Enter code**, type the code, tap **Save code**.
5. Expected: the only status text is `saved, we will connect when you have signal`. No inviter name, no claim, no list of people.

### Row 3: app installed from a link where the install referrer is missing

This row is **awaiting phone** and is **not fully testable with this app**: the app has no link handling and no install referrer code.

What the founder can check with the demo app, on a phone:

1. Install the APK as a file (for example `adb install`, or copy it to the phone and open it). A file install has no Play install referrer. The design doc already assumes this for an installed-file pilot.
2. Complete row 1 steps 5 to 6 and row 2 steps 1 to 2 to get a code, then open **Enter code**.
3. Expected: the app does not depend on a referrer. Typing the code works exactly as in rows 2 and 5.

Not checked, needs building first: opening an invite link on the phone, reading the token from the link or from the install referrer, and what the app shows when the link opened the app but no referrer was delivered.

### Row 4: typed code with one wrong symbol

1. Get a code as in row 2 step 1. Turn phone airplane mode on and Signal **off**.
2. Open **Enter code**. Type the code with one symbol changed, then tap **Save code**. Try a change in the first symbol, a middle symbol and the last symbol. Then try two neighbouring symbols swapped.
3. Expected each time: `That code has a typo. Check it and try again.` shown under the field. No status text appears below the buttons. Nothing is saved.

### Row 5: right symbols, then signal returns

1. Get a code and upload its binding as in row 2 steps 1 to 2. Switch Signal **off**, phone airplane mode on.
2. In **Enter code**, type the code correctly (lowercase and hyphens are fine) and tap **Save code**. Expected: `saved, we will connect when you have signal`.
3. Turn airplane mode off, switch Signal **on**, tap **Check for signal**.
4. Expected: the status reads `waiting for the person who invited you to confirm`, with `Invited by Zuri: cousin of Otieno through his father`. **No list of people.**
5. Open **Create invite**, tap **Confirm last invite (as inviter)**. Return to **Enter code** and tap **Check for signal**.
6. Expected: now `Rafa`, `Kito` and `Otieno` appear.

Design question this row raises, not decided here: step 4 shows the inviter's name and the claim to someone who has only a code, before anyone has confirmed. That follows design doc section 6, flow 4 ("See who invited you and the claim"). Whether the claim should wait until confirmation is for the founder.
