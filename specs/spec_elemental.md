# Feature Spec Template

---

## 1. Metadata

- Feature name:
- Owner:
- Date:
- Status:
  - Idea / Brainstorm
  - Planned
  - In Progress
  - Ready to Implement
  - Shipped
- Priority:
  - Low / Medium / High
- Related files:
- Related systems:
  - Combat
  - Builder
  - Data / JSON
  - UI
  - Progression
  - Audio / Visual

## 2. One-Line Summary

Add elemental effects to cards and items and equipment and buffs and debuffs

## 3. Problem / Opportunity

What is wrong, missing, unclear, or worth improving?

- Current issue:
    There is no elemental system in the game.
- Why it matters:
    Adding elemental effects to cards will make the game more interesting and strategic.
- Who it affects:
    The player, content authoring, and any future progression work.

## 4. Goals

- Goal 1:
    Add elemental effects to cards
- Goal 2:
    Add elemental resistances and weaknesses to enemies
- Goal 3:
    Add elemental effects to items and equipment
- Goal 4:
    Add elemental buffs and debuffs

## 5. Non-Goals

What this feature will explicitly not solve right now?

- Non-goal 1:
- Non-goal 2:

## 6. Player Experience

What should the player see, feel, or understand when this is done?

- Before:
    The player can see and use cards, enemies, items, and equipment.
- After:
    The player can see and use cards, enemies, items, and equipment with elemental effects.
- Expected player benefit:
    The player can have a more interesting and strategic game experience.

## 7. Current State

Describe the current implementation or behavior.

- Current behavior:
- Relevant scenes/scripts/data:
- Known bugs or limitations:

## 8. Proposed Change

Describe the intended solution at a high level.

- Core idea:
- Why this approach:
- Alternatives considered:

## 9. Scope Breakdown

Only fill the parts that apply.

### Runtime / Godot

- Scenes to update:
- Scripts to update:
- New nodes/components:
- Signals / flow changes:

### Builder / Editor

- New editor sections:
- Existing editors to change:
- New inputs or restrictions:
- Authoring workflow impact:

### Data / Schema

- New fields:
- Changed fields:
- Removed legacy fields:
- Schema version impact:
- Export/import impact:

### Content

| elemental type | buff description | debuff description |
| fire | heat | burn |
| water | ? | ? |
| earth | regen - gain health at the end of turn | poison - lose health at the start of turn|
| wind | haste - draws extra card each turn | slowed - discard a card at the start of turn|
| ice | scaled - gives armor at the end of turn | chill - removes armor at the end of turn |
| lightning | energized - increase energy per turn | jolted - decrease energy per turn | 

### UI / UX

- Layout changes: new elemental damage and resistance UI, elemental types visible on cards and enemies and items and equipment
- Interaction changes:
- Hover / tooltip behavior:
- Visibility rules:

## 10. Rules and Behavior Details

Write exact behavior here if the feature needs precise implementation rules.

- Trigger conditions:
- Limits / caps:
- Order of operations:
- Edge cases:
- Failure cases:

## 11. Implementation Plan

Break the work into concrete steps.

1. Step 1:
2. Step 2:
3. Step 3:
4. Step 4:

## 12. Acceptance Criteria

What must be true for this feature to count as done?

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## 13. Testing / Validation

- Manual test cases:
- Data cases to verify:
- UI states to verify:
- Regression risks:

## 14. Migration / Cleanup

If old behavior exists, define how it should be handled.

- Legacy code to remove:
- Legacy data to support temporarily:
- One-time migration needed:
- Safe cleanup after rollout:

## 15. Risks / Unknowns

- Risk 1:
- Risk 2:
- Unknown 1:

## 16. Open Questions

- Question 1:
- Question 2:
- Question 3:

## 17. Brainstorm Starters

Use these if the feature is still early.

- What is the smallest useful version of this feature?
- What can be hardcoded first and data-driven later?
- Does this belong in runtime, builder, or both?
- What existing system should this reuse instead of duplicating?
- What will probably break if this changes?
- What old implementation should be deleted instead of adapted?
- What content, UI, or tooltip support is needed so players understand it?

## 18. Notes

Freeform notes, references, links, sketches, or follow-up ideas.
