---
description: The design-system foundation for a greenfield project - from a style reference (Stitch/HTML code, a link, a screenshot) it creates variable collections in Figma, tokens in the repository and starter components. Call /foundation <path to reference or link>.
disable-model-invocation: true
---

You are building the design-system foundation of a new project.
Reference: $ARGUMENTS

If the line above is empty or still shows a literal `$ARGUMENTS`, ask the
designer for the path to the reference.

## Step 1. Assess the input
Identify the kind of reference and tell the designer honestly how precise
it will be:
- Code (HTML/CSS, Stitch export, tokens.json) -> values are EXACT.
- Figma file -> get_variable_defs / get_design_context -> exact.
- Screenshot -> values are APPROXIMATE. Warn: "colours were picked off an
  image, verify the hex values before approving."

## Step 2. Extraction and layering
Pull out every value: palette, spacing scale, radii, typography (families,
sizes, weights, line heights). Lay them out in two layers:
- primitives: raw values on scales (color.blue.500, space.4)
- semantic: meanings aliased onto primitives (bg.surface, text.muted,
  bg.accent, bg.danger, space.inline-md, radius.control)
Propose, do NOT decide: which colour is the accent, which is danger.

### PAUSE 1 - validating names
A table: value | primitive | semantic name | your reasoning.
Assigning meanings is the designer's decision. Wait for edits and for
"approved".

## Step 3. Writing (only after approval)
1. Repository: tokens/primitives.json and tokens/semantic.json (DTCG,
   semantics as aliases {color.blue.500}). Show the diff before writing.
2. Figma (use_figma): collection "1. Primitives" with no modes;
   collection "2. Semantic" with Light/Dark modes, values as aliases.
   Dark mode: propose inverting the neutrals, mark it "draft theme".
3. Typography: text styles from the reference. Check that the font is
   available in Figma; if it is not, SAY SO - do not silently substitute.

## Step 4. Starter components (one at a time, each shown)
Exactly 6: Button, Input, Card, Badge, Checkbox, Toggle.
- Page "Foundation - v0 - <date>"
- Each with states default/hover/focus/disabled (+error for Input),
  minimal variants (primary/secondary for Button, no more)
- All values bound ONLY to semantic variables
- Auto Layout, clear variant property names
- After each component, pause: screenshot, "next?"
Do NOT build complex components (Select, DatePicker, Table) - they will
appear later, driven by real feature needs.

## Step 5. Finalising
- Suggest the designer publishes the library by hand (more reliable)
- PROJECT.md: mode -> full-ds, record the collections and components
- CHANGELOG-DESIGN.md: entry "v0 - foundation - <date>": reference source,
  how many tokens, which components
- Remind them: /feature now works in full mode
