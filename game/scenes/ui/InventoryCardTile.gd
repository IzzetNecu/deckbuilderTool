extends PanelContainer
class_name InventoryCardTile

signal hovered(card_data: Dictionary)
signal unhovered(card_data: Dictionary)
signal selected(card_data: Dictionary)
signal action_pressed(card_data: Dictionary)

const COMPACT_TILE_SIZE := Vector2(150, 225)
const DETAIL_TILE_SIZE := Vector2(150, 225)
const NAME_FONT_SIZE_MAX := 15
const NAME_FONT_SIZE_MIN := 9

var card_data: Dictionary = {}
var compact_mode: bool = true
var locked: bool = false
var interactive: bool = true
var selected_state: bool = false
var draggable: bool = false
var drag_section: String = ""
var count_text: String = ""
var footer_text: String = ""
var action_text: String = ""
var action_enabled: bool = true
var rules_text: String = ""

@onready var header_panel: PanelContainer = $Margin/VBox/Header
@onready var name_label: Label = $Margin/VBox/Header/HeaderContent/TitleBox/NameLabel
@onready var meta_label: Label = $Margin/VBox/Header/HeaderContent/TitleBox/MetaLabel
@onready var count_badge: PanelContainer = $Margin/VBox/Header/HeaderContent/Badges/CountBadge
@onready var count_label: Label = $Margin/VBox/Header/HeaderContent/Badges/CountBadge/CountLabel
@onready var cost_badge: PanelContainer = $Margin/VBox/Header/HeaderContent/Badges/CostBadge
@onready var cost_label: Label = $Margin/VBox/Header/HeaderContent/Badges/CostBadge/CostLabel
@onready var art_texture: TextureRect = $Margin/VBox/ArtFrame/ArtTexture
@onready var art_fallback: Label = $Margin/VBox/ArtFrame/ArtFallback
@onready var art_frame: PanelContainer = $Margin/VBox/ArtFrame
@onready var type_badge: PanelContainer = $Margin/VBox/TypeBadge
@onready var type_label: Label = $Margin/VBox/TypeBadge/TypeLabel
@onready var effects_box: PanelContainer = $Margin/VBox/EffectsBox
@onready var effects_label: Label = $Margin/VBox/EffectsBox/EffectsLabel
@onready var footer_label: Label = $Margin/VBox/FooterLabel
@onready var action_button: Button = $Margin/VBox/ActionButton

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	action_button.pressed.connect(func(): action_pressed.emit(card_data))
	resized.connect(_fit_name_to_single_line)
	_set_compact_hit_regions()
	_apply_content()

func setup(data: Dictionary, options: Dictionary = {}) -> void:
	card_data = data.duplicate(true)
	compact_mode = bool(options.get("compact", true))
	locked = bool(options.get("locked", false))
	interactive = bool(options.get("interactive", true))
	selected_state = bool(options.get("selected", false))
	draggable = bool(options.get("draggable", false))
	drag_section = str(options.get("drag_section", ""))
	count_text = str(options.get("count_text", ""))
	footer_text = str(options.get("footer_text", ""))
	action_text = str(options.get("action_text", ""))
	action_enabled = bool(options.get("action_enabled", true))
	rules_text = str(options.get("rules_text", GameState.get_preview_card_text(card_data)))
	tooltip_text = str(options.get("tooltip_text", ""))
	_apply_content()

func set_selected(is_selected: bool) -> void:
	selected_state = is_selected
	_apply_style()

func _apply_content() -> void:
	if not is_node_ready():
		return

	custom_minimum_size = COMPACT_TILE_SIZE if compact_mode else DETAIL_TILE_SIZE
	size = custom_minimum_size
	name_label.text = str(card_data.get("name", "Unknown Card"))
	meta_label.text = "%s • %s" % [
		str(card_data.get("type", "card")).capitalize(),
		str(card_data.get("rarity", "common")).capitalize()
	]
	type_label.text = "%s • %s" % [
		str(card_data.get("type", "card")).to_upper(),
		str(card_data.get("targeting", "self")).replace("_", " ").to_upper()
	]
	count_badge.visible = not count_text.is_empty()
	count_label.text = count_text
	var cost_value = str(int(card_data.get("cost", 0)))
	cost_label.text = cost_value if not cost_value.is_empty() else "-"
	effects_label.text = rules_text
	footer_label.visible = not footer_text.is_empty()
	footer_label.text = footer_text
	action_button.visible = not action_text.is_empty() and not compact_mode
	action_button.text = action_text
	action_button.disabled = not action_enabled
	action_button.focus_mode = Control.FOCUS_NONE
	meta_label.visible = false
	footer_label.visible = not footer_text.is_empty() and not compact_mode
	type_label.get_parent().visible = true
	action_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if compact_mode else Control.MOUSE_FILTER_STOP
	call_deferred("_fit_name_to_single_line")
	_apply_art()
	_apply_style()
	queue_redraw()

func _apply_style() -> void:
	var affinity_colors = _get_affinity_colors()
	var primary = affinity_colors[0] if not affinity_colors.is_empty() else Color(0.46, 0.42, 0.34, 0.85)
	var panel_style = get_theme_stylebox("panel")
	if panel_style is StyleBoxFlat:
		var style := (panel_style as StyleBoxFlat).duplicate()
		style.border_color = Color(0.94, 0.74, 0.38, 1.0) if selected_state else primary
		style.border_width_left = 3 if selected_state else 2
		style.border_width_top = 3 if selected_state else 2
		style.border_width_right = 3 if selected_state else 2
		style.border_width_bottom = 3 if selected_state else 2
		if locked:
			style.bg_color = Color(0.12, 0.12, 0.12, 0.96)
		add_theme_stylebox_override("panel", style)
	_apply_box_style(header_panel, primary, 10, 10, 0, 0)
	_apply_box_style(effects_box, primary, 0, 0, 10, 10)
	_apply_box_style(art_frame, primary.darkened(0.18), 0, 0, 0, 0)
	_apply_box_style(type_badge, primary.darkened(0.1), 0, 0, 0, 0)
	_apply_box_style(cost_badge, primary.darkened(0.1), 999, 999, 999, 999)
	_apply_box_style(count_badge, primary.darkened(0.1), 999, 999, 999, 999)

	modulate = Color(1, 1, 1, 1) if interactive or compact_mode == false else Color(0.88, 0.88, 0.88, 1)
	if locked and compact_mode:
		modulate = Color(0.92, 0.92, 0.92, 1)
	effects_label.add_theme_font_size_override("font_size", 11)
	queue_redraw()

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

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not compact_mode or not draggable or drag_section.is_empty():
		return null
	var preview_root := _build_drag_preview()

	set_drag_preview(preview_root)
	selected.emit(card_data)
	return {
		"type": "deck_card_stack",
		"card_id": str(card_data.get("id", "")),
		"from_section": drag_section
	}

func _build_drag_preview() -> Control:
	var preview_size = DETAIL_TILE_SIZE
	var preview_root := Control.new()
	preview_root.custom_minimum_size = preview_size
	preview_root.size = preview_size
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var scene_path = scene_file_path if not scene_file_path.is_empty() else "res://scenes/ui/InventoryCardTile.tscn"
	var preview_scene = load(scene_path) as PackedScene
	if preview_scene == null:
		return preview_root
	var preview_tile := preview_scene.instantiate() as InventoryCardTile
	preview_tile.setup(card_data, {
		"compact": false,
		"interactive": false,
		"locked": locked,
		"count_text": count_text,
		"footer_text": footer_text,
		"rules_text": rules_text
	})
	preview_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_tile.position = Vector2.ZERO
	preview_tile.custom_minimum_size = preview_size
	preview_tile.size = preview_size
	preview_root.add_child(preview_tile)
	return preview_root

func _apply_art() -> void:
	var image_path = str(card_data.get("cardImage", ""))
	var full_path = image_path
	if not full_path.is_empty() and not full_path.begins_with("res://"):
		full_path = "res://" + full_path
	var texture = load(full_path) if not full_path.is_empty() else null
	art_texture.texture = texture
	art_texture.visible = texture != null
	art_fallback.visible = texture == null
	art_fallback.text = "missing image" if texture == null else ""

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var drop_zone = _find_drop_zone_ancestor()
	if drop_zone == null:
		return false
	return drop_zone._can_drop_data(at_position, data)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var drop_zone = _find_drop_zone_ancestor()
	if drop_zone == null:
		return
	drop_zone._drop_data(at_position, data)

func _find_drop_zone_ancestor() -> InventoryDropZone:
	var node := get_parent()
	while node != null:
		if node is InventoryDropZone:
			return node as InventoryDropZone
		node = node.get_parent()
	return null

func _set_compact_hit_regions() -> void:
	$Margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/Header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/Header/HeaderContent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/Header/HeaderContent/TitleBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/Header/HeaderContent/Badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/Header/HeaderContent/Badges/CountBadge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/Header/HeaderContent/Badges/CostBadge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/ArtFrame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/TypeBadge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/EffectsBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

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

func _on_mouse_entered() -> void:
	if interactive:
		hovered.emit(card_data)

func _on_mouse_exited() -> void:
	if interactive:
		unhovered.emit(card_data)

func _on_gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(card_data)
		accept_event()
