# Elemental Status System Spec

---

## 1. Metadata

- Feature name: Elemental status system
- Owner: Codex draft for repo spec cleanup
- Date: 2026-05-15
- Status: Planned
- Priority: High
- Related files:
  - `game/scenes/combat/CombatManager.gd`
  - `game/scenes/combat/CombatScene.gd`
  - `game/scenes/combat/CombatantPanel.gd`
  - `game/autoloads/GameData.gd`
  - `game/autoloads/GameState.gd`
  - `src/data/models.js`
  - `src/builder/editors/card-editor.js`
  - `src/builder/editors/buff-editor.js`
  - `game/data/game_data.json`
- Related systems:
  - Combat
  - Builder
  - Data / JSON
  - UI

## 2. One-Line Summary

Add a first-class elemental status system to combat, with six element pairs, stack-based effects, opposite-status cancellation, and builder-authored status application on cards.

## 3. Problem / Opportunity

- Current issue:
    The repo has combat stats, structured card effects, and predefined buff icons, but it does not yet have a generic status engine for timed stack-based buffs and debuffs.
- Why it matters:
    Elemental statuses add decision-making, make enemy intent more readable, and create a reusable status framework for later combat content.
- Who it affects:
    Players, combat tuning, card/enemy content authoring, UI, and runtime combat rules.

## 4. Goals

- Goal 1:
    Add six elemental buff/debuff pairs as persistent combat statuses with exact stack and trigger rules.
- Goal 2:
    Let player cards and enemy cards apply elemental statuses through the existing structured effect pipeline.
- Goal 3:
    Show active elemental statuses in combat UI with icons, stack counts, and reminder text.
- Goal 4:
    Expand the builder/data pipeline so elemental status application is authored in JSON instead of hardcoded per card.
- Goal 5: 
    create a new map where each element can be playtested. add new enemies and cards to test the elemental statuses. add elemental cards to the starting items so the player can change the cards in their deck to playtest each element.

## 5. Non-Goals

- Non-goal 1:
    Do not add elemental resistances, weaknesses, or damage types in the first implementation slice.
- Non-goal 2:
    Do not build a fully open-ended custom status designer in the builder; elemental statuses stay in the predefined status catalog.

## 6. Player Experience

- Before:
    Combat has direct card effects like damage, block, draw, and insight, but no lasting elemental states.
- After:
    Cards can add elemental buffs and debuffs that persist across turns, visibly stack, cancel with their elemental opposite, and trigger at clear points in the turn. When a queued next-damage or next-block modifier is active, the player can already see that modified amount on cards in hand before playing them.
- Expected player benefit:
    Combat gets more planning depth, more readable setup/payoff loops, and more variety without requiring hidden rules. Players can inspect a card and understand exactly where its current combat value comes from.

## 7. Current State

- Current behavior:
    `CombatManager.gd` supports structured effects for `damage`, `block`, `heal`, `draw`, and `modify_insight`. Combat UI already renders predefined buff chips for strength, dexterity, and insight, but there is no generic runtime status container or turn-hook system.
- Relevant scenes/scripts/data:
    `CombatManager.gd` owns turn flow and effect execution; `CombatScene.gd` builds visible buff rows; `CombatantPanel.gd` renders buff icons from `GameData.buffs`; `src/data/models.js` normalizes structured card effects; `src/builder/editors/buff-editor.js` manages predefined buff metadata and icons.
- Known bugs or limitations:
    No persistent per-combat status state exists, no trigger scheduling exists for start/end/pre-action status behavior, and the current buff catalog is missing the elemental entries required by this feature.

## 8. Proposed Change

- Core idea:
    Add a runtime `statuses` map to each combat actor, add a new structured card effect type for status application, define a small set of combat trigger hooks, and extend the predefined buff catalog with elemental buff/debuff definitions and icons.
- Why this approach:
    It reuses the existing structured-effect pipeline and combat buff UI instead of creating six one-off mechanics in separate code paths.
- Alternatives considered:
    Hardcoding each elemental rule directly into card execution was rejected because it would duplicate logic and make future status work harder. Full elemental damage typing was deferred because the codebase does not yet have a broader damage-type system.

## 9. Scope Breakdown

### Runtime / Godot

- Scenes to update:
  - `game/scenes/combat/CombatScene.tscn` only if current status row capacity/spacing is insufficient.
- Scripts to update:
  - `game/scenes/combat/CombatManager.gd`
  - `game/scenes/combat/CombatScene.gd`
  - `game/scenes/combat/CombatantPanel.gd`
  - `game/autoloads/GameData.gd`
  - `game/autoloads/GameState.gd` only if later persistence helpers are needed for shared status formatting; no world-map persistence is required in phase 1.
- New nodes/components:
  - No mandatory new scene is required. Reuse existing buff chip rendering if it can show more entries cleanly.
- Signals / flow changes:
  - `stats_updated` remains the main refresh signal.
  - Add internal combat flow hooks for `turn_start`, `before_attack`, `before_block_gain`, and `turn_end`.

### Builder / Editor

- New editor sections:
  - None. Elemental statuses should appear as additional predefined entries in the existing Buffs & Debuffs editor.
- Existing editors to change:
  - `src/builder/editors/card-editor.js` to author `apply_status` effects and select status id, amount, and target.
  - `src/builder/editors/buff-editor.js` to include the elemental status catalog entries and placeholder icon defaults.
- New inputs or restrictions:
  - Card effect editor needs `statusId`, `amount`, and `target`.
  - `statusId` must be restricted to predefined combat statuses.
  - `amount` must be an integer and should not allow zero in authored content.
- Authoring workflow impact:
  - Designers choose a predefined status and stack amount per effect instead of typing custom freeform behavior.

### Data / Schema

- New fields:
  - Card effect shape:
    `{ "type": "apply_status", "statusId": "buff_heat", "amount": 3, "target": "self" }`
  - Normalized `apply_status` contract:
    `type`, `statusId`, `amount`, and `target` are mandatory preserved fields in both JS export and GDScript import. Unknown extra fields may pass through, but `statusId` must never be dropped during normalization.
  - Runtime actor state:
    `statuses: { "buff_heat": 3, "debuff_burning": 1 }`
- Changed fields:
  - `buffs` data collection expands from base stat buffs to the full predefined combat status catalog.
- Removed legacy fields:
  - None in phase 1.
- Schema version impact:
  - Minor schema expansion only. Existing cards stay valid because current effect types remain supported.
- Export/import impact:
  - `src/data/models.js` and `GameData.gd` must normalize `apply_status` effects and the new predefined status entries into exported JSON.

### Content

These elemental statuses are stack-based. `X` means current stack count.

Applying a status first cancels stacks from its opposite status on the same actor. Any remaining amount is then added as stacks of the applied status.

Example:
- Having 5 `heat`, then gain 3 `burning` -> result is 2 `heat`.
- Having 5 `burning`, then gain 3 `heat` -> result is 2 `burning`.

Element pairs:

| Element | Buff | Debuff |
|---|---|---|
| Fire | `heat`: the next attack deals `X` more damage, then lose half the stacks rounded down | `burning`: the next attack deals `X` less damage, minimum 0, then lose half the stacks rounded down |
| Water | `flow`: the next block gain gives `X` more block, then lose half the stacks rounded down | `slippery`: the next block gain gives `X` less block, minimum 0, then lose half the stacks rounded down |
| Earth | `regen`: heal `X` at end of turn, then lose 1 stack | `poison`: lose `X` HP at start of turn, then lose 1 stack |
| Wind | `haste`: draw `X` extra cards at start of turn, then lose 1 stack | `slowed`: discard `X` cards at start of turn, then lose 1 stack |
| Ice | `scaled`: gain `X` block at end of turn, then lose 1 stack | `chill`: lose `X` block at end of turn, minimum 0, then lose 1 stack |
| Lightning | `energized`: the next played card resolves its full effect list twice, then lose one stack | `jolted`: player cards lose 1 energy after the next played card resolves; enemy cards delay their first `X` pending cards to the next enemy turn, then lose all stacks at the end of that turn |


Phase-1 authored content additions:
- New predefined buff entries for the 12 elemental statuses.
- Sample player cards and enemy cards that apply at least one positive and one negative elemental status.
- Placeholder icons for all 12 statuses.
- Reminder text for each status in the predefined status catalog.

### UI / UX

- Layout changes:
  - Combat panels show elemental statuses in the same buff row system as strength/dexterity/insight.
  - Placeholder icons should be available for:
    `fire: 🔥`, `water: 💧`, `earth: ⛰️`, `wind: 💨`, `ice: ❄️`, `lightning: ⚡`
- Interaction changes:
  - Card text in the player hand should include pending `heat`, `burning`, `flow`, or `slippery` adjustments on the first matching effect before the card is played.
  - Clicking a player card should zoom or focus that card and show an explicit breakdown for each visible numeric effect, for example: `Deal 12 (base 5 + strength 2 + heat 5) damage.`
- Hover / tooltip behavior:
  - Each chip should show status name, current stack count, and reminder text from `GameData.buffs`.
- Visibility rules:
  - Hide zero-stack statuses.
  - Show both base stat buffs and elemental statuses when active.
  - If row space is limited, preserve deterministic ordering instead of reflowing randomly.

## 10. Rules and Behavior Details

- Trigger conditions:
  - `heat` and `burning` trigger on the actor’s next outgoing `damage` effect that resolves for an amount above or equal to 0.
  - `flow` and `slippery` trigger on the actor’s next outgoing `block` gain effect.
  - `poison`, `haste` and `slowed` trigger at the start of that actor’s turn.
  - `regen`, `scaled`, and `chill` trigger at the end of that actor’s turn.
  - `energized` triggers when the actor plays their next card.
  - Player `jolted` triggers after the actor finishes playing their next card.
  - Enemy `jolted` triggers when the enemy turn begins by delaying the first `X` pending cards from that turn's queue to the next enemy turn, then clearing all remaining `jolted` stacks at the end of that enemy turn.
- Limits / caps:
  - Minimum stack count is 0.
  - No hard stack cap in phase 1.
  - Damage, block loss, and energy loss cannot drive their target value below 0.
  - Healing cannot exceed max HP.
- Order of operations:
  - Status application:
    1. Identify the target actor.
    2. Cancel against the opposite status for the same element.
    3. Add any remaining stacks to the applied status.
    4. Remove any status entry that reaches 0.
- Start of player turn:
    1. Clear player block as the current implementation already does.
    2. Reset base turn resources.
    3. Determine the current `haste` bonus card count, if any.
    4. Draw the normal hand plus the current `haste` bonus.
    5. If `haste` was active for that draw, lose 1 `haste` stack.
    6. Resolve remaining start-of-turn statuses in this order: `slowed`, then `poison`.
    7. Refresh enemy intent preview if insight-like status changes ever affect it later.
  - Start of enemy turn:
    1. Enemy block clears.
    2. Determine how many pending enemy cards are already being held from prior turn delays.
    3. Determine the current `haste` bonus card count, if any.
    4. Draw or prepare the enemy's normal hand plus the current `haste` bonus, appending new cards behind any already-delayed pending cards.
    5. If `haste` was active for that draw, lose 1 `haste` stack.
    6. Resolve remaining start-of-turn statuses in the same order.
    7. Determine the current enemy `jolted` stack count and skip that many cards from the front of the pending queue for this turn only.
    8. Execute the remaining pending enemy cards in order.
    9. Leave the skipped front cards in the pending queue for the next enemy turn.
    10. At the end of the enemy turn, remove all enemy `jolted` stacks.
  - When resolving a `damage` effect:
    1. Compute base/scaling amount.
    2. Apply `heat` or `burning` once to that effect.
    3. Clamp at minimum 0.
    4. Spend status stacks by removing half the current stacks rounded down.
    5. Apply block and HP loss.
  - While previewing a card in the player hand:
    1. Use the actor's current combat stats and statuses.
    2. Pre-apply `heat` or `burning` to the first visible `damage` effect on that card.
    3. Pre-apply `flow` or `slippery` to the first visible `block` effect on that card.
    4. Clamp previewed damage or block at minimum 0.
    5. Do not mutate or spend status stacks during preview; this is visibility only.
  - When resolving a `block` effect:
    1. Compute base/scaling amount.
    2. Apply `flow` or `slippery` once to that effect.
    3. Clamp at minimum 0.
    4. Spend status stacks by removing half the current stacks rounded down.
    5. Add resulting block.
  - When resolving a played card:
    1. Validate the play target and pay the card cost once.
    2. Remove the card from hand once and move it to its normal post-play zone once.
    3. Check `energized` before the card effect loop begins.
    4. If `energized` is active, resolve the full card effect list twice for that one played card, then spend 1 `energized` stack.
    5. If `energized` is not active, resolve the full card effect list once.
    6. After a player-played card fully resolves, apply `jolted`: lose 1 energy with a minimum of 0, then spend 1 `jolted` stack.
    7. Re-check win/lose state after each full card resolution pass and after post-play status effects.
- Edge cases:
  - If both opposite statuses somehow exist at once due to bad data, cancel them before any trigger resolution.
  - Multi-effect cards only consume `heat`/`burning` on the first `damage` effect and `flow`/`slippery` on the first `block` effect that resolves.
  - If `energized` causes a card to resolve twice, each full resolution pass gets its own "first damage effect" and "first block effect" window.
  - If an actor has no cards in hand when `slowed` triggers, discard as many as possible up to the stack amount.
  - If `chill` triggers on an actor with 0 block, it only removes a stack and has no other effect.
  - If a start/end-of-turn trigger defeats an actor, stop later combat actions once the existing win/lose check fires.
  - If an elemental status defeats the enemy, use the standard combat victory flow: stop later combat actions and show the normal victory/loot screen.
  - If an elemental status defeats the player, use the standard combat defeat flow: show the defeated screen, then return to the map with persistent HP clamped to at least 1.
  - `energized` means "this card resolves twice", not "run the full play pipeline twice": do not pay cost twice, revalidate target twice, remove the card from hand twice, or discard/exhaust it twice.
  - If both player `energized` and player `jolted` are active, resolve the doubled card first, then apply the single `jolted` post-play penalty once.
  - If player `jolted` triggers while the actor has 0 energy, energy stays at 0 and the stack is still spent.
  - If enemy `jolted` is greater than or equal to the number of pending enemy cards, the enemy plays no cards that turn and keeps all pending cards for the next turn.
  - Enemy `jolted` only delays the front `X` cards once for that enemy turn; any remaining enemy `jolted` stacks are removed at end of turn instead of carrying forward.
  - Enemy delayed cards stay at the front of the queue and newly drawn enemy cards are appended behind them on the next turn.
  - `flow` and `slippery` only modify the next structured `block` effect in phase 1; they do not modify `scaled` or other status-driven block changes unless a later spec explicitly expands them.
- Failure cases:
  - Unknown `statusId` in authored data should be ignored with a logged warning instead of crashing combat.
  - Malformed `apply_status` effects should normalize to a safe no-op during data import.

## 11. Implementation Plan

1. Add the schema and predefined catalog.
   - Extend `src/data/models.js` and `game/autoloads/GameData.gd` to normalize `apply_status`.
   - Expand `src/builder/editors/buff-editor.js` with the 12 elemental predefined entries and reminder text.
   - Add placeholder icon assets or paths in authored buff data.
2. Add runtime status state and resolution helpers.
   - Give each combat actor a `statuses` dictionary in `CombatManager.gd`.
   - Implement helpers for status lookup, add/remove stacks, opposite-status cancellation, trigger spending, and stable display ordering.
   - Extend `_apply_effect` to process `apply_status`.
3. Add turn hooks and action modifiers.
   - Insert player start-of-turn status resolution into `_begin_phase()` so `haste` modifies draw first, then `slowed` and `poison` resolve after the hand is drawn.
   - Insert enemy start/end status resolution into `_end_phase()` around the existing enemy action execution loop.
   - Inject `heat`/`burning` into damage resolution and `flow`/`slippery` into block resolution.
   - Add a shared card-play wrapper for both player and enemy card execution so `energized` can repeat the effect list without replaying cost/hand/discard handling and `jolted` can apply exactly once after the full card finishes.
   - Ensure win/lose checks interrupt later queued actions cleanly.
4. Expose status authoring and rendering.
   - Update `src/builder/editors/card-editor.js` to create/edit `apply_status` effects.
   - Update `CombatScene.gd` and `CombatantPanel.gd` so elemental statuses render alongside existing buffs with stack counts and tooltips.
5. Add sample content and regression coverage.
   - Add test/sample cards and at least one enemy that uses elemental statuses.
   - Validate JSON export/import, combat timing, cancellation behavior, and UI readability.

## 12. Acceptance Criteria

- [ ] Cards and enemy cards can apply any predefined elemental status through structured `apply_status` effects.
- [ ] Elemental opposite pairs cancel correctly and triggered statuses spend stacks according to this spec.
- [ ] Start-of-turn and end-of-turn statuses resolve in a deterministic order without breaking current combat flow.
- [ ] `energized` makes the next played card resolve its full effect list twice without double-paying cost or double-moving the card between hand/discard/exhaust zones.
- [ ] `jolted` applies once after the next played card fully resolves, clamps energy loss at 0, and still spends a stack when no energy can be lost.
- [ ] Active elemental statuses appear in combat UI with icon, stack count, and reminder text.
- [ ] Player hand card text previews already include pending `heat`, `burning`, `flow`, and `slippery` modifiers on the first applicable effect before the card is played.
- [ ] Clicking a player card zooms or focuses it and shows a readable numeric breakdown for the currently previewed values.
- [ ] Existing non-elemental cards still function after the schema/runtime expansion.

## 13. Testing / Validation

- Manual test cases:
  - Play a card that applies `heat`, then play a damage card and confirm extra damage and half-stack decay.
  - Apply `burning` to the player, then attack and confirm reduced damage with minimum 0.
  - Apply `flow` and `slippery` and confirm they modify the next block gain only.
  - Apply `regen`, `poison`, `scaled`, `chill`, `haste`, `slowed`, `energized`, and `jolted` and verify trigger timing and one-stack decay.
  - Apply `energized`, then play a multi-effect card and confirm the full effect list resolves twice while cost, hand removal, and discard/exhaust handling happen once.
  - Apply `energized` together with `heat` or `flow` and confirm each doubled resolution pass can consume the relevant "next damage" or "next block" modifier once.
  - Apply both `energized` and `jolted`, play one card, and confirm the card resolves twice before exactly one post-play energy loss and one `jolted` stack loss.
  - Apply `jolted` at 0 energy and confirm the next card still resolves normally, energy remains at 0, and the `jolted` stack is removed.
  - Apply `slowed` at the start of the player turn and confirm it discards from the newly drawn hand instead of resolving before any cards are drawn.
  - Apply opposite statuses in both orders and confirm exact cancellation behavior.
  - Gain `heat`, `burning`, `flow`, or `slippery` while cards are already in hand and confirm the visible hand text updates to the pre-play amount without spending stacks.
  - Click a damage or block card while those preview modifiers are active and confirm the zoomed card shows a breakdown such as `base + stat + status`.
- Data cases to verify:
  - Legacy cards without `apply_status` still load.
  - Invalid `statusId` or malformed `apply_status` data fails safely.
  - Buff catalog export includes all 12 elemental statuses with reminder text and icon path fields.
- UI states to verify:
  - Zero-stack statuses are hidden.
  - Multiple active statuses remain readable on both player and enemy panels.
  - Tooltips display correct reminder text and current values.
- Regression risks:
  - Turn-start draw/energy flow can break if status hooks are inserted in the wrong order.
  - Card-play flow can regress if Lightning statuses are implemented by replaying the entire `play_card` pipeline instead of only replaying card effect resolution.
  - Combat panel buff row may overflow once 12 new statuses exist.
  - Card text preview may need follow-up work if later designs want dynamic elemental token replacement.

## 14. Migration / Cleanup

- Legacy code to remove:
  - None immediately. This is an additive feature.
- Legacy data to support temporarily:
  - Continue supporting current non-elemental card effect shapes with no changes.
- One-time migration needed:
  - Existing `buffs` authored data should be merged with the expanded predefined catalog the same way current base-stat buffs are merged now.
- Safe cleanup after rollout:
  - If placeholder icons are replaced with final art later, keep ids and reminder text stable so saved/exported content does not churn.

## 15. Risks / Unknowns

- Risk 1:
    The current combat flow was not written around generalized status hooks, so turn-order bugs are the main implementation risk.
- Risk 2:
    Sharing the buff row between permanent combat stats and many temporary elemental statuses may create readability issues on smaller layouts.
- Risk 3:
    `energized` and `jolted` need explicit card-play lifecycle rules; otherwise cost payment, discard/exhaust handling, and post-play energy loss will be implemented inconsistently between player and enemy turns.
- Unknown 1:
    Whether future equipment/consumable systems should reuse `apply_status` directly in combat or need a broader effect framework outside cards.

## 16. Open Questions

- Question 1:
    Should elemental statuses be allowed on equipment/consumables in the same implementation slice, or should phase 1 stay card-driven only?
- Question 2:
    Do we want a fixed display order by element pair, or should statuses sort by trigger timing or stack size?
- Question 3:
    Should later elemental resistances/weaknesses reuse the same status catalog, or be modeled as separate enemy/player stat modifiers?

## 17. Brainstorm Starters

- What is the smallest useful version of this feature?
  - Status application on cards plus runtime resolution, without resistances or equipment hooks.
- What can be hardcoded first and data-driven later?
  - Trigger scheduling and opposite-pair lookup can be hardcoded first; status metadata and application amounts should stay data-driven.
- Does this belong in runtime, builder, or both?
  - Both. Runtime owns rules; builder owns the authored status application and icon metadata.
- What existing system should this reuse instead of duplicating?
  - Reuse structured card effects and the existing predefined buff UI/catalog path.
- What will probably break if this changes?
  - Turn-start sequencing, hand draw/discard flow, and crowded combat buff rows.
- What old implementation should be deleted instead of adapted?
  - None yet; there is no older status system to preserve.
- What content, UI, or tooltip support is needed so players understand it?
  - Clear icons, readable stack counts, reminder text, and sample cards/enemies that demonstrate both positive and negative status interactions.

## 18. Notes

- This spec intentionally narrows the first implementation slice. The original draft also mentioned enemy resistances/weaknesses and elemental effects from items/equipment, but those should follow after the generic combat status engine exists and proves stable.
