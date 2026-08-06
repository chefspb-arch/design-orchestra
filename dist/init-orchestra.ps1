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
#                            yourself, by hand
#   orchestra -Status      - what is installed and at which version
#
# Every project gets its OWN copy of the agents and its OWN brain (./brain).
# Projects cannot see each other. Updating the seed never changes old projects.
#
# Your shared seed lives OUTSIDE this repository:
#   %APPDATA%\design-orchestra\seed  (override with $env:DESIGN_ORCHESTRA_HOME)

param(
  [switch]$Update,
  [switch]$Promote,
  [switch]$Share,
  [switch]$Status
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

  if (@($candidates).Count -eq 0) {
    Write-Host "No rules marked '$PromoteMarker' were found. Nothing to propose." -ForegroundColor Yellow
    if (@($nonCandidate).Count -gt 0) {
      Write-Host "The file has $(@($nonCandidate).Count) unmarked rule(s) - they are not considered."
    }
    exit 0
  }

  Write-Host ""
  Write-Host "Candidates found: $(@($candidates).Count). Confirm EACH one separately." -ForegroundColor Yellow
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

  $notSent = @($declined) + @($nonCandidate)
  if (@($notSent).Count -gt 0) {
    Write-Host "NOT BEING SENT - $(@($notSent).Count) rule(s):" -ForegroundColor DarkGray
    foreach ($n in $declined)     { Write-Host "  - $n   [you declined]" -ForegroundColor DarkGray }
    foreach ($n in $nonCandidate) { Write-Host "  - $n   [not marked]" -ForegroundColor DarkGray }
    Write-Host ""
  }

  if (@($approved).Count -eq 0) {
    Write-Host "No rules approved. Nothing was sent."
    exit 0
  }

  Write-Host "GOING INTO A PUBLIC ISSUE - $(@($approved).Count) rule(s):" -ForegroundColor Yellow
  foreach ($a in $approved) { Write-Host "  - $a" }
  Write-Host ""

  $bodyText = "## Proposed rules" + "`n`n" +
              (($approved | ForEach-Object { "- $_" }) -join "`n") + "`n`n" +
              "---`nSubmitted via orchestra -Share (v$ver). Each rule was confirmed individually."
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
    if ($newRel -contains $old) { continue }
    $p = Join-Path $proj $old
    if (Test-Path $p) { Move-Item -Force $p "$p.bak"; $orphans += $old }
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
  Write-Host "  3. /feature specs/name.md   - the Scout will create PROJECT.md"
}

# Every path out of this script MUST end in an explicit exit. Falling off the
# end leaves $LASTEXITCODE untouched in the caller: $null in a fresh process,
# or a stale code left by some earlier command in a long session. A caller
# that checks the exit code then reads a successful install as a failure -
# which is exactly what broke CI.
exit 0
