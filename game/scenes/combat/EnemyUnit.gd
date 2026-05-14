extends VBoxContainer

var combat_manager: Node = null

@onready var name_label: Label = $NameLabel
@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPLabel
@onready var block_label: Label = $BlockLabel
@onready var insight_label: Label = $InsightLabel
@onready var highlight_rect: ColorRect = $HighlightRect
@onready var revealed_cards_container: HBoxContainer = $RevealedCardsContainer

func _ready() -> void:
	highlight_rect.visible = false
	highlight_rect.color = Color(1, 0.8, 0, 0.3)

func update_stats(enemy_name: String, hp: int, max_hp: int, block: int, insight: int) -> void:
	name_label.text = enemy_name
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_label.text = "%d / %d HP" % [hp, max_hp]
	block_label.text = "Block: %d" % block
	block_label.visible = block > 0
	insight_label.text = "INS: %d" % insight

func update_intent_slots(intent_slots: Array) -> void:
	for child in revealed_cards_container.get_children():
		child.queue_free()

	for intent_slot in intent_slots:
		if bool(intent_slot.get("is_hidden", false)):
			revealed_cards_container.add_child(_make_hidden_card_preview())
			continue
		revealed_cards_container.add_child(_make_card_preview(intent_slot.get("card", {})))

func _make_card_preview(card_data: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.05, 0.05, 0.9)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(82, 96)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = card_data.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = combat_manager.get_card_text(card_data, "enemy") if combat_manager else card_data.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 9)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.modulate = Color(1, 0.7, 0.7)
	vbox.add_child(desc_lbl)

	return panel

func _make_hidden_card_preview() -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.12, 0.92)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(82, 96)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = "Hidden"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.modulate = Color(0.85, 0.85, 0.85)
	vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = "?"
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 24)
	desc_lbl.modulate = Color(0.65, 0.65, 0.65)
	vbox.add_child(desc_lbl)

	return panel

func set_highlight(active: bool) -> void:
	highlight_rect.visible = active
