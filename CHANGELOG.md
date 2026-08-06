# Changelog

Release history of the orchestra. Loosely follows Keep a Changelog.
(Not to be confused with `CHANGELOG-DESIGN.md`, which is created inside
your project and tracks mockup versions rather than the tool.)

## 1.12.0

The orchestra installs on macOS and Linux. One command is deliberately left
behind, and says so.

### Added

- **`dist/orchestra.sh`** - the shell counterpart of `init-orchestra.ps1`.
  `orchestra`, `--update`, `--status`, `--promote`, `--no-banner`, `--help`,
  with the same isolation guarantees, the same `*.bak` discipline and the same
  rule that every path out of the script ends in an explicit exit. Written to
  POSIX sh - no arrays, no `[[ ]]`, not even `local` - so it runs under dash,
  zsh and the bash 3.2 that macOS still ships. It resolves symlinks before
  looking for its payload, because putting it on `PATH` means a symlink in
  `~/.local/bin` and the payload lives next to the real file.
- **The seed follows XDG on Unix**: `$XDG_DATA_HOME/design-orchestra`, falling
  back to `~/.local/share`. `DESIGN_ORCHESTRA_HOME` overrides it as before.
- **A `Shell installer` CI job on ubuntu-latest** - shellcheck, an LF check, a
  test that `banner.sh` stays silent and inert when sourced, a 78-column and
  strict-ASCII assertion on the rendered banner, and a branch-by-branch exit
  code smoke test. It runs on Linux on purpose: a shell script developed
  against Git Bash can look perfect and still trip over a GNU/BSD difference.

### Not added, on purpose

- **`--share` is absent from the shell installer** and exits 2 with an
  explanation rather than doing something approximate. It anonymises text on
  its way to a PUBLIC issue, and the PowerShell implementation leans on
  lookbehind assertions and a deliberate case-sensitive/insensitive split that
  POSIX tools do not have; a shell version would be a re-implementation whose
  output differs in ways nobody could enumerate. Two different privacy floors
  depending on which OS the command was run from is worse than one platform
  not having the feature. It becomes available when both implementations can
  be run against one shared corpus and produce byte-identical output - that
  corpus is the precondition, not a follow-up.

### Fixed

- **`-Update` after a shell install moved the entire deployment to `*.bak`.**
  `orchestra.sh` writes `.orchestra-manifest.txt` with forward slashes and the
  PowerShell side compared those against its own backslash paths, so every
  single entry looked like a file that had left the distribution: eleven
  agents and skills renamed away, and a warning that eleven files had been
  dropped. Both installers now normalise the separator before comparing, in
  both directions. Caught by installing with one and updating with the other -
  which is exactly what a person with a Mac and a PC will do.

### Verified

- The rule parser is a port, not a rewrite: `orchestra.sh` and the original
  PowerShell functions were run against one corpus of edge cases - markers in
  four spellings and any case, three- versus four-space indents, tab indents,
  horizontal rules, duplicate keys differing only in case and spacing - and
  produce identical output, line for line.
- Round trip both ways: install with either installer, update and read status
  with the other. No spurious backups, no false orphans.

## 1.11.0

A first install introduces itself. Everything else stays as quiet as it was.

The banner is deliberately narrow in scope: it appears on a FIRST install and
nowhere else. `-Status`, `-Update`, `-Promote`, `-Share` and a repeat run are
all somebody waiting for one useful line, and an ASCII frame above that line
costs them a screenful of scrollback for nothing.

### Added

- **An ASCII banner on first install** - a wireframe window, the shape the
  orchestra actually works on. Strict ASCII, 66 columns of art under a 71
  column signature line, 11 lines including its blank margins. Both limits are
  load-bearing: PowerShell 5.1 under the default raster fonts renders Unicode
  box drawing as mojibake, and a line wider than the terminal wraps - a banner
  that wraps mid-frame reads as a broken install, which is a poor thing for a
  first impression to be.
- **`-NoBanner`** suppresses it, for scripted installs that want the result
  and nothing else. The shell port will spell this `--no-banner`; PowerShell
  cannot, because under `[CmdletBinding()]` a double dash is not a parameter
  prefix at all and the script would reject it as a positional argument. The
  alias `-no-banner` is accepted for whoever arrives from the shell side.
- **Colour degrades instead of assuming.** Green via `Write-Host`, but only
  when it can land somewhere that renders it: `NO_COLOR` (any non-empty value,
  per no-color.org), `TERM=dumb`, redirected output and hosts without a
  `RawUI` each fall back to plain text. Verified by reading the rendered frame
  back out of a real 78 column screen buffer, in both directions.
- **`dist/banner.sh`** - the same art for the shell installer that does not
  exist yet. It is a library, not a script: sourcing it prints nothing, sets
  no shell options, installs no traps and touches no globals, and sourcing it
  twice is a no-op the second time. Suppression is left to the caller rather
  than parsed inside, so the banner cannot leak into a mode that simply forgot
  to ask. Syntax checked under `sh`, `bash` and `dash`.

### Fixed

- **`.gitattributes` had no rule for `*.sh`**, so a shell script committed
  from Windows would arrive with CRLF line endings and die on its first line
  with an error naming a character you cannot see. Shell scripts are now LF on
  checkout too - the opposite of the `.ps1` rule, and for the same reason:
  the encoding is part of whether the file runs at all.

### Known limits

- A custom `DESIGN_ORCHESTRA_REPO` longer than roughly 48 characters pushes
  the address onto its own line, and one longer than 78 still wraps. A URL
  cannot be broken and must not be truncated - half an address is worse than
  a wrapped one. The art itself is unaffected in every case.

## 1.10.0

`-Share` learns to offer this cycle's findings, not just rules. The rules
channel was the only way anything portable left a project, and a rule is a
narrow shape: "contentious point X was decided as Y, because Z" is useful to
someone else's project but is not a rule and had nowhere to go.

The guarantees are the point of this feature, so they are the same ones
`-Share` already made for rules, with no exceptions and no new switches.

### Added

- **Portable findings are offered alongside marked rules.** Contentious-point
  decisions and source conflicts from `CHANGELOG-DESIGN.md`; sticking points,
  frequencies and flow breaks from `EXIT-TEST*.md`. Whitelisted **sections**,
  never whole files - a heading you invent yourself is not read, so anything
  you want kept out can simply live under its own heading.
- **Findings are anonymised BEFORE they are shown, not after approval.**
  Emails, links (Figma, Linear, any `http`), node and instance ids, ticket
  keys, Windows paths and Figma file keys are already rewritten in the text on
  screen. Nobody should have to spot an address in a wall of text at the
  moment they are saying yes.
- **Names are listed, not guessed** - `DESIGN_ORCHESTRA_REDACT_NAMES`, plus
  attribution shapes ("per Jane Roe", "- John Doe, Legal") caught directly.
  When the list is empty the orchestra says so out loud rather than implying
  a coverage it does not have.
- **`Test-ResidualIdentity` hints at what could not be rewritten safely** -
  a capitalised pair that might be a surname or might be "Purchase Order", a
  bare domain, something phone-shaped. A hint, never a silent edit.
- Same ceremony as rules throughout: one item at a time, empty answer means
  no, full text shown before anything is sent, and a "NOT BEING SENT" list
  covering refusals, unmarked rules and files deliberately skipped.

### Security

- **`PROJECT.md` is never read, and the switch to opt in is gone.** While
  this feature was being built it had `-Share -IncludeDecisions`, which
  offered the passport's product decisions line by line. It was removed: the
  passport is the one file guaranteed to hold client names, colleagues, mail,
  phone numbers, file keys and node ids at once, and anonymisation is a floor
  rather than a guarantee. A phone number written as `+7 921 555 12 34`
  survives every rewrite in this script and raises only a hint - verified
  against a passport built for the purpose. The person most likely to pass
  such a switch is the person least likely to reread ten passport lines at a
  y/n prompt.
- **An unknown switch is now an error.** The script's `param()` block had no
  `[CmdletBinding()]`, which makes it "simple": PowerShell collects anything
  it does not recognise into `$args` and ignores it silently. So
  `orchestra -Shrae` quietly performed a plain install, and - once
  `-IncludeDecisions` was removed - `orchestra -Share -IncludeDecisions`
  would have quietly run an ordinary `-Share`, leaving someone to conclude
  the passport held no decisions rather than that it is deliberately never
  read.

### Fixed

- **`Get-SectionItems` kept the text queued for a public issue in
  script-scope variables.** Its accumulator lived in `$script:acc` and
  `$script:cur` because its nested `Flush` helper could not assign to its
  parent's locals - the PowerShell scoping rule that catches everyone once.
  The output was correct (an old-versus-new differential over eleven markdown
  shapes plus interleaved calls agrees everywhere), but material headed for a
  public issue had no business sitting in a script-wide variable. The helper
  is gone, the state is function-local, and the only way out of the function
  is its return value. The two dead locals PSScriptAnalyzer flagged, `$items`
  and `$current`, were the leftovers of that same workaround.
- Nine PSScriptAnalyzer findings, fixed in the code rather than by relaxing
  the settings: `Get-RedactNames` -> `Get-RedactNameList`, `Get-SectionItems`
  -> `Get-SectionItemList` (singular nouns), `Remove-Identifiers` ->
  `ConvertTo-AnonymisedText` (it returns a rewritten copy and changes nothing
  on the machine, so a `Remove-*` verb was being asked for `-WhatIf` and
  `-Confirm` support that would mean nothing), and three
  `$x -ne $null` comparisons removed along with the helper that held them.

### Documentation

- The feature shipped undocumented - the commit touched only the script.
  Section 6c of the guide now covers what else `-Share` offers, what is read
  and what is not, how anonymisation works and where its floor is; the README
  summary and both command tables say that findings are included and that
  `PROJECT.md` is never read.

### Continuous integration

The `/start` release went to `main` with a red build whose cause was not in
the diff: `Install-Module PSScriptAnalyzer` failed, `Analyze` was skipped,
and the job reported failure. Nothing in the pull request could have caused
it, and nothing in the log said so. No behaviour change here, so the version
stays at 1.10.0.

- **The analyzer is cached** (`actions/cache`) and downloaded with
  `Save-Module` into `RUNNER_TEMP` rather than installed into the user
  profile. The workspace is deliberately avoided: anything under the checkout
  would be walked by `Invoke-ScriptAnalyzer -Path . -Recurse` and by the BOM
  check, so the job would end up analysing the analyser's own hundreds of
  `.ps1`/`.psd1` files. `RUNNER_TEMP` is also independent of the runner
  account name, which keeps the cache key stable.
- **Three attempts with 5s/10s backoff**, and TLS 1.2 forced first: Windows
  PowerShell 5.1 still negotiates 1.0/1.1 by default while PSGallery has
  required 1.2 for years, and that mismatch surfaces as an opaque "Unable to
  connect to the remote server".
- **The version is pinned** (`PSSA_VERSION`) instead of floating to whatever
  the gallery serves that morning, so a new analyzer release can no longer
  turn `main` red without a commit that says so. The cache key follows the
  pin, so bumping it is a one-line edit.
- **A failure now explains itself.** The message states that this step is the
  only one in the workflow that touches the network, that nothing in the diff
  can cause it, and that re-running is the first thing to try - instead of
  leaving a contributor hunting through their own changes.
- **Three distinct failures are told apart.** A pin that is not a version
  number fails immediately rather than burning 15s of backoff and then
  blaming the gallery; a version the gallery does not have is reported as a
  wrong pin and not retried at all, since the gallery answered. That branch
  keys off `FullyQualifiedErrorId`, never the message text - error messages
  are localised, and an English substring match silently took the wrong
  branch when tested against a PowerShell answering in Russian.
- `Analyze` verifies the module is where the cache should have put it and
  prints the version it actually loaded, so a bad cache entry is not mistaken
  for a code failure.

## 1.9.0

One command to start from. The orchestra had four entry points and no door:
you had to know that `/feature` exists, that it is the wrong command for a
greenfield project, and that it wants a spec path typed out by hand. That
was the single most common complaint - not that the chain is bad, but that
it is not obvious where to begin.

### Added

- **`/start` - the interactive entry point.** It reads `PROJECT.md` and the
  listing of `specs/` for a cheap orientation (no Scout - that is a
  diagnosis, and an expensive one), offers the four modes as a numbered
  list with one line of explanation each, collects whatever the chosen mode
  needs, and hands over to that mode's own skill. No mode logic is
  duplicated inside it: it routes and stops.
  - **Feature no longer asks for a path.** The specs in `specs/` are listed
    numbered (minus `_template.md`); you answer with a number.
  - **Modes that cannot work are marked, not hidden.** No `PROJECT.md`, or
    `Mode: from-scratch` in it, and Feature is shown as unavailable with the
    reason on the same line; an empty `specs/` says so too. Hiding an option
    only moves the confusion one step later.
  - **It never picks the mode for you**, however obvious the state of the
    project makes the answer. Routing on a guess is how people end up in
    `/feature` on a project with no design system.
  - **The Figma link is asked for only when it is both needed and missing**
    from the passport.
  - After the mode finishes, it names `orchestra -Share` in one paragraph
    and does nothing else - it never runs it and never sends anything.

### Documentation

- `/start` heads the table of in-Claude commands in the README, marked
  "start here". The others stay as they are: they are for people who already
  know what they want.
- First run, in both the README and the guide, now says `/start` instead of
  `/feature specs/your-spec.md`.
- The guide describes the skill's five steps, so the routing is inspectable
  rather than magic.
- **The installer's closing hint pointed past the new door.** Step 3 of
  "Next:" after a successful install said `/feature specs/name.md` - the
  first thing a new user reads, sending them straight to the command that
  needs a path and a design system. It now leads with `/start` and keeps
  `/feature` underneath as the shortcut for people who know the mode.
- CI's install smoke test asserts five skills, `start` among them, and
  compares the deployed count against the distribution - a skill added to
  `dist/` but forgotten in the assertion list would otherwise ship untested.

## 1.8.2

The same exit-code bug as 1.8.1, one layer up: in the CI step itself.

### Fixed

- **Workflow steps inherited a stale exit code.** For `shell: powershell`,
  GitHub appends `if (Test-Path variable:\LASTEXITCODE) { exit $LASTEXITCODE }`
  to every `run` block. The smoke test's last case is the in-repo guard, which
  deliberately returns 1, so the block ended with `$LASTEXITCODE = 1` and the
  step failed even though all eight assertions had printed `(ok)`. Every `run`
  block now ends in an explicit `exit 0`.
- **The local CI runner could not have caught it.** It invoked each block with
  `powershell -File`, which returns 0 when a script ends without an explicit
  `exit`, so GitHub's epilogue was never simulated. The runner now appends the
  same epilogue GitHub does and asserts the exit code of every step.

### Documentation

Five gaps found by walking the README as a first-time user on a clean
machine. No code changes, so the version stays at 1.8.2.

- **`/log` was undocumented.** The skill ships and CI checks that it
  deploys, but the README mentioned only `/feature`, `/concept` and
  `/foundation` - so the one command that feeds out-of-cycle edits into
  the learning loop was invisible. Now in "How it works" and in a new
  table of in-Claude commands.
- **"Where things live" did not match a fresh install.** It promised
  `PROJECT.md` and `CHANGELOG-DESIGN.md`, which `orchestra` does not
  create (the agents write them on the first run), and omitted
  `AGENTS.md`, `.orchestra-version` and `.orchestra-manifest.txt`, which
  it does. The seed is likewise marked as appearing only after
  `-Promote` - `orchestra -Status` was already more honest than the
  README here.
- **No word that an open Claude Code session must be restarted.** Skills
  are read at session start, so running `orchestra` next to a live
  session leaves `/feature` unknown, with nothing to explain it.
- **`git clone` was not offered.** Install step 1 listed only
  Code -> Download ZIP.
- **The Figma prerequisites were a bare list under Requirements**, with
  no check to run before starting. A miss - unpublished library, no Dev
  seat, MCP not connected - only surfaced mid-run. First run now opens
  with a five-point preflight checklist.

## 1.8.1

Exit codes. CI's install smoke test failed even though the install itself
succeeded.

### Fixed

- **The install/update path fell off the end of `dist/init-orchestra.ps1`
  without an explicit `exit`.** A script that ends that way leaves
  `$LASTEXITCODE` untouched in the caller: `$null` in a fresh process (what
  CI hit - hence the empty `install returned` message), or a stale code from
  some earlier command in a longer session. In a local session a fully
  successful `-Update` was observed returning `1`, inherited from a previous
  `-Share`. Every branch of both scripts now ends in an explicit `exit`.
- The same omission in `install.ps1`: the registration path had no `exit 0`.
- **The smoke test only covered two commands.** It now checks the exit code
  of every branch - install, `-Update`, re-run, `-Status`, `-Promote`,
  `-Share` with and without a valid repo, and the in-repo guard - and it
  poisons `$LASTEXITCODE` before each call, so a missing `exit` is reported
  as such instead of silently inheriting a passing `0`.
- The smoke test's expectations no longer depend on `$DefaultRepoUrl`. It
  used to assume the placeholder value, so CI would have started failing for
  anyone who set a real repository URL. The URL is now pinned per case
  through `DESIGN_ORCHESTRA_REPO`.
- The smoke-test helper splatted an array of strings, which silently fails to
  bind switch parameters: `-Update` and friends arrived as dropped positional
  arguments, with no error, so every case actually re-tested the default
  branch. It splats a hashtable now.

## 1.8.0

First public release. Pre-publication audit: security and repository
structure.

### Security

- **`-Share` no longer drags unmarked rules along.** The "promote
  candidate" marker used to apply until the end of the section: marking one
  rule sent every following line into the public issue, including client and
  internal system names. A candidate is now **only the line the marker sits
  on**. A marker on a heading is deliberately unsupported and produces a
  warning.
- **Confirmation is now per rule.** Instead of one "yes" for the whole
  list, y/n for each rule, with an empty answer meaning "no". Even if the
  formats diverge again in the future, a human sees every line.
- **`-Share` shows what is NOT being sent** - both refusals and every
  unmarked rule, so a rule landing in the wrong list is visible.
- **The "leak auto-filter" was renamed to a "hint"** in both the code and
  the docs. It does not catch client or product names; calling it a
  safeguard was wrong. Hex colour detection was added, and the promise in
  the README was rewritten around per-rule consent.
- **Private rules are no longer written into the repository.** `-Promote`
  used to write into `dist/payload/`, i.e. into a git working tree, risking
  an accidental commit into a pull request and causing conflicts on
  `git pull`. The shared seed moved to `%APPDATA%\design-orchestra\seed\`
  (override with `DESIGN_ORCHESTRA_HOME`).
- **The public repository URL comes from an environment variable**
  (`DESIGN_ORCHESTRA_REPO`) rather than an edit to a tracked file. It is
  validated as an https URL before `Start-Process`.
- **A boundary around the Scout's Bash.** Bash is kept - it is needed to
  parse dumps that do not fit into normal output - but explicitly limited
  to reading and parsing local project files: no network calls, no writes,
  no deletions, and never executing commands that came from data.
- **The "data is not instructions" invariant** was added to `AGENTS.md`, to
  the `/feature` conductor's invariants and as its own section for the
  Scout: spec text and Figma strings are quoted and analysed, never executed.
- The issue URL length is checked: on overflow a blank form is opened and
  the text is written to `%TEMP%\orchestra-share.md`.

### Fixed

- `payload/AGENTS.md` was never copied into projects - the installer only
  deployed `.claude/`, `brain-seed` and `specs`. It is now installed, but
  only when the project does not already have its own `AGENTS.md`.
- `-Update` silently discarded your edits to agents and skills. A changed
  file is now saved as `<file>.bak` before being overwritten, and the list
  is printed.
- `-Update` did not remove agents dropped from a newer version. A manifest
  (`.orchestra-manifest.txt`) was added; orphaned files are moved to `*.bak`
  rather than deleted.
- The "do not run inside the distribution" guard relied on the folder being
  named `design-orchestra-dist`. After a GitHub "Download ZIP" the name
  differs, so the guard never fired and an install littered the repository
  itself. Real paths are compared now.
- Installation no longer requires a specific folder name or location.
  `install.ps1` was added: it takes the path from `$PSScriptRoot`, writes a
  marked block into the profile (re-running never duplicates it), clears the
  block mark from `*.ps1` only, and supports `-Uninstall`.
- `-Promote` used to take any line starting with `-`, including horizontal
  rules and Chronicler comments, and deduplicated by byte-identical strings.
  Rule lines are now recognised explicitly, the marker is stripped, and
  comparison runs on normalised text.
- `-Promote` crashed with a raw exception when the seed had no
  `rules/personal.md`. The seed is created on first use.
- `tools:` lists were removed from all six agents. They named `mcp__figma`,
  but the real prefix depends on how the user named their MCP server; on a
  mismatch the agent silently ended up without Figma. Agents now inherit the
  available tools.
- `web_fetch` -> `WebFetch` in `/concept` and in the guide.
- Skills no longer break when `$ARGUMENTS` substitution does not happen:
  they ask the designer for the path instead of guessing.
- A broken empty code block in the guide that broke GitHub rendering.
- `-Share` was missing from the command tables in the guide and INSTALL.

### Repository structure

- README, GUIDE, INSTALL, CONTRIBUTING, LICENSE and VERSION live in the
  root so GitHub renders the front page. The distribution moved to `dist/`.
- Added `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CHANGELOG.md`, issue and PR
  templates, `.gitignore` and `.gitattributes`.
- CI: PSScriptAnalyzer over both scripts, a BOM check, a VERSION/CHANGELOG
  consistency check and an install smoke test on an empty folder.
- A non-affiliation notice for Figma, Anthropic, Google, Refero and Lazyweb.

## 1.7.0 and earlier

Internal pre-publication versions; no history was kept.
