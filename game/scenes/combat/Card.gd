extends Panel
class_name CombatCard

signal preview_requested(card_data: Dictionary)
var card_data: Dictionary = {}
var combat_manager: Node = null
var enemy_unit: Node = null
var source_side: String = "player"
var allow_drag_play: bool = true

var is_dragging: bool = false
var is_zoomed: bool = false
var preview_only: bool = false
var pending_click: bool = false
var press_position: Vector2 = Vector2.ZERO
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO
var original_parent: Node = null
var original_index: int = -1
var original_scale: Vector2 = Vector2.ONE

const DRAG_THRESHOLD := 14.0
const NAME_FONT_SIZE_MAX := 15
const NAME_FONT_SIZE_MIN := 9

@onready var name_label: Label = $Margin/VBox/Header/NameLabel
@onready var cost_label: Label = $Margin/VBox/Header/CostBadge/CostLabel
@onready var art_texture: TextureRect = $Margin/VBox/ArtFrame/ArtTexture
@onready var art_fallback: Label = $Margin/VBox/ArtFrame/ArtFallback
@onready var type_label: Label = $Margin/VBox/TypeBadge/TypeLabel
@onready var effects_label: Label = $Margin/VBox/EffectsLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	$Margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/Header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/Header/CostBadge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/ArtFrame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/TypeBadge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_fit_name_to_single_line)
	_apply_card_content()

func setup(data: Dictionary, mgr: Node, enemy: Node, card_source_side: String = "player", can_drag_play: bool = true) -> void:
	card_data = data
	combat_manager = mgr
	enemy_unit = enemy
	source_side = card_source_side
	allow_drag_play = can_drag_play
	var refresh_callable = Callable(self, "refresh_display")
	if combat_manager and not combat_manager.stats_updated.is_connected(refresh_callable):
		combat_manager.stats_updated.connect(refresh_callable)

	_apply_card_content()

func refresh_display() -> void:
	if not is_node_ready():
		return
	cost_label.text = _get_cost_text()
	effects_label.text = _get_effects_text()

func _apply_card_content() -> void:
	if not is_node_ready():
		return
	name_label.text = str(card_data.get("name", "?"))
	type_label.text = "%s • %s" % [
		str(card_data.get("type", "card")).to_upper(),
		str(card_data.get("targeting", "self")).replace("_", " ").to_upper()
	]
	call_deferred("_fit_name_to_single_line")
	_apply_art()
	refresh_display()

func set_preview_mode(enabled: bool) -> void:
	preview_only = enabled
	is_zoomed = enabled
	mouse_filter = Control.MOUSE_FILTER_IGNORE if enabled else Control.MOUSE_FILTER_STOP
	refresh_display()

func _get_effects_text() -> String:
	if is_zoomed and card_data.has("preview_description"):
		return str(card_data.get("preview_description", ""))
	if not is_zoomed and card_data.has("compact_description"):
		return str(card_data.get("compact_description", ""))
	if combat_manager:
		return combat_manager.get_card_text(card_data, source_side, is_zoomed)
	return GameState.get_preview_card_text(card_data)

func _get_cost_text() -> String:
	if is_zoomed and card_data.has("preview_cost_text"):
		return str(card_data.get("preview_cost_text", ""))
	if not is_zoomed and card_data.has("compact_cost_text"):
		return str(card_data.get("compact_cost_text", ""))
	return str(int(card_data.get("cost", 0)))

func _fit_name_to_single_line() -> void:
	var font: Font = name_label.get_theme_font("font")
	if font == null:
		name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE_MAX)
		return

	var available_width = name_label.size.x
	if available_width <= 0.0:
		available_width = max(size.x - 56.0, 40.0)

	var font_size = NAME_FONT_SIZE_MAX
	while font_size > NAME_FONT_SIZE_MIN:
		var text_width = font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		if text_width <= available_width:
			break
		font_size -= 1
	name_label.add_theme_font_size_override("font_size", font_size)

func _apply_art() -> void:
	var image_path = str(card_data.get("cardImage", ""))
	var full_path = image_path
	if not full_path.is_empty() and not full_path.begins_with("res://"):
		full_path = "res://" + full_path
	var texture = load(full_path) if not full_path.is_empty() else null
	art_texture.texture = texture
	art_texture.visible = texture != null
	art_fallback.visible = texture == null
	art_fallback.text = "missing image" if image_path.is_empty() or texture == null else ""

func _is_targeted() -> bool:
	return str(card_data.get("targeting", "self")) == "single_enemy"

func _can_afford() -> bool:
	if not combat_manager:
		return false
	return combat_manager.player_energy >= card_data.get("cost", 0) and combat_manager.current_phase == CombatManager.Phase.PLAY

func _gui_input(event: InputEvent) -> void:
	if preview_only:
		return
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
					preview_requested.emit(card_data)
					accept_event()

func _input(event: InputEvent) -> void:
	if preview_only:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if is_dragging:
			_release_drag(event.global_position)
			get_viewport().set_input_as_handled()
		elif pending_click and not _is_point_inside_card(event.global_position):
			pending_click = false
	elif event is InputEventMouseMotion:
		if pending_click and not is_dragging and allow_drag_play and _can_afford():
			if event.global_position.distance_to(press_position) >= DRAG_THRESHOLD:
				pending_click = false
				_dismiss_preview()
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
	if canvas and canvas.has_method("clear_hand_hover"):
		canvas.clear_hand_hover()
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
		var scene = get_tree().current_scene
		var over_hand = scene and scene.has_method("is_point_over_hand_area") and scene.is_point_over_hand_area(global_pos)
		if not over_hand:
			played = combat_manager.play_card(card_data, "self")

	if played:
		_dismiss_preview()
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
	var scene = get_tree().current_scene
	if scene and scene.has_method("refresh_hand_layout"):
		scene.call_deferred("refresh_hand_layout")

func _dismiss_preview() -> void:
	var scene = get_tree().current_scene
	if scene and scene.has_method("hide_card_preview"):
		scene.hide_card_preview()

func _is_over_node(target_node: Control, global_pos: Vector2) -> bool:
	var rect = Rect2(target_node.global_position, target_node.size)
	return rect.has_point(global_pos)

func _is_point_inside_card(global_pos: Vector2) -> bool:
	var local_point = get_global_transform().affine_inverse() * global_pos
	return Rect2(Vector2.ZERO, size).has_point(local_point)
