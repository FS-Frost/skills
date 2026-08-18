---
name: pedantry
description: Interrogation to close understanding gaps before implementing. Use it when you are not confident in a plan, when a term is ambiguous, when the scope is not closed, or when the user asks for pedantry. Triggers: "I'm not sure", plan with gaps, ambiguous term, fuzzy scope, "just do it" with no acceptance criteria, symptom without a confirmed cause, "/pedantry", "be pedantic".
argument-hint: "[topic] [plan] [request to interrogate]"
---

# Skill: Pedantry

Single goal: that the user and you describe **the same problem** before writing a single line of code. This is not a requirements interview. It is closing gaps that, left open, cause the wrong thing to be built.

Language: English.

## Two modes

This skill runs in one of two modes. Determine it before anything else.

**Forced mode** — the user invoked it explicitly (`/pedantry`, "use pedantry", "be pedantic") or passed arguments.

- TOPIC: the received arguments. If empty, apply to the last plan or request in this conversation.
- **Run even if your confidence is high.** Here your job is to *hunt* for the gap, not to declare there is none. Assume there is at least one and find it.
- **The read-only precondition does not apply.** Invoking it is the declaration that there is a pending implementation to interrogate.
- **"I found no gaps" is only valid** if it comes with the Agreement block, all seven points filled and verifiable against the code. Without that, you are not done.
- **Do not implement anything.** Forced mode ends at the Agreement, and its last line is the handoff line.

**Automatic mode** — you activated by threshold, without the user asking. The precondition and threshold of the next two sections govern.

## Precondition (automatic mode only)

Applies **only to requests that will mutate something**: code, schema, configuration, external state.

If the request is read-only —analyze, explain, compare, review, search, opine— **do not activate**. Answer. Blocking writes on something that does not write is theater.

## When to activate (automatic mode only)

Once the precondition is met, **always activate**. Every request that mutates something goes through pedantry before writing.

Single exception: trivial and precise requests (typo in a named file, mechanical rename, formatting). Pedantry over the obvious is noise. This skill is the sole authority over the activation threshold.

Upon activating, these signals indicate **which gaps to interrogate first** (they are not a gate — activation already happened):

- You cannot name the exact file/function/table to change → Terms and Scope.
- The user uses a term the code does not use, or that means something else in this repo → Terms.
- There are ≥2 reasonable readings of the request leading to different implementations → Problem and Scope.
- You cannot say how to verify it turned out right → Acceptance criteria.
- The request touches dangerous zones of the repo without enough detail (`migrations/`, `alembic/`, `auth/`, `.env*`, `docker-compose*`, credentials or MySQL/Mongo connections, vendored code) → Risk.
- The plan has a step whose "how" is a black box → Assumptions.
- The user describes a symptom and the cause is not confirmed → Problem.

If no signal applies and the seven gaps are already closed by the conversation itself, emit the Agreement block directly, with no rounds — being pedantic does not force you to ask, it forces you to close the gaps in writing.

## Blocking rule

**While a gap is open: zero writes.** No `Edit`, no `Write`, no state-mutating commands.

Allowed: reading, searching, `glob`, read-only commands, and updating the repo's `CLAUDE.md` with what the Agreement decided (see Closure) — the only permitted write.

Tell the user in one line what is blocked and exactly what is missing to unblock it. Do not leave it implicit.

Mandatory order: read-only exploration of the repo → questions in rounds of ≤4, as many rounds as needed → Agreement block. Zero edits before the Agreement.

## Code first, user second

Every question the repo can answer **gets answered by reading the repo** — not by asking.

Before asking anything: read the repo with the available search and read tools (`Read`, `glob`, grep) — do not skip the reading.

Ask the user only what the code does not know: intent, priority, trade-off, scope, what "correct" means for the business.

## Question protocol

- Rounds of **at most 4** questions. Prefix each round with `Round N — open gaps: X/7` so convergence is visible and survives compaction.
- **Question form according to the gap**:
  - Closed answer space (choosing scope, choosing strategy, yes/no with consequences) → `AskUserQuestion`. Each option declares its consequence; the recommended one goes first and marked `(Recommended)`.
  - Open space (mapping terms, concrete scenario, XY) → plain-text question in the chat. Do not invent 4 fake options to force the widget.
- If an answer changes **what** you will ask next, that question goes alone.
- **No round cap**: run as many as needed to close the seven gaps. The progress condition is progress, not quantity. Progress = closing a gap **or** redefining/invalidating it (e.g. XY reveals the request was something else — zero gaps closed, but real progress). Stalling = **two consecutive rounds** with neither → close with an Agreement block — complete, or marked incomplete (see Closure) — instead of asking more.
- If the user answers "I don't know" (or equivalent), that counts as an open gap: note it and do not re-ask. It gets resolved by reading more code, proposing a concrete scenario, or stays empty in the Agreement.
- Forbidden to ask something the user already answered in this conversation.
- Every question must change the implementation. If the answer changes nothing, do not ask it.

## The seven gaps

Internal checklist. List for the user **only the missing ones**, not always all seven.

1. **Problem** — what hurts today, with a concrete case.
2. **Terms** — every noun in the request mapped to a real table/class/endpoint.
3. **Scope** — what gets touched.
4. **Out of scope** — what explicitly does NOT.
5. **Acceptance criteria** — how it is verified: command, endpoint or screen.
6. **Assumptions** — what you are assuming and the user must confirm or correct.
7. **Risk** — what breaks if an assumption is false.

## Techniques

- **Concrete scenario**: propose a case with fictional data (never real PII) and ask the user to say what should happen. Abstractions hide disagreements; concrete cases reveal them.
- **Contradiction with the code**: if the user states something the repo disproves, show `file:line` and ask which one rules.
- **Term-splitting**: split overloaded terms. "User" — the one who logs in or the beneficiary? They are different things.
- **XY**: if the request already arrives as a solution, ask for the problem behind it before accepting it.

## Closure — Agreement block

The seven gaps, one per line:

```
## Agreement
- Problem:
- Terms (request → code):
- Scope:
- Out of scope:
- Acceptance criteria:
- Confirmed assumptions:
- Accepted risk:
```

It goes in the chat. Then, **integrate the decisions into the repo's `CLAUDE.md` by updating whatever applies**:

- Mapped term the file does not declare → add the definition where the file documents vocabulary or conventions.
- Decision that sets a durable rule ("always X", "never Y") → add it to the existing rules section.
- Confirmed assumption that contradicts something the file states → fix that line in place; do not duplicate or accumulate versions.
- The task's ephemera (acceptance criteria, one-off scope, this implementation's risk) **is not stored** — it lives in the chat.
- If the Agreement produces nothing durable, do not touch the file. An `incomplete — reformulate` Agreement is never integrated: there are no decisions.

If the repo has no `CLAUDE.md`, ask for authorization to create it before writing. Do not create other files in the repo.

If a round ends without closing any new gap (see Protocol), the problem is fuzzy: emit the block with what you have and head it `## Agreement: incomplete — reformulate`, listing which lines stayed empty and why. That is a valid closure: you ask the user to reformulate the problem from scratch, you do not keep asking nor loop trying to fill the seven points.

Contradictions with `CLAUDE.md` are resolved in that same integration. If the agreement contradicts something `README.md` declares, ask the user for authorization to update it — do not edit it on your own initiative.

## Exit and handoff

You exit when the seven gaps are closed, or when the user says "enough, move on". In that second case: declare in writing the assumptions left open and move on without insisting again.

Always end with this line, literally:

`Agreement closed. Say "continue" to implement according to this agreement.`

## Worked example

**Request**: "we need to fix the transcriptions timeout".

Repo reading first — searching the code for `timeout` yields two distinct timeouts: one in the HTTP client (`client.py:44`, 30s) and one in the queue worker (`worker.py:112`, 300s). That turns a fuzzy request into a question with a closed answer space.

**Round 1 — open gaps: 4/7** (`AskUserQuestion`, 2 questions):
- Which timeout is failing? → `client.py:44` (30s, cuts long audios) *(Recommended — matches the symptom)* / `worker.py:112` (300s) / both.
- Raise the limit or split the audio into chunks? → raise limit (1 line, risk of hung connections) / chunking (real change, works for audios of any length).

Answers: `client.py`, chunking. One acceptance-criteria gap remains open → plain text, no widget:

> With what concrete case do we declare it solved? E.g.: a 25-min audio goes through `POST /transcribe` and returns the full text with no 504.

Confirmed. Closure:

```
## Agreement
- Problem: audios >~8 min die with 504; the 30s timeout at client.py:44 cuts the request.
- Terms (request → code): "transcriptions timeout" → client.py:44, not worker.py:112.
- Scope: client.py (audio chunking), client tests.
- Out of scope: worker.py, the queue timeout, the UI.
- Acceptance criteria: POST /transcribe with a 25-min audio returns 200 and the full text.
- Confirmed assumptions: the STT backend accepts partial chunks and order is preserved.
- Accepted risk: if the STT does not preserve order across chunks, the text comes out scrambled — caught by the 25-min test.
```

`Agreement closed. Say "continue" to implement according to this agreement.`

## Stalling example

**Request**: "the system is slow, optimize it".

Repo reading reveals no obvious bottleneck. Round 1: slow where — endpoint, screen, job? → "in general". A concrete case: which action, how long does it take, how long should it? → "I don't know, it feels slow". Zero gaps closed; "I don't know" noted as an open gap. Round 2 with a proposed concrete scenario: "does `POST /transcribe` with a 5-min audio take >30s?" → "not that I know". Second consecutive round without closing or redefining anything → stalling. There is no round 3: you close.

```
## Agreement: incomplete — reformulate
- Problem: (empty — no measurable concrete case; "slow in general" is not reproducible)
- Terms (request → code): "the system" unmapped to endpoint/screen/job.
- Acceptance criteria: (empty — without a concrete case there is no possible verification)
- ...
```

And you ask to reformulate: "I need a concrete case: a specific action, how long it takes today and how long it should take. With that we reopen."

## Antipatterns

- Asking for the sake of asking to look rigorous.
- Accumulating history in `CLAUDE.md` instead of updating the lines that apply.
- Turning it into a 30-point questionnaire.
- Asking what can be answered by reading the repo.
- Forcing `AskUserQuestion` on open questions, inventing options.
- Repeating the block every turn without adding anything new.
- Staying pedantic after the user closed the topic.
- Activating on a read-only request (automatic mode only).
- In forced mode: declaring "there are no gaps" without the complete Agreement, or implementing anything.
