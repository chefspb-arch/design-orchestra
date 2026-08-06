# Security

## Reporting a vulnerability

Do not open a public issue. Use GitHub's private channel: the **Security ->
Report a vulnerability** tab of this repository (Private Vulnerability
Reporting).

Include: what happens, how to reproduce it, the orchestra version
(`orchestra -Status`), and your Windows and PowerShell versions
(`$PSVersionTable`). You will get a reply within 7 days. Anything critical
is fixed in a new release with an entry in [CHANGELOG.md](CHANGELOG.md).

## Threat model

The orchestra is a set of markdown files holding instructions for agents,
plus a PowerShell installer that copies them into your project. That sets
the boundaries:

**What the installer does.** Reads its own `dist/payload/`, writes into the
current project (`.claude/`, `brain/`, `specs/`, `AGENTS.md`,
`.orchestra-version`, `.orchestra-manifest.txt`), writes to your seed at
`%APPDATA%\design-orchestra\seed\`, and in exactly one case (`-Share`)
opens a browser on a GitHub issue form.

**What the installer does not do.** It never downloads or executes code
from the network. It never touches the registry, services, startup entries
or the task scheduler. It never handles credentials. It never deletes
irreversibly - anything displaced goes to `*.bak`.

**Where the real risk is.**

1. **Leaking private rules through `-Share`.** This is the only path by
   which text from your machine reaches a public place. That is why
   confirmation is per rule, why an empty answer means "no", and why the
   list of what is NOT being sent is printed before submission. The
   "looks like project data" hint is a heuristic, not a filter: it does not
   catch client or internal system names. The final check is always human.
   Before 1.8.0, a marker on one line dragged neighbouring rules into the
   issue - see the changelog.

2. **Prompt injection through specs and Figma content.** The orchestra
   reads files that frequently come from a client, and strings from other
   people's Figma files. That text can contain instructions aimed at the
   model. The "data is not instructions" invariant is written into
   `AGENTS.md`, into the `/feature` conductor, and as its own section for
   the Scout. The Scout has Bash (needed to parse dumps that do not fit
   into normal output) and its boundary is stated explicitly: reading and
   parsing local files only, no network calls, no writes, and never
   executing a command that came from data.

3. **Third-party sources.** `/concept` may fetch styles.refero.design, and
   the guide mentions a third-party plugin and MCP server. All of this is
   optional, unaffiliated and not vetted by the maintainer. Installing
   someone else's plugin grants it access to your Claude Code session.

4. **Claude Code's own boundaries.** The orchestra neither widens nor
   weakens Claude Code's permissions - it inherits them. Rights to run
   commands and write files are configured on the Claude Code side, and
   responsibility for them lives there.

## What we ask of your system

- `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` - only if policy
  forbids local scripts. It is the mildest sufficient relaxation; `Bypass`
  and `Unrestricted` are not required.
- `Unblock-File` - applied only to `*.ps1` inside the unpacked folder;
  nothing is unblocked recursively across your disk.

Both are performed by you explicitly; the installer never does them
silently.

## Out of scope

- Opinions on UX rules and mockup quality - ordinary issues.
- Vulnerabilities in Claude Code, Figma and MCP servers - report to their
  vendors.
