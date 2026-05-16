# Combat UI Overhaul

Combat UI overhaul for the live Godot combat scene, including deck/discard inspection, combat inventory, larger hand presentation, and card-image support in both builder preview and runtime combat cards.

---

## 1. Metadata

- Feature name:
  - Combat UI Overhaul
- Owner:
  - TBD
- Date:
  - 2026-05-16
- Status:
  - Planned
- Priority:
  - High
- Related files:
  - `game/scenes/combat/CombatScene.tscn`
  - `game/scenes/combat/CombatScene.gd`
  - `game/scenes/combat/CombatManager.gd`
  - `game/scenes/combat/CombatantPanel.tscn`
  - `game/scenes/combat/CombatantPanel.gd`
  - `game/scenes/combat/Card.tscn`
  - `game/scenes/combat/Card.gd`
  - `game/scenes/ui/InventoryPanel.tscn`
  - `game/scenes/ui/InventoryPanel.gd`
  - `game/autoloads/GameState.gd`
  - `game/autoloads/GameData.gd`
  - `src/data/models.js`
  - `src/builder/editors/card-editor.js`
- Related systems:
  - Combat
  - Builder
  - Data / JSON
  - UI
  - Audio / Visual

## 2. One-Line Summary

Replace the current minimal combat layout with a fuller panel-based combat UI that supports bigger hand cards, combat deck/discard inspection, combat inventory, and card artwork while preserving the existing combat rules and intent flow.

## 3. Problem / Opportunity

- Current issue:
  - The live combat UI is functional but sparse. It has the player and enemy panels, hand cards, intent preview, and zoom overlay, but it does not yet provide dedicated combat deck/discard inspection, combat inventory interaction, or card-image support.
  - The current combat scene still carries transitional layout decisions from the earlier panel refactor, such as the simple hand strip and code-built preview overlay.
  - The builder preview already implies a richer card presentation than the live runtime card scene currently shows.
- Why it matters:
  - The player needs a more readable battlefield and better access to combat information during play.
  - Combat UX will keep drifting unless the desired layout, interaction model, and runtime/builder contracts are documented in one place.
  - Adding card images touches both builder and runtime, so the contract needs to be explicit before implementation starts.
- Who it affects:
  - Players reading combat state, enemy intent, and card information.
  - Developers changing combat UI scenes, combat draw/hand behavior, and card-builder fields.

## 4. Goals

- Goal 1:
  - Make the combat UI more user friendly and information-rich.
- Goal 2:
  - Add a combat deck inspection screen.
- Goal 3:
  - Add a combat discard pile inspection screen.
- Goal 4:
  - Make hand cards larger and closer to the builder preview feel.
- Goal 5:
  - Add card image support to both builder previews and runtime combat cards.

## 5. Non-Goals

- Non-goal 1:
  - Redesign the combat rules, enemy intent generation rules, or the overall combat turn structure.
- Non-goal 2:
  - Replace the shared `CombatantPanel` architecture with separate bespoke player/enemy panel frameworks.
- Non-goal 3:
  - Convert the general out-of-combat inventory system into a full combat loadout editor.

## 6. Player Experience

- Before:
  - The player sees portraits, HP/block, buffs, hand cards, and enemy intent cards, but the hand is still relatively small, deck/discard are not inspectable in combat, and inventory interaction is not part of the combat scene.
  - Runtime combat cards show text-only presentation with no card artwork.
- After:
  - The player sees a clearer battlefield with fixed portrait panels, visible buff/debuff rails, a larger overlapping hand, inspectable deck and discard views, a combat inventory/equipment reference view, and card artwork in both builder and runtime.
  - Enemy intent remains visible in the center combat area as upcoming enemy intent cards only.
- Expected player benefit:
  - Better readability, better combat information access, and a stronger card-game presentation.

## 7. Current State

- Current behavior:
  - `CombatScene` instantiates one shared `CombatantPanel` for the player and one for the enemy.
  - `CombatantPanel` currently owns portraits, HP/block bar, buffs, and enemy intent slots.
  - `Card` currently renders text-only cards and is reused for hand cards, enemy intent cards, and preview overlay cards.
  - The combat preview overlay is built dynamically in `CombatScene.gd`.
  - The hand is rendered in a plain `HBoxContainer` with equal spacing.
  - There is no combat deck/discard inspection UI.
  - There is no combat inventory UI beyond the existing general inventory system elsewhere in the game.
  - Current player draw logic has no hand cap; `_draw_player_cards()` appends into `player_hand` directly.
  - Builder card preview uses an art placeholder only; cards do not yet have a dedicated image-path field.
- Relevant scenes/scripts/data:
  - `CombatScene.tscn` owns battlefield, play zone, hand area, HUD, and end turn button.
  - `CombatScene.gd` wires combat manager events, panel updates, hand rendering, preview overlay, and loot/defeat transitions.
  - `CombatManager.gd` owns player hand, draw pile, discard pile, enemy intent slots, and combat card draw/play resolution.
  - `CombatantPanel.gd` owns actor portrait, HP/block, buff icons, and enemy intent visuals.
  - `InventoryPanel.gd` already has equipment and consumable presentation, but currently treats consumables as view-only in that phase.
  - `src/data/models.js` currently has `portraitImage` and `iconImage` fields in related models, but no dedicated card image field.
  - `src/builder/editors/card-editor.js` currently shows `[Art Placeholder]` in the preview.
- Known bugs or limitations:
  - The current hand layout is too simple for larger card presentation.
  - There is no card image support contract for cards yet.
  - The general inventory panel is not designed as a combat-pausing overlay with consumable use actions.

## 8. Proposed Change

The combat scene should follow the layout below:

- `A`: player debuff/buff area
- `B`: enemy debuff/buff area
- `C`: play area and upcoming enemy intent cards
- `D`: player discard pile button/view entry
- `E`: inventory and equipment reference button
- Line under player portrait: player HP/block bar
- Line under enemy portrait: enemy HP/block bar

```
 ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
 │  ┌─────────────────────────┐ ┌───┐    ┌─────────────────┐   ┌───┐  ┌─────────────────────────┐  │
 │  │                         │ │   │    │                 │   │   │  │                         │  │
 │  │                         │ │   │    │                 │   │   │  │                         │  │
 │  │                         │ │   │    │                 │   │   │  │                         │  │
 │  │                         │ │   │    │                 │   │   │  │                         │  │
 │  │                         │ │   │    │                 │   │   │  │                         │  │
 │  │                         │ │   │    │                 │   │   │  │                         │  │
 │  │     player portrait     │ │ A │    │ C               │   │ B │  │     enemy portrait      │  │
 │  │                         │ │   │    │                 │   │   │  │                         │  │
 │  │                         │ │   │    │                 │   │   │  │                         │  │
 │  │                         │ │   │    │                 │   │   │  │                         │  │
 │  │                         │ │   │    │                 │   │   │  │                         │  │
 │  │                         │ │   │    │                 │   │   │  │                         │  │
 │  │                         │ │   │    │                 │   │   │  │                         │  │
 │  └─────────────────────────┘ └───┘    └─────────────────┘   └───┘  └─────────────────────────┘  │
 │  ──────────────────────────                                        ──────────────────────────   │
 │                    ┌───────────────────────────────────────────────┐                            │
 │  ┌───────┐┌───────┐│                                               │ ┌───────┐   ┌──────────┐   │
 │  │       ││       ││                                               │ │       │   │          │   │
 │  │ E.    ││ deck  ││                     hand                      │ │ D     │   │ end turn │   │
 │  │       ││       ││                                               │ │       │   │          │   │
 │  └───────┘└───────┘└───────────────────────────────────────────────┘ └───────┘   └──────────┘   │
 └─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## 9. Scope Breakdown

### Runtime / Godot

- Scenes to update:
  - `CombatScene.tscn`
  - `CombatantPanel.tscn`
  - `Card.tscn`
  - likely a new combat overlay scene or in-scene overlay nodes for deck/discard/inventory fullscreen views
- Scripts to update:
  - `CombatScene.gd`
  - `CombatManager.gd`
  - `CombatantPanel.gd`
  - `Card.gd`
  - likely a new combat-specific inspection/inventory controller script
- New nodes/components:
  - deck inspection overlay
  - discard inspection overlay
  - combat inventory overlay with tabs for consumables and equipment reference
  - transient tooltip/message node for `hand is full`
- Signals / flow changes:
  - combat scene needs open/close handlers for deck, discard, and inventory overlays
  - combat scene needs pause-style interaction gating while fullscreen views are open
  - draw flow must enforce a hard hand cap of 10

### Builder / Editor

- Existing editors to change:
  - `card-editor.js`
- New inputs or restrictions:
  - card image path field
  - builder preview should render card image when present
- Authoring workflow impact:
  - cards now require or support an image path in addition to text/effect data

### Data / Schema

- New fields:
  - `cardImage` string field on cards for image path
- Changed fields:
  - none required for existing combat rules
- Removed legacy fields:
  - none
- Schema version impact:
  - additive schema change only
- Export/import impact:
  - builder export and Godot card loading must preserve `cardImage`

### Content

- New cards / enemies / relics / buffs / items:
  - none required
- New icons / portraits / art placeholders:
  - card images per card
  - runtime fallback art: black image with `missing image`
- Text to write:
  - `hand is full`
  - item context menu labels: `Use`, `Discard`
  - missing-image fallback text

### UI / UX

- Layout changes:
  - larger overlapping/fanned hand
  - fixed portrait panels with HP/block directly below portraits
  - center area for upcoming enemy intent cards
  - bottom-left inventory button and deck button
  - bottom-right discard button and end turn button
- Interaction changes:
  - deck/discard open as fullscreen views
  - deck/discard cards can be zoomed
  - inventory opens as fullscreen view with two tabs
  - opening any fullscreen view pauses other combat interaction
- Hover / tooltip behavior:
  - hovered hand card lifts above neighbors and slightly pushes neighboring cards aside
  - `hand is full` tooltip appears for 3 seconds when a draw is blocked
  - missing-image fallback shows black image with `missing image`
- Visibility rules:
  - center area shows upcoming enemy intent cards only
  - buff/debuff rails scroll when they overflow
  - end turn remains bottom-right

## 10. Rules and Behavior Details

- Trigger conditions:
  - clicking `deck` opens the fullscreen deck inspection view
  - clicking `discard` opens the fullscreen discard inspection view
  - clicking `E` opens combat inventory/equipment reference
  - pressing `Esc` or clicking the close button closes any fullscreen inspection/inventory view
  - clicking a consumable in combat inventory opens a context menu with `Use` and `Discard`
  - consumable `Use` should only be enabled when the current combat phase and the consumable's effect rules allow it
- Limits / caps:
  - player hand size cap is 10
  - if a draw would exceed 10, the card is not drawn and the player sees `hand is full` for 3 seconds
  - if a future feature creates a card while the hand is full, it should go to discard pile instead of hand
- Order of operations:
  - combat draw resolves
  - hand cap is checked before appending to hand
  - if the card cannot enter hand, it is skipped or redirected based on source rule
  - UI refreshes afterward
- Edge cases:
  - all hand cards must remain visible in the overlap/fan layout
  - duplicate cards in deck/discard/intent views must still zoom correctly
  - hidden enemy intent cards must still show hidden placeholder preview behavior
  - opening a fullscreen deck/discard/inventory view blocks hand play and drag interaction until closed
  - consumable use/discard behavior must not bypass combat phase restrictions accidentally
- Failure cases:
  - missing card image path or missing file should show black image with `missing image`
  - no interaction should leak through behind an open fullscreen overlay

## 11. Implementation Plan

1. Add data and builder support for card images.
   - Add `cardImage` to card model normalization in `src/data/models.js`.
   - Add card image path input and builder preview rendering in `src/builder/editors/card-editor.js`.
   - Ensure exported JSON carries `cardImage`.
2. Upgrade runtime card rendering.
   - Update `Card.tscn` and `Card.gd` to render image area plus fallback art.
   - Keep preview-mode and compact intent-card behavior working with the new image layout.
3. Rework combat scene layout.
   - Update `CombatScene.tscn` to match the new bottom-row controls and central `C` area.
   - Keep `CombatantPanel` as the portrait/stat/buff container and preserve current HP/block behavior.
4. Implement combat deck/discard inspection.
   - Add fullscreen overlay views for deck and discard.
   - Render cards from current draw/discard runtime state and allow zoom from those views.
   - Block other combat input while these views are open.
5. Implement combat inventory/equipment reference.
   - Reuse inventory data from `GameState`.
   - Add two tabs: consumables and equipment reference.
   - Add item context menu with `Use` and `Discard` for consumables.
6. Rework hand presentation and draw rules.
   - Replace plain hand strip layout with overlap/fan layout.
   - Implement hover lift and slight neighbor push.
   - Add hand size cap enforcement in `CombatManager.gd`.
   - Add 3-second `hand is full` tooltip feedback.
7. Validate and clean up.
   - Verify overlay gating, card zoom, intent display, image fallback, hand cap behavior, and builder/runtime image parity.

## 12. Acceptance Criteria

- [ ] Combat layout matches the high-level sketch: portraits left/right, buff rails adjacent, HP/block below portraits, center intent area, larger bottom hand, bottom-row deck/inventory/discard/end-turn controls.
- [ ] Upcoming enemy intent cards appear in the center area and remain zoomable.
- [ ] Deck inspection opens as a fullscreen view, shows remaining deck cards, and allows zooming cards.
- [ ] Discard inspection opens as a fullscreen view, shows discard pile cards, and allows zooming cards.
- [ ] Inventory opens as a fullscreen view with consumables and equipment-reference tabs.
- [ ] Clicking a consumable opens a context menu with `Use` and `Discard`.
- [ ] While deck/discard/inventory fullscreen views are open, hand play and other combat interaction are blocked.
- [ ] Hand cards render larger in an overlap/fan layout, stay visible, and hover-lift while slightly pushing neighbors aside.
- [ ] Player hand is capped at 10 cards during combat.
- [ ] When a draw is blocked by full hand, the player sees `hand is full` for 3 seconds.
- [ ] Cards support a `cardImage` field in builder preview and runtime combat rendering.
- [ ] Missing card images render a black placeholder with `missing image`.

## 13. Testing / Validation

- Manual test cases:
  - start combat and confirm overall new layout placement
  - click deck and discard buttons and confirm fullscreen open/close behavior
  - press `Esc` to close fullscreen deck/discard/inventory views
  - open inventory and confirm consumables/equipment tabs
  - click a consumable and confirm context menu shows `Use` and `Discard`
  - hover hand cards at low and high hand counts and confirm overlap/fan behavior
  - open deck/discard/inventory and confirm hand play is blocked
  - click revealed and hidden enemy intent cards and confirm preview still works
  - verify card images render in builder preview and runtime combat
  - verify missing-image fallback appears when image path is absent or broken
  - draw to 10 cards and verify extra draw is blocked with tooltip
- Data cases to verify:
  - card with valid image path
  - card with empty image path
  - card with broken image path
  - hand with 1, 5, and 10 cards
  - many buffs/debuffs causing scroll in `A` and `B`
  - player with multiple consumables in combat inventory
- UI states to verify:
  - player turn
  - enemy turn
  - deck overlay open
  - discard overlay open
  - inventory overlay open
  - hover-expanded hand card
  - hand full tooltip visible
- Regression risks:
  - breaking drag/drop card play while adding hover/fan layout
  - breaking preview overlay routing while adding fullscreen overlays
  - introducing data mismatch between builder `cardImage` field and Godot runtime loading
  - accidentally allowing clicks through fullscreen overlays

## 14. Migration / Cleanup

- Legacy code to remove:
  - remove any dead combat UI nodes that become obsolete after the new layout lands
  - if the old generic `PlayZone` no longer has meaning, remove or repurpose it explicitly
- Legacy data to support temporarily:
  - cards without `cardImage` must remain valid and show fallback art
- One-time migration needed:
  - none required; `cardImage` is additive
- Safe cleanup after rollout:
  - delete any old placeholder-only card preview code once image rendering is stable
  - remove duplicated inventory presentation paths if a combat-specific overlay supersedes them

## 15. Risks / Unknowns

- Risk 1:
  - Hand hover/fan behavior can conflict with existing click-to-preview and drag-to-play logic in `Card.gd`.
- Risk 2:
  - Combat inventory and consumable use may expand scope if current consumable data lacks the runtime actions needed for in-combat use.
- Risk 3:
  - Adding fullscreen overlays for deck/discard/inventory can create input-layer bugs if overlay ownership is inconsistent.
- Unknown 1:
  - Whether current consumable definitions already support all desired in-combat use cases without additional effect semantics or target-selection rules.

## 16. Resolved Questions

- Enemy cards area:
  - upcoming enemy intent cards only
- Deck inspection:
  - show remaining deck cards as cards in a fullscreen view; cards can be zoomed
- Discard inspection:
  - same as deck inspection, but showing discard pile
- Inventory:
  - combat inventory/equipment reference in one fullscreen view with two tabs
  - consumables tab supports click -> context menu -> `Use` / `Discard`
  - equipment tab is reference only
  - inventory pauses other combat interaction
- Hand behavior:
  - overlap/fan layout
  - hovered card lifts above neighbors and slightly pushes neighboring cards aside
  - all cards remain visible
  - hand cap is 10
- Hand full behavior:
  - blocked draw shows `hand is full` tooltip for 3 seconds
- Buff/debuff overflow:
  - clip with scroll
- Portraits:
  - fixed size
- HP/block bars:
  - directly under portraits
- End Turn:
  - bottom-right as shown in the sketch
- Card images:
  - same task/spec
  - required in both builder preview and runtime
  - new image-path field on cards
  - expected aspect ratio is `1:1.5`
  - missing image renders black fallback with `missing image`
- Area `E`:
  - inventory and equipment reference button

## 17. Notes

- Existing code reuse strategy:
  - keep `CombatantPanel` for actor-side presentation
  - keep `Card` as the shared card renderer for hand, previews, and intent cards
  - reuse `GameState` / `GameData` consumable and equipment data
  - prefer a combat-specific inventory overlay instead of directly reusing the existing general inventory panel as-is
- Buddy review direction:
  - the main remaining implementation risk is no longer product ambiguity; it is runtime interaction complexity, especially hand hover/drag coexistence and combat consumable integration
