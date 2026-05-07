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
	current_enemy_id = enemy_id
	var err = get_tree().change_scene_to_file("res://scenes/combat/CombatScene.tscn")
	if err != OK:
		push_error("Failed to load CombatScene.")

var current_event_id: String = ""
var current_enemy_id: String = ""

func start_event(event_id: String) -> void:
	print("SceneManager: Starting Event ID: ", event_id)
	current_event_id = event_id
	var event_scene = preload("res://scenes/event/EventDialog.tscn").instantiate()
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.add_child(event_scene)
	get_tree().current_scene.add_child(canvas_layer)
func show_text(text: String) -> void:
	print("SceneManager: Showing Text: ", text)
	# TODO: overlay a message box
