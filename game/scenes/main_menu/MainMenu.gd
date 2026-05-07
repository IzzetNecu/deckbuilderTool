extends Control

func _ready() -> void:
	$CenterContainer/VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$CenterContainer/VBoxContainer/ContinueButton.pressed.connect(_on_continue_pressed)
	
	# Show/Hide continue button
	if not FileAccess.file_exists(GameState.SAVE_PATH):
		$CenterContainer/VBoxContainer/ContinueButton.hide()

func _on_continue_pressed() -> void:
	if GameState.load_game():
		if GameState.current_map_id != "":
			SceneManager.load_map(GameState.current_map_id)
		else:
			_on_start_pressed() # Fallback if save is corrupted or map missing

func _on_start_pressed() -> void:
	print("Start Game Pressed")
	# Initialize GameState
	GameState.health = GameState.max_health
	GameState.initialize_flags()
	
	# Find first overworld map or something?
	# We can just start on a hardcoded map or check GameData.maps
	var first_map = ""
	for map_id in GameData.maps:
		if GameData.maps[map_id].get("isOverworld", false):
			first_map = map_id
			break
	
	if first_map != "":
		SceneManager.load_map(first_map)
	else:
		push_error("No overworld map found to start.")
