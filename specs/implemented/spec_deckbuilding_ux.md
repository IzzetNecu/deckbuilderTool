# Feature Spec

## 1. Metadata

- Feature name: Deckbuilding UX loadout presets and validation pass
- Owner: current
- Date: 2026-05-17
- Status:
  - Planned
- Priority:
  - High
- Related files:
  - `specs/spec_deckbuilding_ux.md`
  - `game/autoloads/GameState.gd`
  - `game/scenes/ui/InventoryPanel.gd`
  - `game/scenes/ui/InventoryPanel.tscn`
  - `game/scenes/combat/CombatManager.gd`
  - `src/data/models.js`
  - `src/builder/editors/player-editor.js`
- Related systems:
  - Combat
  - UI
  - Progression
  - Data / JSON

## 2. One-Line Summary

Add true deck-and-equipment loadout presets on top of the shipped inventory deckbuilder, with explicit validation, save migration, and a small preset-management UI.

## 3. Problem / Opportunity

- Current issue:
  The original UX draft is stale. The current repo already has a usable deckbuilder with selected deck stacks, reserve stacks, granted-by-equipment stacks, minimum deck-size enforcement, and equipment slots. What is still missing is the feature the draft actually wanted: fast switching between different strategies without rebuilding the deck and equipment manually every time.
- Why it matters:
  The current UX still makes experimentation expensive because `GameState` only stores one active `deck` and one active `equipped_slots` map. Players can edit that one configuration, but they cannot save multiple builds and swap between them safely.
- Who it affects:
  Players who want to test multiple builds, future progression features that grant more owned cards/equipment, and save/load stability for the between-combat loop.

## 4. Goals

- Goal 1:
  Support multiple saved loadouts where each loadout contains a selected deck and equipped-slot configuration.
- Goal 2:
  Let the player switch loadouts from the inventory overlay with validation and clear failure messaging.
- Goal 3:
  Preserve the current reserve/selected/granted deckbuilder workflow and layer presets on top instead of replacing it.
- Goal 4:
  Migrate existing saves that only contain one `deck` plus `equipped_slots` into the new model without data loss.

## 5. Non-Goals

- Non-goal 1:
  Rebuilding the existing card-stack deck editor or equipment bag flow from scratch.
- Non-goal 2:
  Adding builder-authored default multiple loadouts in this phase. Runtime save/load presets are enough.
- Non-goal 3:
  Allowing loadout switching during combat, events, or any scene other than the inventory overlay on the world map.

## 6. Player Experience

- Before:
  The player can edit one active deck and one active equipment layout, but changing strategies means manually redoing those choices.
- After:
  The player opens inventory, chooses a saved loadout, sees whether it is valid, and can switch to it in one action. If the target loadout is invalid because owned cards or equipment changed, the UI explains why and blocks the switch or save action.
- Expected player benefit:
  Strategy swapping becomes fast, safe, and understandable without losing the current detailed card-editing flow.

## 7. Current State

- Current behavior:
  `InventoryPanel.gd` already renders a deck workspace with reserve, selected, and granted sections, and the items tab already supports explicit equip/unequip actions. `GameState.gd` owns one active `deck` array and one active `equipped_slots` dictionary, and `CombatManager.gd` uses `GameState.get_effective_deck()` to build the combat draw pile.
- Relevant scenes/scripts/data:
  - Active deck and active equipment state live in `game/autoloads/GameState.gd:30-35`.
  - Deck add/remove and minimum-size enforcement live in `game/autoloads/GameState.gd:133-155`.
  - Effective combat deck computation lives in `game/autoloads/GameState.gd:172-192`.
  - Equip logic and slot blocking live in `game/autoloads/GameState.gd:200-259`.
  - Save/load currently serialize only one active deck plus one active equipment layout in `game/autoloads/GameState.gd:302-365`.
  - The current deckbuilder workspace is assembled in `game/scenes/ui/InventoryPanel.gd:81-129`.
  - The items tab equip/unequip flow is assembled in `game/scenes/ui/InventoryPanel.gd:131-184` and `game/scenes/ui/InventoryPanel.gd:398-523`.
- Known bugs or limitations:
  - No loadout preset data model exists anywhere in runtime or builder code.
  - Switching strategies means mutating the one active `deck` and `equipped_slots` source of truth.
  - Validation exists only at the card removal point. There is no holistic "is this build valid to save/switch/use" check.
  - Shared-inventory conflicts are not represented. Two theoretical presets can both claim the same owned copy of a card or the same unique equipment item because presets do not exist yet.
- Verified counts:
  - Current code directly involved in this UX totals 1,956 lines:
    `wc -l game/scenes/ui/InventoryPanel.gd game/autoloads/GameState.gd src/builder/editors/player-editor.js src/data/models.js`
  - The current inventory panel alone is 813 lines:
    `wc -l game/scenes/ui/InventoryPanel.gd`
  - Current exported content contains 1 player, 22 cards, and 8 equipment entries; the default player starts with an 8-card selected deck and 15 owned cards:
    `node -e "const d=require('./game/data/game_data.json'); const p=d.players[0]||{}; console.log(JSON.stringify({players:d.players.length,equipment:d.equipment.length,cards:d.cards.length,defaultStartingDeck:(p.startingDeck||[]).length,defaultOwnedCards:(p.startingOwnedCards||[]).length}, null, 2))"`

## 8. Proposed Change

- Core idea:
  Add loadout presets as an additive runtime model in `GameState`, keep owned inventory global, and treat the currently edited `deck` and `equipped_slots` as the active loadout view. The inventory overlay gets a preset-management strip above the existing deckbuilder so the player can create, rename, duplicate, delete, validate, and switch loadouts without losing the current editor.
- Why this approach:
  It preserves the shipped deckbuilder, keeps combat integration intact through `get_effective_deck()`, and limits the blast radius to the existing state owner and inventory UI instead of introducing a second deckbuilding scene.
- Alternatives considered:
  - Option A, recommended:
    Fixed small set of runtime loadout slots layered onto `GameState`.
    This matches the original intent, minimizes UI complexity, and keeps switching quick.
  - Option B:
    Unlimited named presets with create/delete/reorder management.
    This is more flexible but expands UI, persistence, and edge-case handling noticeably.
  - Option C:
    Keep one active deck and add import/export or copy-from-current only.
    This does not solve the actual strategy-switching pain point and is not enough.

## 9. Scope Breakdown

### Runtime / Godot

- Scenes to update:
  - `InventoryPanel.tscn`
- Scripts to update:
  - `GameState.gd`
  - `InventoryPanel.gd`
  - `CombatManager.gd` only if active-loadout reads need explicit helper usage
- New nodes/components:
  - Loadout selector row above the current deck workspace
  - Buttons for save/apply, rename, duplicate, and delete
  - Validation/status area for invalid loadouts
- Signals / flow changes:
  - Switching loadouts must atomically refresh deck stacks, granted cards, equipped slots, summary text, and status messaging

### Builder / Editor

- New editor sections:
  - None required in phase 1 if presets are runtime-save data only
- Existing editors to change:
  - None required unless we later decide to author multiple starter loadouts
- New inputs or restrictions:
  - None for this phase
- Authoring workflow impact:
  - No builder change required to ship runtime loadout presets

### Data / Schema

- New fields:
  - Runtime save field: `loadouts`
  - Runtime save field: `active_loadout_id`
  - Per-loadout fields: `id`, `label`, `deck`, `equipped_slots`
  - Optional derived validation result structure returned by helper functions, not necessarily serialized
- Changed fields:
  - `deck` and `equipped_slots` become the active-loadout working view rather than the only saved configuration
- Removed legacy fields:
  - None immediately; legacy single-deck saves need migration support
- Schema version impact:
  - Medium for save data only
- Export/import impact:
  - `game/data/game_data.json` does not need a schema change for phase 1

### Content

- New cards / enemies / relics / buffs / items:
  - None required
- New icons / portraits / art placeholders:
  - None required
- Text to write:
  - Loadout labels
  - Validation error messages
  - Empty-state text for missing loadouts

### UI / UX

- Layout changes:
  - Add a loadout strip above the deck workspace while keeping the current card catalog, current deck, and granted sections
- Interaction changes:
  - The player can save the current build into a loadout, switch to another loadout, duplicate a loadout, rename it, and delete non-default loadouts
- Hover / tooltip behavior:
  - Existing card-detail behavior remains unchanged
  - Invalid loadouts show short reasons in the loadout strip and a fuller explanation in the status area
- Visibility rules:
  - Loadout controls are visible only in the deck tab of the inventory overlay

## 10. Rules and Behavior Details

- Trigger conditions:
  - Loadout switching is available only while the inventory overlay is open outside combat.
- Limits / caps:
  - Working assumption for this spec: 3 fixed loadout slots.
  - If the user chooses named unlimited presets instead, the data model stays similar but the UI/CRUD scope increases.
- Order of operations:
  1. Global owned state remains `owned_cards`, `equipment`, `consumables`, and `key_items`.
  2. Each loadout stores only its selected `deck` plus `equipped_slots`.
  3. Activating a loadout copies its `deck` and `equipped_slots` into the active runtime view.
  4. `get_effective_deck()` continues to derive combat cards from active selected deck plus active equipment-granted cards.
  5. Combat starts from the active loadout only.
- Edge cases:
  - A loadout can become invalid after loot changes, item removal, or future deck-size rules.
  - A loadout with a two-handed weapon and an off-hand item must resolve atomically; switching cannot briefly produce an impossible slot state.
  - Two presets cannot both consume more copies of a card or item than the player owns at switch time.
  - Legacy saves with no loadout data must migrate into a default loadout built from the current `deck` and `equipped_slots`.
- Failure cases:
  - Invalid loadouts must not silently auto-corrupt into a different build during switch.
  - Switching loadouts must not leave deck stacks, granted cards, or equipped-slot rows showing stale data from the previous preset.
  - Old saves must not fail to load just because loadouts are newly introduced.

## 11. Missing Components To Add

1. A runtime save schema for multiple loadouts.
2. A `GameState` API for create, rename, duplicate, delete, validate, activate, and migrate loadouts.
3. One central validation helper that checks minimum deck size, owned card counts, owned equipment counts, slot compatibility, and blocked-slot rules.
4. An inventory-panel header strip for loadout management.
5. Explicit invalid-loadout messaging and switch/save blocking behavior.
6. Regression coverage for save migration, combat deck generation, and equipment-granted cards after a loadout swap.

## 12. Implementation Plan

1. Rebaseline `GameState` around an additive loadout model.
   - Add `loadouts` and `active_loadout_id`.
   - Add helpers for `get_active_loadout()`, `set_active_loadout()`, `save_current_state_into_loadout()`, `create_loadout_from_current()`, `duplicate_loadout()`, `rename_loadout()`, `delete_loadout()`, and `validate_loadout()`.
   - Keep `deck` and `equipped_slots` as the active working view to minimize breakage, but route all writes through loadout-aware helpers.
2. Add save migration.
   - When `load_game()` sees no `loadouts`, create one default migrated loadout from legacy `deck` plus `equipped_slots`.
   - Preserve existing save compatibility and avoid rejecting migrated data on first load.
3. Centralize validation.
   - Build one validation result object that checks:
     minimum deck size, selected-vs-owned card counts, equipped-vs-owned item counts, valid slot type per item, and two-handed/off-hand conflicts.
   - Use the same helper for save/apply/switch decisions and UI messaging.
4. Add the loadout controls to `InventoryPanel`.
   - Insert a header strip above the current deck workspace.
   - Show current loadout, slot labels, invalid-state badges, and actions for switch/save/rename/duplicate/delete.
   - Refresh the existing reserve/selected/granted sections from the newly active loadout after every action.
5. Keep combat integration stable.
   - Confirm `CombatManager` still pulls from `GameState.get_effective_deck()` without knowing about loadout internals.
   - Verify granted-by-equipment cards update correctly after switching loadouts.
6. Run regression validation.
   - Fresh game
   - Migrated old save
   - Invalid preset due to missing owned cards
   - Invalid preset due to equipment conflict
   - Switching between two valid presets repeatedly

## 13. Acceptance Criteria

- [ ] Existing saves that contain only one `deck` and one `equipped_slots` layout load successfully and migrate into a default loadout.
- [ ] The deck tab exposes visible loadout controls without removing the current reserve/selected/granted card workflow.
- [ ] The player can save at least one alternate loadout and switch between loadouts from the inventory overlay.
- [ ] Switching loadouts updates selected deck stacks, granted-by-equipment stacks, equipped slot rows, and summary counts in one refresh.
- [ ] Loadout validation blocks impossible builds and explains why the build is invalid.
- [ ] Combat still starts with the effective deck from the active loadout, including equipment-granted cards.
- [ ] Invalid legacy or stale presets do not crash the inventory overlay or corrupt the active deck.

## 14. Testing / Validation

- Manual test cases:
  - Create a second loadout from the current build, change cards and equipment, then switch back and forth.
  - Load a pre-loadout save and confirm migration creates a usable default preset.
  - Attempt to switch to a preset that no longer matches owned inventory and confirm the UI blocks or warns exactly as specified.
  - Equip a two-handed weapon in one preset and an off-hand build in another, then switch repeatedly.
- Data cases to verify:
  - One valid default loadout only
  - Multiple valid loadouts sharing the same owned pool
  - Stale loadout referencing missing equipment
  - Stale loadout below minimum deck size
- UI states to verify:
  - Empty preset slot
  - Active valid preset
  - Active invalid preset
  - Delete/rename/duplicate flow
- Regression risks:
  - Save/load compatibility
  - `CombatManager` draw-pile initialization
  - Inventory panel growing further past its current size unless some loadout UI is factored into helpers or a dedicated component

## 15. Migration / Cleanup

- Legacy code to remove:
  - None immediately
- Legacy data to support temporarily:
  - Saves containing only top-level `deck` and `equipped_slots`
- One-time migration needed:
  - Yes; create a default loadout from legacy active state
- Safe cleanup after rollout:
  - Once migrated-save support is stable, reduce direct non-helper writes to `deck` and `equipped_slots`

## 16. Risks / Unknowns

- Risk 1:
  `GameState.deck` and `GameState.equipped_slots` are used as direct globals today, so loadout work can become brittle unless those writes are centralized early.
- Risk 2:
  `InventoryPanel.gd` is already large, so adding preset controls inline without extracting helper sections can make future UI work harder.
- Unknown 1:
  If the user prefers unlimited named presets instead of fixed slots, the CRUD and UI scope needs to expand.

## 17. Open Questions

- Should phase 1 ship with `3 fixed loadout slots` or `unlimited named presets`?
  Recommended: 3 fixed slots.
- When a target loadout is invalid because inventory changed, should switch be blocked or should the preset load in a degraded editable state?
  Recommended: block switch, preserve the preset data, and show reasons.
- Should deleting a loadout clear the slot or compact/reorder the remaining presets?
  Recommended: clear the slot and keep slot positions stable.

## 18. Notes

- Buddy brainstorm convergence:
  - `codex` won the confidence vote at 93%.
  - `opencode` scored 88%.
  - `claude` scored 87%.
  - `kimi` failed to return valid JSON in this run.
- Cross-buddy agreement:
  - Rebaseline the spec around the already-shipped deckbuilder instead of re-specifying implemented UI.
  - Add loadouts as an additive runtime save model, not as a replacement deckbuilder.
  - Treat migration, atomic switching, and shared-inventory validation as the main risks.
