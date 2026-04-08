# Deck Builder - Game Authoring Tool

A web-based editor for authoring all content for a deckbuilding adventure RPG. 
This builder exports a structured JSON payload that can be directly imported and parsed natively by a GDScript game client in Godot.

## Features

The editor operates completely client-side utilizing vanilla HTML, CSS, JavaScript (ES modules) and `localStorage`. It requires no build tools to run—simply host the directory with any local static HTTP server (e.g. `python3 -m http.server`).

### Editors Included
- **Factions**: Create factions with ordered ranks (e.g. Outsider, Initiate, Member, Elder) for story branching.
- **Cards**: Author Attack, Defend, Skill, or Power cards. Assign cost, mechanic effects (`DEAL_DAMAGE:6`), rarity, and preview them live.
- **Consumables**: Single-use items allowing special effects during and out of combat.
- **Equipment**: Items that can be worn by the player on specific slots (`offHand`, `onehandedWeapon`, `twohandedWeapon`, `head`, `armor`, `legs`, `ring`, `amulet`). Supports stat conditions for equipping and attaching cards directly into the player's deck.
- **Key Items**: Narrative and quest items (e.g. Dungeon Keys) driving dialogue events.
- **Enemies**: Build monsters, assign them Health Points, configure their potential loot drops (from Consumables, Equipment, and Key Items), and build their unique behavior deck using the Cards you engineered.
- **Events (Narrative)**: Build rich choose-your-own-adventure dialogue trees. Options can have complex Prerequisites (e.g. `hasStrength >= 5` or `hasMoney >= 120`) and distinct Outcomes.
- **Map Node-Graph Editor**: A fully custom HTML5 canvas graph editor allowing you to draw paths between maps, rest sites, shops, and combat encounters. Supports nested sub-maps (e.g. Dungeons).

## JSON Export Schema

The primary output of the tool is the exported JSON payload, which acts as the contract between this Builder and the Godot game.

```json
{
  "factions": [...],
  "cards": [...],
  "consumables": [...],
  "equipment": [...],
  "keyItems": [...],
  "enemies": [...],
  "events": [...],
  "deckTemplates": [...],
  "maps": [...]
}
```

## Running the Builder Locally

1. Clone the repository.
2. Open a terminal in the root folder (`deckbuilderTool/`).
3. Run `python3 -m http.server 8000` (or your preferred local web server).
4. Navigate to `http://localhost:8000` in your web browser.
