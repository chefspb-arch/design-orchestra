# Install (once per machine)

## 1. Unpack the repository
Anywhere. The folder name does not matter - the path is taken from where
`install.ps1` sits.

## 2. Register the `orchestra` command
In PowerShell, from the root of the unpacked folder:

    powershell -ExecutionPolicy Bypass -File .\install.ps1

What the script does:
- appends an `orchestra` function to your PowerShell profile inside a
  marked block `# >>> design-orchestra >>>` - running it again replaces the
  block rather than piling up copies;
- clears the "downloaded from the internet" mark from `*.ps1`
  (`Unblock-File`);
- checks your execution policy and prints the command to fix it if it
  blocks startup.

Restart PowerShell. Check with `Get-Command orchestra`.

If policy forbids scripts, once:

    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

`RemoteSigned` allows local scripts and still requires a signature for
downloaded ones. It is the mildest sufficient relaxation.

To remove the command: `.\install.ps1 -Uninstall`.

## 2a. macOS and Linux

Use `dist/orchestra.sh`. There is no registration script for it yet, so put it
on your PATH yourself - a symlink works, since the installer resolves the link
before looking for its payload:

    chmod +x dist/orchestra.sh
    mkdir -p ~/.local/bin
    ln -s "$PWD/dist/orchestra.sh" ~/.local/bin/orchestra

Options take a double dash there: `--update`, `--status`, `--promote`,
`--no-banner`. The seed lives in
`${XDG_DATA_HOME:-~/.local/share}/design-orchestra/seed`.

`--share` is **not available** in the shell installer: it prepares text for a
public issue, its anonymisation cannot be reproduced faithfully with POSIX
tools, and a second, weaker privacy floor for macOS and Linux would be worse
than not having the feature there. It refuses and exits non-zero. Use
PowerShell for that one command.

## 3. Usage
In EVERY project (isolated build, projects cannot see each other):

    cd C:\path\to\your\project
    orchestra            # install: own agents + own brain ./brain
    claude
    /feature specs/spec-name.md

Other commands:

    orchestra -Status    # version, brain state, path to your seed
    orchestra -Update    # update the agents to the distribution version;
                         # brain/passport/specs untouched
    orchestra -Promote   # this project's personal rules -> your seed
                         # (picked up by NEW installs only)
    orchestra -Share     # propose rules to the public seed:
                         # confirmed one rule at a time
                         # (PowerShell only - see 2a)

## Isolation architecture
- Agents and skills: a copy under `.claude\` in every project. Edits in one
  project do not affect another. `-Update` overwrites them with the
  distribution version, but any file you changed is copied to `*.bak` first
  and listed.
- Brain: its own `./brain` per project. Journal, precedents and rules never
  cross between projects.
- Your shared seed: `%APPDATA%\design-orchestra\seed\` on Windows,
  `${XDG_DATA_HOME:-~/.local/share}/design-orchestra/seed` on macOS and
  Linux - outside the repository either way, so private rules never land in
  git. Override the path with the `DESIGN_ORCHESTRA_HOME` variable.
- The only channel that carries knowledge between projects is a manual
  `orchestra -Promote`: you decide which personal rules become the starting
  point for future projects.

## What the installer does NOT do
- It never touches the network and downloads nothing.
- It never writes to the registry and creates no services or scheduled tasks.
- It never touches your `brain/`, `PROJECT.md`, `specs/` or
  `CHANGELOG-DESIGN.md` on update.
- It never deletes irreversibly: everything displaced goes to `*.bak`.

## Requirements
Claude Code + Figma MCP (remote), Dev/Full seat. No paid external services
beyond those.

## Suggested project .gitignore
If the repository is shared with a team and the orchestra is your personal
tool:

    .claude/agents/
    .claude/skills/
    brain/
    .orchestra-version
    .orchestra-manifest.txt
    *.bak

If the orchestra is the team's, do the opposite and commit everything: the
brain is then versioned along with the project. Either way, do not commit
`*.bak`.
