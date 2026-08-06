# Design Orchestra

A chain of Claude Code agents that builds Figma mockups from a written
spec - with review gates, a justification behind every decision, and a
memory that learns from your edits.

## What it is

You drop a spec into a folder, run one command, and a chain of specialised
agents breaks the spec down, finds the holes in it, justifies UX decisions
against precedents from your own project, assembles screens with every
state from your component library, verifies what was built against the
spec, runs the contentious parts past a panel of synthetic respondents -
and stops at exactly two points where the decision has to be yours.

After your review, the Chronicler compares what the orchestra built against
what you changed, and proposes rules. Approved ones enter the project's
brain, and the next feature is built with them in mind. The learning metric
is the share of frames you did not have to touch.

Every project is an isolated build with its own brain. Projects know
nothing about each other.

**Nothing leaves your machine on its own.** The single command that touches
the network is `orchestra -Share`: it asks about each rule separately, shows
you the list of what is NOT being sent, and at the end merely opens an issue
form - you press the button.

## Requirements

- Claude Code (Pro/Max/Team subscription) - https://claude.com/claude-code
- Figma MCP (remote), a Dev or Full seat on a paid Figma plan
- Windows PowerShell 5.1+ (installer only; the agents themselves are plain
  markdown and work anywhere)

## Install

1. Download the repository (Code -> Download ZIP) and unpack it anywhere.
   The folder name does not matter.
2. In PowerShell, from the root of the unpacked folder:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```
   The script registers an `orchestra` command in your profile (running it
   again does not create duplicates), clears the "downloaded from the
   internet" mark from the `.ps1` files, and tells you if your execution
   policy still blocks the command.
3. Restart PowerShell.

To remove the command: `.\install.ps1 -Uninstall`.

## First run

```powershell
cd path\to\your\project
orchestra                     # isolated install into the project
claude                        # check the header: the path is YOUR project!
```
Inside Claude Code:
```
/feature specs/your-spec.md
```
Full manual: [GUIDE.md](GUIDE.md).

## Commands

| Command | What it does |
|---|---|
| `orchestra` | install the orchestra into the current project |
| `orchestra -Status` | version, brain state, where your seed lives |
| `orchestra -Update` | update the agents to the distribution version; brain, passport and specs are untouched, changed files are kept as `*.bak` |
| `orchestra -Promote` | this project's personal rules -> your shared seed (new projects only) |
| `orchestra -Share` | propose rules to the public seed: per-rule confirmation, you submit by hand |

## Where things live

```
<repository>/             <- this repo; nothing is ever written into it
  install.ps1
  dist/init-orchestra.ps1
  dist/payload/           <- what gets deployed into projects

<your project>/
  .claude/agents|skills/  <- your copy of the agents (overwritten by -Update)
  brain/                  <- THIS project's brain
  specs/, PROJECT.md, CHANGELOG-DESIGN.md

%APPDATA%\design-orchestra\seed\   <- your shared seed across projects
```

The user seed sits outside the repository on purpose: otherwise `-Promote`
would drop private rules into a git working tree, with the risk of
committing them into a pull request. Override with
`$env:DESIGN_ORCHESTRA_HOME`.

## FAQ - the rakes people actually stepped on

**`orchestra` is not found** - restart PowerShell after `install.ps1`.
Check with `Get-Command orchestra`.

**"File is not digitally signed" / "running scripts is disabled"** - allow
local scripts once: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

**`/feature` - Unknown command** - look at the Claude Code header: if it
shows `C:\WINDOWS\System32` or some other folder, you started claude outside
your project. `/exit` -> `cd` into the project -> `claude`.

**A Figma plugin skill hijacks the request** - make `/feature` the first
command of the session, with no accompanying text.

**The Scout "cannot see" the library** - the library must be published
(Assets -> Publish) and enabled in the working file.

**`get_variable_defs` asks for a selection** - open the kit file in the
Figma desktop app and select any frame: the tool works from a selection.

**My edits to an agent disappeared after `-Update`** - they are right
there, in `<file>.bak`. The installer never deletes changed files; it sets
a copy aside and prints the list.

## How it works

The Conductor (the `/feature` skill) runs a chain of six agents: the Scout
(project diagnosis -> passport), the Spec Analyst (plan plus four review
gates), the UX Advisor (decisions justified against precedents), the Builder
(the only one that writes to Figma), the Respondent (panel, blind A/B) and
the Chronicler (journal -> rules -> learning metric). Plus `/concept`
(visual directions for a greenfield project) and `/foundation` (design
system foundation from a reference). Versioning: version pages in Figma
plus CHANGELOG-DESIGN.md.

## Contributing

Rules accumulated by your Chronicler can be proposed to the shared seed
with `orchestra -Share`. Acceptance criteria are in
[CONTRIBUTING.md](CONTRIBUTING.md). Vulnerabilities: [SECURITY.md](SECURITY.md).
Release history: [CHANGELOG.md](CHANGELOG.md).

## Licence

MIT - see [LICENSE](LICENSE). Provided as is, without warranty.

Not affiliated with or endorsed by Figma, Anthropic, Google (Stitch),
Refero or Lazyweb. All names belong to their owners; subscriptions and
compliance with their terms are the user's responsibility.
