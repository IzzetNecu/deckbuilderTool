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

const CARD_TYPE_ORDER := {
	"attack": 0,
	"defend": 1,
	"skill": 2,
	"power": 3,
	"status": 4
}

var inventory_card_tile_scene = preload("res://scenes/ui/InventoryCardTile.tscn")
var inventory_drop_zone_script = preload("res://scenes/ui/InventoryDropZone.gd")

@onready var close_button: Button = $Window/VBox/Header/CloseButton
@onready var background: ColorRect = $Background
@onready var deck_tab: Button = $Window/VBox/Tabs/DeckTab
@onready var items_tab: Button = $Window/VBox/Tabs/ItemsTab
@onready var compendium_tab: Button = $Window/VBox/Tabs/CompendiumTab
@onready var content_grid: GridContainer = $Window/VBox/ContentScroll/Grid

var current_tab: String = "deck"
var status_message: String = ""

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	background.gui_input.connect(_on_background_input)
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
	stats.get_node("Ins").text = "INS: %d" % GameState.insight
	stats.get_node("Gold").text = "Gold: %d" % GameState.gold

func _on_close_pressed() -> void:
	if get_parent() is CanvasLayer:
		get_parent().queue_free()
	else:
		queue_free()

func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_close_pressed()

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

	var reserve_entries = _build_reserve_entries()
	var selected_entries = _build_selected_entries()
	var granted_entries = _build_granted_entries()

	var workspace = HBoxContainer.new()
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 10)

	var left_column = VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.size_flags_stretch_ratio = 1.1
	left_column.add_theme_constant_override("separation", 8)
	workspace.add_child(left_column)

	var center_column = VBoxContainer.new()
	center_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_column.size_flags_stretch_ratio = 1.0
	center_column.add_theme_constant_override("separation", 8)
	workspace.add_child(center_column)

	left_column.add_child(_make_note_panel("Deck Builder", _get_deck_summary_text()))
	left_column.add_child(_make_card_stack_section(
		"Card Catalog",
		"Drag reserve stacks into the current deck.",
		"reserve",
		reserve_entries,
		"No reserve cards. Your selected deck already uses every owned copy."
	))

	center_column.add_child(_make_card_stack_section(
		"Current Deck",
		"Drag selected stacks back to reserve to remove one copy.",
		"selected",
		selected_entries,
		"No selected cards."
	))
	center_column.add_child(_make_card_stack_section(
		"Granted by Equipment",
		"Locked stacks from equipped items.",
		"granted",
		granted_entries,
		"No equipped gear is granting cards right now."
	))

	content_grid.add_child(workspace)

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
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

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
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	vbox.add_child(body)
	panel.set_meta("body", body)
	return panel

func _make_card_stack_section(title: String, subtitle: String, section_id: String, entries: Array, empty_text: String) -> PanelContainer:
	var panel: InventoryDropZone = inventory_drop_zone_script.new()
	panel.configure(section_id, section_id != "granted")
	panel.card_dropped.connect(_on_drop_zone_card_dropped)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title_label)

	var subtitle_label = Label.new()
	subtitle_label.text = subtitle
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.modulate = Color(0.7, 0.7, 0.7)
	subtitle_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(subtitle_label)

	var flow = HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	vbox.add_child(flow)

	if entries.is_empty():
		flow.add_child(_make_empty_label(empty_text))
		return panel

	for entry in entries:
		flow.add_child(_make_card_tile(entry))
	return panel

func _make_card_tile(entry: Dictionary) -> Control:
	var tile: InventoryCardTile = inventory_card_tile_scene.instantiate()
	var action_text = ""
	var section = str(entry.get("section", ""))
	if str(entry.get("section", "")) == "reserve":
		action_text = "Add"
	elif str(entry.get("section", "")) == "selected":
		action_text = "Remove"

	tile.setup(entry.get("card_data", {}), {
		"compact": true,
		"locked": bool(entry.get("locked", false)),
		"draggable": str(entry.get("section", "")) != "granted",
		"drag_section": str(entry.get("section", "")),
		"count_text": "" if section == "reserve" or section == "selected" else str(entry.get("count_text", "")),
		"rules_text": str(entry.get("rules_text", "")),
		"tooltip_text": str(entry.get("tooltip_text", "")),
		"action_text": action_text,
		"action_enabled": bool(entry.get("action_enabled", false)),
		"stack_count": int(entry.get("copies", 1))
	})
	tile.action_pressed.connect(_on_deck_tile_action.bind(entry))

	if section != "reserve" and section != "selected":
		return tile

	var wrapper = VBoxContainer.new()
	wrapper.custom_minimum_size = Vector2(150, 0)
	wrapper.add_theme_constant_override("separation", 4)
	wrapper.mouse_filter = Control.MOUSE_FILTER_PASS
	wrapper.add_child(tile)

	var state_label = Label.new()
	state_label.text = str(entry.get("count_text", ""))
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_label.add_theme_font_size_override("font_size", 11)
	state_label.modulate = Color(0.84, 0.84, 0.84)
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(state_label)
	return wrapper

func _make_keyword_panel(keyword_entry: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var name_label = Label.new()
	var short_label = str(keyword_entry.get("shortLabel", ""))
	name_label.text = str(keyword_entry.get("name", "")) if short_label.is_empty() else "%s (%s)" % [
		str(keyword_entry.get("name", "")),
		short_label
	]
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	var reminder_label = Label.new()
	reminder_label.text = str(keyword_entry.get("reminderText", ""))
	reminder_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reminder_label.modulate = Color(0.84, 0.84, 0.84)
	vbox.add_child(reminder_label)
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
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(0.72, 0.72, 0.72)
	return label

func _make_inline_note(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(0.72, 0.72, 0.72)
	return label

func _build_selected_entries() -> Array:
	var selected_counts = _count_ids(GameState.deck)
	var granted_counts = _count_granted_cards_by_id()
	var entries: Array = []
	for card_id in selected_counts.keys():
		var card_data = GameData.get_card(str(card_id))
		if card_data.is_empty():
			continue
		var selected_count = int(selected_counts[card_id])
		var reserve_count = max(GameState.get_owned_card_count(str(card_id)) - selected_count, 0)
		entries.append(_build_card_entry(
			"selected",
			str(card_id),
			card_data,
			selected_count,
			"Selected x%d" % selected_count,
			"Reserve copies: %d  |  Effective combat copies: %d" % [
				reserve_count,
				selected_count + int(granted_counts.get(card_id, 0))
			],
			"Selected deck stack. Drag it to reserve to remove one copy if the deck stays above minimum size.",
			GameState.can_remove_card_from_deck(str(card_id)),
			false
		))
	entries.sort_custom(Callable(self, "_sort_card_entries"))
	return entries

func _build_reserve_entries() -> Array:
	var entries: Array = []
	var reserve_counts = _build_reserve_counts()
	for card_id in reserve_counts.keys():
		var card_data = GameData.get_card(str(card_id))
		if card_data.is_empty():
			continue
		var reserve_count = int(reserve_counts[card_id])
		entries.append(_build_card_entry(
			"reserve",
			str(card_id),
			card_data,
			reserve_count,
			"Reserve x%d" % reserve_count,
			"Owned copies not currently selected.",
			"Reserve stack. Drag it into the current deck to add one copy.",
			GameState.can_add_card_to_deck(str(card_id)),
			false
		))
	entries.sort_custom(Callable(self, "_sort_card_entries"))
	return entries

func _build_granted_entries() -> Array:
	var grouped := {}
	for entry in GameState.get_granted_card_entries():
		var card_id = str(entry.get("card_id", ""))
		if card_id.is_empty():
			continue
		if not grouped.has(card_id):
			grouped[card_id] = {
				"count": 0,
				"sources": []
			}
		grouped[card_id]["count"] = int(grouped[card_id]["count"]) + 1
		grouped[card_id]["sources"].append("%s (%s)" % [
			str(entry.get("equipment_name", entry.get("equipment_id", ""))),
			_slot_label(str(entry.get("slot", "")))
		])

	var entries: Array = []
	for card_id in grouped.keys():
		var card_data = GameData.get_card(str(card_id))
		if card_data.is_empty():
			continue
		var source_list = _unique_strings(grouped[card_id]["sources"])
		var source_text = ", ".join(source_list)
		entries.append(_build_card_entry(
			"granted",
			str(card_id),
			card_data,
			int(grouped[card_id]["count"]),
			"Granted x%d" % int(grouped[card_id]["count"]),
			source_text,
			"Granted by equipped items. These copies are locked and only appear in combat while the source gear stays equipped.",
			false,
			true,
			"Granted by: %s" % source_text
		))
	entries.sort_custom(Callable(self, "_sort_card_entries"))
	return entries

func _build_card_entry(section: String, card_id: String, card_data: Dictionary, copies: int, count_text: String, footer_text: String, detail_context: String, action_enabled: bool, locked: bool, tooltip_text: String = "") -> Dictionary:
	return {
		"section": section,
		"detail_key": "%s:%s" % [section, card_id],
		"card_id": card_id,
		"card_data": card_data,
		"count_text": count_text,
		"footer_text": footer_text,
		"detail_context": detail_context,
		"rules_text": GameState.get_preview_card_text(card_data),
		"keyword_entries": GameState.get_card_keyword_entries(card_data),
		"locked": locked,
		"tooltip_text": tooltip_text,
		"action_enabled": action_enabled,
		"copies": copies
	}

func _get_deck_summary_text() -> String:
	var selected_size = GameState.deck.size()
	var reserve_size = _count_total(_build_reserve_counts())
	var granted_size = GameState.get_granted_card_entries().size()
	var effective_size = GameState.get_effective_deck().size()
	var minimum_size = GameState.get_minimum_deck_size()
	return "Selected deck: %d cards  |  Reserve copies: %d  |  Granted by gear: %d  |  Effective combat deck: %d  |  Minimum progress: %d / %d" % [
		selected_size,
		reserve_size,
		granted_size,
		effective_size,
		min(selected_size, minimum_size),
		minimum_size
	]

func _count_ids(items: Array) -> Dictionary:
	var counts := {}
	for item_id in items:
		counts[item_id] = int(counts.get(item_id, 0)) + 1
	return counts

func _count_total(counts: Dictionary) -> int:
	var total := 0
	for value in counts.values():
		total += int(value)
	return total

func _count_granted_cards_by_id() -> Dictionary:
	var counts := {}
	for entry in GameState.get_granted_card_entries():
		var card_id = str(entry.get("card_id", ""))
		if card_id.is_empty():
			continue
		counts[card_id] = int(counts.get(card_id, 0)) + 1
	return counts

func _build_reserve_counts() -> Dictionary:
	var reserve_counts := {}
	var selected_counts := _count_ids(GameState.deck)
	for card_id in GameState.owned_cards:
		var selected_count = int(selected_counts.get(card_id, 0))
		if selected_count > 0:
			selected_counts[card_id] = selected_count - 1
			continue
		reserve_counts[card_id] = int(reserve_counts.get(card_id, 0)) + 1
	return reserve_counts

func _sort_card_entries(a: Dictionary, b: Dictionary) -> bool:
	var a_card = a.get("card_data", {})
	var b_card = b.get("card_data", {})
	var a_type = int(CARD_TYPE_ORDER.get(str(a_card.get("type", "")), 999))
	var b_type = int(CARD_TYPE_ORDER.get(str(b_card.get("type", "")), 999))
	if a_type != b_type:
		return a_type < b_type
	var a_cost = int(a_card.get("cost", 0))
	var b_cost = int(b_card.get("cost", 0))
	if a_cost != b_cost:
		return a_cost < b_cost
	return str(a_card.get("name", "")).naturalnocasecmp_to(str(b_card.get("name", ""))) < 0

func _on_deck_tile_action(_card_data: Dictionary, entry: Dictionary) -> void:
	var section = str(entry.get("section", ""))
	var card_id = str(entry.get("card_id", ""))
	match section:
		"reserve":
			_add_reserved_card(card_id)
		"selected":
			_remove_selected_card(card_id)

func _on_drop_zone_card_dropped(target_section: String, drag_data: Dictionary) -> void:
	var from_section = str(drag_data.get("from_section", ""))
	var card_id = str(drag_data.get("card_id", ""))
	if card_id.is_empty() or from_section == target_section:
		return

	match [from_section, target_section]:
		["reserve", "selected"]:
			_add_reserved_card(card_id)
		["selected", "reserve"]:
			_remove_selected_card(card_id)

func _unique_ids(items: Array) -> Array:
	var unique: Array = []
	for item_id in items:
		if not unique.has(item_id):
			unique.append(item_id)
	return unique

func _unique_strings(items: Array) -> Array:
	var unique: Array = []
	for item_text in items:
		var text_value = str(item_text)
		if not unique.has(text_value):
			unique.append(text_value)
	return unique

func _add_reserved_card(card_id: String) -> void:
	var card_name = str(GameData.get_card(card_id).get("name", card_id))
	if GameState.add_card_to_deck(card_id):
		status_message = "Added %s to the selected deck." % card_name
		GameState.save()
	else:
		status_message = "No extra owned copy of %s is available to add." % card_name
	_refresh_content()

func _remove_selected_card(card_id: String) -> void:
	var card_name = str(GameData.get_card(card_id).get("name", card_id))
	if GameState.remove_card_from_deck(card_id):
		status_message = "Removed %s from the selected deck." % card_name
		GameState.save()
	else:
		status_message = "Cannot remove %s below the minimum deck size of %d." % [
			card_name,
			GameState.get_minimum_deck_size()
		]
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
