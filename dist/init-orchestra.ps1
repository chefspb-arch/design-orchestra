# init-orchestra.ps1 - deploys an ISOLATED orchestra build into the current project.
#
# Usage (from your project root):
#   orchestra              - install the orchestra into this project
#   orchestra -Update      - update agents/skills to the distribution version
#                            (brain, passport and specs are left alone; changed
#                             files are kept next to the new ones as *.bak)
#   orchestra -Promote     - this project's personal rules -> your shared seed,
#                            so NEW projects start with them
#   orchestra -Share       - propose portable rules to the PUBLIC seed (GitHub).
#                            Every rule is confirmed SEPARATELY; you submit it
#                            yourself, by hand. Also offers this cycle's
#                            portable findings (contentious-point decisions,
#                            source conflicts, exit-test frequencies) - each
#                            one anonymised BEFORE you see it, then confirmed
#                            one by one, exactly like a rule.
#                            PROJECT.md is never read: the passport is dirty by
#                            definition (names, mail, file keys, node ids,
#                            phone numbers), and anonymisation is a floor, not
#                            a guarantee - so there is no switch to opt into it
#   orchestra -Status      - what is installed and at which version
#   orchestra -NoBanner    - install without the ASCII banner. The banner is
#                            printed on a FIRST install only - never on
#                            -Status, -Update, -Promote or -Share, and never on
#                            a repeat run - so this switch is for that one
#                            case, and for scripted installs that want nothing
#                            but the result
#
# Every project gets its OWN copy of the agents and its OWN brain (./brain).
# Projects cannot see each other. Updating the seed never changes old projects.
#
# Your shared seed lives OUTSIDE this repository:
#   %APPDATA%\design-orchestra\seed  (override with $env:DESIGN_ORCHESTRA_HOME)

# [CmdletBinding()] is what makes an unknown switch an ERROR. Without it a
# script's param() block is "simple": anything it does not recognise is
# collected into $args and silently ignored, so `orchestra -Shrae` quietly
# performs a plain install, and `orchestra -Share -IncludeDecisions` - a switch
# that existed while this feature was being built - quietly runs an ordinary
# -Share. Someone who still types it would conclude the passport held no
# decisions, rather than learning it is deliberately never read.
[CmdletBinding()]
param(
  [switch]$Update,
  [switch]$Promote,
  [switch]$Share,
  [switch]$Status,
  # The bash port spells this --no-banner. PowerShell cannot: with
  # [CmdletBinding()] a double dash is not a parameter prefix at all, so
  # `--no-banner` would be a positional argument and the script would reject it
  # outright. Here it is -NoBanner; the alias keeps -no-banner working too, for
  # whoever comes from the shell side out of habit.
  [Alias('no-banner')]
  [switch]$NoBanner
)

$ErrorActionPreference = "Stop"

# Public seed repository. If you forked, do NOT edit this line - set
# $env:DESIGN_ORCHESTRA_REPO instead, so updates never conflict.
$DefaultRepoUrl = "https://github.com/chefspb-arch/design-orchestra"

$PromoteMarker = "promote candidate"

# Patterns are built UP FRONT and only into variables: in PowerShell the
# -replace operator binds tighter than +, so an inline concatenation like
#   $t -replace 'a' + $x + 'b', ''
# silently parses differently than it reads, and nothing gets stripped.
$MarkerRe      = [regex]::Escape($PromoteMarker)
$MarkerParenRe = '\s*\(\s*' + $MarkerRe + '[^)]*\)'
$MarkerTailRe  = '\s*[-]?\s*' + $MarkerRe + '.*$'

# ---------------------------------------------------------------- paths ----

$dist = $PSScriptRoot
if (-not $dist) { $dist = Split-Path -Parent $MyInvocation.MyCommand.Path }
$payload  = Join-Path $dist "payload"
$repoRoot = Split-Path -Parent $dist

if (-not (Test-Path $payload)) {
  Write-Host "No payload folder next to the script ($payload)." -ForegroundColor Red
  Write-Host "The distribution was not unpacked completely." -ForegroundColor Red
  exit 1
}

$verFile = @((Join-Path $repoRoot "VERSION"), (Join-Path $dist "VERSION")) |
           Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $verFile) {
  Write-Host "VERSION file not found (neither in the repo root nor next to the script)." -ForegroundColor Red
  exit 1
}
$ver = (Get-Content $verFile -Raw).Trim()

$proj = (Get-Location).Path

function Get-OrchestraHome {
  if ($env:DESIGN_ORCHESTRA_HOME) { return $env:DESIGN_ORCHESTRA_HOME }
  return (Join-Path $env:APPDATA "design-orchestra")
}
$orchHome  = Get-OrchestraHome
$seedDir   = Join-Path $orchHome "seed"
$seedRules = Join-Path $seedDir "rules\personal.md"

function Get-RepoUrl {
  if ($env:DESIGN_ORCHESTRA_REPO) { return $env:DESIGN_ORCHESTRA_REPO.TrimEnd('/') }
  return $DefaultRepoUrl.TrimEnd('/')
}

# Guard against running inside the orchestra repository itself - by real path,
# not by folder name: GitHub's "Download ZIP" gives the folder a different name.
$projFull = (Resolve-Path $proj).Path.TrimEnd('\')
$repoFull = (Resolve-Path $repoRoot).Path.TrimEnd('\')
if ($projFull -eq $repoFull -or
    $projFull.StartsWith($repoFull + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
  Write-Host "You are inside the orchestra repository ($repoFull)." -ForegroundColor Red
  Write-Host "Go to your own project folder and run orchestra there." -ForegroundColor Red
  exit 1
}

# --------------------------------------------------------------- banner ----

# Strict ASCII, and every line inside 78 columns. Two hard reasons, both learned
# from a console rather than guessed: PowerShell 5.1 under the default raster
# fonts renders Unicode box drawing as mojibake, and a line wider than the
# window wraps - a banner that wraps mid-frame reads as a broken install, which
# is the first thing a new user would see.
$BannerArt = @(
  '  .--------------------------------------------------------------.',
  '  | [o][o][o]                                                    |',
  '  +----------+---------------------------------------------------+',
  '  | ######## |  +---------------+  +--------------------------+  |',
  '  | ######## |  |               |  --------------------------    |',
  '  | ######## |  +---------------+  -----------------------       |',
  '  +----------+---------------------------------------------------+'
)

function Test-BannerColor {
  # https://no-color.org - any non-empty value means "no colour".
  if ($env:NO_COLOR) { return $false }
  if ($env:TERM -eq 'dumb') { return $false }
  # Redirected output is a file or a pipe: colour there is pointless at best.
  # No guard around the call: IsOutputRedirected has been on System.Console
  # since .NET 4.5, and Windows PowerShell 5.1 cannot run on anything older.
  if ([Console]::IsOutputRedirected) { return $false }
  # Hosts without RawUI (remoting, embedders) cannot colour at all.
  if (-not $Host.UI -or -not $Host.UI.RawUI) { return $false }
  return $true
}

function Show-Banner {
  # -NoBanner is checked by the caller, not here: suppression is a decision
  # about the run, and keeping it at the single call site means the banner
  # cannot leak into a mode that simply forgot to ask.
  $color = Test-BannerColor
  # The scheme is dropped to keep the line inside 78 columns.
  $repo  = (Get-RepoUrl) -replace '^https?://', ''
  $tag   = "  Design Orchestra v$ver  -  $repo"
  if ($tag.Length -le 78) {
    $lines = @('') + $BannerArt + @('', $tag, '')
  } else {
    # A custom $env:DESIGN_ORCHESTRA_REPO can be any length. Give the address
    # its own line instead of letting it wrap through the middle of the version.
    $lines = @('') + $BannerArt + @('', "  Design Orchestra v$ver", "  $repo", '')
  }
  foreach ($l in $lines) {
    if ($color) { Write-Host $l -ForegroundColor Green } else { Write-Host $l }
  }
}

# -------------------------------------------------------------- helpers ----

function Get-InstalledVersion {
  $f = Join-Path $proj ".orchestra-version"
  if (Test-Path $f) { return (Get-Content $f -Raw).Trim() }
  return $null
}

function Test-RuleLine([string]$line) {
  if ($line -match '^\s*-{3,}\s*$') { return $false }   # horizontal rule
  # 4+ spaces of indent is a markdown code block, not a list item. Without
  # this check the marked example in the personal.md header was picked up
  # by -Share as if it were a real rule.
  return ($line -match '^ {0,3}[-*]\s+\S')
}

function Get-RuleText([string]$line) {
  $t = $line.Trim()
  $t = $t -replace '^[-*]\s+', ''
  # the marker is bookkeeping - it never goes into the public text
  $t = $t -replace $MarkerParenRe, ''
  $t = $t -replace $MarkerTailRe, ''
  return $t.Trim()
}

function Get-RuleKey([string]$text) {
  return (($text -replace '\s+', ' ').Trim().ToLowerInvariant())
}

# A hint, not a filter: flags lines that LOOK like project data.
# The decision always stays with the human - see the per-rule prompt in -Share.
function Get-DataHint([string]$text) {
  if ($text -match 'https?://')             { return "a link" }
  if ($text -match 'figma\.com')            { return "a Figma link" }
  if ($text -match '[0-9]{3,}:[0-9]{3,}')   { return "looks like a Figma node id" }
  if ($text -match '#[0-9A-Fa-f]{6}\b')     { return "a specific hex colour" }
  if ($text -match '\b[A-Za-z0-9]{22}\b')   { return "looks like a fileKey" }
  return $null
}

# ------------------------------------------------- anonymisation (Share) ----
# Applied BEFORE the human sees a line, never after. The point is that nobody
# has to spot an email in a wall of text at the moment they are saying yes.
# It is a floor, not a guarantee - Test-ResidualIdentity flags what it cannot
# safely rewrite, and the human still decides.

# Names cannot be detected reliably, so they are listed, not guessed:
#   $env:DESIGN_ORCHESTRA_REDACT_NAMES = "Jane Roe;John Doe"
function Get-RedactNameList {
  if (-not $env:DESIGN_ORCHESTRA_REDACT_NAMES) { return @() }
  return @($env:DESIGN_ORCHESTRA_REDACT_NAMES -split ';' |
           ForEach-Object { $_.Trim() } |
           Where-Object { $_ -ne "" })
}

# ConvertTo-, not Remove-: this returns a rewritten copy and changes nothing on
# the machine. A Remove-* verb would (correctly) be asked to support -WhatIf
# and -Confirm, which would be meaningless for a pure string transform.
function ConvertTo-AnonymisedText([string]$text) {
  $t = $text
  foreach ($n in (Get-RedactNameList)) {
    $t = $t -replace [regex]::Escape($n), '<name removed>'
  }
  # The list above only helps if someone filled it in. Real names in these
  # files almost always arrive as an ATTRIBUTION, so catch that shape directly
  # - it is narrow enough not to eat domain terms like "Purchase Order".
  # -creplace: -replace ignores case and would match ordinary lowercase words.
  $roles = 'Compliance|Legal|Finance|Design|Engineering|Product|Admissions|Marketing|SCO|PM|QA|CTO|CEO'
  $t = $t -creplace ('[A-Z][a-z]{2,}\s+[A-Z][a-z]{2,}(?=\s*[,/]\s*(' + $roles + ')\b)'), '<name removed>'
  $t = $t -creplace '(?<=(?:—|--|-)\s)[A-Z][a-z]{2,}\s+[A-Z][a-z]{2,}(?=\s*[,.]|\s*$)', '<name removed>'
  $t = $t -creplace '(?<=\b(?:by|per|from|contact|asked|confirmed by|according to)\s)[A-Z][a-z]{2,}\s+[A-Z][a-z]{2,}\b', '<name removed>'
  $t = $t -replace '[\w.%+\-]+@[\w.\-]+\.[A-Za-z]{2,}', '<email removed>'
  $t = $t -replace 'https?://(www\.)?figma\.com/\S*', '<figma link removed>'
  $t = $t -replace 'https?://\S+', '<link removed>'
  # -creplace, not -replace: PowerShell's -replace is case-INSENSITIVE, so
  # [A-Z]{2,6}-[0-9]+ would also eat ordinary text like "top-10" or "step-07".
  $t = $t -creplace '\b[A-Z]{2,6}-[0-9]{1,6}\b', '<ticket removed>'
  # Instance ids first: the plain node-id rule below would otherwise consume
  # the second half of I30:967;2012:878 and leave the first half stranded.
  $t = $t -replace '\bI?[0-9]{1,7}:[0-9]{1,7};[0-9]{1,7}:[0-9]{1,7}\b', '<node id removed>'
  $t = $t -replace '\b[0-9]{1,7}:[0-9]{1,7}\b', '<node id removed>'
  $t = $t -replace '\b[A-Za-z]:\\[^\s,;]+', '<path removed>'
  # A Figma fileKey is a bare 22+ char alphanumeric token. Checked last so the
  # rewrites above do not leave one stranded mid-sentence.
  $t = $t -replace '(?<![\w/])[A-Za-z0-9]{22,}(?![\w/])', '<figma key removed>'
  return ($t -replace '\s{2,}', ' ').Trim()
}

# What the rewrites above cannot safely touch. A hint for the human, never a
# silent edit - auto-stripping every Capitalised Pair would eat "Chapter 35"
# and "Certificate of Eligibility" along with the surnames.
function Test-ResidualIdentity([string]$text) {
  $found = @()
  # -cmatch throughout. With -match every one of these fires on every line,
  # because -match ignores case and [A-Z] then matches lowercase too - a hint
  # that fires always is worse than no hint, since people learn to skip it.
  if ($text -cmatch '\b[A-Z][a-z]{2,}\s+[A-Z][a-z]{2,}\b') { $found += "a capitalised name-like pair" }
  if ($text -cmatch '\bwww\.\S+')                          { $found += "a bare domain" }
  # 9+ digits, so ISO dates like 2026-08-06 do not read as phone numbers.
  if (($text -replace '[^0-9]', '').Length -ge 9 -and
      $text -cmatch '\+?[0-9][0-9\s\-().]{7,}[0-9]')       { $found += "something phone-shaped" }
  if ($text -cmatch '@[A-Za-z0-9_\-]{2,}')                 { $found += "an @handle" }
  if (@($found).Count -eq 0) { return $null }
  return ($found -join ", ")
}

# Pull list/table lines out of the sections we are willing to publish. The
# whitelist is by SECTION, not by file: a file is never shipped wholesale.
#
# All state is function-local. An earlier version kept the accumulator in
# $script: scope, because the nested Flush helper could not assign to its
# parent's locals - a PowerShell rule that catches everyone once. That worked,
# but it put the text queued for a PUBLIC issue in a script-wide variable that
# any later code could read or overwrite. The helper is gone and the state is
# local, so the only way out of this function is its return value.
function Get-SectionItemList([string]$Path, [string[]]$HeadingPattern) {
  if (-not (Test-Path $Path)) { return @() }
  # Indexed, not foreach: we need lookahead for table headers, and we have to
  # rejoin wrapped lines. Taking markdown one physical line at a time ships
  # half-sentences - "...out of scope, contradicting" - into a public issue.
  $lines    = @(Get-Content $Path -Encoding UTF8)
  $items    = [System.Collections.ArrayList]::new()
  $current  = ''
  $inWanted = $false

  for ($i = 0; $i -lt $lines.Count; $i++) {
    $ln = $lines[$i]

    if ($ln -match '^\s*#{1,6}\s') {
      if ($current.Trim() -ne '') { [void]$items.Add((($current -replace '\s{2,}', ' ').Trim())) }
      $current  = ''
      $inWanted = $false
      foreach ($p in $HeadingPattern) {
        if ($ln -match $p) { $inWanted = $true; break }
      }
      continue
    }
    if (-not $inWanted) { continue }

    if ($ln.Trim() -eq '') {
      if ($current.Trim() -ne '') { [void]$items.Add((($current -replace '\s{2,}', ' ').Trim())) }
      $current = ''
      continue
    }

    if ($ln -match '^\s*\|') {
      if ($current.Trim() -ne '') { [void]$items.Add((($current -replace '\s{2,}', ' ').Trim())) }
      $current = ''
      if ($ln -match '^\s*\|[\s\-:|]+\|\s*$') { continue }          # separator
      # A row followed by a separator is the header, not data.
      if ($i + 1 -lt $lines.Count -and $lines[$i + 1] -match '^\s*\|[\s\-:|]+\|\s*$') { continue }
      $cells = @($ln.Trim().Trim('|') -split '\|' |
                 ForEach-Object { $_.Trim() } |
                 Where-Object { $_ -ne '' })
      if ($cells.Count -ge 2) { [void]$items.Add(($cells -join ' - ')) }
      continue
    }

    if ($ln -match '^\s{0,3}[-*]\s+\S') {
      if ($current.Trim() -ne '') { [void]$items.Add((($current -replace '\s{2,}', ' ').Trim())) }
      $current = ($ln.Trim() -replace '^[-*]\s+', '')
      continue
    }
    if ($ln -match '^\s{0,3}[0-9]{1,3}[.)]\s+\S') {
      if ($current.Trim() -ne '') { [void]$items.Add((($current -replace '\s{2,}', ' ').Trim())) }
      $current = ($ln.Trim() -replace '^[0-9]{1,3}[.)]\s+', '')
      continue
    }
    # anything else non-blank inside the section continues the current item
    if ($current -ne '') { $current = $current + ' ' + $ln.Trim() }
  }
  if ($current.Trim() -ne '') { [void]$items.Add((($current -replace '\s{2,}', ' ').Trim())) }
  return $items.ToArray()
}

$script:NoConsole = $false

# No live console (script, CI, scheduler) - every answer is "no". Consent to
# publish anything outside this machine comes from a human, never by default.
function Read-YesNo([string]$prompt) {
  if ($script:NoConsole) { return $false }
  try {
    $a = Read-Host $prompt
  } catch {
    $script:NoConsole = $true
    Write-Host ""
    Write-Host "No interactive input - treating every answer as 'no'." -ForegroundColor Yellow
    Write-Host "orchestra -Share only works in a live console: a human confirms." -ForegroundColor Yellow
    Write-Host ""
    return $false
  }
  return ($a -match '^\s*(y|yes)\s*$')
}

function Initialize-UserSeed {
  if (Test-Path $seedDir) { return }
  New-Item -ItemType Directory -Force -Path $seedDir | Out-Null
  Copy-Item -Recurse -Force (Join-Path $payload "brain-seed\*") $seedDir
  Write-Host "Created your shared seed: $seedDir" -ForegroundColor Green
}

function Get-PayloadFileList {
  $claudeSrc = Join-Path $payload ".claude"
  $out = @()
  foreach ($f in (Get-ChildItem -Path $claudeSrc -File -Recurse)) {
    $rel = ".claude\" + $f.FullName.Substring($claudeSrc.Length).TrimStart('\')
    $out += [pscustomobject]@{ Src = $f.FullName; Rel = $rel }
  }
  return $out
}

# --------------------------------------------------------------- Status ----

if ($Status) {
  $iv = Get-InstalledVersion
  if ($iv) {
    Write-Host "Orchestra installed: v$iv (distribution: v$ver)"
    if (Test-Path (Join-Path $proj "brain")) {
      Write-Host "Brain:     ./brain - present"
    } else {
      Write-Host "Brain:     MISSING" -ForegroundColor Red
    }
    if (Test-Path (Join-Path $proj "PROJECT.md")) {
      Write-Host "Passport:  PROJECT.md - present"
    } else {
      Write-Host "Passport:  none (the Scout creates it on the first /feature)"
    }
    $j = Get-ChildItem (Join-Path $proj "brain\journal") -Filter "2*.md" -ErrorAction SilentlyContinue
    Write-Host "Journal:   $(@($j).Count) file(s)"
    $mf = Join-Path $proj ".orchestra-manifest.txt"
    if (Test-Path $mf) {
      $n = @(Get-Content $mf -Encoding UTF8 | Where-Object { $_.Trim() -ne "" }).Count
      Write-Host "Orchestra files in .claude\: $n"
    }
    $baks = Get-ChildItem (Join-Path $proj ".claude") -Filter "*.bak" -Recurse -ErrorAction SilentlyContinue
    if (@($baks).Count -gt 0) {
      Write-Host "Backups kept from updates: $(@($baks).Count) (*.bak under .claude\)" -ForegroundColor Yellow
    }
  } else {
    Write-Host "The orchestra is not installed in this project. Run: orchestra"
  }
  Write-Host ""
  if (Test-Path $seedRules) {
    Write-Host "Your shared seed: $seedDir"
  } else {
    Write-Host "Your shared seed: not created yet (appears on orchestra -Promote)"
  }
  $r = Get-RepoUrl
  if ($r -like "*REPLACE_WITH*") {
    Write-Host "Public repository: not configured (-Share unavailable)" -ForegroundColor DarkGray
  } else {
    Write-Host "Public repository: $r"
  }
  exit 0
}

# -------------------------------------------------------------- Promote ----

if ($Promote) {
  $src = Join-Path $proj "brain\rules\personal.md"
  if (-not (Test-Path $src)) {
    Write-Host "This project has no brain\rules\personal.md" -ForegroundColor Red
    exit 1
  }
  Initialize-UserSeed
  $dstDir = Split-Path -Parent $seedRules
  if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Force -Path $dstDir | Out-Null }
  if (-not (Test-Path $seedRules)) {
    Set-Content -Path $seedRules -Encoding UTF8 -Value "# Designer's personal rules"
  }

  $seedLines = @(Get-Content $seedRules -Encoding UTF8)
  $seedKeys  = @()
  foreach ($ln in $seedLines) {
    if (Test-RuleLine $ln) { $seedKeys += (Get-RuleKey (Get-RuleText $ln)) }
  }

  $new = @()
  $newKeys = @()
  foreach ($ln in (Get-Content $src -Encoding UTF8)) {
    if (-not (Test-RuleLine $ln)) { continue }
    $text = Get-RuleText $ln
    if ($text -eq "") { continue }
    $key = Get-RuleKey $text
    if ($seedKeys -contains $key) { continue }
    if ($newKeys  -contains $key) { continue }
    $newKeys += $key
    $new += "- $text"
  }

  if (@($new).Count -eq 0) { Write-Host "No new rules to promote."; exit 0 }

  Add-Content -Path $seedRules -Encoding UTF8 -Value ""
  Add-Content -Path $seedRules -Encoding UTF8 -Value "## Promoted from project '$(Split-Path $proj -Leaf)' - $(Get-Date -Format yyyy-MM-dd)"
  foreach ($n in $new) { Add-Content -Path $seedRules -Encoding UTF8 -Value $n }

  Write-Host "Rules promoted to the seed: $(@($new).Count)" -ForegroundColor Green
  Write-Host "Seed: $seedRules"
  Write-Host "New projects will pick them up on install. Existing ones are untouched (isolation)."
  exit 0
}

# ---------------------------------------------------------------- Share ----

if ($Share) {
  $src = Join-Path $proj "brain\rules\personal.md"
  if (-not (Test-Path $src)) {
    Write-Host "This project has no brain\rules\personal.md" -ForegroundColor Red
    exit 1
  }
  $repo = Get-RepoUrl
  if ($repo -like "*REPLACE_WITH*") {
    Write-Host "Public repository is not configured." -ForegroundColor Red
    Write-Host 'Set it once:  $env:DESIGN_ORCHESTRA_REPO = "https://github.com/<login>/design-orchestra"' -ForegroundColor Yellow
    exit 1
  }
  if ($repo -notmatch '^https://[A-Za-z0-9.\-]+/') {
    Write-Host "DESIGN_ORCHESTRA_REPO must be an https URL. Got: $repo" -ForegroundColor Red
    exit 1
  }

  # A candidate is ONLY the line the marker sits on.
  # Block-level marking is deliberately unsupported: it used to make one
  # marked line drag every following rule of the section into a public issue.
  $candidates   = @()
  $nonCandidate = @()
  $headingWarn  = $false
  foreach ($ln in (Get-Content $src -Encoding UTF8)) {
    if ($ln -match '^\s*#{1,6}\s' -and $ln -match $MarkerRe) {
      $headingWarn = $true
      continue
    }
    if (-not (Test-RuleLine $ln)) { continue }
    $text = Get-RuleText $ln
    if ($text -eq "") { continue }
    if ($ln -match $MarkerRe) { $candidates += $text }
    else { $nonCandidate += $text }
  }

  if ($headingWarn) {
    Write-Host ""
    Write-Host "Note: the '$PromoteMarker' marker sits on a HEADING." -ForegroundColor Yellow
    Write-Host "Block marking is not supported - mark each rule on its own line." -ForegroundColor Yellow
  }

  # ---- this cycle's portable findings, anonymised before anyone sees them ----
  # Whitelisted sections only. A file is never shipped whole.
  $findings   = @()   # @{ Group; Text }
  $excluded   = @()

  $chg = Join-Path $proj "CHANGELOG-DESIGN.md"
  foreach ($it in (Get-SectionItemList $chg @('[Cc]ontentious', '[Ss]ource conflict'))) {
    $findings += [pscustomobject]@{ Group = "Contentious-point decisions and source conflicts"; Text = $it }
  }

  foreach ($tf in (Get-ChildItem -Path $proj -Filter "EXIT-TEST*.md" -File -ErrorAction SilentlyContinue)) {
    foreach ($it in (Get-SectionItemList $tf.FullName @('[Ss]ticking point', '[Ff]requency', '[Ff]low break'))) {
      $findings += [pscustomobject]@{ Group = "Exit-test findings (synthetic run, frequencies)"; Text = $it }
    }
  }

  # PROJECT.md is never opened. It is the one file guaranteed to hold client
  # names, colleagues' names, mail, phone numbers, file keys and node ids all
  # at once, and anonymisation is a floor rather than a guarantee: a phone
  # number written as "+7 921 555 12 34" survives every rewrite here and only
  # raises a hint. A switch to opt in was tried and removed - the person most
  # likely to pass it is the person least likely to reread ten passport lines
  # at a y/n prompt.
  $passport = Join-Path $proj "PROJECT.md"
  if (Test-Path $passport) {
    $excluded += "PROJECT.md - the passport is dirty by definition; never read, and there is no switch to change that."
  }

  # Anonymise BEFORE display, then drop anything that anonymised down to noise.
  $findings = @($findings | ForEach-Object {
    $clean = ConvertTo-AnonymisedText $_.Text
    if ($clean.Length -lt 12) { return }
    [pscustomobject]@{ Group = $_.Group; Text = $clean }
  } | Where-Object { $null -ne $_ })

  if (@($candidates).Count -eq 0 -and @($findings).Count -eq 0) {
    Write-Host "No rules marked '$PromoteMarker' and no portable findings. Nothing to propose." -ForegroundColor Yellow
    if (@($nonCandidate).Count -gt 0) {
      Write-Host "The file has $(@($nonCandidate).Count) unmarked rule(s) - they are not considered."
    }
    foreach ($e in $excluded) { Write-Host "  not read: $e" -ForegroundColor DarkGray }
    exit 0
  }

  if (@($findings).Count -gt 0 -and @(Get-RedactNameList).Count -eq 0) {
    Write-Host ""
    Write-Host "No name list is set, so only attribution-shaped names are caught automatically." -ForegroundColor Yellow
    Write-Host 'Set one for this machine:  $env:DESIGN_ORCHESTRA_REDACT_NAMES = "Jane Roe;John Doe"' -ForegroundColor Yellow
    Write-Host "Until then, read every finding for colleagues' names before you say yes." -ForegroundColor Yellow
  }

  Write-Host ""
  Write-Host "To confirm: $(@($candidates).Count) rule(s), $(@($findings).Count) finding(s). EACH one separately." -ForegroundColor Yellow
  Write-Host "Findings are anonymised before you see them - names, mail, keys, node ids, tickets and links are already stripped." -ForegroundColor DarkGray
  Write-Host "An empty answer means 'no'. Nothing is sent - an issue form opens, you press the button."
  Write-Host ""

  $approved = @()
  $declined = @()
  $i = 0
  foreach ($c in $candidates) {
    $i++
    Write-Host "[$i/$(@($candidates).Count)] $c"
    $hint = Get-DataHint $c
    if ($hint) {
      Write-Host "        hint: this looks like project data ($hint). Check it yourself." -ForegroundColor Yellow
    }
    if (Read-YesNo "        Propose this rule to the public seed? (y/n)") {
      $approved += $c
    } else {
      $declined += $c
    }
    Write-Host ""
  }

  # ---- findings, same ceremony: one at a time, anonymised text shown as-is ----
  $okFindings  = @()
  $noFindings  = @()
  if (@($findings).Count -gt 0) {
    $j = 0
    $lastGroup = ""
    foreach ($f in $findings) {
      $j++
      if ($f.Group -ne $lastGroup) {
        Write-Host "-- $($f.Group) --" -ForegroundColor Cyan
        $lastGroup = $f.Group
      }
      Write-Host "[$j/$(@($findings).Count)] $($f.Text)"
      $res = Test-ResidualIdentity $f.Text
      if ($res) {
        Write-Host "        hint: anonymisation could not safely rewrite $res. Read it again before saying yes." -ForegroundColor Yellow
      }
      if (Read-YesNo "        Propose this finding publicly? (y/n)") {
        $okFindings += $f
      } else {
        $noFindings += $f
      }
      Write-Host ""
    }
  }

  $notSent = @($declined) + @($nonCandidate)
  if (@($notSent).Count -gt 0 -or @($noFindings).Count -gt 0 -or @($excluded).Count -gt 0) {
    Write-Host "NOT BEING SENT:" -ForegroundColor DarkGray
    foreach ($n in $declined)     { Write-Host "  - $n   [rule, you declined]" -ForegroundColor DarkGray }
    foreach ($n in $nonCandidate) { Write-Host "  - $n   [rule, not marked]" -ForegroundColor DarkGray }
    foreach ($n in $noFindings)   { Write-Host "  - $($n.Text)   [finding, you declined]" -ForegroundColor DarkGray }
    foreach ($e in $excluded)     { Write-Host "  - $e" -ForegroundColor DarkGray }
    Write-Host ""
  }

  if (@($approved).Count -eq 0 -and @($okFindings).Count -eq 0) {
    Write-Host "Nothing approved. Nothing was sent."
    exit 0
  }

  Write-Host "GOING INTO A PUBLIC ISSUE - $(@($approved).Count) rule(s), $(@($okFindings).Count) finding(s):" -ForegroundColor Yellow
  foreach ($a in $approved)   { Write-Host "  - $a" }
  foreach ($f in $okFindings) { Write-Host "  - $($f.Text)" }
  Write-Host ""

  $bodyText = ""
  if (@($approved).Count -gt 0) {
    $bodyText += "## Proposed rules" + "`n`n" +
                 (($approved | ForEach-Object { "- $_" }) -join "`n") + "`n`n"
  }
  foreach ($g in (@($okFindings) | ForEach-Object { $_.Group } | Select-Object -Unique)) {
    $bodyText += "## $g" + "`n`n" +
                 ((@($okFindings) | Where-Object { $_.Group -eq $g } |
                   ForEach-Object { "- $($_.Text)" }) -join "`n") + "`n`n"
  }
  $bodyText += "---`nSubmitted via orchestra -Share (v$ver). Each item was confirmed individually. " +
               "Findings were anonymised before being shown for confirmation; no project file was exported whole."
  $bodyFile = Join-Path $env:TEMP "orchestra-share.md"
  Set-Content -Path $bodyFile -Value $bodyText -Encoding UTF8

  if (-not (Read-YesNo "Open the issue form in a browser? (y/n)")) {
    Write-Host "Cancelled. Nothing was sent. Text saved to: $bodyFile"
    exit 0
  }

  $url = "$repo/issues/new?title=$([uri]::EscapeDataString('Rule proposal'))&body=$([uri]::EscapeDataString($bodyText))"
  if ($url.Length -gt 6000) {
    Write-Host "Too many rules for a URL - GitHub would truncate the request." -ForegroundColor Yellow
    Write-Host "Text saved to: $bodyFile - paste it into the form by hand."
    Start-Process "$repo/issues/new"
  } else {
    Start-Process $url
  }
  Write-Host "Issue form opened. Edit before publishing - you submit it yourself." -ForegroundColor Green
  Write-Host "Copy of the text: $bodyFile"
  exit 0
}

# ------------------------------------------------------- install/update ----

$installed = Get-InstalledVersion

if ($installed -and -not $Update) {
  Write-Host "Orchestra is already installed (v$installed). To update the agents: orchestra -Update" -ForegroundColor Yellow
  exit 0
}

# First install only. -Status, -Update, -Promote and -Share all leave the script
# above this point, and a repeat `orchestra` exits on the line right above: none
# of them is a first impression, all of them are someone waiting for one useful
# line of output.
if (-not $Update -and -not $NoBanner) { Show-Banner }

# --- Agents and skills: always copied (this IS the update) ---
# Copied file by file along relative paths: Copy-Item -Recurse into a missing
# destination used to flatten the tree, and the skills overwrote each other
# (they are all named SKILL.md).
$files     = Get-PayloadFileList
$claudeDst = Join-Path $proj ".claude"
New-Item -ItemType Directory -Force -Path $claudeDst | Out-Null

$backedUp = @()
foreach ($it in $files) {
  $dstPath = Join-Path $proj $it.Rel
  $dstDir  = Split-Path -Parent $dstPath
  if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Force -Path $dstDir | Out-Null }
  if (Test-Path $dstPath) {
    if ((Get-FileHash $dstPath).Hash -ne (Get-FileHash $it.Src).Hash) {
      Copy-Item -Force $dstPath "$dstPath.bak"
      $backedUp += $it.Rel
    }
  }
  Copy-Item -Force $it.Src $dstPath
}

# --- Files dropped from the distribution: never deleted silently, moved to .bak ---
$manifestPath = Join-Path $proj ".orchestra-manifest.txt"
$newRel = @($files | ForEach-Object { $_.Rel })
$orphans = @()
if (Test-Path $manifestPath) {
  foreach ($old in (Get-Content $manifestPath -Encoding UTF8)) {
    if ($old.Trim() -eq "") { continue }
    # orchestra.sh writes this file with forward slashes. Compared raw, every
    # single entry then looks like a file that has left the distribution, so
    # an -Update after a shell install moved the WHOLE deployment to *.bak and
    # announced that eleven files had been dropped. The separator is not part
    # of the identity of the path, so it is normalised before comparing.
    $oldNorm = $old.Replace('/', '\')
    if ($newRel -contains $oldNorm) { continue }
    $p = Join-Path $proj $oldNorm
    if (Test-Path $p) { Move-Item -Force $p "$p.bak"; $orphans += $oldNorm }
  }
}
Set-Content -Path $manifestPath -Value $newRel -Encoding UTF8

# --- Clean up leftovers from an old flattened install (v<=1.4.0) ---
# Only files in the .claude\ root that are byte-identical to a distribution
# original are removed - those are provably installer debris.
$stale = @()
foreach ($it in $files) {
  $name = Split-Path $it.Rel -Leaf
  $flat = Join-Path $claudeDst $name
  if (-not (Test-Path $flat)) { continue }
  if ((Resolve-Path $flat).Path -eq (Resolve-Path (Join-Path $proj $it.Rel)).Path) { continue }
  if ((Get-FileHash $flat).Hash -eq (Get-FileHash $it.Src).Hash) {
    Remove-Item $flat -Force
    $stale += $name
  }
}
if (@($stale).Count -gt 0) {
  Write-Host "Removed debris from a previous install in .claude\: $($stale -join ', ')" -ForegroundColor DarkGray
}

# --- AGENTS.md: only if the project does not have one yet ---
$agentsSrc = Join-Path $payload "AGENTS.md"
$agentsDst = Join-Path $proj "AGENTS.md"
if (Test-Path $agentsSrc) {
  if (-not (Test-Path $agentsDst)) {
    Copy-Item -Force $agentsSrc $agentsDst
    Write-Host "Created AGENTS.md (project description for non-Claude agents)" -ForegroundColor Green
  } elseif (-not $Update) {
    Write-Host "AGENTS.md already exists - left alone. Sample: dist\payload\AGENTS.md" -ForegroundColor DarkGray
  }
}

# --- Brain: first install only, never touched on update ---
if (-not (Test-Path (Join-Path $proj "brain"))) {
  Copy-Item -Recurse (Join-Path $payload "brain-seed") (Join-Path $proj "brain")
  if (Test-Path $seedRules) {
    Copy-Item -Force $seedRules (Join-Path $proj "brain\rules\personal.md")
    Write-Host "Created the project brain: .\brain (isolated) + personal rules from your seed" -ForegroundColor Green
  } else {
    Write-Host "Created the project brain: .\brain (isolated)" -ForegroundColor Green
  }
} else {
  Write-Host "The brain .\brain already exists - left alone."
}

# --- specs: only if absent ---
if (-not (Test-Path (Join-Path $proj "specs"))) {
  Copy-Item -Recurse (Join-Path $payload "specs") (Join-Path $proj "specs")
  Write-Host "Created specs\ with a spec template" -ForegroundColor Green
}

Set-Content -Path (Join-Path $proj ".orchestra-version") -Value $ver -Encoding UTF8

Write-Host ""
if (@($backedUp).Count -gt 0) {
  Write-Host "These files differed from the distribution and were kept as *.bak:" -ForegroundColor Yellow
  foreach ($f in $backedUp) { Write-Host "  $f  ->  $f.bak" -ForegroundColor Yellow }
  Write-Host "If those were your edits, port them into the new version of the file." -ForegroundColor Yellow
  Write-Host ""
}
if (@($orphans).Count -gt 0) {
  Write-Host "Files no longer in the distribution (moved to *.bak):" -ForegroundColor Yellow
  foreach ($f in $orphans) { Write-Host "  $f" -ForegroundColor Yellow }
  Write-Host ""
}

if ($Update) {
  Write-Host "Agents and skills updated to v$ver. Brain, passport and specs untouched." -ForegroundColor Green
} else {
  Write-Host "Orchestra v$ver installed into the project (isolated build)." -ForegroundColor Green
  Write-Host ""
  Write-Host "Next:" -ForegroundColor Yellow
  Write-Host "  1. Put your spec in specs\  (template: specs\_template.md)"
  Write-Host "  2. claude"
  Write-Host "  3. /start                   - interactive entry point, asks what you want to do"
  Write-Host "     or /feature specs/name.md if you already know the mode" -ForegroundColor DarkGray
}

# Every path out of this script MUST end in an explicit exit. Falling off the
# end leaves $LASTEXITCODE untouched in the caller: $null in a fresh process,
# or a stale code left by some earlier command in a long session. A caller
# that checks the exit code then reads a successful install as a failure -
# which is exactly what broke CI.
exit 0
