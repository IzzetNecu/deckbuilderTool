# Feature Spec

## 1. Metadata

- Feature name: Equipment system simplification and equipment UI overhaul
- Owner: current
- Date: 2026-05-17
- Status:
  - Planned
- Priority:
  - High
- Related files:
  - `specs/spec_equipment_ui_overhaul.md`
  - `game/autoloads/GameState.gd`
  - `game/autoloads/GameData.gd`
  - `game/scenes/ui/InventoryPanel.gd`
  - `game/scenes/ui/InventoryPanel.tscn`
  - `src/data/models.js`
  - `src/builder/editors/equipment-editor.js`
  - `src/builder/editors/player-editor.js`
  - `game/data/game_data.json`
- Related systems:
  - UI
  - Progression
  - Data / JSON
  - Builder
  - Combat

## 2. One-Line Summary

Simplify the equipment slot system and rebuild the inventory equipment experience around a dedicated equipment tab, icon-based equipment presentation, and clearer at-a-glance information.

## 3. Problem / Opportunity

- Current issue:
  The draft correctly identifies a UX problem but understates its cause. The current inventory panel already supports equipment equip/unequip flow, yet equipment is still presented as text-heavy rows inside the `Items` tab, mixed with consumables and key items. The current slot taxonomy is also heavier than the visible content needs: runtime and builder still hardcode 8 slot ids and multiple equipment types even though current shipped content only uses one weapon, one off-hand, rings, and amulets.
- Why it matters:
  Players do not get fast visual recognition of their gear, slot occupancy, or granted cards. The mixed tab structure also makes “items” mean too many things at once. If the project wants a cleaner and more legible progression loop, the equipment model and the equipment screen need to be simplified together.
- Who it affects:
  Players, save/load compatibility, builder authoring, and any future deckbuilding or reward features that depend on equipment.

## 4. Goals

- Goal 1:
  Replace the current 8-slot equipment model with a smaller 5-slot model: 2 weapon slots, 1 armor slot, and 2 accessory slots.
- Goal 2:
  Move equipment out of the mixed `Items` tab into a dedicated `Equipment` tab.
- Goal 3:
  Replace text-row equipment presentation with an icon-grid inventory plus clearer equipped-slot visuals and hover detail.
- Goal 4:
  Reduce equipment type complexity by removing `head` and `legs`, merging `ring` and `amulet` into `accessory`, and replacing `weapon` plus `offHand` with a slot-capacity-based weapon model.

## 5. Non-Goals

- Non-goal 1:
  Full item-effect-system expansion beyond what is needed to preserve current equip and granted-card behavior.
- Non-goal 2:
  A full redesign of the deck tab, compendium tab, or the broader world-map shell.
- Non-goal 3:
  Final art polish for all equipment. Placeholder icons are acceptable if the slot/data/UI model is correct.

## 6. Player Experience

- Before:
  The player opens `Items` and sees equipment, consumables, and key items in one scroll stack. Equipped gear is presented as labeled text rows. Equipment in the bag is shown as text entries with equip buttons and no icon-first scanning.
- After:
  The player opens a dedicated `Equipment` tab, sees equipped gear in a stable top section with 5 visible slots, scans owned gear in a compact icon grid grouped by broad type, and hovers an item to see description, effects, granted cards, and flavor text. The `Items` tab becomes a cleaner consumables-plus-key-items view.
- Expected player benefit:
  Equipment becomes faster to parse, easier to compare, and more satisfying to manage without needing to read every row in full.

## 7. Current State

- Current behavior:
  `InventoryPanel.gd` currently has only `Deck`, `Items`, and `Compendium` tabs. The `Items` tab already contains four sections in one screen: equipped slots, equipment bag, consumables, and key items. `GameState.gd` and player/equipment authoring still use an 8-slot layout with explicit slot ids and type-to-slot mapping.
- Relevant scenes/scripts/data:
  - The inventory tabs and `Items` rendering are defined in `game/scenes/ui/InventoryPanel.gd:25-30` and `game/scenes/ui/InventoryPanel.gd:131-184`.
  - Current equipment slot labels are hardcoded in `game/scenes/ui/InventoryPanel.gd:3-12`.
  - Current runtime slot ids are hardcoded in `game/autoloads/GameState.gd:5-14`.
  - Current equip behavior and type-based slot routing live in `game/autoloads/GameState.gd:200-259` and `game/autoloads/GameState.gd:477-491`.
  - Current player starting equipped-slot normalization lives in `game/autoloads/GameData.gd:182-186`.
  - Current builder equipment type options live in `src/builder/editors/equipment-editor.js:81-92`.
  - Current player authoring still exposes the old 8-slot starter layout in `src/builder/editors/player-editor.js:127-140` and `src/builder/editors/player-editor.js:188-197`.
- Known bugs or limitations:
  - No equipment icon or image field exists in the equipment data model, so an icon-grid UI cannot be implemented without schema work.
  - The current slot model is hardcoded across runtime, builder, and content normalization.
  - Current equipment rows are functional but visually dense and do not support quick at-a-glance comparison.
  - The `Items` tab mixes equipment management and item inventory into one overloaded screen.
- Verified counts:
  - Current files directly involved in this overhaul total 2,116 lines:
    `wc -l game/scenes/ui/InventoryPanel.gd game/autoloads/GameState.gd src/builder/editors/equipment-editor.js src/data/models.js game/scenes/ui/InventoryPanel.tscn`
  - Current equipment content count is 8 items across 4 active types:
    `node -e "const d=require('./game/data/game_data.json'); const byType={}; for(const e of d.equipment){byType[e.type]=(byType[e.type]||0)+1;} console.log(JSON.stringify(byType,null,2));"`
  - Current exported equipment uses only these types: `onehandedWeapon`, `offHand`, `ring`, `amulet`; the player starter data still includes the full old slot map:
    `node -e "const d=require('./game/data/game_data.json'); const p=d.players[0]||{}; console.log(JSON.stringify({equipmentTypes:[...new Set(d.equipment.map(e=>e.type))], startingEquipped:p.startingEquipped||{}, equipmentCount:d.equipment.length}, null, 2))"`

## 8. Proposed Change

- Core idea:
  Turn this into one coordinated overhaul with three layers:
  1. simplify the equipment slot/data model,
  2. split equipment into its own inventory tab with dedicated layout,
  3. add icon-driven equipment presentation with hover details and rebuilt sample content.
- Why this approach:
  The visual problem and the complexity problem are linked. Re-skinning the existing 8-slot mixed-items screen would leave the underlying model and tab confusion intact. Simplifying the equipment taxonomy first gives the UI a cleaner structure and reduces future authoring burden.
- Alternatives considered:
  - Option A, recommended:
    Ship the slot-model simplification and equipment-tab overhaul together.
    This is the cleanest player-facing result and prevents building new UI on top of a taxonomy that the draft already wants to remove.
  - Option B:
    Keep the current slot model and do only a visual refresh.
    This reduces risk short-term but preserves the complexity the draft explicitly wants to remove.
  - Option C:
    Simplify the data model first, keep the current text-row UI temporarily, and defer icon-grid UI.
    This is safer if implementation needs to be split into phases, but it does not deliver the full intended UX in one pass.

## 9. Scope Breakdown

### Runtime / Godot

- Scenes to update:
  - `InventoryPanel.tscn`
- Scripts to update:
  - `InventoryPanel.gd`
  - `GameState.gd`
  - `GameData.gd`
  - `CombatScene.gd` if shared slot labels remain duplicated there
- New nodes/components:
  - Dedicated `Equipment` tab button
  - Equipped-slot visual strip or grid for 5 slots
  - Equipment inventory icon grid
  - Persistent detail panel for focused equipment information
- Signals / flow changes:
  - Switching tabs must separate equipment from consumables/key items cleanly
  - Equipping/unequipping must refresh slot visuals, granted cards, and detail state in one pass

### Builder / Editor

- New editor sections:
  - Equipment icon/image field
  - Weapon slot-cost input with constrained values for 1-slot vs 2-slot weapons
- Existing editors to change:
  - `equipment-editor.js`
  - `player-editor.js`
- New inputs or restrictions:
  - New equipment type values
  - Weapon slot cost / slot usage field
  - Starting equipped mapping for the new 5-slot schema
- Authoring workflow impact:
  - Authors will no longer create head/legs/ring/amulet/offHand types directly
  - Authors will need icon paths for equipment items if the icon-grid is meant to be meaningful
  - The builder tool must stop exposing legacy slot ids and legacy equipment type options anywhere in player or equipment authoring

### Data / Schema

- New fields:
  - Equipment image/icon field, e.g. `equipmentImage`
  - Weapon slot usage field, e.g. `slotCost` with values such as `1` or `2`
- Changed fields:
  - Equipment `type` values change to a smaller taxonomy, likely `weapon`, `armor`, `accessory`
  - Player `startingEquipped` changes from the current 8-slot map to a 5-slot layout
- Removed legacy fields:
  - Legacy slot ids `head`, `legs`, `amulet`, `ring_left`, `ring_right`, `weapon_main`, `off_hand`
  - Legacy equipment type values `onehandedWeapon`, `twohandedWeapon`, `offHand`, `ring`, `amulet`
- Schema version impact:
  - Medium to high for runtime save data and exported content
- Export/import impact:
  - `GameData` normalization must support the new schema and may keep only minimal stale-save fallback; legacy authored equipment content does not need preservation

### Content

- New cards / enemies / relics / buffs / items:
  - Replace current playtest equipment set with a smaller set matching the new slot taxonomy
  - Draft target: 2 test items each for `weapon`, `armor`, and `accessory`
- New icons / portraits / art placeholders:
  - Placeholder equipment icons are required if the grid view is part of the ship target
- Text to write:
  - Slot labels
  - Hover detail strings
  - Empty-state and invalid-equip messaging

### UI / UX

- Layout changes:
  - Add a dedicated `Equipment` tab
  - Move consumables and key items into a slimmer `Items` tab
  - Show equipped items in a top summary area and owned equipment below in a grid
- Interaction changes:
  - Equipping happens from icon cards or a detail panel, not long text rows only
  - Hovering or focusing an equipment icon updates the persistent detail panel with effect text, granted cards, flavor text, and slot usage
- Hover / tooltip behavior:
  - Detail content must stay readable even when icons are small
  - Equipment-granted card ids should resolve to readable names, not raw ids
- Visibility rules:
  - Equipment management remains out-of-combat only in this phase

## 10. Rules and Behavior Details

- Trigger conditions:
  - Equipment management is available from the inventory overlay on the world map.
- Limits / caps:
  - New slot target is 5 visible equip positions:
    `weapon_1`, `weapon_2`, `armor`, `accessory_1`, `accessory_2`
  - A weapon has `slotCost` 1 or 2.
- Order of operations:
  1. Equipment type determines which broad slot family the item can occupy.
  2. `slotCost` decides whether a weapon occupies one or both weapon slots.
  3. Equipped state updates first.
  4. Granted cards are then recomputed from the new equipped state.
  5. Deck summary and UI refresh after the recomputation.
- Edge cases:
  - Equipping a 2-slot weapon must clear both weapon slots.
  - Equipping a 1-slot weapon when a 2-slot weapon is equipped must first clear the 2-slot weapon.
  - Equipping the same accessory item twice must still respect owned-copy counts.
  - Old saves and old starter data need a deterministic migration path from ring/amulet/offHand/head/legs semantics.
  - Hover details must still work for items missing icon art.
- Failure cases:
  - Old equipment data must not become silently unequippable without a visible migration/default path.
  - The UI must not show empty or broken image widgets without fallback states.
  - Equipping items must not desync the granted-card section used by deckbuilding.

## 11. Missing Components To Add

1. A new equipment slot taxonomy and migration contract.
2. A new runtime equipped-state structure for 5 slots.
3. A new equipment image/icon field.
4. A new weapon capacity field such as `slotCost`.
5. A dedicated `Equipment` tab and reduced `Items` tab.
6. A hover/detail presentation that resolves cards and text cleanly.
7. Replacement sample equipment content authored for the new model.

## 12. Implementation Plan

1. Redefine the equipment schema.
   - Replace the old equipment type list with the new broad categories.
   - Add `equipmentImage` and `slotCost`.
   - Update `src/data/models.js` and builder defaults.
2. Rework player and runtime slot state.
   - Replace the current 8-slot `SLOT_ORDER`.
   - Update `GameState` equip, unequip, slot validation, blocked-slot handling, and granted-card traversal.
   - Update `GameData` player normalization and `player-editor.js` starter equipped inputs.
3. Add migration-safe normalization.
   - Define how old `startingEquipped` and save `equipped_slots` map into the new 5-slot model.
   - Legacy authored equipment content is removed rather than converted.
   - Keep only enough stale-save fallback to avoid crashes when older equipped-slot data is encountered.
4. Rebuild the inventory tab structure.
   - Add a dedicated `Equipment` tab in `InventoryPanel.tscn` and `InventoryPanel.gd`.
   - Move equipment out of the current `Items` tab.
   - Keep consumables and key items visible in `Items`.
5. Implement the equipment presentation overhaul.
   - Replace text-row bag entries with icon cards or compact tiles.
   - Add a persistent detail panel that updates from hover/focus and shows description, granted cards, effect text, flavor, rarity, and slot usage.
   - Keep explicit equip/unequip actions visible and understandable.
6. Rebuild sample content and validate.
   - Replace current equipment content in `game/data/game_data.json` with the new taxonomy.
   - Update the builder tool so authors can create and edit only the new equipment taxonomy and starting-equipped layout.
   - Run a full manual pass on equip rules, save/load, and deck granted-card integration.

## 13. Acceptance Criteria

- [ ] The inventory overlay exposes a separate `Equipment` tab and a separate `Items` tab.
- [ ] Equipment no longer uses the old 8-slot player-facing layout.
- [ ] The runtime and builder both support the new 5-slot model consistently.
- [ ] The builder tool no longer exposes legacy equipment types or legacy starting-equipped slot fields.
- [ ] Equipment entries render with icon-capable UI and readable fallback when art is missing.
- [ ] Hovering or focusing an equipment entry updates a persistent detail panel with description, granted cards, and slot usage clearly.
- [ ] Equipping and unequipping continue to update deck-granted cards correctly.
- [ ] Existing save/content migration is handled safely enough that the game can still load without crashing.
- [ ] New playtest equipment content exists for each new broad type.

## 14. Testing / Validation

- Manual test cases:
  - Open the new `Equipment` tab with starter equipment.
  - Equip and unequip 1-slot and 2-slot weapons repeatedly.
  - Equip two accessories, then remove one and confirm granted cards update correctly.
  - Confirm consumables and key items still appear in the slimmer `Items` tab.
  - Load an old save or old content state and verify migration fallback behavior.
- Data cases to verify:
  - Missing icon path
  - Old save with legacy slots populated
  - Multiple owned copies of the same accessory
  - Weapon with `slotCost: 2`
- UI states to verify:
  - Empty equipment inventory
  - Fully occupied 5-slot loadout
  - Hovered equipment with long text
  - Equipment with no granted cards
- Regression risks:
  - Save compatibility
  - Deck granted-card recomputation
  - Builder/runtime schema drift during the slot migration

## 15. Migration / Cleanup

- Legacy code to remove:
  - Old slot labels and type-routing paths tied to `head`, `legs`, `ring`, `amulet`, `offHand`, `weapon_main`, and `off_hand`
- Legacy data to support temporarily:
  - Old `startingEquipped` maps
  - Old `equipped_slots` save data
- One-time migration needed:
  - Yes, for runtime save data; legacy authored equipment content can be deleted and replaced
- Safe cleanup after rollout:
  - Remove minimal stale-save normalization branches once old saves are no longer relevant

## 16. Risks / Unknowns

- Risk 1:
  This is a cross-system migration, not a local UI pass, so under-scoping it will create brittle partial conversions.
- Risk 2:
  If icon support lands without enough placeholder assets, the new UI can look more broken than the current text rows.
- Unknown 1:
  Whether stale runtime saves with now-removed equipped items should silently clear those slots or surface a one-time warning message.

## 17. Open Questions

- Should this ship as one combined phase or split into:
  1. schema/slot migration first
  2. visual equipment-tab overhaul second
  Recommended: split internally in implementation order, even if presented as one feature.
## 18. Notes

- Current shipped content already suggests the old taxonomy is over-provisioned:
  there are no live `head` or `legs` items in `game/data/game_data.json`, and current content only uses `onehandedWeapon`, `offHand`, `ring`, and `amulet`.
- Confirmed direction for this spec:
  legacy authored equipment can be removed instead of converted, but the builder tool must be updated in the same feature so new content can only be authored against the replacement schema.
  Equipment detail uses a persistent detail panel that updates from hover/focus, not ephemeral-only tooltips.
- Buddy confidence vote:
  - Refreshed vote after locking persistent detail panel:
    `codex`: 91, recommended winner
    `claude`: 88
    `kimi`: no structured output in the refreshed run
    `opencode`: no refreshed result surfaced in the generated run directory
  - Earlier broader vote before the final interaction decision:
    `codex`: 91
    `claude`: 85
    `opencode`: 35
    `kimi`: failed to return valid JSON
- Cross-buddy agreement:
  - This must be specified as a schema-and-runtime migration, not just a visual UI update.
  - The new weapon slot-capacity model needs exact conflict rules before implementation.
  - Equipment icons/tooltips require explicit data support and fallback behavior.
