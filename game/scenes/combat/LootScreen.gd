extends Control

@onready var loot_list: VBoxContainer = $Panel/VBox/LootList
@onready var continue_btn: Button = $Panel/VBox/ContinueButton

func _ready() -> void:
	continue_btn.pressed.connect(_on_continue)

func setup(loot_table: Array) -> void:
	for child in loot_list.get_children():
		child.queue_free()

	var header = Label.new()
	header.text = "Victory! You found:"
	header.add_theme_font_size_override("font_size", 18)
	loot_list.add_child(header)

	var got_anything = false
	for entry in loot_table:
		var chance = entry.get("chance", 0.0)
		if randf() <= chance:
			got_anything = true
			var type = entry.get("type", "")
			var id = entry.get("id", "")
			# Apply the loot via OutcomeExecutor
			var outcome = { "type": "add" + _capitalize(type), "target": id, "value": "1" }
			OutcomeExecutor.execute_one(outcome)
			# Show label
			var lbl = Label.new()
			lbl.text = "• %s: %s" % [type, _resolve_name(type, id)]
			loot_list.add_child(lbl)

	if not got_anything:
		var lbl = Label.new()
		lbl.text = "Nothing this time..."
		lbl.modulate = Color(0.6, 0.6, 0.6)
		loot_list.add_child(lbl)

func _capitalize(s: String) -> String:
	if s.is_empty():
		return s
	return s[0].to_upper() + s.substr(1)

func _resolve_name(type: String, id: String) -> String:
	match type:
		"consumable": return GameData.get_consumable(id).get("name", id)
		"equipment":  return GameData.get_equipment(id).get("name", id)
		"keyItem":    return GameData.get_key_item(id).get("name", id)
		"card":       return GameData.get_card(id).get("name", id)
	return id

func _on_continue() -> void:
	SceneManager.load_map(GameState.current_map_id)
