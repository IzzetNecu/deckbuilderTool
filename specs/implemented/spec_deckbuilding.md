# Feature Spec

## 1. Metadata

- Feature name: Inventory, deckbuilding, and equipment flow update
- Owner: current
- Date: 2026-05-14
- Status:
  - Planned
- Priority:
  - High
- Related files:
  - `specs/spec_deckbuilding.md`
  - `game/autoloads/SceneManager.gd`
  - `game/autoloads/GameState.gd`
  - `game/autoloads/GameData.gd`
  - `game/scenes/ui/InventoryPanel.tscn`
  - `game/scenes/ui/InventoryPanel.gd`
  - `game/scenes/combat/Card.gd`
  - `src/data/models.js`
  - `src/builder/editors/equipment-editor.js`
  - `src/builder/editors/player-editor.js`
- Related systems:
  - Builder
  - Data / JSON
  - UI
  - Progression
  - Combat

## 2. One-Line Summary

Stabilize the existing inventory overlay and extend it into the between-combat deckbuilding and equipment management screen, with explicit equipped-slot rules and a safe deck source of truth.

## 3. Problem / Opportunity

- Current issue:
  The current spec assumes the game needs a brand-new inventory scene, but the repo already has a live `InventoryPanel` overlay. That overlay likely crashes in the deck tab because it reuses `Card.tscn` with a `null` combat manager.
- Why it matters:
  Deckbuilding, consumables, and equipment are part of the non-combat progression loop. If the inventory screen crashes or has no equip/deck rules, the core loop cannot expand safely.
- Who it affects:
  The player, content authoring, and any future progression work.

## 4. Goals

- Goal 1:
  The player can open the existing inventory/deckbuilding overlay from the world map without crashes.
- Goal 2:
  The player can add and remove cards from their active deck between combats with explicit validation rules.
- Goal 3:
  The player can equip and unequip equipment through explicit slots, with predictable card-granting behavior.
- Goal 4:
  The builder/runtime data model is clear enough that future item effects can be added without rewriting deck state again.

## 5. Non-Goals

- Non-goal 1:
  Full functional item effects are not required in this phase beyond safe inventory presentation and equip/unequip flow.
- Non-goal 2:
  A total redesign of the main menu, map flow, or progression shell is not required.
- Non-goal 3:
  A full compendium/relic encyclopedia system is not required beyond keeping the existing tab stable.

## 6. Player Experience

- Before:
  The world map has an inventory button, but opening inventory can crash. The deck tab is not a real deckbuilder, items are passive list entries, and equipment slots do not exist as player-facing state.
- After:
  The player opens a stable overlay from the world map, reviews deck and inventory, edits the deck between combats, equips gear into valid slots, and sees which cards are granted by gear and which cards are part of the chosen deck.
- Expected player benefit:
  The non-combat loop becomes understandable and usable, and future reward/content systems have a stable home.

## 7. Current State

- Current behavior:
  `WorldMap.gd` connects `UI/InventoryButton` to `SceneManager.toggle_inventory()`, which opens `InventoryPanel.tscn` as a `CanvasLayer` overlay.
- Relevant scenes/scripts/data:
  - Inventory overlay open/close: `game/autoloads/SceneManager.gd:30-43`
  - Inventory UI: `game/scenes/ui/InventoryPanel.tscn`, `game/scenes/ui/InventoryPanel.gd`
  - Persistent player runtime state: `game/autoloads/GameState.gd`
  - Card data and equipment schema: `src/data/models.js`
  - Builder authoring for player/equipment: `src/builder/editors/player-editor.js`, `src/builder/editors/equipment-editor.js`
- Known bugs or limitations:
  - Probable crash path:
    `InventoryPanel._show_deck()` calls `card_scene.setup(card_data, null, null)` in `game/scenes/ui/InventoryPanel.gd:57-67`, but `Card.setup()` in `game/scenes/combat/Card.gd:23-30` unconditionally calls `combat_manager.get_card_text(...)`.
  - `GameState` currently stores `deck`, `consumables`, `equipment`, and `key_items` as flat arrays, but has no explicit `equipped_slots` structure.
  - `GameState.add_equipment()` and `remove_equipment()` mutate `deck` directly based on `equipment.cardIds`, which makes long-term deck ownership and equip state ambiguous.
  - Equipment authoring currently has slot `type`, `cardIds`, and `conditions`, but runtime slot occupancy rules do not exist yet.
  - The spec draft is factually outdated because it says “build a new scene that replaces the old inventory scene.”
- Verified counts:
  - Runtime files directly involved in the current inventory/deck/equipment flow total 620 lines:
    `wc -l game/scenes/ui/InventoryPanel.gd game/autoloads/GameState.gd game/autoloads/SceneManager.gd game/scenes/combat/Card.gd game/scenes/world_map/WorldMap.gd`
  - Current exported content counts are:
    1 player, 8 cards, 1 consumable, 0 equipment, 0 key items, 3 enemies, 4 deck templates, 1 map
    Command:
    `node -e "const d=require('./game/data/game_data.json'); console.log(JSON.stringify({players:d.players.length,cards:d.cards.length,consumables:d.consumables.length,equipment:d.equipment.length,keyItems:d.keyItems.length,enemies:d.enemies.length,deckTemplates:d.deckTemplates.length,maps:d.maps.length}, null, 2))"`

## 8. Proposed Change

- Core idea:
  Upgrade the existing `InventoryPanel` into the official between-combat deckbuilding/inventory screen instead of replacing it. Fix the crash first, then add explicit runtime state for equipped slots and an active deck that is distinct from equipment-granted cards.
- Why this approach:
  It reuses the live map-to-overlay flow that already exists, keeps scope tied to the real crash and missing rules, and avoids building a second overlapping menu system.
- Alternatives considered:
  - Option A, recommended:
    Incremental upgrade of `InventoryPanel` and `GameState`.
    This solves the live bug and establishes a clean progression model with the smallest blast radius.
  - Option B:
    Build a separate main-menu/meta scene and move deckbuilding there.
    This may become attractive later if the game wants a camp/town shell, but it is broader than the current problem and would duplicate inventory logic during transition.
  - Option C:
    Keep the current flat inventory arrays and patch the crash only.
    This is not recommended because equip/unequip and deck editing rules would remain ambiguous and become harder to migrate later.

## 9. Scope Breakdown

### Runtime / Godot

- Scenes to update:
  - `InventoryPanel.tscn`
  - Potentially add a lightweight inventory-safe card preview scene instead of reusing combat cards directly
- Scripts to update:
  - `InventoryPanel.gd`
  - `GameState.gd`
  - `SceneManager.gd` only if overlay entry points expand
  - `Card.gd` only if reused safely for non-combat views
- New nodes/components:
  - Deck list section with editable card entries
  - Equipment slot section
  - Inventory bag section
  - Action buttons for equip, unequip, remove from deck, add to deck, and use item
- Signals / flow changes:
  - Inventory actions should refresh the overlay UI immediately
  - If deck/equipment state changes on the map, UI refresh should not require scene reload

### Builder / Editor

- New editor sections:
  - None required if equipment stays simple, but player starting loadout may need clearer separation between owned gear and equipped gear
- Existing editors to change:
  - `equipment-editor.js`
  - `player-editor.js`
- New inputs or restrictions:
  - Equipment slot occupancy or starter equipped-state fields
  - Optional starter test equipment content
- Authoring workflow impact:
  - Authors can define equipment cards and slot types with fewer runtime assumptions

### Data / Schema

- New fields:
  - Recommended runtime save/state field:
    `equipped_slots`
  - Recommended player authoring fields:
    `startingEquipped` or equivalent slot map
  - Optional runtime helper field:
    `deck_locked_cards` or a computed equivalent if the deckbuilder needs explicit non-removable entries
- Changed fields:
  - Clarify that `equipment` means owned but not necessarily equipped
  - Clarify that the active combat deck is derived from deckbuilding choices plus equipped-item granted cards
- Removed legacy fields:
  - None required immediately
- Schema version impact:
  - Low to medium if save format changes
- Export/import impact:
  - `GameData` and save/load paths must normalize any new player/equipment state

### Content

- New cards / enemies / relics / buffs / items:
  - At least 1 test equipment item with `cardIds`
  - Optional 1 test armor/head/ring item to validate slot behavior
- New icons / portraits / art placeholders:
  - Placeholder equipment labels are acceptable for this phase
- Text to write:
  - Button text and slot labels
  - Tooltip/help text for locked or equipment-granted cards

### UI / UX

- Layout changes:
  - Keep the existing overlay shell and tabs, but restructure the content area into purpose-specific sections instead of a generic grid for everything
- Interaction changes:
  - Add explicit equip/unequip and add/remove deck actions
- Hover / tooltip behavior:
  - Equipment-granted cards and locked cards should explain why they cannot be removed
- Visibility rules:
  - Deck editing and equipment management are available on the world map and not during combat

## 10. Rules and Behavior Details

- Trigger conditions:
  - Inventory/deckbuilding opens from the world map inventory button.
  - Deck editing and equipment changes are only allowed outside combat.
- Limits / caps:
  - Phase 1 should define whether there is a fixed deck size, minimum size, or “any owned non-granted card can be toggled.”
  - If no deck-size rule exists yet, the spec should explicitly allow free add/remove from owned non-granted cards and defer deck-size balancing.
- Order of operations:
  - Recommended model:
    1. Owned deck pool is stored separately from equipped-item granted cards.
    2. Equipped slots determine which equipment is active.
    3. Effective combat deck is computed from player-selected deck plus granted cards from currently equipped gear.
    4. Combat uses a snapshot of the effective deck at combat start.
- Edge cases:
  - Removing equipment must not accidentally remove a player-owned copy of the same card if the card was granted by gear and also chosen manually.
  - Equipping a two-handed weapon must invalidate the off-hand slot.
  - Equipping an item into an occupied slot must either swap or block with a clear message.
  - Duplicate rings need explicit slot rules:
    either `ring_left` and `ring_right`, or a 2-capacity `rings` array.
  - Consumables with no implemented runtime effect should still be safe to inspect and optionally “use” only if the spec defines a placeholder behavior.
- Failure cases:
  - Opening inventory must never instantiate a combat-only card UI path that requires a combat manager.
  - Invalid save data without equipped-slot entries should fall back safely to empty equipped slots.

## 11. Implementation Plan

1. Fix the immediate crash by removing or safely abstracting combat-only card preview logic from `InventoryPanel`.
2. Define the runtime/source-of-truth model in `GameState`:
   owned deck data, owned inventory bag, equipped slots, and computed effective deck behavior.
3. Update the inventory UI so deck cards, equipped gear, and bag items are rendered with inventory-safe components and explicit actions.
4. Update player/equipment authoring to support starter equipped state and create a small test equipment set.
5. Add save/load normalization and migration-safe defaults for any new runtime fields.
6. Validate between-combat flows:
   open overlay, inspect deck, equip gear, unequip gear, and start combat with the correct resulting deck.

## 12. Acceptance Criteria

- [ ] Opening inventory from the world map no longer crashes.
- [ ] The deck tab uses inventory-safe rendering and does not require a combat manager.
- [ ] The player can add and remove non-granted cards from the active deck outside combat.
- [ ] The player can equip and unequip gear through explicit slot rules.
- [ ] Equipment-granted cards appear in the effective deck and are clearly identified as granted.
- [ ] Unequipping an item removes only that item’s granted cards and does not corrupt the player’s owned deck choices.
- [ ] Save/load preserves deck choices, inventory contents, and equipped-slot state.
- [ ] The builder can author at least one equipment item and one player start-state scenario that exercises the full loop.

## 13. Testing / Validation

- Manual test cases:
  - Open inventory from the world map on a fresh run.
  - Open inventory from a continued save.
  - Switch tabs repeatedly and close/reopen overlay.
  - Equip gear that grants cards, start combat, and confirm those cards are in the draw pile.
  - Unequip gear and confirm only granted cards are removed.
- Data cases to verify:
  - No equipment owned
  - One equipped item with `cardIds`
  - Duplicate owned equipment
  - Saved game missing new equipped-slot fields
- UI states to verify:
  - Empty bag
  - Empty active deck area
  - Occupied slot
  - Locked or non-removable equipment-granted card
- Regression risks:
  - Save/load compatibility
  - Combat deck initialization from `GameState`
  - Event/loot systems that currently add equipment directly into the flat `equipment` array

## 14. Migration / Cleanup

- Legacy code to remove:
  - Inventory deck rendering that depends on combat-only card setup
- Legacy data to support temporarily:
  - Existing saves and player data with only flat `equipment` arrays
- One-time migration needed:
  - Not necessarily a formal migration file, but `GameState.load_game()` should default missing equipped-slot state safely
- Safe cleanup after rollout:
  - Remove any temporary compatibility path that mutates `GameState.deck` directly on equip/unequip once the computed-deck approach is live

## 15. Risks / Unknowns

- Risk 1:
  If `GameState.deck` remains the only source of truth, equipment-granted cards and player-owned deck edits will keep colliding.
- Risk 2:
  If the team tries to combine “inventory fix,” “main menu redesign,” and “future item effects” in one pass, scope will drift.
- Unknown 1:
  Whether the intended deckbuilding rule is “chosen active deck from owned pool” or simply “remove/add from one persistent list with no reserve collection yet.”
- Unknown 2:
  Whether consumables should be usable from the map in this phase or remain informational only.

## 16. Open Questions

- Question 1:
  Should the player own a broader card pool than the active deck in this phase, or is the active deck the only persistent card collection for now?
- Question 2:
  Should starter equipment be defined as already equipped, merely owned in bag, or both depending on content?
- Question 3:
  Should equipment slot logic support dual rings and two-handed weapon conflicts in phase 1, or should the first implementation restrict equipment types temporarily?

## 17. Brainstorm Starters

- What is the smallest useful version of this feature?
  Fix the crash, add equipped-slot state, and support one equipment-granted-card loop.
- What can be hardcoded first and data-driven later?
  Slot labels and ring-hand conflict rules can start hardcoded if the runtime model stays explicit.
- Does this belong in runtime, builder, or both?
  Both. Runtime needs explicit state; builder needs starter content and clearer authoring intent.
- What existing system should this reuse instead of duplicating?
  Reuse the current map overlay entry point and the existing player/equipment data pipelines.
- What will probably break if this changes?
  Save/load, combat deck initialization, and reward/event equipment additions.
- What old implementation should be deleted instead of adapted?
  Reusing `Card.tscn` directly in inventory if it continues to assume combat-only services.
- What content, UI, or tooltip support is needed so players understand it?
  Slot labels, “granted by equipment” labeling, and blocked-action explanations.

## 18. Notes

- Buddy workflow used:
  `brainstorm-run.sh` on 2026-05-14. Most buddies failed locally, but the successful output converged with local code inspection:
  the correct direction is to upgrade the existing `InventoryPanel`, not replace it.
- Recommended implementation path:
  Option A, incremental overlay upgrade.
- Key evidence references:
  - `game/autoloads/SceneManager.gd:30-43`
  - `game/scenes/ui/InventoryPanel.gd:57-67`
  - `game/scenes/combat/Card.gd:23-30`
  - `game/autoloads/GameState.gd:17-20`
  - `game/autoloads/GameState.gd:105-123`
  - `src/data/models.js:126-137`
