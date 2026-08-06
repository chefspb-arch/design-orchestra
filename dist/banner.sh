# banner.sh - the Design Orchestra ASCII banner for the shell installer.
#
# This file is a LIBRARY. Sourcing it defines functions and nothing else: it
# prints nothing, sets no shell options, installs no traps, exports no
# variables and touches no globals. Sourcing it twice is a no-op the second
# time. orchestra.sh can therefore source it at the very top, before it has
# decided what the run is even about.
#
#   . "$(dirname "$0")/banner.sh"
#   orchestra_show_banner "$version" "$repo_url"
#
# Suppression is the caller's business, not this file's: parse --no-banner in
# orchestra.sh and simply do not call orchestra_show_banner. That keeps the
# banner out of --status/--update/--promote/--share by construction, since
# those paths never call it either.

# Colour support, in the order the answers actually settle the question:
#   NO_COLOR set to anything non-empty  -> no colour (https://no-color.org)
#   stdout is not a terminal            -> no colour (piped or redirected;
#                                          escape codes would land in the file)
#   TERM unset, empty or "dumb"         -> no colour
#   tput says fewer than 8 colours      -> no colour
# Returns 0 (true in shell terms) when colour is safe to emit.
orchestra_banner_use_color() {
    [ -n "${NO_COLOR:-}" ] && return 1
    [ -t 1 ] || return 1
    case "${TERM:-}" in
        '' | dumb) return 1 ;;
    esac
    # tput is the authority when it exists, but it is absent on minimal images
    # and it fails loudly on an unknown TERM - neither is a reason to abort, so
    # both fall back to "the checks above were enough".
    if command -v tput >/dev/null 2>&1; then
        _oc_colors=$(tput colors 2>/dev/null) || _oc_colors=''
        if [ -n "$_oc_colors" ] && [ "$_oc_colors" -lt 8 ] 2>/dev/null; then
            unset _oc_colors
            return 1
        fi
        unset _oc_colors
    fi
    return 0
}

# orchestra_show_banner <version> <repo-url>
#
# Strict ASCII, 7 art lines, every line inside 78 columns - the same art the
# PowerShell installer prints, byte for byte. The width limit is not decoration:
# a line wider than the terminal wraps, and a banner that wraps mid-frame reads
# as a broken install.
orchestra_show_banner() {
    _ob_ver="${1:-}"
    # Drop the scheme to keep the signature line inside 78 columns.
    _ob_repo=$(printf '%s' "${2:-}" | sed -e 's|^https\{0,1\}://||')

    _ob_green=''
    _ob_reset=''
    if orchestra_banner_use_color; then
        _ob_green=$(printf '\033[32m')
        _ob_reset=$(printf '\033[0m')
    fi

    _ob_tag="  Design Orchestra v${_ob_ver}  -  ${_ob_repo}"

    # Colour is opened and closed on every line rather than once around the
    # whole block. One span would be shorter, but anything that cuts the output
    # short - Ctrl+C, a dead pipe, `head` - would then swallow the reset and
    # leave the user's terminal green for good.
    orchestra_banner_line '' \
        '  .--------------------------------------------------------------.' \
        '  | [o][o][o]                                                    |' \
        '  +----------+---------------------------------------------------+' \
        '  | ######## |  +---------------+  +--------------------------+  |' \
        '  | ######## |  |               |  --------------------------    |' \
        '  | ######## |  +---------------+  -----------------------       |' \
        '  +----------+---------------------------------------------------+' \
        ''

    # A custom $DESIGN_ORCHESTRA_REPO can be any length. Give the address its
    # own line rather than letting it wrap through the middle of the version.
    # A URL longer than 78 columns still wraps - it cannot be broken and it
    # must not be truncated, since a half URL is worse than a wrapped one.
    if [ "${#_ob_tag}" -le 78 ]; then
        orchestra_banner_line "$_ob_tag"
    else
        orchestra_banner_line "  Design Orchestra v${_ob_ver}" "  ${_ob_repo}"
    fi
    orchestra_banner_line ''

    unset _ob_ver _ob_repo _ob_green _ob_reset _ob_tag
}

# Internal. Prints each argument as its own line, wrapped in the colour chosen
# by the caller ($_ob_green / $_ob_reset - empty strings when colour is off).
# printf, not echo: `echo -e` is not portable, and a repo URL containing a
# backslash gets mangled by the echo builtins that interpret escapes.
orchestra_banner_line() {
    for _ob_l in "$@"; do
        if [ -z "$_ob_l" ]; then
            printf '\n'
        else
            printf '%s%s%s\n' "$_ob_green" "$_ob_l" "$_ob_reset"
        fi
    done
    unset _ob_l
}
