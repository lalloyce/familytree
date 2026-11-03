# Paper Test: Reading the Family Chain Aloud

Design reference: sections 4, 7, 10 and 14 of `docs/2026-11-03-lineage-app-design.md`.

## Why we do this

The app's default view is the "spoken chain", a plain list that reads like the way the family says its lineage aloud. That rests on an assumption: that people think in chains, not charts. This test checks the assumption before anything is built. It also checks one more assumption: that relatives have an email address they can open on their phone.

Nothing is installed. Nobody uses an app. You read, you ask, you write.

## Who and how

- Test with three to five relatives. Include older and younger people.
- Use English. Luo is a later test, because the first release is English only.
- Test one person at a time, in a quiet place. Do not let others call out answers.
- You need: this script, one recording sheet per relative (the last section), a pen, and a phone or watch that shows seconds.
- Do not explain the app. Do not hint at the answers. If a relative asks what a word means, write down the question and say "what do you think it means?"
- Say thank you at the end. If a person prefers, record initials or nothing in the name box.

## Before you start (about one minute)

Read this aloud:

> "I am working on a way for our family to write down who is related to whom. Before I build anything, I want to hear how you say things. There are no wrong answers. If I say something the wrong way, please tell me."

On the recording sheet, fill in the name or initials, the age band, and phone use.

## Part A: The spoken chain

**Goal:** find out whether the chain reads the way the family says it.

**Step 1.** Read this aloud, slowly, once:

> "Myself, son of Juma, son of Manyi, son of Winyo, son of Ochieng, son of Winyo, son of someone we forgot."

**Step 2.** Ask:

> "Is that how you say it?"

**Step 3.** Let the person answer in their own words. Write down every correction word for word, in the box on the sheet. Include small changes, such as a different word for "son of", a different order of names, or a name said another way.

**Step 4.** Read the chain again as a list, one line at a time. Pause after each line and ask "is that how you say it?" Write down any correction against the line number.

1. Myself, son of Juma
2. Juma, son of Manyi
3. Manyi, son of Winyo, house 2
4. Winyo, son of Ochieng
5. Ochieng, son of Winyo
6. Winyo, son of someone we forgot

Note for the reader: two different men are called Winyo. Lines 4 and 5 are about Manyi's father and his grandfather, so do not stop to explain. If the person gets confused about which Winyo, write that down. It is a result.

**Step 5.** Ask these three questions, one at a time. Write the answers word for word.

- "When I say 'house 2', what does that mean to you?"
- "Is there a word you would use instead?"
- "Would you rather hear this as a list like this, or see it drawn as a family tree?"

Do not suggest an answer to any of them.

## Part B: Winyo's four houses

**Goal:** find out whether a person can read the house idea from paper, and how long it takes.

**Step 1.** Show this page to the person. Hand it over. Do not read it aloud.

---

**WINYO had four wives. Each wife and her children make one house.**

| House | Wife | Children |
|---|---|---|
| House 1 | not known yet | not known yet |
| House 2 | Atieno Nyang'or | Manyi, Wade |
| House 3 | not known yet | not known yet |
| House 4 | not known | Owala |

---

**Step 2.** Start the timer. Ask:

> "Who is Manyi's full brother?"

Stop the timer when the person gives an answer. Write down the answer and the seconds. Do not say whether it was right until the sheet is filled in.

**Step 3.** Start the timer again. Ask:

> "Who is only a brother through the father?"

Stop the timer at the answer. Write down the answer and the seconds.

For your own reference: the answer to the first question is Wade (same house, same mother). The answer to the second is Owala (same father, different house). Winyo's other sons, if any, are in houses 1 and 3, which are not known.

**Step 4.** After both answers, ask:

> "Was that easy, or did you have to think?"

Write down the answer word for word.

## Part C: Email on the phone

**Goal:** check the sign-in assumption in design section 14. The founder chose email sign-in for simplicity. It has not been tested against the people who will use it.

Ask these questions, one at a time:

1. "Do you have an email address?"
2. If yes: "Can you open it on your phone, right now, without help?"
3. If no, or if unsure: "Does anyone else in your house open email for you?"
4. "Do you use WhatsApp?" (This is context only. It does not change the sign-in plan.)

Write down yes, no or unsure for each, and any words the person used. Do not suggest that they should get an email address.

## After each session

Within the hour, while it is fresh:

1. Read the sheet back. Make sure each correction is written exactly as the person said it, not as you remember it.
2. Add anything you noticed that you did not ask about, such as hesitation, laughter, or a person who did not recognise a name.
3. Copy the result into the summary tables below.

## What the result changes

Use this list when you fill in the decision line.

- **Wording corrections.** If relatives say the chain differently (a different word for "son of", a different order, a different way to say the house), the line formats in plan Task 12 change to match before Task 12 starts. Record the corrected wording exactly.
- **"It does not read like how we say it."** If several relatives say the chain does not sound like their own speech, the default view in design section 7 changes. The spoken chain stops being the default and the family decides what replaces it (for example the diagram, or a different list format).
- **"House" is not understood.** If relatives cannot read the house idea in Part B, the house wording and the Family tab's house view in design section 7 need rework before Task 13.
- **Email problem.** If one or more relatives cannot open email on their phone, the sign-in assumption in design section 14 stays marked as unverified and fails. Record who, and raise it before the server work in M2.

## Results (founder fills in)

Nothing below has been filled in. Do not copy any answers from this script.

### Table 1: Who was tested

| # | Name or initials | Age band | Phone use | Date |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |

### Table 2: Part A, the spoken chain

| # | Said "yes, that is how we say it"? (yes / no / partly) | Corrections, word for word | Meaning of "house 2" in their words | Prefers list, tree or neither |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |

### Table 3: Part B, the four houses

| # | Answer: full brother | Seconds | Answer: brother through the father only | Seconds | Easy or hard, in their words |
|---|---|---|---|---|---|
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |
| 4 | | | | | |
| 5 | | | | | |

### Table 4: Part C, email

| # | Has email? | Can open on phone? | Someone else opens it? | Uses WhatsApp? |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |

### Wording to carry into Task 12

(Write the corrected line format here if any relative changed it. Leave blank if none.)

### Decision

Decision: pending. Options: spoken chain stays default | change to: ___

---

## Recording sheet (copy this page once per relative)

**Relative number:** ______   **Date:** ______________   **Place:** ______________

**Name or initials:** ______________________   (Leave the name off if the person prefers.)

**Age band** (circle one): under 25   25 to 39   40 to 59   60 and over

**Phone use** (circle one): smartphone, daily   smartphone, sometimes   basic phone only   none   Other: ______________

### Part A: The spoken chain

Is that how you say it, for the whole chain? (circle) yes   no   partly

Corrections to the whole chain, word for word:

________________________________________________________________

________________________________________________________________

Corrections by line (write the line number, then what they said):

| Line | What they said |
|---|---|
| 1 Myself, son of Juma | |
| 2 Juma, son of Manyi | |
| 3 Manyi, son of Winyo, house 2 | |
| 4 Winyo, son of Ochieng | |
| 5 Ochieng, son of Winyo | |
| 6 Winyo, son of someone we forgot | |

"When I say 'house 2', what does that mean to you?"

________________________________________________________________

"Is there a word you would use instead?"

________________________________________________________________

List or family tree? (circle) list   tree   either   neither      Their words: ______________________

### Part B: Winyo's four houses

| Question | Their answer | Seconds |
|---|---|---|
| Who is Manyi's full brother? | | |
| Who is only a brother through the father? | | |

"Was that easy, or did you have to think?" Their words:

________________________________________________________________

### Part C: Email on the phone

| Question | yes / no / unsure | Their words |
|---|---|---|
| Do you have an email address? | | |
| Can you open it on your phone, without help? | | |
| Does anyone else open email for you? | | |
| Do you use WhatsApp? | | |

### Other things I noticed

________________________________________________________________

________________________________________________________________

**Total time for the session (minutes):** ______
