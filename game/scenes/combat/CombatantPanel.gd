extends Control

const NORMAL_CARD_SIZE := Vector2(150, 225)

var combat_manager: Node = null
var panel_side: String = "player"
var card_scene = preload("res://scenes/combat/Card.tscn")

@onready var name_label: Label = $VBox/NameLabel
@onready var portrait_texture: TextureRect = $VBox/PortraitArea/PortraitTexture
@onready var placeholder_label: Label = $VBox/PortraitArea/PlaceholderLabel
@onready var energy_badge: Label = $VBox/PortraitArea/EnergyBadge
@onready var highlight_rect: ColorRect = $VBox/PortraitArea/HighlightRect
@onready var hp_bar_frame: Control = $VBox/HPBarFrame
@onready var block_outline: Panel = $VBox/HPBarFrame/BlockOutline
@onready var hp_bar: ProgressBar = $VBox/HPBarFrame/HPBar
@onready var block_value_label: Label = $VBox/HPBarFrame/BlockValueLabel
@onready var hp_value_label: Label = $VBox/HPBarFrame/HPValueLabel
@onready var buffs_container: HBoxContainer = $VBox/BuffScroll/BuffsContainer
@onready var intent_section: VBoxContainer = $VBox/IntentSection
@onready var intent_cards_container: HBoxContainer = $VBox/IntentSection/RevealedCardsContainer
@onready var action_slot: HBoxContainer = $VBox/IntentSection/ActionSlot

func _ready() -> void:
	hp_bar.show_percentage = false
	highlight_rect.visible = false
	highlight_rect.color = Color(1, 0.8, 0, 0.24)

func configure(side: String, show_intents: bool) -> void:
	panel_side = side
	intent_section.visible = show_intents
	var align_right = panel_side == "enemy"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if align_right else HORIZONTAL_ALIGNMENT_LEFT
	buffs_container.alignment = BoxContainer.ALIGNMENT_END if align_right else BoxContainer.ALIGNMENT_BEGIN
	intent_cards_container.alignment = BoxContainer.ALIGNMENT_END if align_right else BoxContainer.ALIGNMENT_BEGIN
	action_slot.alignment = BoxContainer.ALIGNMENT_END if align_right else BoxContainer.ALIGNMENT_BEGIN
	hp_bar.custom_minimum_size = Vector2(180, 14) if align_right else Vector2(250, 18)
	energy_badge.visible = panel_side == "player"
	_apply_hp_bar_layout()

func get_action_slot() -> HBoxContainer:
	return action_slot

func update_actor(actor_name: String, portrait_path: String, hp: int, max_hp: int, block: int, energy_text: String, buff_values: Array) -> void:
	name_label.text = actor_name
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_value_label.text = "%d / %d" % [hp, max_hp]
	block_value_label.text = str(block) if block > 0 else ""
	energy_badge.text = energy_text
	_apply_portrait(portrait_path, actor_name)
	_update_block_outline(block, max_hp)
	_render_buffs(buff_values)

func update_intent_slots(intent_slots: Array) -> void:
	for child in intent_cards_container.get_children():
		child.queue_free()

	for index in range(intent_slots.size()):
		var intent_slot = intent_slots[index]
		if bool(intent_slot.get("is_hidden", false)):
			intent_cards_container.add_child(_make_hidden_card_preview(index))
			continue
		intent_cards_container.add_child(_make_card_preview(intent_slot.get("card", {}), index))

func set_highlight(active: bool) -> void:
	highlight_rect.visible = active

func _apply_portrait(portrait_path: String, actor_name: String) -> void:
	var full_path = portrait_path
	if not full_path.is_empty() and not full_path.begins_with("res://"):
		full_path = "res://" + full_path
	var texture = load(full_path) if not full_path.is_empty() else null
	if texture:
		portrait_texture.texture = texture
		portrait_texture.visible = true
		placeholder_label.visible = false
		return

	portrait_texture.texture = null
	portrait_texture.visible = false
	placeholder_label.text = actor_name.substr(0, mini(actor_name.length(), 8))
	placeholder_label.visible = true

func _update_block_outline(block: int, max_hp: int) -> void:
	var clamped_ratio = clamp(float(block) / float(max(max_hp, 1)), 0.0, 1.0)
	block_outline.visible = block > 0
	block_outline.size = Vector2(hp_bar_frame.size.x * clamped_ratio, hp_bar_frame.size.y)
	block_outline.position = Vector2.ZERO if panel_side != "enemy" else Vector2(hp_bar_frame.size.x - block_outline.size.x, 0.0)

func _apply_hp_bar_layout() -> void:
	var is_enemy = panel_side == "enemy"
	hp_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN if is_enemy else ProgressBar.FILL_BEGIN_TO_END

	if is_enemy:
		hp_value_label.anchor_left = 0.0
		hp_value_label.anchor_right = 0.0
		hp_value_label.offset_left = 6.0
		hp_value_label.offset_right = 92.0
		hp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

		block_value_label.anchor_left = 1.0
		block_value_label.anchor_right = 1.0
		block_value_label.offset_left = -70.0
		block_value_label.offset_right = -6.0
		block_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		return

	hp_value_label.anchor_left = 1.0
	hp_value_label.anchor_right = 1.0
	hp_value_label.offset_left = -92.0
	hp_value_label.offset_right = -6.0
	hp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	block_value_label.anchor_left = 0.0
	block_value_label.anchor_right = 0.0
	block_value_label.offset_left = 6.0
	block_value_label.offset_right = 70.0
	block_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func _render_buffs(buff_values: Array) -> void:
	for child in buffs_container.get_children():
		child.queue_free()

	for buff_value in buff_values:
		var amount = int(buff_value.get("value", 0))
		if amount <= 0:
			continue
		buffs_container.add_child(_make_buff_icon(buff_value))

func _make_buff_icon(buff_value: Dictionary) -> Control:
	var buff_id = str(buff_value.get("id", ""))
	var buff_def = GameData.get_buff(buff_id)
	var kind = str(buff_def.get("kind", "buff"))
	var title = str(buff_def.get("name", buff_id))
	var fallback_short_label = title.substr(0, mini(title.length(), 3)).to_upper()
	var short_label = str(buff_def.get("shortLabel", fallback_short_label))
	var icon_path = str(buff_def.get("iconImage", ""))
	var reminder = str(buff_def.get("reminderText", ""))
	var amount = int(buff_value.get("value", 0))

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(48, 52)
	panel.tooltip_text = "%s (%d)\n%s" % [title, amount, reminder]

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.12, 0.12, 0.95) if kind == "debuff" else Color(0.1, 0.16, 0.12, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.6, 0.28, 0.28) if kind == "debuff" else Color(0.3, 0.62, 0.42)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var root = MarginContainer.new()
	root.add_theme_constant_override("margin_left", 4)
	root.add_theme_constant_override("margin_top", 4)
	root.add_theme_constant_override("margin_right", 4)
	root.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(root)

	var vbox = VBoxContainer.new()
	root.add_child(vbox)

	var icon_control: Control = _make_buff_icon_visual(icon_path, short_label)
	vbox.add_child(icon_control)

	var amount_label = Label.new()
	amount_label.text = str(amount)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(amount_label)

	return panel

func _make_buff_icon_visual(icon_path: String, short_label: String) -> Control:
	var full_path = icon_path
	if not full_path.is_empty() and not full_path.begins_with("res://"):
		full_path = "res://" + full_path
	var texture = load(full_path) if not full_path.is_empty() else null
	if texture:
		var icon = TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(24, 24)
		return icon

	var label = Label.new()
	label.text = short_label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 24)
	label.add_theme_font_size_override("font_size", 10)
	return label

func _make_card_preview(card_data: Dictionary, slot_index: int) -> CombatCard:
	var preview_card: CombatCard = card_scene.instantiate()
	var preview_data = card_data.duplicate(true)
	preview_data["preview_key"] = _build_intent_preview_key(slot_index, preview_data)
	preview_data["preview_source_side"] = "enemy"
	preview_card.custom_minimum_size = NORMAL_CARD_SIZE
	preview_card.size = NORMAL_CARD_SIZE
	preview_card.setup(preview_data, combat_manager, self, "enemy", false)
	preview_card.preview_requested.connect(_forward_preview_request)
	return preview_card

func _make_hidden_card_preview(slot_index: int) -> CombatCard:
	var preview_card: CombatCard = card_scene.instantiate()
	var preview_data := {
		"id": "__enemy_hidden__",
		"name": "Hidden",
		"cost": 0,
		"description": "?",
		"compact_description": "?",
		"preview_description": "This card is hidden from you. Gain more insight to reveal it.",
		"compact_cost_text": "",
		"preview_cost_text": "",
		"effects": [],
		"preview_key": "__enemy_hidden_%d" % slot_index,
		"preview_source_side": "enemy"
	}
	preview_card.custom_minimum_size = NORMAL_CARD_SIZE
	preview_card.size = NORMAL_CARD_SIZE
	preview_card.setup(preview_data, combat_manager, self, "enemy", false)
	preview_card.preview_requested.connect(_forward_preview_request)
	return preview_card

func _forward_preview_request(card_data: Dictionary) -> void:
	var scene = get_tree().current_scene
	if scene and scene.has_method("_on_card_preview_requested"):
		scene.call("_on_card_preview_requested", card_data)

func _build_intent_preview_key(slot_index: int, card_data: Dictionary) -> String:
	return "enemy_intent_%d_%s" % [slot_index, str(card_data.get("id", "unknown"))]
