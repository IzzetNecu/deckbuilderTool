extends Node

signal map_updated

const SLOT_ORDER := [
	"weapon_main",
	"off_hand",
	"head",
	"armor",
	"legs",
	"amulet",
	"ring_left",
	"ring_right"
]

var player_id: String = ""

# Persistent player data
var health: int = 20
var max_health: int = 20
var strength: int = 1
var dexterity: int = 1
var insight: int = 0
var max_energy: int = 3
var gold: int = 0
var hand_size: int = 5

var owned_cards: Array = []
var deck: Array = []
var consumables: Array = []
var equipment: Array = []
var key_items: Array = []
var equipped_slots: Dictionary = {}

var current_map_id: String = ""
var current_node_id: String = ""
var visited_nodes: Array = []
var flags: Dictionary = {}

const SAVE_PATH = "user://savegame.json"

func initialize_from_player(selected_player_id: String = "") -> void:
	var player = GameData.get_player(selected_player_id)
	if player.is_empty():
		return

	player_id = str(player.get("id", selected_player_id))
	var base_stats = player.get("baseStats", {})
	max_health = int(base_stats.get("maxHealth", 20))
	health = max_health
	strength = int(base_stats.get("strength", 1))
	dexterity = int(base_stats.get("dexterity", 1))
	insight = int(base_stats.get("insight", 0))
	max_energy = int(base_stats.get("maxEnergy", 3))
	hand_size = int(base_stats.get("handSize", 5))

	deck = player.get("startingDeck", []).duplicate()
	owned_cards = player.get("startingOwnedCards", deck).duplicate()
	var inventory = player.get("startingInventory", {})
	consumables = inventory.get("consumables", []).duplicate()
	equipment = inventory.get("equipment", []).duplicate()
	key_items = inventory.get("keyItems", []).duplicate()
	equipped_slots = _sanitize_equipped_slots(player.get("startingEquipped", {}))
	gold = 0

func set_flag(flag_name: String, value: bool) -> void:
	flags[flag_name] = value

func get_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)

func get_stat(stat_name: String) -> int:
	if stat_name in self:
		return get(stat_name)
	return 0

func get_consumable_count(id: String) -> int:
	var count = 0
	for item in consumables:
		if item == id:
			count += 1
	return count

func get_equipment_count(id: String) -> int:
	var count = 0
	for item in equipment:
		if item == id:
			count += 1
	return count

func get_key_item_count(id: String) -> int:
	var count = 0
	for item in key_items:
		if item == id:
			count += 1
	return count

func get_owned_card_count(card_id: String) -> int:
	var count := 0
	for owned_id in owned_cards:
		if owned_id == card_id:
			count += 1
	return count

func get_selected_card_count(card_id: String) -> int:
	var count := 0
	for selected_id in deck:
		if selected_id == card_id:
			count += 1
	return count

func get_equipped_item_count(id: String) -> int:
	var count := 0
	for slot_id in SLOT_ORDER:
		if str(equipped_slots.get(slot_id, "")) == id:
			count += 1
	return count

func get_available_equipment_count(id: String) -> int:
	return max(0, get_equipment_count(id) - get_equipped_item_count(id))

func has_consumable(id: String) -> bool:
	return get_consumable_count(id) > 0

func has_equipment(id: String) -> bool:
	return get_equipment_count(id) > 0

func has_key_item(id: String) -> bool:
	return get_key_item_count(id) > 0

func can_add_card_to_deck(card_id: String) -> bool:
	return get_selected_card_count(card_id) < get_owned_card_count(card_id)

func add_card_to_deck(card_id: String) -> bool:
	if not can_add_card_to_deck(card_id):
		return false
	deck.append(card_id)
	return true

func remove_card_from_deck(card_id: String) -> bool:
	var idx = deck.find(card_id)
	if idx == -1:
		return false
	deck.remove_at(idx)
	return true

func add_owned_card(card_id: String, add_to_deck: bool = true) -> void:
	owned_cards.append(card_id)
	if add_to_deck:
		deck.append(card_id)

func remove_owned_card(card_id: String) -> bool:
	var owned_idx = owned_cards.find(card_id)
	if owned_idx == -1:
		return false
	owned_cards.remove_at(owned_idx)
	var deck_idx = deck.find(card_id)
	if deck_idx != -1:
		deck.remove_at(deck_idx)
	return true

func get_effective_deck() -> Array:
	var effective_deck = deck.duplicate()
	for entry in get_granted_card_entries():
		effective_deck.append(entry.get("card_id", ""))
	return effective_deck

func get_granted_card_entries() -> Array:
	var entries: Array = []
	for slot_id in SLOT_ORDER:
		var equipment_id = str(equipped_slots.get(slot_id, ""))
		if equipment_id.is_empty():
			continue
		var equip_data = GameData.get_equipment(equipment_id)
		for card_id in equip_data.get("cardIds", []):
			entries.append({
				"card_id": card_id,
				"equipment_id": equipment_id,
				"equipment_name": str(equip_data.get("name", equipment_id)),
				"slot": slot_id
			})
	return entries

func get_equipped_slots() -> Dictionary:
	return equipped_slots.duplicate(true)

func get_slot_item(slot_id: String) -> String:
	return str(equipped_slots.get(slot_id, ""))

func is_slot_blocked(slot_id: String) -> bool:
	if slot_id != "off_hand":
		return false
	var main_item_id = get_slot_item("weapon_main")
	if main_item_id.is_empty():
		return false
	var main_item = GameData.get_equipment(main_item_id)
	return str(main_item.get("type", "")) == "twohandedWeapon"

func get_valid_slots_for_equipment(id: String) -> Array:
	return _valid_slots_for_equipment_data(GameData.get_equipment(id))

func equip_item(id: String, preferred_slot: String = "") -> Dictionary:
	var equip_data = GameData.get_equipment(id)
	if equip_data.is_empty():
		return {"ok": false, "message": "Equipment not found."}
	if get_available_equipment_count(id) <= 0:
		return {"ok": false, "message": "No unequipped copy available."}
	if not _meets_equipment_conditions(equip_data):
		return {"ok": false, "message": "Requirements not met."}

	var valid_slots = _valid_slots_for_equipment_data(equip_data)
	if valid_slots.is_empty():
		return {"ok": false, "message": "Unsupported slot type."}

	var slot_id = preferred_slot
	if slot_id.is_empty():
		slot_id = _pick_default_slot(valid_slots)
	if not valid_slots.has(slot_id):
		return {"ok": false, "message": "Invalid slot."}
	if is_slot_blocked(slot_id):
		return {"ok": false, "message": "That slot is blocked by a two-handed weapon."}

	var equip_type = str(equip_data.get("type", ""))
	match equip_type:
		"twohandedWeapon":
			equipped_slots["weapon_main"] = ""
			equipped_slots["off_hand"] = ""
			equipped_slots["weapon_main"] = id
		"onehandedWeapon":
			var current_weapon = GameData.get_equipment(get_slot_item("weapon_main"))
			if str(current_weapon.get("type", "")) == "twohandedWeapon":
				equipped_slots["weapon_main"] = ""
			equipped_slots[slot_id] = id
		"offHand":
			if is_slot_blocked("off_hand"):
				return {"ok": false, "message": "Off-hand is blocked by a two-handed weapon."}
			equipped_slots[slot_id] = id
		_:
			equipped_slots[slot_id] = id

	return {"ok": true, "message": "Equipped."}

func unequip_slot(slot_id: String) -> bool:
	if not equipped_slots.has(slot_id):
		return false
	if str(equipped_slots.get(slot_id, "")).is_empty():
		return false
	equipped_slots[slot_id] = ""
	return true

func add_consumable(id: String, amount: int = 1) -> void:
	for i in range(amount):
		consumables.append(id)

func remove_consumable(id: String, amount: int = 1) -> void:
	var removed = 0
	for i in range(consumables.size() - 1, -1, -1):
		if consumables[i] == id:
			consumables.remove_at(i)
			removed += 1
			if removed >= amount:
				break

func add_equipment(id: String, amount: int = 1) -> void:
	for i in range(amount):
		equipment.append(id)

func remove_equipment(id: String, amount: int = 1) -> void:
	var removed = 0
	for i in range(equipment.size() - 1, -1, -1):
		if equipment[i] != id:
			continue
		equipment.remove_at(i)
		removed += 1
		_trim_equipped_item(id)
		if removed >= amount:
			break

func add_key_item(id: String, amount: int = 1) -> void:
	for i in range(amount):
		key_items.append(id)

func remove_key_item(id: String, amount: int = 1) -> void:
	var removed = 0
	for i in range(key_items.size() - 1, -1, -1):
		if key_items[i] == id:
			key_items.remove_at(i)
			removed += 1
			if removed >= amount:
				break

func save() -> void:
	var save_data = {
		"player_id": player_id,
		"health": health,
		"max_health": max_health,
		"strength": strength,
		"dexterity": dexterity,
		"insight": insight,
		"max_energy": max_energy,
		"gold": gold,
		"hand_size": hand_size,
		"owned_cards": owned_cards,
		"deck": deck,
		"consumables": consumables,
		"equipment": equipment,
		"key_items": key_items,
		"equipped_slots": equipped_slots,
		"current_map_id": current_map_id,
		"current_node_id": current_node_id,
		"visited_nodes": visited_nodes,
		"flags": flags
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		print("GameState: Saved successfully to ", SAVE_PATH)

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("GameState: No save file found.")
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("GameState: Failed to parse save file.")
		return false

	var data = json.data
	player_id = str(data.get("player_id", player_id))
	if player_id.is_empty():
		initialize_from_player()
	else:
		initialize_from_player(player_id)

	health = int(data.get("health", health))
	max_health = int(data.get("max_health", max_health))
	strength = int(data.get("strength", strength))
	dexterity = int(data.get("dexterity", dexterity))
	insight = int(data.get("insight", insight))
	max_energy = int(data.get("max_energy", max_energy))
	gold = int(data.get("gold", gold))
	hand_size = int(data.get("hand_size", hand_size))
	owned_cards = data.get("owned_cards", data.get("deck", owned_cards)).duplicate()
	deck = data.get("deck", deck).duplicate()
	consumables = data.get("consumables", consumables).duplicate()
	equipment = data.get("equipment", equipment).duplicate()
	key_items = data.get("key_items", key_items).duplicate()
	equipped_slots = _sanitize_equipped_slots(data.get("equipped_slots", {}))
	current_map_id = str(data.get("current_map_id", current_map_id))
	current_node_id = str(data.get("current_node_id", current_node_id))
	visited_nodes = data.get("visited_nodes", visited_nodes).duplicate()
	flags = data.get("flags", flags).duplicate()

	_prune_deck_to_owned_cards()

	print("GameState: Loaded successfully from ", SAVE_PATH)
	return true

func initialize_flags() -> void:
	flags.clear()
	for flag_id in GameData.flags:
		var flag = GameData.flags[flag_id]
		flags[str(flag.get("name", flag_id))] = flag.get("defaultValue", false)

func get_preview_card_text(card_data: Dictionary) -> String:
	var description = str(card_data.get("description", ""))
	for effect in card_data.get("effects", []):
		var amount = int(effect.get("amount", 0))
		match str(effect.get("scaling", "none")):
			"strength":
				amount += strength
			"dexterity":
				amount += dexterity
			"insight":
				amount += insight
		var effect_type = str(effect.get("type", ""))
		description = description.replace("{" + effect_type + "}", str(amount))
		description = description.replace("{" + _legacy_token_for_effect(effect_type) + "}", str(amount))
	return description

func _empty_equipped_slots() -> Dictionary:
	var slots := {}
	for slot_id in SLOT_ORDER:
		slots[slot_id] = ""
	return slots

func _sanitize_equipped_slots(raw_slots: Dictionary) -> Dictionary:
	var sanitized = _empty_equipped_slots()
	var remaining_counts := {}
	for equipment_id in equipment:
		remaining_counts[equipment_id] = int(remaining_counts.get(equipment_id, 0)) + 1

	for slot_id in SLOT_ORDER:
		var equipment_id = str(raw_slots.get(slot_id, ""))
		if equipment_id.is_empty():
			continue
		var equip_data = GameData.get_equipment(equipment_id)
		if equip_data.is_empty():
			continue
		if int(remaining_counts.get(equipment_id, 0)) <= 0:
			continue
		if not _valid_slots_for_equipment_data(equip_data).has(slot_id):
			continue
		if slot_id == "off_hand" and _slot_blocked_in_slots(slot_id, sanitized):
			continue
		sanitized[slot_id] = equipment_id
		remaining_counts[equipment_id] = int(remaining_counts.get(equipment_id, 0)) - 1

	return sanitized

func _prune_deck_to_owned_cards() -> void:
	var available_counts := {}
	for card_id in owned_cards:
		available_counts[card_id] = int(available_counts.get(card_id, 0)) + 1

	var pruned_deck: Array = []
	for card_id in deck:
		if int(available_counts.get(card_id, 0)) <= 0:
			continue
		pruned_deck.append(card_id)
		available_counts[card_id] = int(available_counts.get(card_id, 0)) - 1
	deck = pruned_deck

func _trim_equipped_item(id: String) -> void:
	while get_equipped_item_count(id) > get_equipment_count(id):
		for slot_id in SLOT_ORDER:
			if str(equipped_slots.get(slot_id, "")) == id:
				equipped_slots[slot_id] = ""
				break

func _valid_slots_for_equipment_data(equip_data: Dictionary) -> Array:
	match str(equip_data.get("type", "")):
		"onehandedWeapon", "twohandedWeapon":
			return ["weapon_main"]
		"offHand":
			return ["off_hand"]
		"head":
			return ["head"]
		"armor":
			return ["armor"]
		"legs":
			return ["legs"]
		"amulet":
			return ["amulet"]
		"ring":
			return ["ring_left", "ring_right"]
	return []

func _pick_default_slot(valid_slots: Array) -> String:
	for slot_id in valid_slots:
		if str(equipped_slots.get(slot_id, "")).is_empty():
			return slot_id
	return str(valid_slots[0])

func _slot_blocked_in_slots(slot_id: String, slot_state: Dictionary) -> bool:
	if slot_id != "off_hand":
		return false
	var main_item_id = str(slot_state.get("weapon_main", ""))
	if main_item_id.is_empty():
		return false
	var main_item = GameData.get_equipment(main_item_id)
	return str(main_item.get("type", "")) == "twohandedWeapon"

func _meets_equipment_conditions(equip_data: Dictionary) -> bool:
	for condition in equip_data.get("conditions", []):
		if not _evaluate_equipment_condition(condition):
			return false
	return true

func _evaluate_equipment_condition(condition: Dictionary) -> bool:
	if str(condition.get("type", "")) != "hasStat":
		return true
	var left_value = _stat_value_for_condition(str(condition.get("target", "")))
	var right_value = int(condition.get("value", 0))
	match str(condition.get("operator", ">=")):
		"<=":
			return left_value <= right_value
		"==":
			return left_value == right_value
		_:
			return left_value >= right_value

func _stat_value_for_condition(target: String) -> int:
	match target:
		"health":
			return health
		"strength":
			return strength
		"dexterity":
			return dexterity
		"energy", "maxEnergy":
			return max_energy
		"handsize", "handSize":
			return hand_size
		"insight":
			return insight
	return 0

func _legacy_token_for_effect(effect_type: String) -> String:
	match effect_type:
		"damage":
			return "ATTACK"
		"block":
			return "DEFEND"
		"heal":
			return "HEAL"
		"draw":
			return "DRAW"
		"discard":
			return "DISCARD"
		"gain_energy":
			return "GAIN_ENERGY"
		"modify_insight":
			return "INSIGHT"
	return effect_type.to_upper()
