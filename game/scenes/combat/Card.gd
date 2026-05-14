extends Panel

var card_data: Dictionary = {}
var combat_manager: Node = null
var enemy_unit: Node = null

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO
var original_parent: Node = null

@onready var name_label: Label = $VBox/NameLabel
@onready var cost_label: Label = $VBox/CostLabel
@onready var effects_label: Label = $VBox/EffectsLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	$VBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(data: Dictionary, mgr: Node, enemy: Node) -> void:
	card_data = data
	combat_manager = mgr
	enemy_unit = enemy

	name_label.text = data.get("name", "?")
	cost_label.text = "Cost: %d" % data.get("cost", 0)
	effects_label.text = combat_manager.get_card_text(data, "player")

func _is_targeted() -> bool:
	return str(card_data.get("targeting", "self")) == "single_enemy"

func _can_afford() -> bool:
	if not combat_manager:
		return false
	return combat_manager.player_energy >= card_data.get("cost", 0) and combat_manager.current_phase == CombatManager.Phase.PLAY

func _gui_input(event: InputEvent) -> void:
	if not _can_afford():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event.global_position)
				accept_event()

func _input(event: InputEvent) -> void:
	if not is_dragging:
		return

	if event is InputEventMouseMotion:
		global_position = event.global_position + drag_offset
		_check_hover(event.global_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release_drag(event.global_position)

func _start_drag(global_pos: Vector2) -> void:
	is_dragging = true
	original_position = global_position
	original_parent = get_parent()
	drag_offset = global_position - global_pos

	var canvas = get_tree().current_scene
	original_parent.remove_child(self)
	canvas.add_child(self)
	global_position = original_position

func _release_drag(global_pos: Vector2) -> void:
	if not is_dragging:
		return
	is_dragging = false

	var played = false
	if _is_targeted():
		if enemy_unit and _is_over_node(enemy_unit, global_pos):
			played = combat_manager.play_card(card_data, "enemy")
	else:
		var hand_area = get_tree().current_scene.get_node_or_null("HandArea")
		var over_hand = hand_area and _is_over_node(hand_area, global_pos)
		if not over_hand:
			played = combat_manager.play_card(card_data, "self")

	if played:
		queue_free()
	else:
		_snap_back()

	if enemy_unit:
		enemy_unit.set_highlight(false)

func _check_hover(global_pos: Vector2) -> void:
	if enemy_unit and _is_targeted():
		enemy_unit.set_highlight(_is_over_node(enemy_unit, global_pos))

func _snap_back() -> void:
	get_parent().remove_child(self)
	original_parent.add_child(self)
	position = Vector2.ZERO

func _is_over_node(target_node: Control, global_pos: Vector2) -> bool:
	var rect = Rect2(target_node.global_position, target_node.size)
	return rect.has_point(global_pos)
