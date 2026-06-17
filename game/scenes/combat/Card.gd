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

@onready var header_panel: PanelContainer = $Margin/VBox/Header
@onready var name_label: Label = $Margin/VBox/Header/HeaderContent/NameLabel
@onready var cost_badge: PanelContainer = $Margin/VBox/Header/HeaderContent/CostBadge
@onready var cost_label: Label = $Margin/VBox/Header/HeaderContent/CostBadge/CostLabel
@onready var art_texture: TextureRect = $Margin/VBox/ArtFrame/ArtTexture
@onready var art_fallback: Label = $Margin/VBox/ArtFrame/ArtFallback
@onready var art_frame: PanelContainer = $Margin/VBox/ArtFrame
@onready var type_badge: PanelContainer = $Margin/VBox/TypeBadge
@onready var type_label: Label = $Margin/VBox/TypeBadge/TypeLabel
@onready var effects_box: PanelContainer = $Margin/VBox/EffectsBox
@onready var effects_label: Label = $Margin/VBox/EffectsBox/EffectsLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	$Margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/Header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/Header/HeaderContent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/Header/HeaderContent/CostBadge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/ArtFrame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/TypeBadge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/EffectsBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_apply_style()
	refresh_display()
	queue_redraw()

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

func _apply_style() -> void:
	var colors = _get_affinity_colors()
	var primary = colors[0] if not colors.is_empty() else Color(0.46, 0.42, 0.34, 0.85)
	var panel_style = get_theme_stylebox("panel")
	if panel_style is StyleBoxFlat:
		var style := (panel_style as StyleBoxFlat).duplicate()
		style.border_color = primary
		add_theme_stylebox_override("panel", style)
	_apply_box_style(header_panel, primary, 10, 10, 0, 0)
	_apply_box_style(effects_box, primary, 0, 0, 10, 10)
	_apply_box_style(art_frame, primary.darkened(0.18), 0, 0, 0, 0)
	_apply_box_style(type_badge, primary.darkened(0.1), 0, 0, 0, 0)
	_apply_box_style(cost_badge, primary.darkened(0.1), 999, 999, 999, 999)

func _draw() -> void:
	var colors = _get_affinity_colors()
	if colors.is_empty():
		return
	_draw_affinity_pie_background(colors)

func _draw_affinity_pie_background(colors: Array) -> void:
	var interior_rect = Rect2(Vector2(2.0, 2.0), Vector2(max(size.x - 4.0, 0.0), max(size.y - 4.0, 0.0)))
	var corner_radius := 10.0
	if colors.size() == 1:
		draw_colored_polygon(_build_rounded_rect_polygon(interior_rect, corner_radius), colors[0].darkened(0.28))
		return
	var center = size * 0.5
	var step = TAU / float(colors.size())
	var start_angle = -PI * 0.5
	for i in range(colors.size()):
		var segment_color: Color = colors[i].darkened(0.28)
		var points := PackedVector2Array()
		points.append(center)
		var angle_from = start_angle + step * i
		var angle_to = angle_from + step
		var arc_steps = 12
		for arc_index in range(arc_steps + 1):
			var t = float(arc_index) / float(arc_steps)
			var angle = lerp(angle_from, angle_to, t)
			points.append(_point_on_rounded_rect_edge(center, Vector2(cos(angle), sin(angle)), interior_rect, corner_radius))
		draw_colored_polygon(points, segment_color)

func _point_on_rounded_rect_edge(origin: Vector2, direction: Vector2, rect: Rect2, radius: float) -> Vector2:
	var low := 0.0
	var high = max(rect.size.x, rect.size.y)
	for _i in range(18):
		var mid = (low + high) * 0.5
		var point = origin + direction * mid
		if _point_in_rounded_rect(point, rect, radius):
			low = mid
		else:
			high = mid
	return origin + direction * low

func _point_in_rounded_rect(point: Vector2, rect: Rect2, radius: float) -> bool:
	if not rect.has_point(point):
		return false
	var left = rect.position.x
	var right = rect.position.x + rect.size.x
	var top = rect.position.y
	var bottom = rect.position.y + rect.size.y
	var corner_center := Vector2.ZERO
	if point.x < left + radius and point.y < top + radius:
		corner_center = Vector2(left + radius, top + radius)
	elif point.x > right - radius and point.y < top + radius:
		corner_center = Vector2(right - radius, top + radius)
	elif point.x > right - radius and point.y > bottom - radius:
		corner_center = Vector2(right - radius, bottom - radius)
	elif point.x < left + radius and point.y > bottom - radius:
		corner_center = Vector2(left + radius, bottom - radius)
	else:
		return true
	return point.distance_to(corner_center) <= radius

func _build_rounded_rect_polygon(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var centers = [
		Vector2(rect.position.x + rect.size.x - radius, rect.position.y + radius),
		Vector2(rect.position.x + rect.size.x - radius, rect.position.y + rect.size.y - radius),
		Vector2(rect.position.x + radius, rect.position.y + rect.size.y - radius),
		Vector2(rect.position.x + radius, rect.position.y + radius)
	]
	var starts = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for corner_index in range(4):
		for step_index in range(7):
			var angle = starts[corner_index] + (PI * 0.5) * float(step_index) / 6.0
			points.append(centers[corner_index] + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _get_affinity_colors() -> Array:
	var colors: Array = []
	for affinity_id in GameData.normalize_affinity_ids(card_data.get("card_affinities", []), 3):
		colors.append(GameData.get_affinity_color(int(affinity_id)))
	return colors

func _apply_box_style(control: Control, border_color: Color, top_left: int, top_right: int, bottom_right: int, bottom_left: int) -> void:
	var base_style = control.get_theme_stylebox("panel")
	var style := StyleBoxFlat.new()
	if base_style is StyleBoxFlat:
		style = (base_style as StyleBoxFlat).duplicate()
	style.bg_color = Color(0.045, 0.042, 0.058, 0.94)
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = top_left
	style.corner_radius_top_right = top_right
	style.corner_radius_bottom_right = bottom_right
	style.corner_radius_bottom_left = bottom_left
	control.add_theme_stylebox_override("panel", style)

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
