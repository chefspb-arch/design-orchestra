## What changes

<!-- One paragraph: what and why. -->

## How it was verified

<!-- Console output beats a retelling. -->

- [ ] Tested against an **empty temporary folder**, not a real project
- [ ] `Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1` - clean
- [ ] If `.ps1` changed: saved as **UTF-8 with BOM** (PowerShell 5.1 reads
      BOM-less files as ANSI, which corrupts any non-ASCII text)

## Checklist for the areas touched

- [ ] Touched `-Share` or `-Promote`: verified that nothing leaves the
      machine except explicitly confirmed lines
- [ ] Touched files under `dist/payload/`: verified that `orchestra` and
      `orchestra -Update` deploy them correctly
- [ ] Changed installer behaviour: README / GUIDE / INSTALL updated
- [ ] User-visible change: there is an entry in `CHANGELOG.md`