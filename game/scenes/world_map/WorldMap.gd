extends Node2D

var map_data: Dictionary = {}
var map_node_scene = preload("res://scenes/world_map/MapNode.tscn")

func _ready() -> void:
	if GameState.current_map_id == "":
		push_error("No current map ID set.")
		return
		
	map_data = GameData.get_map(GameState.current_map_id)
	if map_data.is_empty():
		push_error("Map not found: " + GameState.current_map_id)
		return
		
	# Try to load background
	var bg_path = map_data.get("backgroundImage", "")
	if bg_path != "":
		var full_path = bg_path
		if not full_path.begins_with("res://"):
			full_path = "res://" + full_path
		var tex = load(full_path)
		if tex:
			$Background.texture = tex
			$Background.size = tex.get_size()
		else:
			print("Could not load background image: ", bg_path)
			
	_build_map()

func _build_map() -> void:
	var nodes_container = $Nodes
	var connections_container = $Connections
	
	var node_lookup = {}
	
	# Instantiate nodes
	var nodes_list = map_data.get("nodes", [])
	for n in nodes_list:
		var instance = map_node_scene.instantiate()
		nodes_container.add_child(instance)
		instance.setup(n)
		node_lookup[n.get("id")] = instance
		
	# Draw connections
	var connections_list = map_data.get("connections", [])
	for conn in connections_list:
		var from_id = conn.get("fromNodeId")
		var to_id = conn.get("toNodeId")
		var conditions = conn.get("conditions", [])
		var gate_type = conn.get("gateType", "none")
		
		if not node_lookup.has(from_id) or not node_lookup.has(to_id):
			continue
			
		var from_node = node_lookup[from_id]
		var to_node = node_lookup[to_id]
		
		# Check conditions
		var is_unlocked = ConditionEvaluator.evaluate_all(conditions)
		
		if gate_type == "hard" and not is_unlocked:
			continue # Hidden entirely
			
		var line = Line2D.new()
		line.add_point(from_node.position + from_node.custom_minimum_size / 2.0)
		line.add_point(to_node.position + to_node.custom_minimum_size / 2.0)
		line.width = 4.0
		
		if is_unlocked:
			line.default_color = Color(1, 1, 1, 0.8)
		elif gate_type == "soft":
			line.default_color = Color(0.3, 0.3, 0.3, 0.5)
			# Maybe draw dashes if possible, but Godot Line2D dashed needs texture
			
		connections_container.add_child(line)

	# Ensure lines are drawn behind nodes
	move_child($Connections, 1)
	move_child($Nodes, 2)
