extends Panel

var card_data: Dictionary = {}
var combat_manager: Node = null
var enemy_unit: Node = null

var is_dragging: bool = false
var is_zoomed: bool = false
var pending_click: bool = false
var press_position: Vector2 = Vector2.ZERO
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO
var original_parent: Node = null
var original_index: int = -1
var original_scale: Vector2 = Vector2.ONE

const DRAG_THRESHOLD := 14.0
const ZOOM_SCALE := Vector2(2.2, 2.2)

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
	var refresh_callable = Callable(self, "refresh_display")
	if combat_manager and not combat_manager.stats_updated.is_connected(refresh_callable):
		combat_manager.stats_updated.connect(refresh_callable)

	name_label.text = data.get("name", "?")
	cost_label.text = "Cost: %d" % data.get("cost", 0)
	refresh_display()

func refresh_display() -> void:
	effects_label.text = _get_effects_text()

func _get_effects_text() -> String:
	if combat_manager:
		return combat_manager.get_card_text(card_data, "player", is_zoomed)
	return GameState.get_preview_card_text(card_data)

func _is_targeted() -> bool:
	return str(card_data.get("targeting", "self")) == "single_enemy"

func _can_afford() -> bool:
	if not combat_manager:
		return false
	return combat_manager.player_energy >= card_data.get("cost", 0) and combat_manager.current_phase == CombatManager.Phase.PLAY

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pending_click = true
				press_position = event.global_position
				accept_event()
			else:
				if is_dragging:
					_release_drag(event.global_position)
				elif pending_click:
					pending_click = false
					_toggle_zoom()
					accept_event()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if pending_click and not is_dragging and _can_afford():
			if event.global_position.distance_to(press_position) >= DRAG_THRESHOLD:
				pending_click = false
				if is_zoomed:
					_collapse_zoom()
				_start_drag(press_position)
				global_position = event.global_position + drag_offset
				_check_hover(event.global_position)
		elif is_dragging:
			global_position = event.global_position + drag_offset
			_check_hover(event.global_position)

func _start_drag(global_pos: Vector2) -> void:
	is_dragging = true
	original_position = global_position
	original_parent = get_parent()
	original_index = get_index()
	original_scale = scale
	drag_offset = global_position - global_pos

	var canvas = get_tree().current_scene
	original_parent.remove_child(self)
	canvas.add_child(self)
	global_position = original_position

func _release_drag(global_pos: Vector2) -> void:
	if not is_dragging:
		return
	is_dragging = false
	pending_click = false

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
	if original_index >= 0:
		original_parent.move_child(self, mini(original_index, original_parent.get_child_count() - 1))
	scale = original_scale
	position = Vector2.ZERO
	refresh_display()

func _toggle_zoom() -> void:
	if is_dragging:
		return
	if is_zoomed:
		_collapse_zoom()
	else:
		_expand_zoom()

func _expand_zoom() -> void:
	if is_zoomed:
		return
	is_zoomed = true
	original_parent = get_parent()
	original_index = get_index()
	original_position = global_position
	original_scale = scale
	var canvas = get_tree().current_scene
	original_parent.remove_child(self)
	canvas.add_child(self)
	scale = ZOOM_SCALE
	z_index = 200
	global_position = _get_zoom_position()
	refresh_display()

func _collapse_zoom() -> void:
	if not is_zoomed:
		return
	is_zoomed = false
	if get_parent():
		get_parent().remove_child(self)
	original_parent.add_child(self)
	if original_index >= 0:
		original_parent.move_child(self, mini(original_index, original_parent.get_child_count() - 1))
	scale = original_scale
	z_index = 0
	position = Vector2.ZERO
	refresh_display()

func _get_zoom_position() -> Vector2:
	var viewport_rect = get_viewport_rect()
	var scaled_size = size * ZOOM_SCALE
	return (viewport_rect.size - scaled_size) * 0.5

func _is_over_node(target_node: Control, global_pos: Vector2) -> bool:
	var rect = Rect2(target_node.global_position, target_node.size)
	return rect.has_point(global_pos)
