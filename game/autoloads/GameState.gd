extends Node

signal map_updated

const SLOT_ORDER := [
	"weapon_1",
	"weapon_2",
	"armor",
	"accessory_1",
	"accessory_2"
]

const WEAPON_SLOTS := ["weapon_1", "weapon_2"]
const ACCESSORY_SLOTS := ["accessory_1", "accessory_2"]

const BASE_MINIMUM_DECK_SIZE := 15
const MAX_LOADOUTS := 3
const DEFAULT_LOADOUT_ID := "loadout_1"

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
var loadouts: Array = []
var active_loadout_id: String = DEFAULT_LOADOUT_ID

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
	_initialize_default_loadout()
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
	var counted_two_slot_weapon := false
	for slot_id in SLOT_ORDER:
		if str(equipped_slots.get(slot_id, "")) == id:
			if _is_two_slot_weapon_id(id):
				if counted_two_slot_weapon:
					continue
				counted_two_slot_weapon = true
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

func get_minimum_deck_size() -> int:
	return BASE_MINIMUM_DECK_SIZE

func can_remove_card_from_deck(card_id: String) -> bool:
	return get_selected_card_count(card_id) > 0

func add_card_to_deck(card_id: String) -> bool:
	if not can_add_card_to_deck(card_id):
		return false
	deck.append(card_id)
	return true

func remove_card_from_deck(card_id: String) -> bool:
	if not can_remove_card_from_deck(card_id):
		return false
	var idx = deck.find(card_id)
	if idx == -1:
		return false
	deck.remove_at(idx)
	return true

func replace_current_build(selected_deck: Array, slots: Dictionary) -> void:
	deck = selected_deck.duplicate()
	equipped_slots = _sanitize_equipped_slots_for_loadout(slots)

func add_owned_card(card_id: String, add_to_deck: bool = true) -> void:
	owned_cards.append(card_id)
	if add_to_deck:
		deck.append(card_id)
	_sync_active_loadout_from_current()

func remove_owned_card(card_id: String) -> bool:
	var owned_idx = owned_cards.find(card_id)
	if owned_idx == -1:
		return false
	owned_cards.remove_at(owned_idx)
	var deck_idx = deck.find(card_id)
	if deck_idx != -1:
		deck.remove_at(deck_idx)
	_sync_active_loadout_from_current()
	return true

func get_effective_deck() -> Array:
	var effective_deck = deck.duplicate()
	for entry in get_granted_card_entries():
		effective_deck.append(entry.get("card_id", ""))
	return effective_deck

func get_granted_card_entries() -> Array:
	var entries: Array = []
	var counted_two_slot_weapons := {}
	for slot_id in SLOT_ORDER:
		var equipment_id = str(equipped_slots.get(slot_id, ""))
		if equipment_id.is_empty():
			continue
		var equip_data = GameData.get_equipment(equipment_id)
		if equip_data.is_empty():
			continue
		if _equipment_slot_cost(equip_data) > 1:
			if counted_two_slot_weapons.has(equipment_id):
				continue
			counted_two_slot_weapons[equipment_id] = true
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
	if not WEAPON_SLOTS.has(slot_id):
		return false
	var weapon_1_item = get_slot_item("weapon_1")
	var weapon_2_item = get_slot_item("weapon_2")
	return not weapon_1_item.is_empty() and weapon_1_item == weapon_2_item and slot_id == "weapon_2" and _is_two_slot_weapon_id(weapon_1_item)

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
		if str(equip_data.get("type", "")) != "weapon" or _equipment_slot_cost(equip_data) > 1:
			return {"ok": false, "message": "That slot is occupied by a two-slot weapon."}

	var equip_type = str(equip_data.get("type", ""))
	match equip_type:
		"weapon":
			_clear_weapon_slots_if_two_slot_equipped()
			if _equipment_slot_cost(equip_data) > 1:
				equipped_slots["weapon_1"] = id
				equipped_slots["weapon_2"] = id
			else:
				equipped_slots[slot_id] = id
		_:
			equipped_slots[slot_id] = id

	return {"ok": true, "message": "Equipped."}

func unequip_slot(slot_id: String) -> bool:
	if not equipped_slots.has(slot_id):
		return false
	if str(equipped_slots.get(slot_id, "")).is_empty():
		return false
	var equipment_id = str(equipped_slots.get(slot_id, ""))
	if _is_two_slot_weapon_id(equipment_id):
		equipped_slots["weapon_1"] = ""
		equipped_slots["weapon_2"] = ""
		return true
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
		_sync_active_loadout_from_current()
		if removed >= amount:
			break

func get_loadouts() -> Array:
	var snapshot: Array = []
	for loadout in loadouts:
		snapshot.append((loadout as Dictionary).duplicate(true))
	return snapshot

func get_active_loadout() -> Dictionary:
	var loadout = _find_loadout(active_loadout_id)
	return loadout.duplicate(true) if not loadout.is_empty() else {}

func save_current_state_into_loadout(loadout_id: String = "") -> Dictionary:
	var target_id = active_loadout_id if loadout_id.is_empty() else loadout_id
	var validation = validate_loadout({
		"id": target_id,
		"deck": deck,
		"equipped_slots": equipped_slots
	})
	if not bool(validation.get("ok", false)):
		return {
			"ok": false,
			"message": "Cannot save invalid loadout: %s" % _join_validation_messages(validation)
		}
	var index = _find_loadout_index(target_id)
	if index == -1:
		return {"ok": false, "message": "Loadout not found."}
	var loadout = _dict_from_variant(loadouts[index])
	loadout["deck"] = deck.duplicate()
	loadout["equipped_slots"] = equipped_slots.duplicate(true)
	loadouts[index] = loadout
	return {"ok": true, "message": "Saved %s." % str(loadout.get("label", "Loadout"))}

func activate_loadout(loadout_id: String) -> Dictionary:
	var index = _find_loadout_index(loadout_id)
	if index == -1:
		return {"ok": false, "message": "Loadout not found."}
	var target_loadout = _dict_from_variant(loadouts[index])
	var validation = validate_loadout(target_loadout)
	if not bool(validation.get("ok", false)):
		return {
			"ok": false,
			"message": "Cannot switch loadouts: %s" % _join_validation_messages(validation),
			"validation": validation
		}
	active_loadout_id = loadout_id
	deck = _array_from_variant(target_loadout.get("deck", []))
	equipped_slots = _sanitize_equipped_slots_for_loadout(_dict_from_variant(target_loadout.get("equipped_slots", {})))
	return {"ok": true, "message": "Switched to %s." % str(target_loadout.get("label", "Loadout"))}

func create_loadout_from_current(label: String = "") -> Dictionary:
	if loadouts.size() >= MAX_LOADOUTS:
		return {"ok": false, "message": "All %d loadout slots are already in use." % MAX_LOADOUTS}
	var validation = validate_loadout({"deck": deck, "equipped_slots": equipped_slots})
	if not bool(validation.get("ok", false)):
		return {
			"ok": false,
			"message": "Cannot create invalid loadout: %s" % _join_validation_messages(validation)
		}
	var loadout_id = _next_loadout_id()
	var display_label = label.strip_edges() if not label.strip_edges().is_empty() else "Loadout %d" % _next_loadout_number(loadout_id)
	var loadout = _make_loadout(loadout_id, display_label, deck, equipped_slots)
	loadouts.append(loadout)
	active_loadout_id = loadout_id
	return {"ok": true, "message": "Created %s." % display_label, "loadout": loadout.duplicate(true)}

func duplicate_loadout(loadout_id: String = "") -> Dictionary:
	if loadouts.size() >= MAX_LOADOUTS:
		return {"ok": false, "message": "All %d loadout slots are already in use." % MAX_LOADOUTS}
	var source_id = active_loadout_id if loadout_id.is_empty() else loadout_id
	var source = _find_loadout(source_id)
	if source.is_empty():
		return {"ok": false, "message": "Loadout not found."}
	var validation = validate_loadout(source)
	if not bool(validation.get("ok", false)):
		return {
			"ok": false,
			"message": "Cannot duplicate invalid loadout: %s" % _join_validation_messages(validation)
		}
	var new_id = _next_loadout_id()
	var new_label = "%s Copy" % str(source.get("label", "Loadout"))
	var duplicate = _make_loadout(new_id, new_label, _array_from_variant(source.get("deck", [])), _dict_from_variant(source.get("equipped_slots", {})))
	loadouts.append(duplicate)
	return {"ok": true, "message": "Duplicated %s." % str(source.get("label", "Loadout")), "loadout": duplicate.duplicate(true)}

func rename_loadout(loadout_id: String, label: String) -> Dictionary:
	var trimmed_label = label.strip_edges()
	if trimmed_label.is_empty():
		return {"ok": false, "message": "Loadout name cannot be empty."}
	var index = _find_loadout_index(loadout_id)
	if index == -1:
		return {"ok": false, "message": "Loadout not found."}
	var loadout = _dict_from_variant(loadouts[index])
	if str(loadout.get("label", "")).strip_edges() == trimmed_label:
		return {
			"ok": true,
			"message": "Loadout is already named %s." % trimmed_label,
			"loadout": loadout.duplicate(true)
		}
	loadout["label"] = trimmed_label
	loadouts[index] = loadout
	return {
		"ok": true,
		"message": "Renamed loadout to %s." % trimmed_label,
		"loadout": loadout.duplicate(true)
	}

func delete_loadout(loadout_id: String) -> Dictionary:
	if loadouts.size() <= 1:
		return {"ok": false, "message": "At least one loadout is required."}
	var index = _find_loadout_index(loadout_id)
	if index == -1:
		return {"ok": false, "message": "Loadout not found."}
	if loadout_id == DEFAULT_LOADOUT_ID:
		return {"ok": false, "message": "The default loadout cannot be deleted."}
	var deleted_label = str(loadouts[index].get("label", "Loadout"))
	loadouts.remove_at(index)
	if active_loadout_id == loadout_id:
		var fallback = _dict_from_variant(loadouts[0])
		var activation = activate_loadout(str(fallback.get("id", DEFAULT_LOADOUT_ID)))
		if not bool(activation.get("ok", false)):
			active_loadout_id = str(fallback.get("id", DEFAULT_LOADOUT_ID))
			deck = _array_from_variant(fallback.get("deck", []))
			equipped_slots = _sanitize_equipped_slots_for_loadout(_dict_from_variant(fallback.get("equipped_slots", {})))
	return {"ok": true, "message": "Deleted %s." % deleted_label}

func validate_loadout(loadout: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var candidate_deck = _array_from_variant(loadout.get("deck", []))
	var candidate_slots = _migrate_legacy_slots(_dict_from_variant(loadout.get("equipped_slots", {})))
	if candidate_deck.size() < get_minimum_deck_size():
		errors.append("Selected deck has %d cards; minimum is %d." % [
			candidate_deck.size(),
			get_minimum_deck_size()
		])

	var owned_card_counts = _count_array_ids(owned_cards)
	var selected_card_counts = _count_array_ids(candidate_deck)
	for card_id in selected_card_counts.keys():
		if GameData.get_card(str(card_id)).is_empty():
			errors.append("Unknown card: %s." % str(card_id))
		if int(selected_card_counts[card_id]) > int(owned_card_counts.get(card_id, 0)):
			errors.append("%s uses %d copies, but only %d are owned." % [
				_card_label(str(card_id)),
				int(selected_card_counts[card_id]),
				int(owned_card_counts.get(card_id, 0))
			])

	var equipped_counts := {}
	var two_slot_seen := {}
	for slot_id in SLOT_ORDER:
		var equipment_id = str(candidate_slots.get(slot_id, ""))
		if equipment_id.is_empty():
			continue
		var equip_data = GameData.get_equipment(equipment_id)
		if equip_data.is_empty():
			errors.append("Unknown equipment in %s: %s." % [slot_id, equipment_id])
			continue
		if not _valid_slots_for_equipment_data(equip_data).has(slot_id):
			errors.append("%s cannot be equipped in %s." % [_equipment_label(equipment_id), slot_id])
		if not _meets_equipment_conditions(equip_data):
			errors.append("%s requirements are not met." % _equipment_label(equipment_id))
		var slot_cost = _equipment_slot_cost(equip_data)
		if slot_cost > 1:
			if slot_id == "weapon_2" and str(candidate_slots.get("weapon_1", "")) == equipment_id:
				continue
			if slot_id != "weapon_1" or str(candidate_slots.get("weapon_2", "")) != equipment_id:
				errors.append("%s must occupy both weapon slots." % _equipment_label(equipment_id))
			if not two_slot_seen.has(equipment_id):
				equipped_counts[equipment_id] = int(equipped_counts.get(equipment_id, 0)) + 1
				two_slot_seen[equipment_id] = true
			continue
		if slot_id == "weapon_2" and _slot_blocked_in_slots(slot_id, candidate_slots):
			errors.append("%s is blocked by a two-slot weapon." % slot_id)
		equipped_counts[equipment_id] = int(equipped_counts.get(equipment_id, 0)) + 1

	for equipment_id in equipped_counts.keys():
		if int(equipped_counts[equipment_id]) > get_equipment_count(str(equipment_id)):
			errors.append("%s uses %d copies, but only %d are owned." % [
				_equipment_label(str(equipment_id)),
				int(equipped_counts[equipment_id]),
				get_equipment_count(str(equipment_id))
			])

	return {
		"ok": errors.is_empty(),
		"errors": errors
	}

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
		"loadouts": loadouts,
		"active_loadout_id": active_loadout_id,
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
	loadouts = _sanitize_loadouts(data.get("loadouts", []), {
		"deck": deck,
		"equipped_slots": equipped_slots
	})
	active_loadout_id = str(data.get("active_loadout_id", active_loadout_id))
	if _find_loadout_index(active_loadout_id) == -1:
		var fallback_loadout = _dict_from_variant(loadouts[0]) if not loadouts.is_empty() else {}
		active_loadout_id = str(fallback_loadout.get("id", DEFAULT_LOADOUT_ID)) if not fallback_loadout.is_empty() else DEFAULT_LOADOUT_ID
	var active_loadout = _find_loadout(active_loadout_id)
	if active_loadout.is_empty():
		_initialize_default_loadout()
	else:
		deck = _array_from_variant(active_loadout.get("deck", deck))
		equipped_slots = _sanitize_equipped_slots_for_loadout(_dict_from_variant(active_loadout.get("equipped_slots", equipped_slots)))

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

func get_card_keyword_entries(card_data: Dictionary) -> Array:
	var keyword_entries: Array = []
	var seen_ids := {}

	for effect in card_data.get("effects", []):
		var effect_type = str(effect.get("type", ""))
		match effect_type:
			"apply_status":
				_append_keyword_entry(keyword_entries, seen_ids, str(effect.get("statusId", "")))
			"modify_insight":
				_append_keyword_entry(keyword_entries, seen_ids, "buff_insight")
			"gain_energy":
				_append_keyword_entry(keyword_entries, seen_ids, "buff_energy")

		match str(effect.get("scaling", "none")):
			"strength":
				_append_keyword_entry(keyword_entries, seen_ids, "buff_strength")
			"dexterity":
				_append_keyword_entry(keyword_entries, seen_ids, "buff_dexterity")
			"insight":
				_append_keyword_entry(keyword_entries, seen_ids, "buff_insight")

	var lower_description = get_preview_card_text(card_data).to_lower()
	for buff_id in GameData.buffs.keys():
		var buff_data = GameData.get_buff(str(buff_id))
		var buff_name = str(buff_data.get("name", "")).to_lower()
		var short_label = str(buff_data.get("shortLabel", "")).to_lower()
		if (not buff_name.is_empty() and lower_description.find(buff_name) != -1) \
		or (not short_label.is_empty() and lower_description.find(short_label) != -1):
			_append_keyword_entry(keyword_entries, seen_ids, str(buff_id))

	return keyword_entries

func _empty_equipped_slots() -> Dictionary:
	var slots := {}
	for slot_id in SLOT_ORDER:
		slots[slot_id] = ""
	return slots

func _sanitize_equipped_slots(raw_slots: Dictionary) -> Dictionary:
	var sanitized = _empty_equipped_slots()
	var migrated_slots = _migrate_legacy_slots(raw_slots)
	var remaining_counts := {}
	for equipment_id in equipment:
		remaining_counts[equipment_id] = int(remaining_counts.get(equipment_id, 0)) + 1

	for slot_id in SLOT_ORDER:
		var equipment_id = str(migrated_slots.get(slot_id, ""))
		if equipment_id.is_empty():
			continue
		var equip_data = GameData.get_equipment(equipment_id)
		if equip_data.is_empty():
			continue
		if int(remaining_counts.get(equipment_id, 0)) <= 0:
			continue
		if not _valid_slots_for_equipment_data(equip_data).has(slot_id):
			continue
		if str(equip_data.get("type", "")) == "weapon" and _equipment_slot_cost(equip_data) > 1:
			sanitized["weapon_1"] = equipment_id
			sanitized["weapon_2"] = equipment_id
			remaining_counts[equipment_id] = int(remaining_counts.get(equipment_id, 0)) - 1
			continue
		if slot_id == "weapon_2" and _slot_blocked_in_slots(slot_id, sanitized):
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
		"weapon":
			if _equipment_slot_cost(equip_data) > 1:
				return ["weapon_1"]
			return WEAPON_SLOTS.duplicate()
		"armor":
			return ["armor"]
		"accessory":
			return ACCESSORY_SLOTS.duplicate()
	return []

func _pick_default_slot(valid_slots: Array) -> String:
	for slot_id in valid_slots:
		if str(equipped_slots.get(slot_id, "")).is_empty():
			return slot_id
	return str(valid_slots[0])

func _slot_blocked_in_slots(slot_id: String, slot_state: Dictionary) -> bool:
	if slot_id != "weapon_2":
		return false
	var weapon_1_item = str(slot_state.get("weapon_1", ""))
	var weapon_2_item = str(slot_state.get("weapon_2", ""))
	return not weapon_1_item.is_empty() and weapon_1_item == weapon_2_item and _is_two_slot_weapon_id(weapon_1_item)

func _migrate_legacy_slots(raw_slots: Dictionary) -> Dictionary:
	var migrated := {}
	for slot_id in SLOT_ORDER:
		migrated[slot_id] = str(raw_slots.get(slot_id, ""))
	if migrated["weapon_1"].is_empty():
		migrated["weapon_1"] = str(raw_slots.get("weapon_main", ""))
	if migrated["weapon_2"].is_empty():
		migrated["weapon_2"] = str(raw_slots.get("off_hand", ""))
	if migrated["accessory_1"].is_empty():
		migrated["accessory_1"] = str(raw_slots.get("ring_left", raw_slots.get("amulet", "")))
	if migrated["accessory_2"].is_empty():
		migrated["accessory_2"] = str(raw_slots.get("ring_right", ""))
	return migrated

func _equipment_slot_cost(equip_data: Dictionary) -> int:
	if str(equip_data.get("type", "")) != "weapon":
		return 1
	return clampi(int(equip_data.get("slotCost", 1)), 1, 2)

func _is_two_slot_weapon_id(equipment_id: String) -> bool:
	if equipment_id.is_empty():
		return false
	return _equipment_slot_cost(GameData.get_equipment(equipment_id)) > 1

func _clear_weapon_slots_if_two_slot_equipped() -> void:
	var weapon_1_item = get_slot_item("weapon_1")
	var weapon_2_item = get_slot_item("weapon_2")
	if not weapon_1_item.is_empty() and weapon_1_item == weapon_2_item and _is_two_slot_weapon_id(weapon_1_item):
		equipped_slots["weapon_1"] = ""
		equipped_slots["weapon_2"] = ""

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

func _append_keyword_entry(target: Array, seen_ids: Dictionary, buff_id: String) -> void:
	if buff_id.is_empty() or seen_ids.has(buff_id):
		return
	var buff_data = GameData.get_buff(buff_id)
	if buff_data.is_empty():
		return
	target.append({
		"id": buff_id,
		"name": str(buff_data.get("name", buff_id)),
		"shortLabel": str(buff_data.get("shortLabel", "")),
		"reminderText": str(buff_data.get("reminderText", ""))
	})
	seen_ids[buff_id] = true

func _initialize_default_loadout() -> void:
	loadouts = [_make_loadout(DEFAULT_LOADOUT_ID, "Default", deck, equipped_slots)]
	active_loadout_id = DEFAULT_LOADOUT_ID

func _make_loadout(id: String, label: String, selected_deck: Array, slots: Dictionary) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"deck": selected_deck.duplicate(),
		"equipped_slots": _normalize_loadout_slots(slots)
	}

func _sanitize_loadouts(raw_loadouts: Variant, legacy_data: Dictionary) -> Array:
	var sanitized: Array = []
	if raw_loadouts is Array:
		for raw_loadout in raw_loadouts:
			if not (raw_loadout is Dictionary):
				continue
			var raw_dict = raw_loadout as Dictionary
			var raw_id = str(raw_dict.get("id", ""))
			if raw_id.is_empty() or _loadout_id_exists_in(raw_id, sanitized):
				raw_id = _next_loadout_id_for(sanitized)
			var raw_label = str(raw_dict.get("label", raw_id)).strip_edges()
			if raw_label.is_empty():
				raw_label = "Loadout %d" % _next_loadout_number(raw_id)
			sanitized.append(_make_loadout(
				raw_id,
				raw_label,
				_array_from_variant(raw_dict.get("deck", [])),
				_dict_from_variant(raw_dict.get("equipped_slots", {}))
			))
			if sanitized.size() >= MAX_LOADOUTS:
				break

	if sanitized.is_empty():
		var legacy_deck = legacy_data.get("deck", deck)
		var legacy_slots = legacy_data.get("equipped_slots", equipped_slots)
		sanitized.append(_make_loadout(DEFAULT_LOADOUT_ID, "Default", _array_from_variant(legacy_deck), _dict_from_variant(legacy_slots)))

	return sanitized

func _sanitize_equipped_slots_for_loadout(raw_slots: Dictionary) -> Dictionary:
	var previous_slots = equipped_slots
	equipped_slots = _empty_equipped_slots()
	var sanitized = _sanitize_equipped_slots(raw_slots)
	equipped_slots = previous_slots
	return sanitized

func _normalize_loadout_slots(raw_slots: Dictionary) -> Dictionary:
	return _migrate_legacy_slots(raw_slots)

func _sync_active_loadout_from_current() -> void:
	var index = _find_loadout_index(active_loadout_id)
	if index == -1:
		if loadouts.is_empty():
			_initialize_default_loadout()
		return
	var loadout = _dict_from_variant(loadouts[index])
	loadout["deck"] = deck.duplicate()
	loadout["equipped_slots"] = equipped_slots.duplicate(true)
	loadouts[index] = loadout

func _find_loadout(loadout_id: String) -> Dictionary:
	var index = _find_loadout_index(loadout_id)
	if index == -1:
		return {}
	return loadouts[index] as Dictionary

func _find_loadout_index(loadout_id: String) -> int:
	for i in range(loadouts.size()):
		var loadout = _dict_from_variant(loadouts[i])
		if str(loadout.get("id", "")) == loadout_id:
			return i
	return -1

func _next_loadout_id() -> String:
	return _next_loadout_id_for(loadouts)

func _next_loadout_id_for(existing_loadouts: Array) -> String:
	for i in range(1, MAX_LOADOUTS + 1):
		var candidate = "loadout_%d" % i
		if not _loadout_id_exists_in(candidate, existing_loadouts):
			return candidate
	return "loadout_%d" % (existing_loadouts.size() + 1)

func _loadout_id_exists_in(loadout_id: String, existing_loadouts: Array) -> bool:
	for loadout in existing_loadouts:
		if loadout is Dictionary and str(loadout.get("id", "")) == loadout_id:
			return true
	return false

func _next_loadout_number(loadout_id: String) -> int:
	var parts = loadout_id.split("_")
	if parts.size() > 1 and parts[parts.size() - 1].is_valid_int():
		return int(parts[parts.size() - 1])
	return loadouts.size() + 1

func _count_array_ids(items: Array) -> Dictionary:
	var counts := {}
	for item_id in items:
		counts[item_id] = int(counts.get(item_id, 0)) + 1
	return counts

func _array_from_variant(value: Variant) -> Array:
	return value.duplicate() if value is Array else []

func _dict_from_variant(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _join_validation_messages(validation: Dictionary) -> String:
	var errors = _array_from_variant(validation.get("errors", []))
	if errors.is_empty():
		return "Unknown validation error."
	return " ".join(errors)

func _card_label(card_id: String) -> String:
	var card_data = GameData.get_card(card_id)
	return str(card_data.get("name", card_id))

func _equipment_label(equipment_id: String) -> String:
	var equip_data = GameData.get_equipment(equipment_id)
	return str(equip_data.get("name", equipment_id))
