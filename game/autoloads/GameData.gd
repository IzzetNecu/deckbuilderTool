extends Node

var schema_version: int = 1
var default_player_id: String = ""

const DEFAULT_ELEMENTAL_AFFINITIES := [
	{"id": 1, "key": "fire", "name": "Fire", "color": "#e4572e", "description": "Direct pressure and attack setup."},
	{"id": 2, "key": "earth", "name": "Earth", "color": "#8a6f3d", "description": "Endurance, attrition, and recovery."},
	{"id": 3, "key": "water", "name": "Water", "color": "#2f80ed", "description": "Defense flow and adaptive protection."},
	{"id": 4, "key": "wind", "name": "Wind", "color": "#4fb286", "description": "Card flow, speed, and disruption."},
	{"id": 5, "key": "lightning", "name": "Lightning", "color": "#f2c94c", "description": "Energy spikes and duplicated action windows."},
	{"id": 6, "key": "ice", "name": "Ice", "color": "#8fd3ff", "description": "Block pressure and end-of-turn control."}
]

var players: Dictionary = {}
var buffs: Dictionary = {}
var factions: Dictionary = {}
var cards: Dictionary = {}
var consumables: Dictionary = {}
var equipment: Dictionary = {}
var key_items: Dictionary = {}
var enemies: Dictionary = {}
var events: Dictionary = {}
var deck_templates: Dictionary = {}
var maps: Dictionary = {}
var flags: Dictionary = {}
var elemental_affinities: Dictionary = {}

func _ready() -> void:
	load_data("res://data/game_data.json")

func load_data(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Could not open game data file: " + path)
		return

	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK:
		push_error("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		return

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("JSON data is not a dictionary.")
		return

	schema_version = int(data.get("schemaVersion", 1))
	default_player_id = str(data.get("defaultPlayerId", ""))
	_load_elemental_affinities(data.get("elemental_affinities", []))

	_index_collection(data.get("players", []), players, Callable(self, "_normalize_player"))
	_index_collection(data.get("buffs", []), buffs, Callable(self, "_normalize_buff"))
	_index_collection(data.get("factions", []), factions)
	_index_collection(data.get("cards", []), cards, Callable(self, "_normalize_card"))
	_index_collection(data.get("consumables", []), consumables, Callable(self, "_normalize_consumable"))
	_index_collection(data.get("equipment", []), equipment, Callable(self, "_normalize_equipment"))
	_index_collection(data.get("keyItems", []), key_items)
	_index_collection(data.get("enemies", []), enemies, Callable(self, "_normalize_enemy"))
	_index_collection(data.get("events", []), events)
	_index_collection(data.get("deckTemplates", []), deck_templates)
	_index_collection(data.get("maps", []), maps)
	_index_collection(data.get("flags", []), flags)

	if default_player_id.is_empty() and not players.is_empty():
		default_player_id = str(players.keys()[0])

func _index_collection(arr: Array, target_dict: Dictionary, normalizer: Callable = Callable()) -> void:
	target_dict.clear()
	for item in arr:
		if typeof(item) != TYPE_DICTIONARY or not item.has("id"):
			continue
		var normalized = item
		if normalizer.is_valid():
			normalized = normalizer.call(item)
		target_dict[normalized["id"]] = normalized

func _normalize_card(item: Dictionary) -> Dictionary:
	var card = item.duplicate(true)
	card["targeting"] = card.get("targeting", "single_enemy" if card.get("requiresTarget", false) else "self")
	card["requiresTarget"] = card["targeting"] == "single_enemy"
	card["cardImage"] = str(card.get("cardImage", ""))
	card["card_affinities"] = normalize_affinity_ids(card.get("card_affinities", card.get("cardAffinities", [])), 3)
	var effects: Array = []
	for effect in card.get("effects", []):
		effects.append(_normalize_effect(effect))
	card["effects"] = effects
	return card

func _normalize_effect(effect) -> Dictionary:
	if typeof(effect) == TYPE_DICTIONARY and effect.has("type"):
		var effect_type = _normalize_effect_type(str(effect.get("type", "damage")))
		var normalized = effect.duplicate(true)
		normalized["type"] = effect_type
		normalized["amount"] = _extract_effect_amount(effect)
		normalized["target"] = str(effect.get("target", _infer_target_from_effect_type(effect_type)))
		normalized["scaling"] = str(effect.get("scaling", effect.get("scalesWith", "none")))
		if effect_type == "apply_status":
			normalized["statusId"] = str(effect.get("statusId", ""))
			if normalized["statusId"].is_empty():
				normalized["amount"] = 0
		return normalized

	var value_str := ""
	var scales_with := "none"
	if typeof(effect) == TYPE_DICTIONARY:
		value_str = str(effect.get("value", ""))
		scales_with = str(effect.get("scalesWith", "none"))
	else:
		value_str = str(effect)

	var parts = value_str.split(":")
	var legacy_type = parts[0] if parts.size() > 0 else ""
	var amount = int(parts[1]) if parts.size() > 1 else 0
	var normalized_type = _normalize_effect_type(legacy_type)
	return {
		"type": normalized_type,
		"amount": amount,
		"target": _infer_target_from_effect_type(normalized_type),
		"scaling": scales_with
	}

func _normalize_effect_type(effect_type: String) -> String:
	var normalized = effect_type.strip_edges()
	if normalized.is_empty():
		return "damage"
	var type_map = {
		"ATTACK": "damage",
		"DEFEND": "block",
		"HEAL": "heal",
		"DRAW": "draw",
		"DISCARD": "discard",
		"GAIN_ENERGY": "gain_energy",
		"INSIGHT": "modify_insight",
		"MODIFY_INSIGHT": "modify_insight",
		"APPLY_STATUS": "apply_status"
	}
	return str(type_map.get(normalized.to_upper(), normalized.to_lower()))

func _extract_effect_amount(effect: Dictionary) -> int:
	if effect.has("amount"):
		return int(effect.get("amount", 0))
	var value_str = str(effect.get("value", ""))
	if value_str.is_empty():
		return 0
	var parts = value_str.split(":")
	if parts.size() > 1:
		return int(parts[1])
	return int(value_str)

func _infer_target_from_effect_type(effect_type: String) -> String:
	if effect_type == "damage":
		return "enemy"
	return "self"

func _normalize_enemy(item: Dictionary) -> Dictionary:
	var enemy = item.duplicate(true)
	enemy["portraitImage"] = str(enemy.get("portraitImage", ""))
	var stats = enemy.get("stats", {})
	enemy["stats"] = {
		"maxHealth": int(stats.get("maxHealth", enemy.get("hp", 10))),
		"strength": int(stats.get("strength", 0)),
		"dexterity": int(stats.get("dexterity", 0)),
		"insight": int(stats.get("insight", 0))
	}
	enemy["hp"] = int(enemy["stats"]["maxHealth"])
	enemy["handSize"] = int(enemy.get("handSize", enemy.get("hand_size", 3)))
	enemy["hand_size"] = enemy["handSize"]
	enemy["intentMode"] = str(enemy.get("intentMode", "deck"))
	enemy["intentPreviewCount"] = int(enemy.get("intentPreviewCount", 0))
	return enemy

func _normalize_player(item: Dictionary) -> Dictionary:
	var player = item.duplicate(true)
	player["portraitImage"] = str(player.get("portraitImage", ""))
	player["player_elemental_capacity"] = clampi(int(player.get("player_elemental_capacity", player.get("playerElementalCapacity", 1))), 0, 6)
	var base_stats = player.get("baseStats", {})
	player["baseStats"] = {
		"maxHealth": int(base_stats.get("maxHealth", 20)),
		"strength": int(base_stats.get("strength", 1)),
		"dexterity": int(base_stats.get("dexterity", 1)),
		"insight": int(base_stats.get("insight", 0)),
		"maxEnergy": int(base_stats.get("maxEnergy", 3)),
		"handSize": int(base_stats.get("handSize", 5))
	}
	var inventory = player.get("startingInventory", {})
	player["startingInventory"] = {
		"consumables": inventory.get("consumables", []).duplicate(),
		"equipment": inventory.get("equipment", []).duplicate(),
		"keyItems": inventory.get("keyItems", []).duplicate()
	}
	player["startingDeck"] = player.get("startingDeck", []).duplicate()
	player["startingOwnedCards"] = player.get("startingOwnedCards", player["startingDeck"]).duplicate()
	var starting_equipped = player.get("startingEquipped", {})
	var normalized_slots := {}
	var migrated_equipped = _migrate_legacy_equipped_slots(starting_equipped)
	for slot_id in ["weapon_1", "weapon_2", "armor", "accessory_1", "accessory_2"]:
		normalized_slots[slot_id] = str(migrated_equipped.get(slot_id, ""))
	player["startingEquipped"] = normalized_slots
	return player

func _normalize_equipment(item: Dictionary) -> Dictionary:
	var equipment_item = item.duplicate(true)
	var legacy_type = str(item.get("type", ""))
	var default_slot_cost = 2 if legacy_type == "twohandedWeapon" else 1
	equipment_item["type"] = _normalize_equipment_type(str(equipment_item.get("type", "accessory")))
	equipment_item["equipmentImage"] = str(equipment_item.get("equipmentImage", ""))
	equipment_item["slotCost"] = clampi(int(equipment_item.get("slotCost", default_slot_cost)), 1, 2)
	if equipment_item["type"] != "weapon":
		equipment_item["slotCost"] = 1
	equipment_item["cardIds"] = equipment_item.get("cardIds", []).duplicate()
	equipment_item["effects"] = equipment_item.get("effects", []).duplicate()
	equipment_item["conditions"] = equipment_item.get("conditions", []).duplicate()
	return equipment_item

func _normalize_equipment_type(equipment_type: String) -> String:
	match equipment_type:
		"onehandedWeapon", "twohandedWeapon", "offHand", "weapon":
			return "weapon"
		"armor", "head", "legs":
			return "armor"
		"ring", "amulet", "accessory":
			return "accessory"
	return "accessory"

func _migrate_legacy_equipped_slots(raw_slots: Dictionary) -> Dictionary:
	var migrated := {}
	for slot_id in ["weapon_1", "weapon_2", "armor", "accessory_1", "accessory_2"]:
		migrated[slot_id] = str(raw_slots.get(slot_id, ""))
	if migrated["weapon_1"].is_empty():
		migrated["weapon_1"] = str(raw_slots.get("weapon_main", ""))
	if migrated["weapon_2"].is_empty():
		migrated["weapon_2"] = str(raw_slots.get("off_hand", ""))
	if migrated["armor"].is_empty():
		migrated["armor"] = str(raw_slots.get("armor", raw_slots.get("head", raw_slots.get("legs", ""))))
	if migrated["accessory_1"].is_empty():
		migrated["accessory_1"] = str(raw_slots.get("ring_left", raw_slots.get("amulet", "")))
	if migrated["accessory_2"].is_empty():
		migrated["accessory_2"] = str(raw_slots.get("ring_right", ""))
	return migrated

func _normalize_buff(item: Dictionary) -> Dictionary:
	var buff = item.duplicate(true)
	buff["name"] = str(buff.get("name", buff.get("id", "")))
	buff["kind"] = str(buff.get("kind", "buff"))
	buff["iconImage"] = str(buff.get("iconImage", ""))
	buff["shortLabel"] = str(buff.get("shortLabel", ""))
	buff["reminderText"] = str(buff.get("reminderText", ""))
	return buff

func _normalize_consumable(item: Dictionary) -> Dictionary:
	var consumable = item.duplicate(true)
	var effects: Array = []
	for effect in consumable.get("effects", []):
		effects.append(_normalize_effect(effect))
	consumable["effects"] = effects
	return consumable

func _load_elemental_affinities(entries: Array) -> void:
	elemental_affinities.clear()
	for base in DEFAULT_ELEMENTAL_AFFINITIES:
		var authored := {}
		for entry in entries:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			if int(entry.get("id", 0)) == int(base.get("id", 0)) or str(entry.get("key", "")) == str(base.get("key", "")):
				authored = entry
				break
		var normalized = base.duplicate(true)
		normalized["name"] = str(authored.get("name", base.get("name", "")))
		normalized["color"] = _normalize_hex_color(str(authored.get("color", base.get("color", "#ffffff"))), str(base.get("color", "#ffffff")))
		normalized["description"] = str(authored.get("description", base.get("description", "")))
		elemental_affinities[int(base.get("id", 0))] = normalized

func normalize_affinity_ids(values: Variant, max_count: int = 6) -> Array:
	var result: Array = []
	if max_count <= 0:
		return result
	var raw_values: Array = values if values is Array else []
	for base in DEFAULT_ELEMENTAL_AFFINITIES:
		var id = int(base.get("id", 0))
		for value in raw_values:
			if int(value) == id and not result.has(id):
				result.append(id)
				break
		if result.size() >= max_count:
			break
	return result

func get_elemental_affinity(id: int) -> Dictionary:
	return elemental_affinities.get(id, {})

func get_elemental_affinity_list() -> Array:
	var result: Array = []
	for base in DEFAULT_ELEMENTAL_AFFINITIES:
		var id = int(base.get("id", 0))
		if elemental_affinities.has(id):
			result.append(elemental_affinities[id])
	return result

func get_affinity_color(id: int) -> Color:
	var affinity = get_elemental_affinity(id)
	return Color.html(str(affinity.get("color", "#ffffff")))

func _normalize_hex_color(value: String, fallback: String) -> String:
	var color = value.strip_edges().to_lower()
	if color.length() != 7 or not color.begins_with("#"):
		return fallback
	for i in range(1, color.length()):
		if not "0123456789abcdef".contains(color.substr(i, 1)):
			return fallback
	return color

func get_default_player() -> Dictionary:
	if players.has(default_player_id):
		return players[default_player_id]
	if players.is_empty():
		return {}
	return players[players.keys()[0]]

func get_player(id: String) -> Dictionary:
	if id.is_empty():
		return get_default_player()
	return players.get(id, {})

func get_buff(id: String) -> Dictionary: return buffs.get(id, {})
func get_card(id: String) -> Dictionary: return cards.get(id, {})
func get_enemy(id: String) -> Dictionary: return enemies.get(id, {})
func get_event(id: String) -> Dictionary: return events.get(id, {})
func get_map(id: String) -> Dictionary: return maps.get(id, {})
func get_consumable(id: String) -> Dictionary: return consumables.get(id, {})
func get_equipment(id: String) -> Dictionary: return equipment.get(id, {})
func get_key_item(id: String) -> Dictionary: return key_items.get(id, {})
func get_faction(id: String) -> Dictionary: return factions.get(id, {})
