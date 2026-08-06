# Proposing a rule to the shared seed

The orchestra learns from review: your Chronicler accumulates rules in
`brain/rules/personal.md`. A portable rule is marked **at the end of its
own line**:

    - Show validation errors at the field (promote candidate)

The marker applies only to the line it sits on. It must not go on a
heading - neighbouring rules will not be picked up, and that is deliberate
(see [CHANGELOG.md](CHANGELOG.md), 1.8.0).

## What `orchestra -Share` does

1. Collects the marked lines from the current project's brain - and only
   those.
2. Asks about **each rule separately**: y/n. An empty answer means "no".
3. Next to a rule that looks like project data (a link, a node id, a hex
   colour, a fileKey) it prints a **hint**. It is a hint, not a filter: it
   does not catch client, product or internal system names - that part is
   on you, line by line.
4. Shows the list of what is **not** being sent: both the rules you
   declined and every unmarked one. If something landed in the wrong list,
   you see it before anything is submitted.
5. Opens a new issue form with the text prefilled. A copy of the text is
   written to `%TEMP%\orchestra-share.md`. You press submit.

Nothing is ever sent automatically. Ever.

The public repository is configured through an environment variable, not by
editing files in the repo:

    $env:DESIGN_ORCHESTRA_REPO = "https://github.com/<login>/design-orchestra"

## Acceptance criteria for a rule

- **Portable**: it works outside your project. "Errors at the field" - yes;
  "take statuses from section X of file Y" - no.
- **Checkable**: you can say unambiguously whether it was violated.
- **No client data**: no project names, no file links, no node ids, no
  specific brand hex values, no domain specifics that reveal the product.
- **Short**: one rule, one to three lines.

Before submitting, make sure you are entitled to share: a rule derived from
work under NDA is your own observation about design, but check that nothing
project-specific survived in the wording.

## What happens next

The maintainer reads the proposal by hand. Accepted rules go into
`dist/payload/brain-seed/rules/ux-patterns.md` in the next release and reach
every user on update. Rejected ones are closed with a reason. The seed's
quality matters more than its size.

## Other contributions

Bugs and improvements to the installer or agents - ordinary issues and PRs.
Describe the reproduction steps; console output beats a retelling.

Changes to `init-orchestra.ps1` and `install.ps1` are checked by
PSScriptAnalyzer in CI. To run it locally:

    Install-Module PSScriptAnalyzer -Scope CurrentUser
    Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1

Anything touching `-Share`, `-Promote` or writes into the user's files must
be tested against an empty temporary folder, not your real project.

For vulnerabilities, do not open a public issue - follow
[SECURITY.md](SECURITY.md).
