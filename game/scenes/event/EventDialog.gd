extends Control

@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var desc_label = $Panel/VBoxContainer/DescLabel
@onready var options_container = $Panel/VBoxContainer/ScrollContainer/OptionsContainer

var event_data: Dictionary = {}

func _ready() -> void:
	# Make background semi-transparent and pretty
	$ColorRect.color = Color(0, 0, 0, 0.4) # Less dimming of background
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.85) # Transparent dark panel
	style.set_corner_radius_all(12)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.4, 0.4, 0.5)
	$Panel.add_theme_stylebox_override("panel", style)

	if SceneManager.current_event_id != "":
		load_event(SceneManager.current_event_id)

func load_event(event_id: String) -> void:
	# Determine if it's a node event or standard event
	if event_id.begins_with("NODE_"):
		var actual_node_id = event_id.trim_prefix("NODE_")
		event_data = _find_node_data(actual_node_id)
		title_label.text = event_data.get("label", "Unknown Location")
	else:
		event_data = GameData.events.get(event_id, {})
		title_label.text = event_data.get("name", "Unknown Event")
		
	desc_label.text = event_data.get("description", "")
	
	_populate_options(event_data.get("options", []))

func _find_node_data(node_id: String) -> Dictionary:
	for map_id in GameData.maps.keys():
		var map = GameData.maps[map_id]
		for node in map.get("nodes", []):
			if node.get("id") == node_id:
				return node
	return {}

func _populate_options(options: Array) -> void:
	# Clear existing
	for child in options_container.get_children():
		child.queue_free()
		
	if options.size() == 0:
		# Add a default leave button
		var btn = Button.new()
		btn.text = "Leave"
		btn.pressed.connect(_on_leave_pressed)
		options_container.add_child(btn)
		return
		
	for i in range(options.size()):
		var opt = options[i]
		
		# Check conditions
		var conditions = opt.get("conditions", [])
		var can_select = true
		for cond in conditions:
			if not ConditionEvaluator.evaluate_one(cond):
				can_select = false
				break
				
		var btn = Button.new()
		btn.text = opt.get("text", "Option")
		if not can_select:
			if opt.get("lockType", "soft") == "hard":
				btn.queue_free()
				continue
			btn.disabled = true
			btn.text += " (Locked)"
			
		btn.pressed.connect(_on_option_pressed.bind(opt.get("outcomes", [])))
		options_container.add_child(btn)

func _on_option_pressed(outcomes: Array) -> void:
	OutcomeExecutor.execute_all(outcomes)
	
	# Transition back to map by default unless scene changed
	var changed_scene = false
	for out in outcomes:
		if out.get("type") in ["travelToMap", "startCombat", "startEvent"]:
			changed_scene = true
			break
			
	if not changed_scene:
		SceneManager.load_map(GameState.current_map_id)

func _on_leave_pressed() -> void:
	SceneManager.load_map(GameState.current_map_id)
