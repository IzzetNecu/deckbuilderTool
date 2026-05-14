extends Node

signal map_updated

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

var deck: Array = []
var consumables: Array = []
var equipment: Array = []
var key_items: Array = []

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
	var inventory = player.get("startingInventory", {})
	consumables = inventory.get("consumables", []).duplicate()
	equipment = inventory.get("equipment", []).duplicate()
	key_items = inventory.get("keyItems", []).duplicate()
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
		equipment.append(id)
		var equip_data = GameData.get_equipment(id)
		for card_id in equip_data.get("cardIds", []):
			deck.append(card_id)

func remove_equipment(id: String, amount: int = 1) -> void:
	var removed = 0
	for i in range(equipment.size() - 1, -1, -1):
		if equipment[i] == id:
			equipment.remove_at(i)
			var equip_data = GameData.get_equipment(id)
			for card_id in equip_data.get("cardIds", []):
				var idx = deck.find(card_id)
				if idx != -1:
					deck.remove_at(idx)
			removed += 1
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
	deck = data.get("deck", deck)
	consumables = data.get("consumables", consumables)
	equipment = data.get("equipment", equipment)
	key_items = data.get("key_items", key_items)
	current_map_id = str(data.get("current_map_id", current_map_id))
	current_node_id = str(data.get("current_node_id", current_node_id))
	visited_nodes = data.get("visited_nodes", visited_nodes)
	flags = data.get("flags", flags)

	print("GameState: Loaded successfully from ", SAVE_PATH)
	return true

func initialize_flags() -> void:
	flags.clear()
	for flag_id in GameData.flags:
		var flag = GameData.flags[flag_id]
		flags[str(flag.get("name", flag_id))] = flag.get("defaultValue", false)
