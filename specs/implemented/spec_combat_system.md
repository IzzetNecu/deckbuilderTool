# Combat System Plan

**Ticket:** LOCAL-COMBAT-SYSTEM
**Status:** ACTIVE / PARTIALLY IMPLEMENTED
**Date:** 2026-05-14

---

## Executive Summary

This repo already has a working card combat prototype in Godot, but the authored data and runtime model are still too loose to support a deeper Slay the Spire-style combat loop safely. The main issue is not drawing cards or applying damage; it is that the `src/` builder exports plain JSON with weak combat semantics, while `game/` directly consumes that data as live runtime state.

The recommended direction is to keep the builder-to-JSON-to-Godot pipeline, but formalize it around a versioned combat schema, explicit actor/runtime state separation, and a structured effect/intention model. That allows the current prototype to grow into a stable, non-roguelike deckbuilder combat system without breaking existing content authoring.

## Implemented Since Initial Draft

The original draft assumed the repo still needed the first major combat-system pass. That is no longer true. The following parts of the plan are already implemented in the current branch and should be treated as the new baseline:

- Structured combat normalization now exists in the load/runtime path, including legacy-to-current effect compatibility in `GameData.gd`.
- Card execution no longer depends on the old card-era targeting assumptions alone; `targeting` is part of the current path and target validation happens in `CombatManager.gd`.
- Drag-and-drop input was repaired in `Card.gd` by ignoring child-control mouse capture and tracking active drag through `_input`.
- Enemy intent now supports partial reveal with hidden placeholders, so the player can see total upcoming enemy plays even when only some are revealed.
- `insight` is part of the active combat UI/intent flow and is rendered as a stat buff instead of only living in the spec.
- Enemy block timing was corrected so enemy armor persists through the player turn and clears when the enemy turn begins.
- Combat UI was refactored around a shared `CombatantPanel` with left player / right enemy layout, portrait placeholders, HP bars, block overlay, buff icons, and enemy intent display.
- Redundant top-HUD player summary text was removed from the live combat scene; HP/block are now shown in-panel.
- The builder now supports player and enemy portrait image fields.
- Buff/debuff authoring now exists as a fixed predefined catalog where the user supplies icons while effect/reminder behavior stays predefined in code/data.
- Loss flow currently exits combat back to the map immediately after a short delay; there is not yet a dedicated defeat screen or a post-defeat HP floor.

This means the remaining spec work is not a greenfield combat redesign. It is now mainly about:

- documenting the current baseline accurately
- identifying remaining gaps
- guiding future combat extensions without reintroducing legacy UI/runtime patterns

## Current State / Root Cause

### Current Runtime Surface

- Godot already has a combat manager with turn phases, draw/discard piles, energy, block, player hand, enemy hand, and win/lose checks in [CombatManager.gd](/Users/sy/Documents/Game/DeckBuilderGame/game/scenes/combat/CombatManager.gd).
- Cards are authored in the web builder and exported as JSON via [store.js](/Users/sy/Documents/Game/DeckBuilderGame/src/data/store.js) and loaded directly by [GameData.gd](/Users/sy/Documents/Game/DeckBuilderGame/game/autoloads/GameData.gd).
- Player stats are no longer only hardcoded; player data, portraits, and combat-related content support now exist in the builder/runtime pipeline.
- Combat presentation no longer uses only a flat HUD; the active scene uses combatant panels with portrait, HP, block, buffs, and intent display.

### Root Cause

The current combat implementation couples three different concerns:

1. Authored content definitions:
   cards, enemies, deck templates, loot tables in exported JSON.
2. Runtime combat state:
   current HP, block, energy, draw piles, discard piles, hands, turn phase.
3. Rule interpretation:
   parsing string-like effects such as `ATTACK:2`, deciding scaling, and deciding target behavior.

That coupling works for the current prototype because the mechanic set is small, but it will become fragile as soon as combat needs:

- more effect types
- statuses/buffs/debuffs
- exhaust/retain/draw/discard manipulation
- enemy intents and telegraphed behavior
- authored player profiles / starting decks
- encounter-level rules and rewards

### Verified Code Facts

- Combat runtime currently spans 4 core files and 537 total lines:
  `wc -l game/scenes/combat/CombatManager.gd game/scenes/combat/CombatScene.gd game/scenes/combat/Card.gd game/scenes/combat/EnemyUnit.gd`
- Exported content currently includes 3 cards, 1 enemy, 4 events, 2 deck templates, 1 map, 0 factions:
  `node -e "const d=require('./game/data/game_data.json'); console.log(JSON.stringify({cards:d.cards.length,enemies:d.enemies.length,events:d.events.length,deckTemplates:d.deckTemplates.length,maps:d.maps.length,factions:d.factions.length}, null, 2))"`
- Combat effect execution currently supports exactly 3 built-in effect verbs:
  `rg -n '"ATTACK"|"DEFEND"|"HEAL"' game/scenes/combat/CombatManager.gd`
- Enemy authored combat data currently consists of `hp`, `hand_size`, `deckTemplateIds`, `deckIds`, and `lootTable`:
  `rg -n 'deckTemplateIds|deckIds|hand_size' src/data/models.js src/builder/editors/enemy-editor.js game/scenes/combat/CombatManager.gd`
- Cards currently expose `cost`, `type`, `requiresTarget`, and `effects`, with effects still represented as string payloads plus optional `scalesWith`:
  `rg -n 'requiresTarget|effects|scalesWith' src/data/models.js src/builder/editors/card-editor.js game/scenes/combat/Card.gd game/scenes/combat/CombatManager.gd`

### What Already Works

- Basic JSON export/import path between `src/` and `game/`
- Player draw/discard/hand loop
- Enemy deck assembly from templates plus extra cards
- Energy spending and turn-ending flow
- Block absorption and HP loss
- Card drag/drop with repaired input handling
- Live token replacement in card text for the existing scaling model
- Hidden enemy intent placeholders for unrevealed upcoming enemy cards
- Shared combatant UI panels with portrait placeholders and buff icon display
- Builder-side fixed buff catalog with icon upload support

These pieces should be preserved and refactored forward rather than replaced outright.

## Current Baseline After Recent Updates

### Runtime

- `CombatManager.gd` now emits enemy intent slots rather than only a revealed-card subset.
- Enemy block clears at the start of the enemy turn instead of before the player turn.
- Combat resolution stops enemy action execution when combat already ended.
- Runtime normalization supports legacy effect payloads and migrated shapes.

### Combat UI

- Player character is rendered on the left and enemy on the right.
- Enemy HP bar is smaller and positioned under the enemy portrait.
- Block is displayed inside the HP bar on the left, with HP values inside the bar on the right.
- Player energy is displayed as a dedicated element near the portrait, not as a buff chip.
- Strength, dexterity, and insight are represented as buff icons under the HP bar.
- Enemy unrevealed upcoming cards show as hidden placeholders during intent preview.
- On defeat, combat currently returns to the map rather than showing a dedicated defeat overlay first.

### Builder / Authored Data

- Buffs/debuffs are now a predefined catalog instead of freeform user-created records.
- Builder users assign icon art for predefined buffs and can read reminder/effect text, but they do not define buff behavior there.
- Player and enemy portrait image fields are supported in the builder.
- Exported data now carries the newer combat/buff/portrait structures as the active baseline.

## Constraints

| # | Constraint | Rationale |
|---|---|---|
| C1 | Keep JSON as the contract between builder and Godot | This is already the authoring pipeline |
| C2 | Avoid breaking existing exported content on the first pass | Current sample data and editor flows should keep loading |
| C3 | Separate authored definitions from runtime battle state | Required for stable turn logic and future save/load |
| C4 | Combat logic must stay data-driven enough for non-programmer content authoring | The web tool is the content surface |
| C5 | Initial migration should fit the existing Godot architecture | Current repo is small and does not justify a full framework rewrite |

## Implementation Options

### Plan A — Keep String Effects, Expand the Parser

**Blast radius:** ~8-10 files

**Pros:**
- Lowest short-term cost
- Minimal builder UI changes
- Keeps old content fully compatible

**Cons:**
- Effect grammar becomes increasingly brittle
- Hard to validate in the builder
- Poor fit for complex targeting, statuses, exhaust, conditional logic
- Pushes complexity into parsing rather than data design

### Plan B — Structured Combat Schema with Compatibility Layer

**Blast radius:** ~12-16 files

**Pros:**
- Best balance of forward growth and migration cost
- Allows builder validation and better editor UX
- Lets Godot normalize old and new card data during migration
- Clean foundation for statuses, intents, exhaust, modifiers, encounter rules

**Cons:**
- Requires coordinated updates in both `src/` and `game/`
- Slightly larger first implementation slice

### Plan C — Full Encounter/Combat DSL Rewrite

**Blast radius:** 20+ files

**Pros:**
- Most flexible long term
- Could model advanced combat and scripted encounters uniformly

**Cons:**
- Too much abstraction for current repo scale
- High implementation risk
- Slows delivery before the core loop is proven fun

## Recommended Direction

Choose **Plan B**.

Use a structured combat schema with a temporary compatibility layer so Godot can read both:

- current effects: `{ value: "ATTACK:6", scalesWith: "strength" }`
- future effects: `{ type: "damage", amount: 6, target: "enemy", scaling: "strength" }`

That lets implementation happen in phases while preserving current content and editor workflows.

## Interfaces

### 1. Authored Card Definition

Recommended target shape:

```json
{
  "id": "card_strike",
  "name": "Strike",
  "description": "Deal {damage} damage.",
  "type": "attack",
  "cost": 1,
  "rarity": "common",
  "targeting": "single_enemy",
  "tags": ["starter"],
  "effects": [
    {
      "type": "damage",
      "amount": 6,
      "target": "enemy",
      "scaling": "strength"
    }
  ]
}
```

Notes:

- Replace `requiresTarget` with a broader `targeting` enum:
  `none`, `self`, `single_enemy`, `all_enemies`, `random_enemy`.
- Keep `description` as display text, not the source of truth for mechanics.
- `effects` should become structured objects, not string payloads.

### 2. Authored Player Definition

New collection needed in `src/`:

```json
{
  "id": "player_default",
  "name": "Hero",
  "baseStats": {
    "maxHealth": 20,
    "strength": 1,
    "dexterity": 1,
    "insight": 0,
    "maxEnergy": 3,
    "handSize": 5
  },
  "startingDeck": ["card_strike", "card_defend"],
  "startingInventory": {
    "consumables": [],
    "equipment": [],
    "keyItems": []
  }
}
```

This closes the current gap where combat-critical player data is only hardcoded in `GameState`.

### 3. Authored Enemy Definition

Recommended enemy additions:

```json
{
  "id": "enemy_bandit",
  "name": "Bandit",
  "stats": {
    "maxHealth": 24,
    "strength": 0,
    "dexterity": 0,
    "insight": 0
  },
  "intentMode": "deck",
  "intentPreviewCount": 1,
  "handSize": 2,
  "deckTemplateIds": [],
  "deckIds": [],
  "lootTable": []
}
```

Notes:

- Keep deck-authored enemies, but move toward intent preview rather than exposing a full enemy hand.
- `intentMode` keeps room for later enemy AI variants without a rewrite.
- Add `insight` to both player and enemy stat blocks. If `player.insight > enemy.insight`, reveal that many upcoming enemy cards, capped by the number of cards the enemy is about to play that turn.
- Revealed intent means showing full card faces, not abstract icons or summary text.
- Enemy intended cards are cards drawn from the enemy deck into the enemy's hand for its upcoming turn.
- The enemy draws that hand before the player acts for the round, then resolves those drawn cards in order once the player turn ends.

### 4. Runtime Combat State

Godot should normalize authored JSON into battle-only state:

```text
CombatState
- phase
- turn_number
- player: ActorState
- enemies: Array[ActorState]
- draw_pile / hand / discard / exhaust
- pending_intents
- combat_rewards
```

```text
ActorState
- actor_id
- source_definition_id
- current_hp
- max_hp
- block
- stats
- statuses
- draw_pile
- hand
- discard
- exhaust
```

This is the core separation currently missing from the repo.

### 5. Insight Rule

Recommended runtime rule:

```text
reveal_count = min(
  max(player_insight - enemy_insight, 0),
  drawn_enemy_cards_this_turn
)
```

Behavior notes:

- `insight` is a combat stat on both player and enemy actors.
- Revealed intent is displayed as full enemy card faces.
- Enemy intent represents the enemy hand drawn from its deck for that round, not cards played during the player phase.
- Once drawn for the round, that enemy hand is what the enemy resolves in order during its turn.
- `insight` determines how many of those drawn enemy cards are revealed to the player as full card faces.

## Blast Radius

| File | Action | Reason |
|---|---|---|
| `src/data/models.js` | Modify | Add `players` and structured combat schema |
| `src/data/store.js` | Modify | Include new collections and possible export versioning |
| `src/builder/builder.js` | Modify | Add player editor and any combat schema navigation |
| `src/builder/editors/card-editor.js` | Modify | Replace freeform effect strings with structured effect UI |
| `src/builder/editors/enemy-editor.js` | Modify | Add enemy stats/intent fields and rename hand-size semantics cleanly |
| `src/builder/editors/deck-editor.js` | Modify | Validate cards against new targeting/effect schema where needed |
| `src/builder/editors/player-editor.js` | Add | Author player base stats and starting deck |
| `game/autoloads/GameData.gd` | Modify | Normalize/export-version-aware loading |
| `game/autoloads/GameState.gd` | Modify | Initialize persistent state from authored player definition |
| `game/scenes/combat/CombatManager.gd` | Modify or split | Move from prototype manager to normalized combat state orchestration |
| `game/scenes/combat/CombatScene.gd` | Modify | Reflect intents, multi-actor state, and richer turn UI |
| `game/scenes/combat/Card.gd` | Modify | Support targeting enum and normalized card data |
| `game/scenes/combat/EnemyUnit.gd` | Modify | Show intent preview instead of raw revealed hand |
| `game/data/game_data.json` | Migrate | Backfill sample data to the new schema |

## User Flow Impact

### Changed

1. Builder authors will define player combat setup instead of relying on hardcoded `GameState`.
2. Card authoring will shift from freeform effect strings toward structured combat effect entries.
3. Enemy authoring will support intent behavior more explicitly.
4. Combat UI will likely show enemy intent preview rather than raw upcoming cards.
5. Defeat flow should show a dedicated defeated screen before returning the player to the map.
6. Leaving combat after defeat should clamp persistent player HP to a minimum of 1 instead of allowing overworld state to stay at 0.

### Unchanged

1. Data still originates in the web tool.
2. Export still produces JSON for Godot.
3. Player still plays cards from hand with energy costs.
4. Enemy decks can still be composed from templates plus individual cards.

## Acceptance Criteria

- [ ] Godot can load exported combat data through a documented schema version or compatibility layer
- [x] Player combat-related authored data is now supported in `src/`, though future expansion may still move more setup out of `GameState`
- [ ] Cards no longer depend on description text or string parsing as the long-term source of truth for mechanics
- [ ] Runtime combat state is separated from authored definitions
- [~] The combat loop supports damage, block, heal, target validation, and intent preview; broader verbs/status coverage remains ongoing
- [ ] Existing sample content can still load during migration
- [ ] Builder authors can define cards, enemies, decks, and player setup without editing Godot code
- [x] Enemy intent visibility is driven by `insight`: for each point the player's `insight` exceeds the enemy's `insight`, reveal one of the enemy cards drawn for that turn
- [x] Revealed intent is shown as full card faces, with hidden placeholders for unrevealed upcoming cards
- [x] Combat UI shows portraits, HP, block, buffs, and energy in the newer panel-based layout
- [ ] If the enemy is defeated by a status effect instead of direct card damage, the normal victory/loot flow still appears
- [ ] On combat defeat, the player sees a dedicated defeated screen before the scene returns to the map
- [ ] After a combat defeat, persistent player HP is clamped to at least 1 before returning to the map

## Decision Points

1. **Targeting model**
   Recommended: enum-based targeting, not a boolean `requiresTarget`.
   Even though combat is single-enemy for now, keep targeting in the model for future summoned enemies or allied combatants.

2. **Enemy design**
   Recommended: keep deck-authored enemies, but show intent summary in UI rather than a full enemy hand.
   Use `insight` advantage to determine how many intended cards are revealed.
   For this design, "revealed" means full card faces for the currently intended plays.
   Intended plays are the exact enemy cards drawn from the enemy deck to resolve after the player ends their turn.

3. **Compatibility strategy**
   Recommended: Godot-side normalization first, builder migration second.

4. **Player authoring**
   Recommended: add a `players` collection rather than continuing to evolve hardcoded `GameState`.

5. **Insight modification sources**
   `insight` should be modifiable by equipment, cards, and statuses, not just by base actor stats.

## Out of Scope

- Full roguelike progression systems
- Procedural run generation
- Meta-progression or relic systems unless explicitly attached to combat needs
- Multiplayer or networked combat
- Reworking map/event systems beyond what combat data integration requires

## Evidence Chain

### PROVEN

- The repo already contains a playable combat prototype with player drag/drop cards and enemy turns, verified by direct inspection of:
  [CombatManager.gd](/Users/sy/Documents/Game/DeckBuilderGame/game/scenes/combat/CombatManager.gd),
  [CombatScene.gd](/Users/sy/Documents/Game/DeckBuilderGame/game/scenes/combat/CombatScene.gd),
  [Card.gd](/Users/sy/Documents/Game/DeckBuilderGame/game/scenes/combat/Card.gd),
  [EnemyUnit.gd](/Users/sy/Documents/Game/DeckBuilderGame/game/scenes/combat/EnemyUnit.gd)
- Builder export is a plain collection dump with no combat-specific normalization:
  [store.js](/Users/sy/Documents/Game/DeckBuilderGame/src/data/store.js)
- Player combat stats are runtime-owned and hardcoded today:
  [GameState.gd](/Users/sy/Documents/Game/DeckBuilderGame/game/autoloads/GameState.gd)

### PROBABLE

- Continuing to add more verbs into the current `TYPE:VALUE` string parser will slow content validation and increase runtime branching in `CombatManager.gd`.

### UNVERIFIED

- Whether enemy decks should remain the primary enemy behavior system long term, or become one authoring input into a richer intent model.
- How enemy replanning works once summons or additional allied enemies exist on the field.

## What We Ruled Out

- **Greenfield rewrite of combat scenes now:** rejected because too much current functionality already exists.
- **Keeping hardcoded player definitions:** rejected because the user explicitly wants players as content alongside cards, enemies, and decks.
- **Full DSL migration first:** rejected because current repo size does not justify it.

## Corrections Log

| Original Assumption | Reality | Impact |
|---|---|---|
| Combat needed to be designed from scratch | A working combat prototype already exists in `game/scenes/combat/` | Plan focuses on evolution and separation, not greenfield design |
| The builder probably already supports players | No player collection/editor exists in `src/` | Player authoring becomes a required phase |
| Buddies were unavailable overall | Buddy doctor reports healthy roster; brainstorm failed specifically from this Codex process | Treat buddy output as unavailable for this session, but not as a repo constraint |
| Combat UI still relied on flat top-HUD stat text | The live combat UI now uses panel-based HP/block/buff presentation and removed the redundant top-HUD player summary | Future UI work should extend `CombatantPanel`, not restore the old HUD |
| Buff/debuff authoring needed freeform creation in the builder | The chosen baseline is a predefined buff catalog with icon-only content authoring | Future status expansion should be implemented in code/data first, then exposed as fixed entries in the builder |

## Expected Outcomes

| Phase | Outcome | Risk |
|---|---|---|
| 1 | Versioned/normalized combat data load path | Low |
| 2 | Authored player definitions + builder support | Low |
| 3 | Structured card effects + compatibility layer | Medium |
| 4 | Runtime combat state split and richer turn pipeline | Medium |
| 5 | Enemy intent UI and additional verbs/statuses | Medium |

## Implementation Phases

### Phase 1 — Stabilize the Contract

- Add `schemaVersion` to exported JSON
- Add Godot normalization layer for old/new combat records
- Introduce typed helper functions for cards, enemies, players

### Phase 2 — Author the Player

- Add `players` collection in `src/data/models.js`
- Add `player-editor.js`
- Add builder navigation
- Let `GameState` initialize from a chosen player definition

### Phase 3 — Replace Loose Card Semantics

- Introduce structured `targeting`
- Introduce structured `effects`
- Keep compatibility parser for existing `value: "ATTACK:2"` content
- Add builder validation for supported effect types

### Phase 4 — Split Runtime State from Authored Definitions

- Introduce battle-specific actor state in Godot
- Stop using raw card definition dictionaries as live hand state
- Add exhaust pile and turn counter support
- Add `insight` as a mutable runtime stat on actors so cards, equipment, and statuses can modify it during combat

### Phase 5 — Enemy Intent and StS-like Combat Readability

- Replace raw revealed enemy hand UI with intent preview
- Support single intent or ordered multi-intent display
- Add `insight` to player and enemy combat stats
- Reveal enemy intended cards based on `max(0, player_insight - enemy_insight)`
- Show revealed intent as full card faces
- Draw enemy intended cards from the enemy deck before the player acts each round
- Resolve those drawn enemy cards in order once the player turn ends
- Add additional verbs such as draw, discard, apply_status, gain_energy, exhaust, weak/vulnerable-like modifiers

### Phase 6 — Future Multi-Target Combat Expansion

- Keep current implementation optimized for one active enemy
- Preserve targeting and actor-state abstractions for future summoned monsters or allied enemy units
- Extend `single_enemy` targeting rules later into target selection across multiple hostile actors without rewriting card schema

## Honest Assessment

The shortest path to a good result is not “copy Slay the Spire exactly.” It is to keep the current data-driven prototype, formalize the builder/runtime contract, and then add StS-like combat semantics on top of that stable base. The repo is already close enough to avoid a rewrite, but not structured enough to safely absorb more mechanics without one planning pass first.

## Session Tracking

| Date | Session | Description |
|---|---|---|
| 2026-05-14 | current | Initial combat system architecture spec |
| 2026-05-14 | current | Updated baseline after combat UI, intent, drag/drop, buff catalog, and block-timing implementation |
