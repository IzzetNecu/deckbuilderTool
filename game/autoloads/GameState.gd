extends Node

# Persistent player data
var health: int = 50
var max_health: int = 50
var strength: int = 0
var dexterity: int = 0
var max_energy: int = 3
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

func save() -> void:
	pass # To be implemented in Phase 6

func load() -> void:
	pass # To be implemented in Phase 6

func initialize_flags() -> void:
	flags.clear()
	for flag_id in GameData.flags:
		var f = GameData.flags[flag_id]
		flags[f.name] = f.get("defaultValue", false)
