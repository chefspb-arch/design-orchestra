# UX rules (general)
Short, checkable rules. The Advisor justifies against them, the Analyst
checks against them. Grown through the Chronicler once the designer approves.

## Forms
- A validation error belongs at its field, not in a banner at the top.
- Validate on blur or on submit; not on every keystroke.
- Error text: what happened plus what to do. Never just "Error!".
- Submit disabled - show why, not just the disabled state.
- One column of fields; short related ones (zip + city) may share a row.
- Labels above fields, not as placeholders.

## Actions
- Destructive - confirm with the object's name, not "Are you sure?".
- Irreversible - the word "permanently" in the confirmation.
- One primary action per screen; secondary ones are visually quieter.
- After an action, an explicit result: toast / state change / navigation.

## Flow
- A wizard of 3+ steps needs a progress indicator and a way back without
  losing data.
- An operation over 1s needs a loading state; over 3s, one with a description.
- Empty states are always designed: what this is plus how to fill it.
- An interrupted flow resumes on return instead of starting over.

## Content
- A button is named after its action: "Save draft", not "OK".
- Numbers, dates and money in the project's locale format.
- Long text truncates with the full version on hover/tap.

## Accessibility
- An interactive target is at least 44x44 on touch.
- Focus is visible on every interactive element.
- Meaning is never carried by colour alone.
