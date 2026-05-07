extends VBoxContainer

var combat_manager: Node = null

@onready var name_label: Label = $NameLabel
@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPLabel
@onready var block_label: Label = $BlockLabel
@onready var highlight_rect: ColorRect = $HighlightRect
@onready var revealed_cards_container: HBoxContainer = $RevealedCardsContainer

func _ready() -> void:
	highlight_rect.visible = false
	highlight_rect.color = Color(1, 0.8, 0, 0.3)

func setup_enemy(data: Dictionary, hp: int, max_hp: int) -> void:
	name_label.text = data.get("name", "Enemy")
	update_stats(hp, max_hp, 0)

func update_stats(hp: int, max_hp: int, block: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_label.text = "%d / %d HP" % [hp, max_hp]
	block_label.text = "Block: %d" % block
	block_label.visible = block > 0

func update_revealed_cards(hand: Array) -> void:
	for child in revealed_cards_container.get_children():
		child.queue_free()

	for card_data in hand:
		var card_preview = _make_card_preview(card_data)
		revealed_cards_container.add_child(card_preview)

func _make_card_preview(card_data: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.05, 0.05, 0.9)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(70, 90)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = card_data.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	for effect in card_data.get("effects", []):
		var eff_text = effect.get("value", str(effect)) if effect is Dictionary else str(effect)
		var scales = effect.get("scalesWith", "none") if effect is Dictionary else "none"
		if scales != "none":
			eff_text += " (+" + scales + ")"
		var eff_lbl = Label.new()
		eff_lbl.text = eff_text
		eff_lbl.add_theme_font_size_override("font_size", 9)
		eff_lbl.modulate = Color(1, 0.5, 0.5)
		vbox.add_child(eff_lbl)

	return panel

func set_highlight(active: bool) -> void:
	highlight_rect.visible = active
