---
description: A design concept for one key page of a greenfield project - 2-3 visual directions to agree on, before any design system exists. Pure visuals. Call /concept; the brief can be a file or plain text.
disable-model-invocation: true
---

CONCEPT mode. This is the one place in the orchestra where raw values are
LEGAL: there is no system yet, you are searching for a visual language.
The "tokens only" invariant does not apply until the concept is approved.

Brief: $ARGUMENTS

If the line above is empty or still shows a literal `$ARGUMENTS`, the
argument was not substituted. Ask the designer for the brief (step 1).

## Step 1. The brief
If what you were given is unclear, ask the designer everything at once,
not one question at a time: product and audience in one sentence; the key
page (landing? dashboard? product card?); 3 mood words; anti-references
("definitely not like X"); real content for the page, if any.
"Lorem" placeholders are forbidden - nobody signs off a concept with fake
text. No content - write plausible copy yourself from the brief and say
that you did.

## Step 2. Directions IN WORDS (cheap, before building)
Sources of visual reference for this step (concept mode only):
- The ui-ux-pro-max skill, if installed (/skills will show it): use its
  style, palette and type-pairing databases to pick directions suited to
  the product category from the brief.
- Refero Styles (styles.refero.design): the FREE part - a catalogue of
  2000+ AI-readable design systems of real products (DESIGN.md: colours,
  typography, spacing, rules). Use WebFetch to open 2-3 styles relevant to
  the product category and use their DESIGN.md as a reference for the
  DIRECTION (not a copy: inspiration from the logic of the system, not
  reproduction of a brand).

Propose 3 distinct directions. For each: a mood name, a type pairing,
colour logic (not a palette but the logic: "monochrome plus one accent"),
density/air, character of shapes, and - if the direction leans on a style
from a database - a link to the source. The directions MUST differ; three
shades of one taste do not count.

### PAUSE - choosing directions
The designer picks 2 (or edits and picks). Building three is expensive;
one leaves nothing to choose between at sign-off.

## Step 3. Build via HTML -> Figma
For each chosen direction:
1. Build ONE complete page as a self-contained HTML file
   (concepts/<direction>.html in the repo): real content, considered
   typography, all the page's sections. This is your strong suit - use it
   fully.
2. Send it to Figma via generate_figma_design onto its own page named
   "Concept <A/B> - <name> - <date>".
3. Next to the mockup, a passport frame for the direction: mood, type
   pairing, colour logic, what this direction optimises for and what it
   pays - so it can be defended to stakeholders.

## Step 4. Handover
- CHANGELOG-DESIGN.md: entry "Concepts - <date> - [under review]"
- Tell the designer: once a direction is chosen, the approved HTML is an
  EXACT code reference for /foundation. The chain is:
  /concept -> sign-off -> /foundation concepts/<chosen>.html -> /feature.
  Nothing has to be re-extracted by eye - the code already exists.

## Tool isolation for concept mode
ui-ux-pro-max and Refero Styles work ONLY here. Do not call or mention them
in /feature or /foundation: there, decisions are dictated by the project's
design system, not by style databases.

## Limits (say them honestly)
- generate_figma_design transfers the page as layers, but the layer
  structure will not be ideal - this is material for agreeing on VISUALS,
  not a production mockup. Production mockups start after /foundation with
  clean components.
- Changes to a direction after sign-off go into the HTML and get
  re-transferred, not hand-tweaked in the concept's layers.
