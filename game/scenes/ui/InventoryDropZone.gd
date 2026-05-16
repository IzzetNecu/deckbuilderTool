extends PanelContainer
class_name InventoryDropZone

signal card_dropped(target_section: String, drag_data: Dictionary)

var target_section: String = ""
var drop_enabled: bool = true
var active_drop_state: bool = false
var base_panel_style: StyleBoxFlat = null

func _ready() -> void:
	var panel_style = get_theme_stylebox("panel")
	if panel_style is StyleBoxFlat:
		base_panel_style = (panel_style as StyleBoxFlat).duplicate()
	_update_style()

func configure(section_id: String, enabled: bool = true) -> void:
	target_section = section_id
	drop_enabled = enabled
	_update_style()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not drop_enabled or typeof(data) != TYPE_DICTIONARY:
		active_drop_state = false
		_update_style()
		return false
	if str(data.get("type", "")) != "deck_card_stack":
		active_drop_state = false
		_update_style()
		return false

	var from_section = str(data.get("from_section", ""))
	active_drop_state = from_section != target_section
	_update_style()
	return active_drop_state

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	active_drop_state = false
	_update_style()
	if typeof(data) == TYPE_DICTIONARY:
		card_dropped.emit(target_section, data)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		active_drop_state = false
		_update_style()

func _update_style() -> void:
	if base_panel_style == null:
		var panel_style = get_theme_stylebox("panel")
		if panel_style is StyleBoxFlat:
			base_panel_style = (panel_style as StyleBoxFlat).duplicate()
	if base_panel_style == null:
		return
	var style := base_panel_style.duplicate()
	if active_drop_state:
		style.border_color = Color(0.95, 0.77, 0.36, 1.0)
		style.bg_color = Color(0.16, 0.16, 0.18, 0.98)
	add_theme_stylebox_override("panel", style)
