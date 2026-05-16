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
var stack_count: int = 1

@onready var name_label: Label = $Margin/VBox/Header/TitleBox/NameLabel
@onready var meta_label: Label = $Margin/VBox/Header/TitleBox/MetaLabel
@onready var count_badge: PanelContainer = $Margin/VBox/Header/Badges/CountBadge
@onready var count_label: Label = $Margin/VBox/Header/Badges/CountBadge/CountLabel
@onready var cost_badge: PanelContainer = $Margin/VBox/Header/Badges/CostBadge
@onready var cost_label: Label = $Margin/VBox/Header/Badges/CostBadge/CostLabel
@onready var art_texture: TextureRect = $Margin/VBox/ArtFrame/ArtTexture
@onready var art_fallback: Label = $Margin/VBox/ArtFrame/ArtFallback
@onready var type_label: Label = $Margin/VBox/TypeBadge/TypeLabel
@onready var effects_label: Label = $Margin/VBox/EffectsLabel
@onready var footer_label: Label = $Margin/VBox/FooterLabel
@onready var action_button: Button = $Margin/VBox/ActionButton
@onready var back_stack_a: PanelContainer = $BackStackA
@onready var back_stack_b: PanelContainer = $BackStackB
@onready var back_stack_a_label: Label = $BackStackA/BackTitle
@onready var back_stack_b_label: Label = $BackStackB/BackTitle

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
	stack_count = max(int(options.get("stack_count", 1)), 1)
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
	back_stack_a_label.text = name_label.text
	back_stack_b_label.text = name_label.text
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
	back_stack_a.visible = compact_mode and stack_count > 1
	back_stack_b.visible = compact_mode and stack_count > 2
	meta_label.visible = false
	footer_label.visible = not footer_text.is_empty() and not compact_mode
	type_label.get_parent().visible = true
	action_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if compact_mode else Control.MOUSE_FILTER_STOP
	call_deferred("_fit_name_to_single_line")
	_apply_art()
	_apply_style()

func _apply_style() -> void:
	var panel_style = get_theme_stylebox("panel")
	if panel_style is StyleBoxFlat:
		var style := (panel_style as StyleBoxFlat).duplicate()
		style.border_color = Color(0.94, 0.74, 0.38, 1.0) if selected_state else Color(0.46, 0.42, 0.34, 0.85)
		style.border_width_left = 3 if selected_state else 2
		style.border_width_top = 3 if selected_state else 2
		style.border_width_right = 3 if selected_state else 2
		style.border_width_bottom = 3 if selected_state else 2
		if locked:
			style.bg_color = Color(0.12, 0.12, 0.12, 0.96)
		add_theme_stylebox_override("panel", style)

	modulate = Color(1, 1, 1, 1) if interactive or compact_mode == false else Color(0.88, 0.88, 0.88, 1)
	if locked and compact_mode:
		modulate = Color(0.92, 0.92, 0.92, 1)
	effects_label.add_theme_font_size_override("font_size", 11)

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
		"rules_text": rules_text,
		"stack_count": stack_count
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
	$Margin/VBox/Header/TitleBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/Header/Badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/Header/Badges/CountBadge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/Header/Badges/CostBadge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/ArtFrame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Margin/VBox/TypeBadge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_stack_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_stack_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_stack_a_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_stack_b_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
