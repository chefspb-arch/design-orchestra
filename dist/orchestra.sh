#!/bin/sh
# orchestra.sh - deploys an ISOLATED orchestra build into the current project.
# The shell counterpart of init-orchestra.ps1, for macOS and Linux.
#
# Usage (from your project root):
#   orchestra                - install the orchestra into this project
#   orchestra --update       - update agents/skills to the distribution version
#                              (brain, passport and specs are left alone;
#                               changed files are kept next to the new ones
#                               as *.bak)
#   orchestra --promote      - this project's personal rules -> your shared
#                              seed, so NEW projects start with them
#   orchestra --status       - what is installed and at which version
#   orchestra --no-banner    - install without the ASCII banner
#
#   orchestra --share        - NOT AVAILABLE HERE. See the note further down.
#
# Every project gets its OWN copy of the agents and its OWN brain (./brain).
# Projects cannot see each other. Updating the seed never changes old projects.
#
# Your shared seed lives OUTSIDE this repository:
#   ${XDG_DATA_HOME:-~/.local/share}/design-orchestra/seed
#   (override with $DESIGN_ORCHESTRA_HOME)
#
# ---------------------------------------------------------------------------
# Why --share is missing rather than approximated
#
# -Share anonymises text that is on its way to a PUBLIC issue. The PowerShell
# implementation leans on lookbehind assertions and on a deliberate split
# between case-sensitive and case-insensitive replacement - neither of which
# POSIX tools have, so a shell version would be a re-implementation, not a
# port, and its output would differ in ways nobody could enumerate.
#
# Two different privacy floors depending on which OS you happened to run the
# command from is worse than one platform not having the feature. So --share
# here refuses loudly and exits non-zero. It becomes available when both
# implementations can be run against one shared corpus and produce identical
# output, byte for byte - that corpus is the precondition, not a follow-up.
# ---------------------------------------------------------------------------
#
# Written to POSIX sh so it runs under dash, bash (including the 3.2 that
# macOS ships) and zsh alike - no arrays, no [[ ]], not even `local`, which is
# universal in practice but still not in the standard. Lists that would be
# arrays elsewhere are newline-delimited here; the payload ships markdown whose
# names we control, so a newline inside a filename is not a case that arises.

set -eu

# --------------------------------------------------------------- arguments --

do_update=0
do_promote=0
do_status=0
no_banner=0

# Unknown options are an ERROR, never silently ignored. The PowerShell side
# takes [CmdletBinding()] for exactly this: without it `orchestra -Shrae`
# quietly performs a plain install, and someone who mistypes --update would
# conclude the update did nothing rather than learning they mistyped.
for arg in "$@"; do
    case "$arg" in
        --update)    do_update=1 ;;
        --promote)   do_promote=1 ;;
        --status)    do_status=1 ;;
        --no-banner) no_banner=1 ;;
        --share)
            echo "orchestra: --share is not available in the shell installer." >&2
            echo "" >&2
            echo "It prepares text for a PUBLIC issue, and its anonymisation cannot be" >&2
            echo "reproduced faithfully with POSIX tools. Rather than ship a second," >&2
            echo "weaker privacy floor for macOS and Linux, it is absent here." >&2
            echo "" >&2
            echo "Use -Share from PowerShell, on any platform where you can run it." >&2
            exit 2
            ;;
        -h|--help)
            sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "orchestra: unknown option '$arg'" >&2
            echo "Try 'orchestra --help'." >&2
            exit 2
            ;;
    esac
done

# ------------------------------------------------------------------- paths --

# The natural way to put this on PATH is a symlink in ~/.local/bin, and the
# payload lives next to the REAL file, not next to the link. `readlink -f`
# would resolve the chain in one call but it is GNU-only - macOS had no -f for
# most of its life - so the chain is walked by hand.
self=$0
while [ -L "$self" ]; do
    link=$(readlink "$self")
    case "$link" in
        /*) self=$link ;;
        *)  self=$(dirname -- "$self")/$link ;;
    esac
done
dist=$(CDPATH='' cd -- "$(dirname -- "$self")" && pwd -P)
payload="$dist/payload"
repo_root=$(CDPATH='' cd -- "$dist/.." && pwd -P)
banner_lib="$dist/banner.sh"

proj=$(pwd -P)

if [ ! -d "$payload" ]; then
    echo "No payload folder next to the script ($payload)." >&2
    echo "The distribution was not unpacked completely." >&2
    exit 1
fi

# banner.sh is the single source of truth for whether colour is safe to emit,
# so a missing one is a broken distribution rather than a cosmetic loss.
if [ ! -f "$banner_lib" ]; then
    echo "No banner.sh next to the script ($banner_lib)." >&2
    echo "The distribution was not unpacked completely." >&2
    exit 1
fi
# shellcheck source=dist/banner.sh
. "$banner_lib"

ver=''
for candidate in "$repo_root/VERSION" "$dist/VERSION"; do
    if [ -f "$candidate" ]; then
        ver=$(tr -d ' \t\r\n' < "$candidate")
        break
    fi
done
if [ -z "$ver" ]; then
    echo "VERSION file not found (neither in the repo root nor next to the script)." >&2
    exit 1
fi

if [ -n "${DESIGN_ORCHESTRA_HOME:-}" ]; then
    orch_home=$DESIGN_ORCHESTRA_HOME
else
    # XDG, not ~/.design-orchestra: this is application state the user never
    # edits by hand, which is what the data directory is for.
    orch_home="${XDG_DATA_HOME:-$HOME/.local/share}/design-orchestra"
fi
seed_dir="$orch_home/seed"
seed_rules="$seed_dir/rules/personal.md"

# Public seed repository. If you forked, do NOT edit this line - set
# $DESIGN_ORCHESTRA_REPO instead, so updates never conflict.
default_repo_url="https://github.com/chefspb-arch/design-orchestra"

repo_url() {
    if [ -n "${DESIGN_ORCHESTRA_REPO:-}" ]; then
        printf '%s\n' "${DESIGN_ORCHESTRA_REPO%/}"
    else
        printf '%s\n' "${default_repo_url%/}"
    fi
}

# Guard against running inside the orchestra repository itself - by real path,
# not by folder name: GitHub's "Download ZIP" gives the folder a different name.
case "$proj" in
    "$repo_root" | "$repo_root"/*)
        echo "You are inside the orchestra repository ($repo_root)." >&2
        echo "Go to your own project folder and run orchestra there." >&2
        exit 1
        ;;
esac

# ------------------------------------------------------------------ output --

# Colour decision comes from banner.sh, so there is one answer to the question
# in the whole distribution rather than two that can drift apart.
if orchestra_banner_use_color; then
    c_green=$(printf '\033[32m'); c_yellow=$(printf '\033[33m')
    c_red=$(printf '\033[31m');   c_dim=$(printf '\033[90m')
    c_off=$(printf '\033[0m')
else
    c_green=''; c_yellow=''; c_red=''; c_dim=''; c_off=''
fi

say()      { printf '%s\n' "$*"; }
say_ok()   { printf '%s%s%s\n' "$c_green"  "$*" "$c_off"; }
say_warn() { printf '%s%s%s\n' "$c_yellow" "$*" "$c_off"; }
say_dim()  { printf '%s%s%s\n' "$c_dim"    "$*" "$c_off"; }
say_err()  { printf '%s%s%s\n' "$c_red"    "$*" "$c_off" >&2; }

# ----------------------------------------------------------------- helpers --

installed_version() {
    if [ -f "$proj/.orchestra-version" ]; then
        tr -d ' \t\r\n' < "$proj/.orchestra-version"
    fi
}

# Every file in the payload's .claude tree, as paths relative to the project
# root, one per line. Newline-delimited because POSIX sh has no arrays; the
# payload ships agent and skill markdown whose names we control, so a newline
# inside a filename is not a case that can arise here.
payload_file_list() {
    find "$payload/.claude" -type f | while IFS= read -r f; do
        printf '.claude/%s\n' "${f#"$payload/.claude/"}"
    done | LC_ALL=C sort
}

# Rule lines, as the PowerShell side defines them:
#   - a horizontal rule (--- or longer) is not a rule
#   - four or more spaces of indent is a markdown code block, not a list item
#     (this is what stopped the marked example in personal.md's own header
#      from being picked up as if it were a real rule)
#   - the "promote candidate" marker is bookkeeping and never travels with the
#     text, in either its "(promote candidate)" or its trailing form
#
# Emits one line per rule: the lowercased comparison key, a tab, then the text.
# All of it in awk: the marker match has to be case-insensitive, and BSD sed
# (which is what macOS has) has no portable way to ask for that.
rule_lines() {
    [ -f "$1" ] || return 0
    awk '
    function trim(s) {
        sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s
    }
    # Cut out "(promote candidate ...)" wherever it appears, then a trailing
    # "- promote candidate ..." if one is left. Index arithmetic on a
    # lowercased copy, because awk has no case-insensitive matching either.
    # `cl` rather than `close`: close() is a built-in and awk rejects the name
    # outright as a parameter.
    function strip_marker(s,   low, m, op, cl, i, ch, head) {
        while (1) {
            low = tolower(s); m = index(low, MARKER)
            if (m == 0) break
            op = 0
            for (i = m - 1; i >= 1; i--) {
                ch = substr(s, i, 1)
                if (ch == "(") { op = i; break }
                if (ch != " " && ch != "\t") break
            }
            if (op == 0) break
            cl = index(substr(low, m), ")")
            if (cl == 0) break
            cl = m + cl - 1
            head = substr(s, 1, op - 1)
            sub(/[ \t]+$/, "", head)
            s = head substr(s, cl + 1)
        }
        low = tolower(s); m = index(low, MARKER)
        if (m > 0) {
            head = substr(s, 1, m - 1)
            sub(/[ \t]*-?[ \t]*$/, "", head)
            s = head
        }
        return trim(s)
    }
    {
        line = $0
        t = trim(line)
        if (t ~ /^-+$/ && length(t) >= 3) next          # horizontal rule
        n = match(line, /[^ ]/)
        if (n == 0) next
        if (n - 1 > 3) next                             # code block, not a list
        ch = substr(line, n, 1)
        if (ch != "-" && ch != "*") next
        rest = substr(line, n + 1)
        if (rest !~ /^[ \t]+[^ \t]/) next               # "-" alone is not a rule
        text = strip_marker(trim(rest))
        if (text == "") next
        key = tolower(text)
        gsub(/[ \t]+/, " ", key)
        print key "\t" text
    }
    ' MARKER="promote candidate" "$1"
}

initialize_user_seed() {
    [ -d "$seed_dir" ] && return 0
    mkdir -p "$seed_dir"
    # The trailing /. copies the CONTENTS, including dotfiles, without
    # depending on the shell's glob settings.
    cp -R "$payload/brain-seed/." "$seed_dir/"
    say_ok "Created your shared seed: $seed_dir"
}

show_banner_if_wanted() {
    [ "$no_banner" -eq 1 ] && return 0
    orchestra_show_banner "$ver" "$(repo_url)"
}

# ------------------------------------------------------------------ status --

if [ "$do_status" -eq 1 ]; then
    iv=$(installed_version)
    if [ -n "$iv" ]; then
        say "Orchestra installed: v$iv (distribution: v$ver)"
        if [ -d "$proj/brain" ]; then
            say "Brain:     ./brain - present"
        else
            say_err "Brain:     MISSING"
        fi
        if [ -f "$proj/PROJECT.md" ]; then
            say "Passport:  PROJECT.md - present"
        else
            say "Passport:  none (the Scout creates it on the first /feature)"
        fi
        jn=0
        if [ -d "$proj/brain/journal" ]; then
            jn=$(find "$proj/brain/journal" -maxdepth 1 -name '2*.md' -type f | wc -l | tr -d ' ')
        fi
        say "Journal:   $jn file(s)"
        if [ -f "$proj/.orchestra-manifest.txt" ]; then
            mn=$(grep -c '[^[:space:]]' "$proj/.orchestra-manifest.txt" || true)
            say "Orchestra files in .claude/: ${mn:-0}"
        fi
        if [ -d "$proj/.claude" ]; then
            bn=$(find "$proj/.claude" -name '*.bak' -type f | wc -l | tr -d ' ')
            [ "$bn" -gt 0 ] && say_warn "Backups kept from updates: $bn (*.bak under .claude/)"
        fi
    else
        say "The orchestra is not installed in this project. Run: orchestra"
    fi
    say ""
    if [ -f "$seed_rules" ]; then
        say "Your shared seed: $seed_dir"
    else
        say "Your shared seed: not created yet (appears on orchestra --promote)"
    fi
    r=$(repo_url)
    case "$r" in
        *REPLACE_WITH*) say_dim "Public repository: not configured (--share unavailable)" ;;
        *)              say "Public repository: $r" ;;
    esac
    exit 0
fi

# ----------------------------------------------------------------- promote --

if [ "$do_promote" -eq 1 ]; then
    src="$proj/brain/rules/personal.md"
    if [ ! -f "$src" ]; then
        say_err "This project has no brain/rules/personal.md"
        exit 1
    fi
    initialize_user_seed
    mkdir -p "$(dirname "$seed_rules")"
    [ -f "$seed_rules" ] || printf '%s\n' "# Designer's personal rules" > "$seed_rules"

    seed_keys=$(rule_lines "$seed_rules" | cut -f1)

    new_file=$(mktemp)
    raw_file=$(mktemp)
    # Redirected from a file, not piped: a pipeline would put the loop in a
    # subshell and every key added to $seen_keys would be discarded at the
    # `done`, so duplicates within one personal.md would all be promoted.
    rule_lines "$src" > "$raw_file"
    : > "$new_file"
    seen_keys=''
    while IFS="$(printf '\t')" read -r key text; do
        [ -z "$text" ] && continue
        printf '%s\n' "$seed_keys" | grep -Fxq -- "$key" && continue
        printf '%s\n' "$seen_keys" | grep -Fxq -- "$key" && continue
        seen_keys="$seen_keys
$key"
        printf -- '- %s\n' "$text" >> "$new_file"
    done < "$raw_file"
    # wc, not `grep -c '^'`: on an empty file grep PRINTS 0 and EXITS 1, so the
    # usual `|| echo 0` guard appends a second zero and the count becomes the
    # two-line string "0\n0", which then blows up the -eq below.
    new_count=$(wc -l < "$new_file" | tr -d ' ')

    if [ "$new_count" -eq 0 ]; then
        rm -f "$new_file" "$raw_file"
        say "No new rules to promote."
        exit 0
    fi

    {
        printf '\n'
        printf '## Promoted from project %s - %s\n' "'$(basename "$proj")'" "$(date +%Y-%m-%d)"
        cat "$new_file"
    } >> "$seed_rules"
    rm -f "$new_file" "$raw_file"

    say_ok "Rules promoted to the seed: $new_count"
    say "Seed: $seed_rules"
    say "New projects will pick them up on install. Existing ones are untouched (isolation)."
    exit 0
fi

# ---------------------------------------------------------- install/update --

installed=$(installed_version)

if [ -n "$installed" ] && [ "$do_update" -eq 0 ]; then
    say_warn "Orchestra is already installed (v$installed). To update the agents: orchestra --update"
    exit 0
fi

# First install only, exactly as on the PowerShell side: --status, --promote
# and --share leave the script above this point, and a repeat run exits on the
# branch right above. None of them is a first impression.
[ "$do_update" -eq 0 ] && show_banner_if_wanted

files=$(payload_file_list)

# Scratch files go to mktemp, never into the project being installed into: a
# run interrupted halfway would otherwise leave its bookkeeping lying in
# someone's repository, and the next run would read it as its own.
bak_list=$(mktemp)
stale_list=$(mktemp)
# shellcheck disable=SC2317  # reached through the trap, not by falling into it
cleanup() { rm -f "$bak_list" "$stale_list"; }
trap cleanup EXIT

# The loop body runs in a subshell because of the pipe, so the list of backed
# up files comes back through the file rather than through a variable.
printf '%s\n' "$files" | while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    srcf="$payload/$rel"
    dstf="$proj/$rel"
    mkdir -p "$(dirname "$dstf")"
    if [ -f "$dstf" ] && ! cmp -s "$dstf" "$srcf"; then
        cp "$dstf" "$dstf.bak"
        printf '%s\n' "$rel" >> "$bak_list"
    fi
    cp "$srcf" "$dstf"
done

backed_up=$(cat "$bak_list")

# Files dropped from the distribution: never deleted silently, moved to .bak.
# Manifest entries written by the PowerShell installer use backslashes, so
# they are normalised on the way in - a project can legitimately be installed
# on Windows and updated from a shell, and vice versa.
manifest="$proj/.orchestra-manifest.txt"
orphans=''
if [ -f "$manifest" ]; then
    while IFS= read -r old; do
        # '\\' inside single quotes is two characters, which is exactly what
        # tr wants for one literal backslash. shellcheck reads it as a
        # misplaced quote escape; it is not.
        # shellcheck disable=SC1003
        old=$(printf '%s\n' "$old" | tr '\\' '/')
        [ -z "$(printf '%s' "$old" | tr -d '[:space:]')" ] && continue
        printf '%s\n' "$files" | grep -Fxq -- "$old" && continue
        if [ -e "$proj/$old" ]; then
            mv -f "$proj/$old" "$proj/$old.bak"
            orphans="$orphans$old
"
        fi
    done < "$manifest"
fi
printf '%s\n' "$files" > "$manifest"

# Clean up leftovers from an old flattened install (v<=1.4.0). Only files in
# the .claude/ root that are byte-identical to a distribution original are
# removed - those are provably installer debris.
printf '%s\n' "$files" | while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    name=$(basename "$rel")
    flat="$proj/.claude/$name"
    [ -f "$flat" ] || continue
    [ "$flat" = "$proj/$rel" ] && continue
    if cmp -s "$flat" "$payload/$rel"; then
        rm -f "$flat"
        printf '%s\n' "$name" >> "$stale_list"
    fi
done
if [ -s "$stale_list" ]; then
    stale=$(tr '\n' ',' < "$stale_list" | sed 's/,$//; s/,/, /g')
    say_dim "Removed debris from a previous install in .claude/: $stale"
fi

# AGENTS.md: only if the project does not have one yet
if [ -f "$payload/AGENTS.md" ]; then
    if [ ! -f "$proj/AGENTS.md" ]; then
        cp "$payload/AGENTS.md" "$proj/AGENTS.md"
        say_ok "Created AGENTS.md (project description for non-Claude agents)"
    elif [ "$do_update" -eq 0 ]; then
        say_dim "AGENTS.md already exists - left alone. Sample: dist/payload/AGENTS.md"
    fi
fi

# Brain: first install only, never touched on update
if [ ! -d "$proj/brain" ]; then
    cp -R "$payload/brain-seed" "$proj/brain"
    if [ -f "$seed_rules" ]; then
        cp "$seed_rules" "$proj/brain/rules/personal.md"
        say_ok "Created the project brain: ./brain (isolated) + personal rules from your seed"
    else
        say_ok "Created the project brain: ./brain (isolated)"
    fi
else
    say "The brain ./brain already exists - left alone."
fi

# specs: only if absent
if [ ! -d "$proj/specs" ]; then
    cp -R "$payload/specs" "$proj/specs"
    say_ok "Created specs/ with a spec template"
fi

printf '%s\n' "$ver" > "$proj/.orchestra-version"

say ""
if [ -n "$backed_up" ]; then
    say_warn "These files differed from the distribution and were kept as *.bak:"
    printf '%s\n' "$backed_up" | while IFS= read -r f; do
        [ -n "$f" ] && say_warn "  $f  ->  $f.bak"
    done
    say_warn "If those were your edits, port them into the new version of the file."
    say ""
fi
if [ -n "$orphans" ]; then
    say_warn "Files no longer in the distribution (moved to *.bak):"
    printf '%s' "$orphans" | while IFS= read -r f; do
        [ -n "$f" ] && say_warn "  $f"
    done
    say ""
fi

if [ "$do_update" -eq 1 ]; then
    say_ok "Agents and skills updated to v$ver. Brain, passport and specs untouched."
else
    say_ok "Orchestra v$ver installed into the project (isolated build)."
    say ""
    say_warn "Next:"
    say "  1. Put your spec in specs/  (template: specs/_template.md)"
    say "  2. claude"
    say "  3. /start                   - interactive entry point, asks what you want to do"
    say_dim "     or /feature specs/name.md if you already know the mode"
fi

# Every path out of this script MUST end in an explicit exit, for the same
# reason the PowerShell side insists on it: a caller that checks the exit code
# should never read a successful install as a failure.
exit 0
