extends Node

# A central place to manage transitions between scenes

func load_map(map_id: String) -> void:
	print("SceneManager: Loading Map ID: ", map_id)
	GameState.current_map_id = map_id
	var err = get_tree().change_scene_to_file("res://scenes/world_map/WorldMap.tscn")
	if err != OK:
		push_error("Failed to load WorldMap scene.")

func start_combat(enemy_id: String) -> void:
	print("SceneManager: Starting Combat with Enemy ID: ", enemy_id)
	# TODO: load CombatScene.tscn and pass enemy_id

func start_event(event_id: String) -> void:
	print("SceneManager: Starting Event ID: ", event_id)
	# TODO: load EventDialog.tscn and pass event_id

func show_text(text: String) -> void:
	print("SceneManager: Showing Text: ", text)
	# TODO: overlay a message box
