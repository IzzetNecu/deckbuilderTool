extends Control

@onready var close_button: Button = $Window/VBox/Header/CloseButton
@onready var deck_tab: Button = $Window/VBox/Tabs/DeckTab
@onready var items_tab: Button = $Window/VBox/Tabs/ItemsTab
@onready var compendium_tab: Button = $Window/VBox/Tabs/CompendiumTab
@onready var content_grid: GridContainer = $Window/VBox/ContentScroll/Grid

var current_tab: String = "deck"

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	deck_tab.pressed.connect(func(): _switch_tab("deck"))
	items_tab.pressed.connect(func(): _switch_tab("items"))
	compendium_tab.pressed.connect(func(): _switch_tab("compendium"))
	
	_switch_tab("deck")

func _on_close_pressed() -> void:
	# If this is inside a CanvasLayer (created by SceneManager), we should free that too
	if get_parent() is CanvasLayer:
		get_parent().queue_free()
	else:
		queue_free()

func _switch_tab(tab_name: String) -> void:
	current_tab = tab_name
	
	# Update button states
	deck_tab.button_pressed = (tab_name == "deck")
	items_tab.button_pressed = (tab_name == "items")
	compendium_tab.button_pressed = (tab_name == "compendium")
	
	_refresh_content()

func _refresh_content() -> void:
	# Clear grid
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
	content_grid.columns = 4
	for card_id in GameState.deck:
		var card_data = GameData.get_card(card_id)
		if card_data:
			var card_scene = preload("res://scenes/combat/Card.tscn").instantiate()
			content_grid.add_child(card_scene)
			card_scene.setup(card_data, null, null)
			# Disable dragging in inventory
			card_scene.set_process_input(false)
			card_scene.mouse_filter = Control.MOUSE_FILTER_PASS

func _show_items() -> void:
	content_grid.columns = 2
	
	# Consumables
	for item_id in GameState.consumables:
		var data = GameData.get_consumable(item_id)
		if data:
			_add_item_entry(data, "Consumable")
			
	# Equipment
	for item_id in GameState.equipment:
		var data = GameData.get_equipment(item_id)
		if data:
			_add_item_entry(data, "Equipment")

func _add_item_entry(data: Dictionary, type: String) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 80)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)
	
	var vbox = VBoxContainer.new()
	hbox.add_child(vbox)
	
	var name_lbl = Label.new()
	name_lbl.text = data.get("name", "Unknown")
	name_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_lbl)
	
	var type_lbl = Label.new()
	type_lbl.text = type
	type_lbl.modulate = Color(0.7, 0.7, 0.7)
	type_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(type_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = data.get("description", "")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(desc_lbl)
	
	content_grid.add_child(panel)

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
