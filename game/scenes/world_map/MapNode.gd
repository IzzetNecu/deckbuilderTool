extends Button

var node_data: Dictionary = {}

func setup(data: Dictionary) -> void:
	node_data = data
	$Label.text = data.get("label", "Unknown")
	position = Vector2(data.get("x", 0), data.get("y", 0)) - custom_minimum_size / 2.0
	
	# Determine state based on visited status
	if GameState.current_node_id == data.get("id", ""):
		modulate = Color(0, 1, 0) # Current node is green
	elif GameState.visited_nodes.has(data.get("id", "")):
		modulate = Color(0.5, 0.5, 1.0) # Visited nodes are blue
	else:
		modulate = Color(1, 1, 1)

func _pressed() -> void:
	if GameState.current_node_id == node_data.get("id", ""):
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
		SceneManager.start_event("NODE_" + GameState.current_node_id)
	else:
		print("Cannot travel: Not connected or locked.")
