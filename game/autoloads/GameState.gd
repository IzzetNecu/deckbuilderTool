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

func get_stat(stat_name: String) -> int:
	if stat_name in self:
		return get(stat_name)
	return 0

func has_consumable(id: String) -> bool:
	return id in consumables

func has_equipment(id: String) -> bool:
	return id in equipment

func has_key_item(id: String) -> bool:
	return id in key_items

func add_consumable(id: String) -> void:
	consumables.append(id)

func remove_consumable(id: String) -> void:
	if id in consumables:
		consumables.erase(id)

func add_equipment(id: String) -> void:
	if not has_equipment(id):
		equipment.append(id)
		# Add associated cards
		var equip_data = GameData.get_equipment(id)
		if equip_data.has("cardIds"):
			for card_id in equip_data.cardIds:
				deck.append(card_id)

func remove_equipment(id: String) -> void:
	if has_equipment(id):
		equipment.erase(id)
		# Remove associated cards
		var equip_data = GameData.get_equipment(id)
		if equip_data.has("cardIds"):
			for card_id in equip_data.cardIds:
				var idx = deck.find(card_id)
				if idx != -1:
					deck.remove_at(idx)

func add_key_item(id: String) -> void:
	if not has_key_item(id):
		key_items.append(id)

func remove_key_item(id: String) -> void:
	if has_key_item(id):
		key_items.erase(id)

func save() -> void:
	pass # To be implemented in Phase 6

func load() -> void:
	pass # To be implemented in Phase 6
