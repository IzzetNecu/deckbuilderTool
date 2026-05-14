# Feature Spec Template

Copy this file for any new feature, rework, balance pass, or update plan.

Use it in three modes:
- Brainstorm: fill only the overview, goals, rough idea, and open questions.
- Scoped plan: add implementation areas, risks, and acceptance criteria.
- Ready-to-build spec: fill everything that applies.

Skip any section that is not useful for the feature. Keep this practical.

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

What is this feature or update in one sentence?

## 3. Problem / Opportunity

What is wrong, missing, unclear, or worth improving?

- Current issue:
- Why it matters:
- Who it affects:

## 4. Goals

- Goal 1:
- Goal 2:
- Goal 3:

## 5. Non-Goals

What this feature will explicitly not solve right now?

- Non-goal 1:
- Non-goal 2:

## 6. Player Experience

What should the player see, feel, or understand when this is done?

- Before:
- After:
- Expected player benefit:

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

- New cards / enemies / relics / buffs / items:
- New icons / portraits / art placeholders:
- Text to write:

### UI / UX

- Layout changes:
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
