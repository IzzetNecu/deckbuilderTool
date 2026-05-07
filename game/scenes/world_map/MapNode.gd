extends Button

var node_data: Dictionary = {}

func setup(data: Dictionary) -> void:
	node_data = data
	var label_text = data.get("label", "")
	$Label.text = label_text
	$Label.visible = label_text != ""
	position = Vector2(data.get("x", 0), data.get("y", 0)) - custom_minimum_size / 2.0
	
	# Determine state based on visited status
	if GameState.current_node_id == data.get("id", ""):
		modulate = Color(0, 1, 0) # Current node is green
	elif GameState.visited_nodes.has(data.get("id", "")):
		modulate = Color(0.5, 0.5, 1.0) # Visited nodes are blue
	else:
		modulate = Color(1, 1, 1)

func _node_has_content(data: Dictionary) -> bool:
	# Only show the dialog if there is at least one option visible to the player.
	# A description alone is not enough — the player just passes through silently.
	for opt in data.get("options", []):
		var conditions_pass = ConditionEvaluator.evaluate_all(opt.get("conditions", []))
		# Soft-locked options are still visible (shown as disabled), so they count
		if conditions_pass or opt.get("lockType", "soft") == "soft":
			return true
	return false

func _pressed() -> void:
	# Already on this node — open its event only if it has content
	if GameState.current_node_id == node_data.get("id", ""):
		if _node_has_content(node_data):
			SceneManager.start_event("NODE_" + GameState.current_node_id)
		return
		
	# Check if this node is connected to the current node
	var map_data = GameData.get_map(GameState.current_map_id)
	var connections = map_data.get("connections", [])
	var can_travel = false
	
	for conn in connections:
		var from_id = conn.get("fromNodeId")
		var to_id = conn.get("toNodeId")
		var target_id = node_data.get("id")
		
		if (from_id == GameState.current_node_id and to_id == target_id) or \
		   (to_id == GameState.current_node_id and from_id == target_id):
			if ConditionEvaluator.evaluate_all(conn.get("conditions", [])):
				can_travel = true
				break
	
	if can_travel:
		GameState.current_node_id = node_data.get("id", "")
		if not GameState.visited_nodes.has(GameState.current_node_id):
			GameState.visited_nodes.append(GameState.current_node_id)
		
		GameState.map_updated.emit()
		# Only open the event dialog if this node has something to show
		if _node_has_content(node_data):
			SceneManager.start_event("NODE_" + GameState.current_node_id)
	else:
		print("Cannot travel: Not connected or locked.")
