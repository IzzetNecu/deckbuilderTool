extends Control

func _ready() -> void:
	$CenterContainer/VBoxContainer/StartButton.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	print("Start Game Pressed")
	# Initialize GameState
	GameState.health = GameState.max_health
	
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
