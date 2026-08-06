# The orchestra: user manual
Version 1.12.0

---

## 1. Install (once per machine)

1. Unpack the repository anywhere - the folder name does not matter.

2. In PowerShell, from the root of the unpacked folder:
   ```
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```
   The script works out its own path, registers the `orchestra` command in
   your profile and clears the "downloaded from the internet" mark from the
   `.ps1` files. Running it again is safe: the block in your profile is
   replaced, not duplicated.

3. Restart PowerShell. Check with `Get-Command orchestra`.

4. If scripts are blocked by policy (an error on start), once:
   ```
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   ```

To take the command back out: `.\install.ps1 -Uninstall`.

### 1a. macOS and Linux

The shell installer is `dist/orchestra.sh`. There is no registration script
for it yet, so put it on your PATH by hand - a symlink is enough, because the
installer resolves the link before looking for its payload:

```sh
chmod +x dist/orchestra.sh
mkdir -p ~/.local/bin
ln -s "$PWD/dist/orchestra.sh" ~/.local/bin/orchestra
```

The options are spelled with a double dash: `--update`, `--status`,
`--promote`, `--no-banner`. Your shared seed lives in
`${XDG_DATA_HOME:-~/.local/share}/design-orchestra/seed` rather than under
`%APPDATA%`.

**`-Share` has no shell equivalent - it is Windows-only for now.** The reason
is in section 6c: it prepares text for a public issue, and its anonymisation
relies on lookbehind and on a deliberate case-sensitivity split that POSIX
tools do not have. A shell version would be a re-implementation whose output
differs in ways nobody could enumerate, and two different privacy floors
depending on which OS you happened to use is worse than one platform not
having the feature. `orchestra.sh --share` says exactly that and exits
non-zero.

Requirements: Claude Code + Figma MCP (remote), a Dev or Full seat on a
paid Figma plan.

---

## 2. Connecting a project (once per project)

```
cd C:\path\to\your\project
orchestra
```

This creates an isolated build: its own agents (`.claude\`), its own brain
(`brain\`), and a `specs\` folder. Projects cannot see each other.

Maintenance commands:

| Command | What it does |
|---|---|
| `orchestra` | install the orchestra into the current project |
| `orchestra -Status` | version, brain state, journal entry count, path to your seed |
| `orchestra -Update` | update the agents to the distribution version; brain, passport and specs are untouched. Files you edited are not lost: before being overwritten they are copied to `<file>.bak` and listed |
| `orchestra -Promote` | this project's personal rules -> your shared seed (`%APPDATA%\design-orchestra\seed\`); new projects only |
| `orchestra -Share` | propose marked rules and this cycle's portable findings to the public seed: confirmation per item, findings anonymised before you see them, `PROJECT.md` never read, submitted by hand. See section 6c. **Windows only**, see section 1a |
| `orchestra -NoBanner` | install without the ASCII banner. The banner appears on a **first install only** - never on `-Status`, `-Update`, `-Promote`, `-Share` or a repeat run - so this switch matters for scripted installs, or if you simply want the output shorter. Colour already turns itself off when `NO_COLOR` is set, when `TERM=dumb`, or when the output is piped to a file |

---

## 3. How to hand over information

### The spec - a file in specs\
Copy `specs\_template.md`, fill it in, save it as
`specs\2026-08-feature-name.md`. The fuller the "States and errors" section,
the fewer questions at Pause 1. PDFs work too - put one in specs\ and pass
the path.

### A style reference - for /foundation
The best input is code: HTML/CSS from Stitch, an export, tokens.json.
Put the file in the project (say `refs\style.html`) and pass the path.
A screenshot is accepted too, but the values will be eyeballed - the
orchestra will warn you and ask you to verify the hex values.

### A brief - for /concept
As text right in the command, or as a file. What is needed: product and
audience in one sentence, which page is the key one, 3 mood words,
anti-references, real content (if you have it). Whatever is missing, the
orchestra will ask for - all at once, in one list.

### Figma links
In Figma: select a frame -> right click -> Copy link to selection
(Cmd/Ctrl+L). Paste it straight into your reply when the orchestra asks.

---

## 4. Working commands (inside Claude Code)

Starting a session always looks the same:
```
cd C:\path\to\your\project
claude
```

### /start - the entry point

If you are not sure which of the commands below you want, type `/start` and
nothing else. It asks, then runs the mode you picked. Five steps:

1. **Orientation.** Reads `PROJECT.md` and the listing of `specs/` - names
   only. It does NOT call the Scout: that is a full diagnosis and an
   expensive one, and the mode you end up in runs its own anyway.
2. **The question.** The four modes as a numbered list, one line of
   explanation each. A mode that cannot work here is marked unavailable
   with the reason on the same line - no `PROJECT.md` or `Mode:
   from-scratch` blocks Feature (nothing to build from), an empty `specs/`
   says so too. It never picks for you, however obvious the answer looks.
3. **The inputs.** Only what is missing, one short question at a time. For
   Feature the specs in `specs/` are listed **numbered** and you answer with
   a number - no typing out paths. For Foundation, the reference path or
   link. For Concept, the brief - and if you do not know what to write, the
   whole brief questionnaire arrives as one list. For Log, what you changed.
   The Figma link is only asked for if the mode needs it and the passport
   does not already have it.
4. **Handover.** It reads the chosen mode's skill and runs it with what it
   collected. Nothing is duplicated inside `/start`; from here on the
   session behaves exactly as if you had typed the mode's own command.
5. **After.** One paragraph pointing at `orchestra -Share`. It does not run
   it and sends nothing.

The commands below are the same four modes, reachable directly - for when
you already know which one you want.

### /feature specs/name.md - the main mode
Building a feature's mockups from a spec. For projects that already have a
design system and mockups.

The chain and the points where you step in:
```
Scout (passport) -> Spec Analyst (plan + gaps)
   PAUSE 1: you confirm the plan and answer the spec gaps
UX Advisor (decisions + contentious points)
Builder (draft in Figma, contentious parts as 2 options)
Spec Analyst (review) -> Panel (5 respondents on contentious points)
Spec Analyst (review of the panel's conclusions) -> Builder (fixes)
Spec Analyst (final coverage table)
   PAUSE 2: your review. You fix the mockups by hand, then write
   "review finished"
Chronicler (journal + proposed rules - you approve them)
```

An option after the final review: the **exit test** - the orchestra will
ask whether to run it. Three synthetic users walk the whole scenario; the
report covers extra actions against the minimal path, sticking points, flow
breaks (they reached a state that does not exist in the build) and screen
complexity. There are never seconds in that report - the model has no
perception of time, so actions are what get measured. It is a prediction,
not a measurement: you still need real users before release.

What you get: a page "Feature - vN - date" with every state, "why"
annotations on the frames, a spec coverage table, a changelog entry, and a
manual-polish list.

### /concept - visual concept (greenfield)
2-3 directions for one key page, to agree on. No design system yet, raw
values are legal. A pause to choose directions in words, before the
expensive build. Result: "Concept A/B" pages plus a passport for each
direction to defend it. The approved HTML becomes an exact reference for
/foundation.

### /foundation <reference> - the design system foundation (greenfield)
From a reference: variable collections in Figma (Primitives + Semantic with
Light/Dark), DTCG tokens in the repository, 6 base components with their
states. Pauses: validating token names (which blue is the accent is your
call), and a look at each component. After this the project is in full-ds
mode and /feature works.

### Routing - automatic
The Scout works out the state of the project:
- library + mockups -> /feature works right away
- mockups without a system -> it offers to extract the system from them
- empty -> /feature stops and points you at /concept or /foundation

### /log <what you changed> - out-of-cycle edits
Fixed something by hand outside the cycle ("tomorrow", after handover)?
Log it: `/log changed the card padding, it felt cramped`.
Otherwise the learning loop never sees that edit. The Chronicler will check
by itself whether the edit breaks an existing rule, and propose a new one
if the edit repeats.

### Claude Code housekeeping
`/clear` between tasks (do it). `/context` if it seems to have forgotten
the rules. `/rewind` to roll files back. Shift+Tab for plan mode on manual
work outside the orchestra.

---

## 5. Your pauses: what to answer

The orchestra stops and waits. Answer formats:

- Pause 1 (plan): "yes" / "yes, but screen X is not needed" / answers to
  the spec gaps as a list. Nothing is built until you answer.
- Contentious points: "point 1 - option A, point 2 - send it to the panel".
- Pause 2 (review): fix the mockups by hand in Figma as usual, then write
  "review finished" - that is the Chronicler's trigger.
- Proposed rules: "rule 1 - yes, rule 2 - no, rule 3 - yes but reword it
  as ...". Only what you approve enters the brain, word for word.

---

## 6. The brain and versions

- `brain\rules\` - rules (general + personal). Grown only through the
  Chronicler, with your approval.
- `brain\journal\` - review history. Do not edit by hand.
- `brain\precedents\index.md` - the project's precedents.
- `CHANGELOG-DESIGN.md` plus the "Changelog" page in Figma - feature
  versions. The file wins. Status goes draft -> approved after your
  "approved" at Pause 2.
- Learning metric: the share of frames untouched in review. The Chronicler
  reports the trend. If it falls, it is obliged to say so.

---

## 6c. How rules leave your machine

Two different channels - do not mix them up:

**`orchestra -Promote` - to you only.** Takes rules from this project's
`brain\rules\personal.md` into your personal seed at
`%APPDATA%\design-orchestra\seed\`. NEW projects pick it up on install.
No network is involved, nothing goes outside. The seed lives outside the
orchestra repository on purpose: otherwise private rules would end up in a
git working tree.

**`orchestra -Share` - to a public repository.** It only works with rules
whose marker sits on **their own line**:

    - Show validation errors at the field (promote candidate)

Then, step by step:
1. The orchestra prints each candidate rule and asks y/n.
   **An empty answer means "no".** There is no longer a single "yes" for
   the whole list.
2. If a line looks like project data (a link, a node id, a hex, a fileKey),
   a hint is printed next to it. It is a hint, not a safeguard: it will not
   catch a client's or an internal system's name. Look yourself.
3. A list of what is **not** going out is printed: both your refusals and
   every unmarked rule. Skim it - if a rule landed in the wrong list, you
   will notice here.
4. An issue form opens with the text prefilled. A copy of the text goes to
   `%TEMP%\orchestra-share.md`. You press the button.

Set the destination once:

    $env:DESIGN_ORCHESTRA_REPO = "https://github.com/<login>/design-orchestra"

### What else -Share offers, besides rules

After the rules, `-Share` offers this cycle's **portable findings** - the
parts of a build that are useful to someone else's project and carry no
product detail:

- contentious-point decisions and source conflicts, from
  `CHANGELOG-DESIGN.md`;
- exit-test findings - sticking points, frequencies, flow breaks - from
  `EXIT-TEST*.md`.

Only **whitelisted sections** of those files are read; a file is never
shipped whole. A section you invent yourself is not read, so anything you
want kept out can simply live under its own heading.

Each finding goes through the same ceremony as a rule: printed on its own,
y/n, empty answer means no, and listed afterwards under "NOT BEING SENT" if
you refused.

The difference is that findings are **anonymised before you see them**, not
after you approve them. Emails, links (Figma, Linear, anything `http`),
node ids, instance ids, ticket keys, Windows paths and Figma file keys are
already rewritten in the text on screen. The point is that nobody has to
spot an address in a wall of text at the moment they are saying yes.

Names cannot be detected reliably, so they are **listed, not guessed**:

    $env:DESIGN_ORCHESTRA_REDACT_NAMES = "Jane Roe;John Doe"

Without that list only attribution-shaped names are caught ("per Jane Roe",
"- John Doe, Legal"). The orchestra says so out loud when the list is empty.
Where it cannot safely rewrite something - a capitalised pair that might be
a surname or might be "Purchase Order", a bare domain, something
phone-shaped - it prints a hint and leaves the text alone. Auto-stripping
every Capitalised Pair would eat "Chapter 35" along with the surnames.

**`PROJECT.md` is never read.** The passport is the one file guaranteed to
hold client names, colleagues, mail, phone numbers and file keys at once,
and anonymisation is a floor, not a guarantee - a phone number written as
`+7 921 555 12 34` survives every rewrite and only raises a hint. There is
no switch to opt in. If a product decision is genuinely portable, write it
as a rule and mark it.

---

## 6b. Optional extra sources

| Source | Where it works | What is taken | Install |
|---|---|---|---|
| ui-ux-pro-max | /concept only | styles, palettes, type pairings for directions | `/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill` then `/plugin install ui-ux-pro-max@ui-ux-pro-max-skill` |
| Refero Styles | /concept only | DESIGN.md of real products as a direction reference | nothing - a free catalogue, the orchestra fetches it via WebFetch |
| Lazyweb MCP | all modes, UX only | flow and screen structure, NOT visuals | connection command from the Lazyweb site; the UX Advisor picks it up automatically |

The separation is baked into the agents: style databases never leak into
/feature (your design system dictates the visuals), and Lazyweb supplies
UX structure only. None of this is required - the orchestra works fully
without them.

These are third-party projects, unaffiliated with the orchestra and not
vetted by its maintainer. Installing a plugin from someone else's
marketplace grants it access to your Claude Code session - your call, your
responsibility.

---

## 7. What the orchestra does NOT do (so you do not wait for it)

- It does not produce pixel-perfect output: a 70-80% draft, the polish is
  yours. The "could not build" list is an honest part of the result, not a
  failure.
- It does not work without a published library in full-ds mode:
  search_design_system only sees published components enabled in the file.
- It does not create components silently: no component X -> it returns
  "component X missing" and the decision is yours.
- It does not write rules into the brain by itself: only through your
  approval.
- It cannot see other projects: knowledge moves only via orchestra -Promote.

---

## 8. First run (recommended)

1. The project with the cleanest library, and a small feature.
2. Check before you start: the library is published (Assets -> Publish with
   no unsaved changes) and enabled in the working file; variable collections
   are published.
3. `orchestra` -> `claude` -> `/start` -> mode 3 (Feature) -> pick the spec
   by number
4. Look at two artefacts: the Scout's passport (did it read the project
   correctly) and the Builder's "could not build" list (where the build
   hits the limits of your design system). This is calibration, not an exam.

## 9. If something is off

| Symptom | What to do |
|---|---|
| /start or /feature is missing from /skills | you are not in the project folder, or orchestra was never run here. If the rest are there but `/start` is not, the project is on an older version: `orchestra -Update`, then restart claude |
| the agents are missing from /agents | orchestra -Update; restart claude |
| my edits to an agent vanished after -Update | they are right there, in `<file>.bak` - the installer never deletes changed files |
| -Share says the repository is not configured | set `$env:DESIGN_ORCHESTRA_REPO`, see section 6c |
| the Scout "cannot see" the library | check that the library is published and enabled in the file |
| the Builder returned a lot of "could not build" | normal on a first run; fix variant names in your library |
| the orchestra "forgot" the middle of the chain | /clear and start /feature again - the passport and changelog survive, a rerun is cheaper than a repair |
| the Figma tools fell off | /mcp -> status; restart claude |
