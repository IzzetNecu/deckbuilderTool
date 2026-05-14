extends Control

const SLOT_LABELS := {
	"weapon_main": "Weapon",
	"off_hand": "Off-Hand",
	"head": "Head",
	"armor": "Armor",
	"legs": "Legs",
	"amulet": "Amulet",
	"ring_left": "Ring Left",
	"ring_right": "Ring Right"
}

@onready var close_button: Button = $Window/VBox/Header/CloseButton
@onready var deck_tab: Button = $Window/VBox/Tabs/DeckTab
@onready var items_tab: Button = $Window/VBox/Tabs/ItemsTab
@onready var compendium_tab: Button = $Window/VBox/Tabs/CompendiumTab
@onready var content_grid: GridContainer = $Window/VBox/ContentScroll/Grid

var current_tab: String = "deck"
var status_message: String = ""

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	deck_tab.pressed.connect(func(): _switch_tab("deck"))
	items_tab.pressed.connect(func(): _switch_tab("items"))
	compendium_tab.pressed.connect(func(): _switch_tab("compendium"))

	_switch_tab("deck")
	_update_stats()

func _update_stats() -> void:
	var stats = $Window/VBox/Header/Stats
	stats.get_node("HP").text = "HP: %d/%d" % [GameState.health, GameState.max_health]
	stats.get_node("Str").text = "STR: %d" % GameState.strength
	stats.get_node("Dex").text = "DEX: %d" % GameState.dexterity
	stats.get_node("Gold").text = "Gold: %d" % GameState.gold

func _on_close_pressed() -> void:
	if get_parent() is CanvasLayer:
		get_parent().queue_free()
	else:
		queue_free()

func _switch_tab(tab_name: String) -> void:
	current_tab = tab_name
	deck_tab.button_pressed = tab_name == "deck"
	items_tab.button_pressed = tab_name == "items"
	compendium_tab.button_pressed = tab_name == "compendium"
	_refresh_content()

func _refresh_content() -> void:
	for child in content_grid.get_children():
		child.queue_free()

	match current_tab:
		"deck":
			_show_deck()
		"items":
			_show_items()
		"compendium":
			_show_compendium()

func _show_deck() -> void:
	content_grid.columns = 1
	var granted_entries = GameState.get_granted_card_entries()
	content_grid.add_child(_make_note_panel(
		"Deck Builder",
		"Selected cards: %d  |  Granted by gear: %d  |  Effective combat deck: %d" % [
			GameState.deck.size(),
			granted_entries.size(),
			GameState.get_effective_deck().size()
		]
	))

	var selected_section = _make_section_panel("Selected Deck", "Cards you chose manually. Remove cards here to move them into the reserve pool.")
	var selected_body: VBoxContainer = selected_section.get_meta("body")
	if GameState.deck.is_empty():
		selected_body.add_child(_make_empty_label("No cards selected."))
	else:
		for card_id in GameState.deck:
			var selected_card_id = card_id
			var card_data = GameData.get_card(card_id)
			if card_data.is_empty():
				continue
			selected_body.add_child(_make_card_row(
				card_data,
				"Selected card",
				"Remove",
				func(): _remove_selected_card(selected_card_id)
			))
	content_grid.add_child(selected_section)

	var granted_section = _make_section_panel("Equipment Granted", "These cards are added automatically at combat start and cannot be removed from the deck tab.")
	var granted_body: VBoxContainer = granted_section.get_meta("body")
	if granted_entries.is_empty():
		granted_body.add_child(_make_empty_label("No equipped gear is granting cards right now."))
	else:
		for entry in granted_entries:
			var card_data = GameData.get_card(str(entry.get("card_id", "")))
			if card_data.is_empty():
				continue
			var source_text = "Granted by %s (%s)" % [
				str(entry.get("equipment_name", entry.get("equipment_id", ""))),
				_slot_label(str(entry.get("slot", "")))
			]
			granted_body.add_child(_make_card_row(card_data, source_text, "Locked"))
	content_grid.add_child(granted_section)

	var reserve_section = _make_section_panel("Reserve Pool", "Owned cards not currently selected. Add them back into the active deck from here.")
	var reserve_body: VBoxContainer = reserve_section.get_meta("body")
	var reserve_counts = _build_reserve_counts()
	if reserve_counts.is_empty():
		reserve_body.add_child(_make_empty_label("No reserve cards. Remove a selected card to move it here."))
	else:
		for card_id in reserve_counts.keys():
			var reserve_card_id = str(card_id)
			var count = int(reserve_counts[card_id])
			var card_data = GameData.get_card(reserve_card_id)
			if card_data.is_empty():
				continue
			var reserve_note = "Reserve copies: %d" % count
			reserve_body.add_child(_make_card_row(
				card_data,
				reserve_note,
				"Add",
				func(): _add_reserved_card(reserve_card_id)
			))
	content_grid.add_child(reserve_section)

func _show_items() -> void:
	content_grid.columns = 1
	content_grid.add_child(_make_note_panel("Equipment", "Owned equipment stays in the bag. Equipped slots decide which items grant combat cards."))

	var slots_section = _make_section_panel("Equipped Slots", "Explicit slot rules apply. Two-handed weapons block the off-hand slot.")
	var slots_body: VBoxContainer = slots_section.get_meta("body")
	for slot_id in GameState.SLOT_ORDER:
		slots_body.add_child(_make_slot_row(slot_id))
	content_grid.add_child(slots_section)

	var bag_section = _make_section_panel("Equipment Bag", "Choose where to equip each item. Ring items support either ring slot.")
	var bag_body: VBoxContainer = bag_section.get_meta("body")
	var equipment_ids = _unique_ids(GameState.equipment)
	if equipment_ids.is_empty():
		bag_body.add_child(_make_empty_label("No owned equipment."))
	else:
		for equipment_id in equipment_ids:
			var equip_data = GameData.get_equipment(equipment_id)
			if equip_data.is_empty():
				continue
			bag_body.add_child(_make_equipment_row(equipment_id, equip_data))
	content_grid.add_child(bag_section)

	var consumables_section = _make_section_panel("Consumables", "Consumables are view-only in this phase.")
	var consumables_body: VBoxContainer = consumables_section.get_meta("body")
	if GameState.consumables.is_empty():
		consumables_body.add_child(_make_empty_label("No consumables owned."))
	else:
		for consumable_id in _unique_ids(GameState.consumables):
			var item_data = GameData.get_consumable(consumable_id)
			if item_data.is_empty():
				continue
			consumables_body.add_child(_make_item_row(
				str(item_data.get("name", consumable_id)),
				"Consumable x%d" % GameState.get_consumable_count(consumable_id),
				str(item_data.get("description", ""))
			))
	content_grid.add_child(consumables_section)

	var key_items_section = _make_section_panel("Key Items", "Key items are tracked here for progression and event checks.")
	var key_items_body: VBoxContainer = key_items_section.get_meta("body")
	if GameState.key_items.is_empty():
		key_items_body.add_child(_make_empty_label("No key items owned."))
	else:
		for key_item_id in _unique_ids(GameState.key_items):
			var item_data = GameData.get_key_item(key_item_id)
			if item_data.is_empty():
				continue
			key_items_body.add_child(_make_item_row(
				str(item_data.get("name", key_item_id)),
				"Key Item x%d" % GameState.get_key_item_count(key_item_id),
				str(item_data.get("description", ""))
			))
	content_grid.add_child(key_items_section)

func _show_compendium() -> void:
	content_grid.columns = 3
	for enemy_id in GameData.enemies:
		var enemy = GameData.enemies[enemy_id]
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(240, 100)
		var vbox = VBoxContainer.new()
		panel.add_child(vbox)

		var name_lbl = Label.new()
		name_lbl.text = enemy.get("name", "Unknown Enemy")
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)

		var hp_lbl = Label.new()
		hp_lbl.text = "Max HP: %d" % enemy.get("hp", 0)
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_lbl.modulate = Color(1, 0.4, 0.4)
		vbox.add_child(hp_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = enemy.get("description", "")
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 10)
		vbox.add_child(desc_lbl)

		content_grid.add_child(panel)

func _make_note_panel(title: String, body_text: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)

	var body_label = Label.new()
	body_label.text = body_text
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.modulate = Color(0.9, 0.9, 0.9)
	vbox.add_child(body_label)

	if not status_message.is_empty():
		var status_label = Label.new()
		status_label.text = status_message
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status_label.modulate = Color(0.93, 0.82, 0.48)
		vbox.add_child(status_label)

	return panel

func _make_section_panel(title: String, subtitle: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)

	var subtitle_label = Label.new()
	subtitle_label.text = subtitle
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(subtitle_label)

	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	vbox.add_child(body)
	panel.set_meta("body", body)
	return panel

func _make_card_row(card_data: Dictionary, subtitle: String, action_text: String = "", on_press: Callable = Callable()) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var text_box = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 4)
	hbox.add_child(text_box)

	var name_label = Label.new()
	name_label.text = str(card_data.get("name", "Unknown Card"))
	name_label.add_theme_font_size_override("font_size", 16)
	text_box.add_child(name_label)

	var subtitle_label = Label.new()
	subtitle_label.text = subtitle
	subtitle_label.modulate = Color(0.72, 0.72, 0.72)
	text_box.add_child(subtitle_label)

	var desc_label = Label.new()
	desc_label.text = GameState.get_preview_card_text(card_data)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 10)
	text_box.add_child(desc_label)

	if not action_text.is_empty():
		var action_button = Button.new()
		action_button.text = action_text
		action_button.custom_minimum_size = Vector2(90, 32)
		if on_press.is_valid():
			action_button.pressed.connect(on_press)
		else:
			action_button.disabled = true
		hbox.add_child(action_button)

	return panel

func _make_item_row(title: String, subtitle: String, description: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title_label)

	var subtitle_label = Label.new()
	subtitle_label.text = subtitle
	subtitle_label.modulate = Color(0.72, 0.72, 0.72)
	vbox.add_child(subtitle_label)

	var desc_label = Label.new()
	desc_label.text = description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(desc_label)
	return panel

func _make_slot_row(slot_id: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var label = Label.new()
	label.text = _slot_label(slot_id)
	label.custom_minimum_size = Vector2(100, 0)
	hbox.add_child(label)

	var text_box = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 4)
	hbox.add_child(text_box)

	var equipped_item_id = GameState.get_slot_item(slot_id)
	var item_name = "Empty"
	var detail = "Nothing equipped."
	if GameState.is_slot_blocked(slot_id):
		item_name = "Blocked"
		detail = "A two-handed weapon is occupying your hands."
	elif not equipped_item_id.is_empty():
		var equip_data = GameData.get_equipment(equipped_item_id)
		item_name = str(equip_data.get("name", equipped_item_id))
		detail = str(equip_data.get("description", ""))

	var name_label = Label.new()
	name_label.text = item_name
	name_label.add_theme_font_size_override("font_size", 16)
	text_box.add_child(name_label)

	var detail_label = Label.new()
	detail_label.text = detail
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 10)
	detail_label.modulate = Color(0.72, 0.72, 0.72)
	text_box.add_child(detail_label)

	if not equipped_item_id.is_empty():
		var button = Button.new()
		button.text = "Unequip"
		button.custom_minimum_size = Vector2(90, 32)
		button.pressed.connect(func(): _unequip_slot(slot_id))
		hbox.add_child(button)

	return panel

func _make_equipment_row(equipment_id: String, equip_data: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	root.add_child(top_row)

	var text_box = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 4)
	top_row.add_child(text_box)

	var name_label = Label.new()
	name_label.text = str(equip_data.get("name", equipment_id))
	name_label.add_theme_font_size_override("font_size", 16)
	text_box.add_child(name_label)

	var counts_label = Label.new()
	counts_label.text = "%s  |  Owned: %d  |  Equipped: %d  |  Available: %d" % [
		str(equip_data.get("type", "")),
		GameState.get_equipment_count(equipment_id),
		GameState.get_equipped_item_count(equipment_id),
		GameState.get_available_equipment_count(equipment_id)
	]
	counts_label.modulate = Color(0.72, 0.72, 0.72)
	text_box.add_child(counts_label)

	var desc_label = Label.new()
	desc_label.text = str(equip_data.get("description", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 10)
	text_box.add_child(desc_label)

	var cards = equip_data.get("cardIds", [])
	if not cards.is_empty():
		var grants_label = Label.new()
		grants_label.text = "Grants: %s" % _join_ids(cards)
		grants_label.add_theme_font_size_override("font_size", 10)
		grants_label.modulate = Color(0.85, 0.82, 0.62)
		text_box.add_child(grants_label)

	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)

	var valid_slots = GameState.get_valid_slots_for_equipment(equipment_id)
	if GameState.get_available_equipment_count(equipment_id) <= 0:
		actions.add_child(_make_inline_note("All owned copies are already equipped."))
	else:
		for slot_id in valid_slots:
			var target_slot_id = str(slot_id)
			var button = Button.new()
			button.text = "Equip %s" % _slot_label(target_slot_id)
			button.pressed.connect(func(): _equip_item(equipment_id, target_slot_id))
			actions.add_child(button)

	return panel

func _make_empty_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.modulate = Color(0.72, 0.72, 0.72)
	return label

func _make_inline_note(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(0.72, 0.72, 0.72)
	return label

func _unique_ids(items: Array) -> Array:
	var unique: Array = []
	for item_id in items:
		if not unique.has(item_id):
			unique.append(item_id)
	return unique

func _build_reserve_counts() -> Dictionary:
	var reserve_counts := {}
	var selected_counts := {}
	for card_id in GameState.deck:
		selected_counts[card_id] = int(selected_counts.get(card_id, 0)) + 1
	for card_id in GameState.owned_cards:
		var selected_count = int(selected_counts.get(card_id, 0))
		if selected_count > 0:
			selected_counts[card_id] = selected_count - 1
			continue
		reserve_counts[card_id] = int(reserve_counts.get(card_id, 0)) + 1
	return reserve_counts

func _add_reserved_card(card_id: String) -> void:
	if GameState.add_card_to_deck(card_id):
		status_message = "Added %s to the selected deck." % card_id
		GameState.save()
	else:
		status_message = "No extra owned copy is available to add."
	_refresh_content()

func _remove_selected_card(card_id: String) -> void:
	if GameState.remove_card_from_deck(card_id):
		status_message = "Removed %s from the selected deck." % card_id
		GameState.save()
	else:
		status_message = "That card was not in the selected deck."
	_refresh_content()

func _equip_item(equipment_id: String, slot_id: String) -> void:
	var result = GameState.equip_item(equipment_id, slot_id)
	status_message = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		GameState.save()
	_refresh_content()

func _unequip_slot(slot_id: String) -> void:
	if GameState.unequip_slot(slot_id):
		status_message = "Unequipped %s." % _slot_label(slot_id)
		GameState.save()
	else:
		status_message = "Nothing was equipped in that slot."
	_refresh_content()

func _slot_label(slot_id: String) -> String:
	return str(SLOT_LABELS.get(slot_id, slot_id))

func _join_ids(items: Array) -> String:
	var parts: Array[String] = []
	for item in items:
		parts.append(str(item))
	return ", ".join(parts)
