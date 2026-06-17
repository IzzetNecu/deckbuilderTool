# Elemental Card Affinity Spec

---

## 1. Metadata

- Feature name: Elemental affinity on cards
- Owner:
- Date:
- Status: Ready for Implementation
- Priority: High
- Related files:
  - `src/data/models.js`
  - `src/builder/editors/card-editor.js`
  - `src/builder/editors/player-editor.js`
  - `src/builder/editors/deck-template-editor.js`
  - `game/autoloads/GameData.gd`
  - `game/autoloads/GameState.gd`
  - `game/scenes/ui/InventoryPanel.gd`
  - `game/scenes/combat/CombatScene.gd`
  - `game/scenes/combat/CombatantPanel.gd`
  - `game/data/game_data.json`
- Related systems:
  - Combat
  - Builder
  - Data / JSON
  - UI
  - Progression

## 2. One-Line Summary

Add elemental affinity metadata to cards and use those affinities for deckbuilding identity, card collection filtering, visual card frames, and save-time deck validation.

## 3. Problem / Opportunity

Elemental affinity adds a new layer of strategy to deckbuilding and gives cards clearer identity for balancing and player-preferred playstyles.

- Current issue:
  Cards do not have a strong identity layer beyond type, effects, rarity, and faction.
- Why it matters:
  Elemental colors create a framework for balancing, card collection filtering, deckbuilding restrictions, and future progression.
- Who it affects:
  Players building decks, content authors creating cards, and future progression systems that modify elemental capacity.

## 4. Goals

- Goal 1:
  Deckbuilding becomes more strategic and identity-driven.
- Goal 2:
  Elemental affinities give cards an identity that helps the player understand the card's purpose and how to use it inside single-color and multi-color decks.
- Goal 3:
  Card creation adds elemental affinities as an authored parameter.
- Goal 4:
  The player editor adds `player_elemental_capacity`, which controls how many elemental affinities the player can select for a deck.
- Goal 5:
  The deckbuilder lets players freely add and remove cards, then validates elemental affinity rules only when saving the deck or loadout.
- Goal 6:
  Equipment itself does not have elemental affinity in this feature, but equipment-granted cards may have elemental affinities and are exempt from manual deck validation.
- Goal 7:
  Card collection sorting/filtering and card frame visuals use the card's elemental affinities.
- Goal 8:
  Enemies display derived elemental affinities in combat based on their deck cards, but elemental affinity does not affect combat behavior in this phase.

## 5. Non-Goals

- Non-goal 1:
  Do not add new card effects tied to elemental affinities.
- Non-goal 2:
  Do not add elemental requirements, bonuses, or affinities directly to equipment items.
- Non-goal 3:
  Do not make elemental affinities modify damage, status effects, enemy AI, or combat math.
- Non-goal 4:
  Do not validate builder deck templates by chosen deck affinities in this phase.

## 6. Player Experience

- Before:
  Cards can be added to decks based on ownership and deck size rules, but cards do not communicate an elemental identity or deck color requirement.
- After:
  Cards have visible elemental frame colors. The player chooses a limited set of unique deck affinities based on elemental capacity. Save fails with a clear message if manually selected deck cards require affinities outside the chosen set.
- Expected player benefit:
  Deckbuilding has clearer archetypes, invalid builds are explained at save time, and collection browsing becomes easier through elemental filters.

## 7. Current State

- Current behavior:
  Cards have ids, names, descriptions, images, types, faction ids, costs, rarity, targeting, and structured effects. Players have base stats, starting decks, owned cards, inventory, and loadouts. Loadout save/switch validation already exists in `GameState.validate_loadout`.
- Relevant scenes/scripts/data:
  The web builder normalizes data in `src/data/models.js` and edits players/cards in the builder editors. Godot loads cards through `GameData.gd`, stores selected deck/loadouts in `GameState.gd`, and renders deckbuilding through `InventoryPanel.gd`.
- Known bugs or limitations:
  No card affinity field exists, no affinity catalog exists, loadouts do not store chosen deck affinities, and deck validation does not check card affinity membership.

## 8. Proposed Change

Add a fixed elemental affinity catalog. The six playable affinities are:

| Id | Key | Default display name | Default color |
|---:|---|---|---|
| 1 | `fire` | Fire | `#e4572e` |
| 2 | `earth` | Earth | `#8a6f3d` |
| 3 | `water` | Water | `#2f80ed` |
| 4 | `wind` | Wind | `#4fb286` |
| 5 | `lightning` | Lightning | `#f2c94c` |
| 6 | `ice` | Ice | `#8fd3ff` |

These affinity ids are separate from combat status ids such as `buff_heat` or `debuff_burning`. The display name `Lightning` aligns with the existing elemental status spec; do not introduce a separate `electro` affinity.

Colorless is not a seventh affinity. A colorless card has no selected affinities and serializes as an empty `card_affinities` array. Colorless cards are valid in every deck and do not require a deck affinity slot.

In the card builder, add an elemental affinity control. A card can have zero, one, two, or three unique elemental affinities. Zero affinities means colorless.

In the builder tool, add an Elemental Affinities section for editing the fixed catalog's display name, color, and description. Colors are stored as CSS-style hex strings in `#rrggbb` format so the web builder and Godot can parse the same value. The six ids and keys are fixed and cannot be added, removed, or reordered. The section should include a card showcase that previews a card frame using the selected affinity color. The card creator should show the same frame treatment.

In the player editor, add `player_elemental_capacity`. The default is `1`, the minimum is `0`, and the maximum is `6`. In this phase, elemental capacity can be changed by progression systems only. Equipment, cards, statuses, and combat effects do not modify elemental capacity.

In the runtime deckbuilder, add a deck affinity picker. The picker shows one circle per point of the player's elemental capacity. Clicking a circle opens an elemental affinity picker with the six playable affinities. Selected affinities must be unique. Empty circles represent no affinity selected. If capacity is `0`, no circles are shown and only colorless manually selected cards can pass affinity validation.

Picker slot count is derived from `player_elemental_capacity`, not from the length of `deck_affinities`. Saving only serializes chosen affinity ids. Empty picker slots are reconstructed from capacity when the deckbuilder opens. The player can clear an already chosen affinity circle back to empty.

The deckbuilder save action remains clickable. When clicked, it validates the manually selected deck against the chosen deck affinities. If validation fails, do not save and show this exact message:

`there are cards in the deck that do not match the chosen affinities`

Do not replace this with a different detailed save-blocking message in phase 1. If detailed invalid-card feedback is later added, it should be supplementary UI while preserving the exact failure message above.

The decklist and card collection should display each card's affinities. Single-affinity cards use a single-color frame. Multi-affinity cards use an equal-size segmented pie frame using each affinity color. Colorless cards use the default neutral frame. Card collection filtering matches cards that contain any selected filter affinity; colorless can be exposed as a separate filter option that matches `card_affinities: []`.

Enemy combat UI should display derived enemy elemental affinities as colored circles at the bottom of the enemy profile picture. Enemy affinities are display-only in this phase.

## 9. Scope Breakdown

### Runtime / Godot

- Scenes to update:
  - `game/scenes/ui/InventoryPanel.tscn` if the deckbuilder layout needs new affinity controls.
  - `game/scenes/combat/CombatScene.tscn` or enemy panel scenes only if the enemy profile affinity row cannot be added in script.
- Scripts to update:
  - `game/autoloads/GameData.gd`
  - `game/autoloads/GameState.gd`
  - `game/scenes/ui/InventoryPanel.gd`
  - `game/scenes/combat/CombatScene.gd`
  - `game/scenes/combat/CombatantPanel.gd`
  - Shared card rendering scripts used by deckbuilder/card previews, if any.
- New nodes/components:
  - Deck affinity picker circles.
  - Card affinity frame or overlay renderer.
  - Enemy affinity indicator row.
- Signals / flow changes:
  - Save/loadout refresh should include `deck_affinities`.
  - Deck validation should include affinity errors in the existing loadout validation flow.

### Builder / Editor

- New editor sections:
  - Elemental Affinities catalog editor with fixed ids/keys and editable name, color, and description.
- Existing editors to change:
  - Card creator/editor: choose zero to three unique card affinities.
  - Player editor: edit `player_elemental_capacity` with min `0`, max `6`, default `1`.
  - Deck template editor: display card-derived affinities for template contents, but do not store chosen deck affinities and do not validate templates by selected affinities.
- New inputs or restrictions:
  - Card affinity choices are unique and limited to three.
  - Deck affinity choices are unique and limited by `player_elemental_capacity`.
  - Affinity catalog ids/keys cannot be added, deleted, or reordered.
  - Duplicate affinity ids in editor input should be normalized to one copy.
  - Unknown affinity ids in editor input should be rejected before export.
- Authoring workflow impact:
  - Authors assign card affinities in the card editor.
  - Authors tune player elemental capacity in the player editor.
  - Authors can change display names, colors, and descriptions for the fixed affinity catalog.

### Data / Schema

- New fields:
  - Card:
    `card_affinities: int[]`
  - Runtime/loadout deck choice:
    `deck_affinities: int[]`
  - Player:
    `player_elemental_capacity: int`
- Root catalog:
    `elemental_affinities: Array<{ id: int, key: String, name: String, color: String, description: String }>`
- Affinity id contract:
  - `1 = fire`
  - `2 = earth`
  - `3 = water`
  - `4 = wind`
  - `5 = lightning`
  - `6 = ice`
- Colorless representation:
  - Card: `card_affinities: []`
  - Deck/loadout: no special colorless id is stored.
- Changed fields:
  - Loadouts should preserve `deck_affinities` alongside `deck` and `equipped_slots`.
  - Save data should persist `deck_affinities` inside each loadout entry in the existing `loadouts` array. No separate top-level `deck_affinities` field is required.
- Removed legacy fields:
  - None.
- Schema version impact:
  - Increment schema version because cards, players, root catalog data, and loadout save shape are expanding.
- Export/import impact:
  - Web builder export must include the root `elemental_affinities` catalog.
  - Godot import must default missing card affinities to `[]`, missing player capacity to `1`, and missing loadout deck affinities to `[]`.
  - Duplicate affinity ids should be normalized to unique ids in catalog order.
  - Unknown affinity ids should be ignored for display and treated as invalid during authoring validation.

### Content

- New cards / enemies / relics / buffs / items:
  - No new cards are required, but existing or test cards should be assigned sample affinities for validation.
- New icons / portraits / art placeholders:
  - No icons required in phase 1. Affinity colors are the primary visual marker.
- Text to write:
  - Affinity catalog descriptions.
  - Save failure message exactly as specified in Section 8.

### UI / UX

- Layout changes:
  - Add deck affinity circles to the deckbuilder.
  - Add card affinity markers and frame colors to deck list/card previews.
  - Add enemy affinity circles below the enemy profile picture in combat.
- Interaction changes:
  - Clicking a deck affinity circle opens a picker for the six playable affinities.
  - Empty circles can remain empty.
  - Save remains clickable and reports validation errors after click.
- Hover / tooltip behavior:
  - Affinity circles and frame markers should show affinity name and description when available.
- Visibility rules:
  - Hide affinity markers for colorless cards unless a neutral marker is useful for clarity.
  - Hide empty deck affinity circles if capacity is `0`.
  - Hide enemy affinity row when the enemy has no non-colorless derived affinities.

## 10. Rules and Behavior Details

- Card affinity rules:
  - A card may have 0 to 3 unique affinities.
  - `card_affinities: []` means colorless.
  - Duplicate authored affinity ids normalize to one copy in catalog order.
  - Unknown authored affinity ids are invalid and should not export.
  - A card with more than one affinity requires all of its affinities to be present in the deck's selected affinities.
- Deck affinity rules:
  - A deck may select up to `player_elemental_capacity` unique affinities.
  - Deck affinities cannot contain duplicates.
  - Deck affinities cannot include colorless.
  - Partial capacity use is allowed. Empty picker slots do not serialize.
  - The number of visible picker slots is rebuilt from `player_elemental_capacity` whenever the deckbuilder opens.
  - A selected picker slot can be cleared back to empty.
  - Duplicate loaded deck affinity ids normalize to one copy in catalog order.
  - Unknown loaded deck affinity ids are dropped during migration/load.
- Save validation:
  - Validate only the manually selected deck.
  - Do not validate equipment-granted cards, locked granted cards, or the full effective combat deck against deck affinities.
  - For each manually selected card, check that every id in `card_affinities` exists in `deck_affinities`.
  - Colorless cards always pass.
  - If any manually selected card fails, block save and show:
    `there are cards in the deck that do not match the chosen affinities`
- Equipment behavior:
  - Equipment items do not have elemental affinities.
  - Equipment may grant cards that have elemental affinities.
  - Equipment-granted cards are allowed even when their affinities are outside the chosen deck affinities.
- Progression behavior:
  - `player_elemental_capacity` can be modified by progression systems only.
  - This feature only needs the player stat and save/load support; the progression feature that changes it may be implemented later.
- Deck templates:
  - Deck templates do not store chosen deck affinities.
  - Deck templates can display the derived union of affinities from their included cards.
  - Deck templates are not validated by selected affinities.
- Enemy display:
  - Enemy affinities are derived as the unique union of non-colorless affinities on all cards in the enemy's deck templates and extra card list.
  - Derived enemy affinities are displayed as colored circles below the enemy profile picture.
  - Enemy affinities do not change enemy card play, targeting, damage, statuses, or AI.
- Ordering:
  - Display affinities in catalog id order: fire, earth, water, wind, lightning, ice.
- Filtering:
  - Card collection affinity filters match cards that have any selected affinity.
  - A separate colorless filter, if shown, matches cards with `card_affinities: []`.

## 11. Implementation Plan

1. Add data model defaults and migration.
   - Add the fixed `elemental_affinities` catalog.
   - Add `card_affinities` to cards.
   - Add `player_elemental_capacity` to players.
   - Add `deck_affinities` to loadouts/save data.
2. Add builder authoring.
   - Add the Elemental Affinities catalog editor.
   - Add card affinity selection to the card editor.
   - Add player elemental capacity to the player editor.
   - Add deck template derived affinity display without validation.
3. Add runtime validation and persistence.
   - Persist chosen `deck_affinities` on loadouts.
   - Extend loadout save validation to check manually selected cards against selected deck affinities.
   - Preserve existing deck size, ownership, and equipment validation behavior.
4. Add deckbuilder UI.
   - Render capacity-based affinity picker circles.
   - Allow click-to-pick unique affinities.
   - Keep save clickable and show the exact failure message when validation fails.
5. Add visuals and filtering.
   - Render single-color and segmented card frames.
   - Add affinity sort/filter support to the card collection.
   - Render enemy derived affinity circles in combat.
6. Validate migration and edge cases.
   - Confirm old cards are colorless.
   - Confirm capacity `0` allows only colorless manually selected cards.
   - Confirm equipment-granted elemental cards do not block save.

## 12. Acceptance Criteria

- [ ] The exported data contains the fixed six-entry `elemental_affinities` catalog with ids 1 through 6.
- [ ] Cards can be authored with zero to three unique `card_affinities`.
- [ ] Missing card affinity data migrates to `card_affinities: []`.
- [ ] Players can be authored with `player_elemental_capacity`, default `1`, min `0`, max `6`.
- [ ] Deckbuilder shows one affinity picker circle per elemental capacity point.
- [ ] Deck affinity selections are unique and serialize as `deck_affinities`.
- [ ] Saving a deck/loadout checks only manually selected cards against `deck_affinities`.
- [ ] Colorless cards always pass deck affinity validation.
- [ ] Multi-affinity cards require all card affinities to be selected by the deck.
- [ ] Equipment-granted cards are visible in the effective deck but do not block save for affinity mismatch.
- [ ] Invalid affinity save attempts show exactly: `there are cards in the deck that do not match the chosen affinities`
- [ ] Card frames use one affinity color for single-affinity cards and equal pie segments for multi-affinity cards.
- [ ] Card collection sorting/filtering can use elemental affinities.
- [ ] Enemy combat UI displays derived enemy affinity circles from enemy deck cards.
- [ ] Elemental affinities do not affect combat calculations or card effects.

## 13. Testing / Validation

- Manual test cases:
  - Create a fire card, select fire in the deckbuilder, save successfully.
  - Create a fire card, select water only, click save, and confirm the exact error message appears.
  - Create a fire/water card and confirm it requires both fire and water selected.
  - Create a colorless card and confirm it saves with any deck affinity choice, including no choices.
  - Set player elemental capacity to `0` and confirm no picker circles appear and only colorless manually selected cards can save.
  - Equip an item that grants an off-affinity card and confirm save validation ignores that granted card.
  - Confirm enemy combat UI displays derived affinity circles for enemy cards and no combat behavior changes.
- Data cases to verify:
  - Old cards without `card_affinities`.
  - Old players without `player_elemental_capacity`.
  - Old loadouts without `deck_affinities`.
  - Duplicate card affinity ids in authored data.
  - Duplicate deck affinity ids in save/load data.
  - Unknown affinity ids in cards or loadouts.
- UI states to verify:
  - Empty affinity picker slot.
  - Full capacity picker.
  - Capacity `0`.
  - Single-affinity card frame.
  - Multi-affinity segmented card frame.
  - Colorless/default card frame.
  - Enemy with no derived affinities.
- Regression risks:
  - Existing loadout save/switch validation.
  - Equipment-granted card display and effective combat deck generation.
  - Existing card editor normalization and JSON export.
  - Combat card rendering if shared frame code is reused.

## 14. Migration / Cleanup

- Legacy code to remove:
  - None required.
- Legacy data to support temporarily:
  - Cards without `card_affinities` should behave as colorless.
  - Players without `player_elemental_capacity` should use `1`.
  - Loadouts without `deck_affinities` should use `[]`.
- One-time migration needed:
  - Add the default fixed affinity catalog to exported data.
  - Normalize existing cards, players, and loadouts on load/export.
- Safe cleanup after rollout:
  - Once all saved/exported data includes affinity fields, keep fallback readers for save compatibility but remove any temporary editor-only migration UI if added.

## 15. Risks / Unknowns

- Risk 1:
  The project currently uses string ids for many authored entities, while this feature uses integer affinity ids. The enum must stay fixed and documented to avoid data drift.
- Risk 2:
  Segmented pie frames may be more complex than simple markers, especially if the same card renderer is shared across combat, deckbuilder, and builder previews.
- Risk 3:
  Adding `deck_affinities` to loadouts touches save/load, validation, and UI state, so migration must be handled carefully.
- Unknown 1:
  The exact progression system that modifies `player_elemental_capacity` is out of scope and may require later save/data changes.

## 16. Open Questions

- None currently. The previous questions were answered and folded into the spec sections above.

## 17. Brainstorm Starters

- What is the smallest useful version of this feature?
- What can be hardcoded first and data-driven later?
- Does this belong in runtime, builder, or both?
- What existing system should this reuse instead of duplicating?
- What will probably break if this changes?
- What old implementation should be deleted instead of adapted?
- What content, UI, or tooltip support is needed so players understand it?

## 18. Notes

- Existing elemental combat statuses remain separate from card affinities. Affinity ids are numeric catalog ids; combat statuses use status ids like `buff_heat`.
