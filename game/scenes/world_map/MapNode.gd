extends Button

var node_data: Dictionary = {}

func setup(data: Dictionary) -> void:
	node_data = data
	$Label.text = data.get("label", "Unknown")
	position = Vector2(data.get("x", 0), data.get("y", 0)) - size / 2.0
	
	# Determine state based on visited status
	if GameState.current_node_id == data.get("id", ""):
		modulate = Color(0, 1, 0) # Current node is green
	elif GameState.visited_nodes.has(data.get("id", "")):
		modulate = Color(0.5, 0.5, 1.0) # Visited nodes are blue
	else:
		modulate = Color(1, 1, 1)

func _pressed() -> void:
	# In a real setup, we'd only allow clicking if it's connected to current_node
	# and conditions are met. For now, let's just trigger it.
	print("Clicked node: ", node_data.get("label", ""))
	GameState.current_node_id = node_data.get("id", "")
	if not GameState.visited_nodes.has(GameState.current_node_id):
		GameState.visited_nodes.append(GameState.current_node_id)
		
	# Trigger the event dialog for this node
	# Wait, node options are the same structure as an event.
	# We can just pass the node data as if it were an event to the EventDialog
	SceneManager.start_event("NODE_" + GameState.current_node_id)
