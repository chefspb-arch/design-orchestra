# Changelog

Release history of the orchestra. Loosely follows Keep a Changelog.
(Not to be confused with `CHANGELOG-DESIGN.md`, which is created inside
your project and tracks mockup versions rather than the tool.)

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
