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

update ingame deckbuilder ui.

## 3. Problem / Opportunity

What is wrong, missing, unclear, or worth improving?

- Current issue: the current deckbuilder ui is very basic and not very user friendly. there is no wasy to look at the cards and it's effect.
- Why it matters: the player needs to know the cards effect to know if it's good enough to put into their deck.
- Who it affects: player experience in deckbuilding.

## 4. Goals

- Goal 1: overhaul deckuilder ui
- Goal 2: show cards full details, hover for more details
- Goal 3: make it easier to see what each card does


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

- Core idea: have a catalog of cards the player has available to them, and show the cards in the deck as stacks of cards, sorted by type and cost. hover effect to show card details, and clicking on them reveals all details (scaling of the cards, tooltips at the side what mentioned keywords do (ex. heat, slow, etc.))
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

1. Rebaseline the deckbuilder work against the current repo state.
   - Treat `InventoryPanel.tscn` and `InventoryPanel.gd` as the starting point, not a greenfield screen.
   - Keep the existing `GameState` deck / owned_cards / equipped_slots model and add one source of truth for the minimum selected deck size, starting at 15 cards with room for future modifiers.
   - Keep the current selected deck, reserve pool, granted-by-equipment cards, and items tab structure, but upgrade the deck tab presentation.
2. Redesign the deck tab layout from list rows into a real deckbuilder workspace.
   - Replace the current stacked text panels with a multi-area layout:
     card catalog area, current deck area, and persistent detail / tooltip area.
   - Support clear counts for selected deck size, reserve copies, effective combat deck size, and minimum deck-size progress toward 15 cards.
   - Preserve map-overlay behavior and close/open flow through `SceneManager.toggle_inventory()`.
3. Introduce a reusable non-combat card presentation component for inventory/deckbuilding.
   - Add a dedicated card tile / preview scene for the inventory screen instead of relying on simple text rows.
   - Show card art, cost, type, short rules text, and copy counts in compact mode.
   - Support locked/granted state for equipment-added cards in their own separate "Granted by Equipment" stack, with hover text that names the source equipment.
4. Implement deckbuilder interactions on top of the existing data model.
   - Hovering a card shows an enlarged preview with full resolved text using current player stats.
   - Clicking a card updates a persistent side detail panel; clicking another card replaces the displayed details.
   - Adding/removing cards updates `GameState.deck`, respects owned copy counts, blocks invalid removals below the current minimum rule, and refreshes selected / reserve / effective deck summaries immediately.
   - Keep minimum-deck enforcement behind a helper or config-backed rule instead of hardcoding `15` directly in button handlers.
5. Add catalog organization and readability features.
   - Group cards into stacks by card id and sort them in the chosen default order: type -> cost -> name.
   - Keep granted cards in a separate clearly labeled section instead of merging them into editable deck stacks.
   - Add empty states for no reserve cards, no selected cards, and missing art / long-text cards.
6. Add keyword reminder support for detailed inspection.
   - Source reminder text from game data JSON, reusing builder-authored buff/debuff descriptions and reminder text where possible.
   - Show keyword explanations in the persistent side detail panel when a hovered/selected card references them.
   - If additional glossary coverage is needed beyond buffs/debuffs, extend the builder/data schema with an explicit authorable glossary or card keyword list rather than relying on fragile text matching in Godot.
7. Validate the overhaul against existing between-combat flows.
   - Manual pass: open from world map, inspect cards, hover cards, change the persistent detail panel by clicking different cards, add/remove reserve copies, verify granted cards stay locked and show source equipment, close/reopen overlay, reload save.
   - Regression pass: item/equipment tab still works, stat-scaled preview text still resolves correctly, and save/load keeps deck state unchanged.

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

- No blocking open questions at the moment.
- Resolved decisions for this phase:
  - Minimum deck size is 15 cards, with room for future modifiers from equipment or other mechanics.
  - Card stack ordering is type -> cost -> name.
  - Clicking a card updates a persistent side detail panel.
  - Equipment-granted cards stay in a separate "Granted by Equipment" section and show their source item on hover.
  - Keyword reminder text should come from builder-authored game data JSON.

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
