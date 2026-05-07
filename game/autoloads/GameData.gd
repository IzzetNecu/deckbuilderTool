extends Node

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

func _ready() -> void:
	load_data("res://data/game_data.json")

func load_data(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Could not open game data file: " + path)
		return
		
	var json_str = file.get_as_text()
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		push_error("JSON Parse Error: ", json.get_error_message(), " in ", json_str, " at line ", json.get_error_line())
		return
		
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("JSON data is not a dictionary.")
		return
		
	_index_collection(data.get("factions", []), factions)
	_index_collection(data.get("cards", []), cards)
	_index_collection(data.get("consumables", []), consumables)
	_index_collection(data.get("equipment", []), equipment)
	_index_collection(data.get("keyItems", []), key_items)
	_index_collection(data.get("enemies", []), enemies)
	_index_collection(data.get("events", []), events)
	_index_collection(data.get("deckTemplates", []), deck_templates)
	_index_collection(data.get("maps", []), maps)
	_index_collection(data.get("flags", []), flags)

func _index_collection(arr: Array, target_dict: Dictionary) -> void:
	target_dict.clear()
	for item in arr:
		if typeof(item) == TYPE_DICTIONARY and item.has("id"):
			target_dict[item.id] = item

# Helper getters
func get_card(id: String) -> Dictionary: return cards.get(id, {})
func get_enemy(id: String) -> Dictionary: return enemies.get(id, {})
func get_event(id: String) -> Dictionary: return events.get(id, {})
func get_map(id: String) -> Dictionary: return maps.get(id, {})
func get_consumable(id: String) -> Dictionary: return consumables.get(id, {})
func get_equipment(id: String) -> Dictionary: return equipment.get(id, {})
func get_key_item(id: String) -> Dictionary: return key_items.get(id, {})
func get_faction(id: String) -> Dictionary: return factions.get(id, {})
