---
description: Record an edit made outside the /feature cycle - by hand, later, "tomorrow". Call /log <what you changed and why>. Without this, out-of-cycle edits never reach the learning loop.
disable-model-invocation: true
---

The designer reports an edit made outside the cycle: $ARGUMENTS

Empty or a literal `$ARGUMENTS` - ask what exactly was changed.

1. Call the chronicler agent in light mode: one entry in
   brain/journal/<YYYY-MM>.md:
   ### <date> - out-of-cycle edit
   - What: <from the designer's words>
   - Why: <from the designer's words; if missing, ask ONE question>
   - Affected: <frame/feature, if named>
2. The Chronicler checks: does this edit resemble an existing brain rule?
   If it does, mark it "rule X violated outside the cycle" (that feeds the
   violation rate). Repeated >=2 times in the journal -> propose a rule
   right now, without waiting for the end of a cycle.
3. Remind the designer in one line: out-of-cycle edits do not count towards
   the untouched-frames metric, so no trend is computed from them.
