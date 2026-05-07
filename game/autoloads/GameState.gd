extends Node

signal map_updated

# Persistent player data
var health: int = 20
var max_health: int = 20
var strength: int = 1
var dexterity: int = 1
var max_energy: int = 2
var gold: int = 0
var hand_size: int = 5

var deck: Array = []           # Array of card ids (String)
var consumables: Array = []    # Array of consumable ids (String)
var equipment: Array = []      # Array of equipment ids (String)
var key_items: Array = []      # Array of key item ids (String)

var current_map_id: String = ""
var current_node_id: String = ""
var visited_nodes: Array = []
var flags: Dictionary = {}

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
		if item == id: count += 1
	return count

func get_equipment_count(id: String) -> int:
	var count = 0
	for item in equipment:
		if item == id: count += 1
	return count

func get_key_item_count(id: String) -> int:
	var count = 0
	for item in key_items:
		if item == id: count += 1
	return count

func has_consumable(id: String) -> bool:
	return get_consumable_count(id) > 0

func has_equipment(id: String) -> bool:
	return get_equipment_count(id) > 0

func has_key_item(id: String) -> bool:
	return get_key_item_count(id) > 0

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
		if not has_equipment(id):
			# If we want to allow multiple identical equipment, we remove the `if not`
			# But typically equipment is unique. We'll allow multiples if requested:
			pass
		equipment.append(id)
		# Add associated cards
		var equip_data = GameData.get_equipment(id)
		if equip_data.has("cardIds"):
			for card_id in equip_data.cardIds:
				deck.append(card_id)

func remove_equipment(id: String, amount: int = 1) -> void:
	var removed = 0
	for i in range(equipment.size() - 1, -1, -1):
		if equipment[i] == id:
			equipment.remove_at(i)
			# Remove associated cards
			var equip_data = GameData.get_equipment(id)
			if equip_data.has("cardIds"):
				for card_id in equip_data.cardIds:
					var idx = deck.find(card_id)
					if idx != -1:
						deck.remove_at(idx)
			removed += 1
			if removed >= amount:
				break

func add_key_item(id: String, amount: int = 1) -> void:
	for i in range(amount):
		if not has_key_item(id):
			key_items.append(id)

func remove_key_item(id: String, amount: int = 1) -> void:
	var removed = 0
	for i in range(key_items.size() - 1, -1, -1):
		if key_items[i] == id:
			key_items.remove_at(i)
			removed += 1
			if removed >= amount:
				break

const SAVE_PATH = "user://savegame.json"

func save() -> void:
	var save_data = {
		"health": health,
		"max_health": max_health,
		"strength": strength,
		"dexterity": dexterity,
		"max_energy": max_energy,
		"gold": gold,
		"hand_size": hand_size,
		"deck": deck,
		"consumables": consumables,
		"equipment": equipment,
		"key_items": key_items,
		"current_map_id": current_map_id,
		"current_node_id": current_node_id,
		"visited_nodes": visited_nodes,
		"flags": flags
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data)
		file.store_string(json_string)
		print("GameState: Saved successfully to ", SAVE_PATH)

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("GameState: No save file found.")
		return false
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("GameState: Failed to parse save file.")
		return false
		
	var data = json.data
	health = data.get("health", health)
	max_health = data.get("max_health", max_health)
	strength = data.get("strength", strength)
	dexterity = data.get("dexterity", dexterity)
	max_energy = data.get("max_energy", max_energy)
	gold = data.get("gold", gold)
	hand_size = data.get("hand_size", hand_size)
	deck = data.get("deck", deck)
	consumables = data.get("consumables", consumables)
	equipment = data.get("equipment", equipment)
	key_items = data.get("key_items", key_items)
	current_map_id = data.get("current_map_id", current_map_id)
	current_node_id = data.get("current_node_id", current_node_id)
	visited_nodes = data.get("visited_nodes", visited_nodes)
	flags = data.get("flags", flags)
	
	print("GameState: Loaded successfully from ", SAVE_PATH)
	return true

func initialize_flags() -> void:
	flags.clear()
	for flag_id in GameData.flags:
		var f = GameData.flags[flag_id]
		flags[f.name] = f.get("defaultValue", false)
