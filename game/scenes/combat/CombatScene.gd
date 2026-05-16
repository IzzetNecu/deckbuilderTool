extends Control

const PREVIEW_SCALE := Vector2(2.1, 2.1)
const HAND_CARD_SIZE := Vector2(150, 225)
const INTENT_CARD_SIZE := HAND_CARD_SIZE
const INSPECTOR_CARD_SIZE := Vector2(156, 234)
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

@onready var combat_manager: Node = $CombatManager
@onready var hand_container: Control = $MainLayout/Rows/BottomRow/HandArea/HandClip/HandContainer
@onready var player_area: Control = $MainLayout/Rows/Battlefield/PlayerCluster/PlayerArea
@onready var enemy_area: Control = $MainLayout/Rows/Battlefield/EnemyCluster/EnemyArea
@onready var intent_cards_container: HBoxContainer = $MainLayout/Rows/Battlefield/CenterCluster/IntentPanel/IntentMargin/IntentCardsContainer
@onready var inventory_button: Button = $MainLayout/Rows/BottomRow/LeftControls/InventoryButton
@onready var deck_button: Button = $MainLayout/Rows/BottomRow/LeftControls/DeckButton
@onready var discard_button: Button = $MainLayout/Rows/BottomRow/LeftControls/DiscardButton
@onready var end_turn_btn: Button = $MainLayout/Rows/BottomRow/RightControls/EndTurnButton
@onready var hand_full_label: Label = $HUD/TopLeft/HandFullLabel
@onready var hud_layer: CanvasLayer = $HUD

var card_scene = preload("res://scenes/combat/Card.tscn")
var combatant_panel_scene = preload("res://scenes/combat/CombatantPanel.tscn")
var player_panel_instance: Control = null
var enemy_panel_instance: Control = null
var current_player_data: Dictionary = {}
var preview_overlay: Control = null
var preview_card_holder: Control = null
var preview_card_node: CombatCard = null
var preview_card_id: String = ""
var screen_overlay: Control = null
var overlay_content: VBoxContainer = null
var overlay_title_label: Label = null
var overlay_body: VBoxContainer = null
var overlay_state: String = ""
var overlay_tab: String = "consumables"
var inventory_context_menu: PopupMenu = null
var selected_consumable_id: String = ""
var hovered_hand_card: CombatCard = null
var hand_notice_serial: int = 0

func _ready() -> void:
	combat_manager.phase_changed.connect(_on_phase_changed)
	combat_manager.player_hand_updated.connect(_on_hand_updated)
	combat_manager.enemy_intent_updated.connect(_on_enemy_intent_updated)
	combat_manager.stats_updated.connect(_on_stats_updated)
	combat_manager.combat_ended.connect(_on_combat_ended)
	combat_manager.hand_full.connect(_on_hand_full)

	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	deck_button.pressed.connect(_on_deck_pressed)
	discard_button.pressed.connect(_on_discard_pressed)
	hand_container.resized.connect(Callable(self, "refresh_hand_layout"))

	_setup_preview_overlay()
	_setup_screen_overlay()

	current_player_data = GameData.get_player(GameState.player_id)

	player_panel_instance = combatant_panel_scene.instantiate()
	player_area.add_child(player_panel_instance)
	player_panel_instance.combat_manager = combat_manager
	player_panel_instance.configure("player", false)

	enemy_panel_instance = combatant_panel_scene.instantiate()
	enemy_area.add_child(enemy_panel_instance)
	enemy_panel_instance.combat_manager = combat_manager
	enemy_panel_instance.configure("enemy", false)

	combat_manager.start_combat(SceneManager.current_enemy_id)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if preview_overlay and preview_overlay.visible:
			hide_card_preview()
			get_viewport().set_input_as_handled()
			return
		if screen_overlay and screen_overlay.visible:
			_close_screen_overlay()
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hand_hover(event.global_position)

func _on_phase_changed(phase: CombatManager.Phase) -> void:
	match phase:
		CombatManager.Phase.BEGINNING:
			end_turn_btn.disabled = true
		CombatManager.Phase.PLAY:
			end_turn_btn.disabled = false
		CombatManager.Phase.END:
			end_turn_btn.disabled = true
		CombatManager.Phase.WIN:
			end_turn_btn.disabled = true
		CombatManager.Phase.LOSE:
			end_turn_btn.disabled = true
	if overlay_state == "inventory":
		_render_inventory_overlay()

func _on_hand_updated(hand: Array) -> void:
	hide_card_preview()
	hovered_hand_card = null
	for child in hand_container.get_children():
		hand_container.remove_child(child)
		child.queue_free()

	for card_data in hand:
		var card_node: CombatCard = card_scene.instantiate()
		card_node.custom_minimum_size = HAND_CARD_SIZE
		card_node.size = HAND_CARD_SIZE
		hand_container.add_child(card_node)
		card_node.setup(card_data, combat_manager, enemy_panel_instance)
		card_node.preview_requested.connect(_on_card_preview_requested)

	call_deferred("refresh_hand_layout")
	call_deferred("_refresh_hover_under_mouse")
	_update_pile_buttons()

func refresh_hand_layout() -> void:
	var cards: Array[CombatCard] = []
	for child in hand_container.get_children():
		if child is CombatCard:
			cards.append(child)
	if cards.is_empty():
		hovered_hand_card = null
		return

	var available_width = max(hand_container.size.x - HAND_CARD_SIZE.x, 0.0)
	var spacing = 0.0
	if cards.size() > 1:
		spacing = min(112.0, available_width / float(cards.size() - 1))
		spacing = max(spacing, 34.0)
	var total_width = HAND_CARD_SIZE.x + spacing * max(cards.size() - 1, 0)
	var start_x = max((hand_container.size.x - total_width) * 0.5, 0.0)
	var base_y = max(hand_container.size.y - HAND_CARD_SIZE.y - 8.0, 0.0)
	var hovered_index = cards.find(hovered_hand_card)

	for index in range(cards.size()):
		var card = cards[index]
		if card.get_parent() != hand_container:
			continue
		var normalized = 0.0
		if cards.size() > 1:
			normalized = float(index) / float(cards.size() - 1) - 0.5
		var hover_push = 0.0
		if hovered_index != -1 and hovered_index != index:
			hover_push = -12.0 if index < hovered_index else 12.0
		var hover_lift = 0.0
		if hovered_index == index:
			hover_lift = 26.0
		card.position = Vector2(start_x + spacing * index + hover_push, base_y + abs(normalized) * 16.0 - hover_lift)
		card.rotation_degrees = normalized * 9.0
		card.z_index = 100 if hovered_index == index else index
	call_deferred("_refresh_hover_under_mouse")

func is_point_over_hand_area(global_pos: Vector2) -> bool:
	var hand_area = hand_container.get_parent()
	var rect = Rect2(hand_area.global_position, hand_area.size)
	return rect.has_point(global_pos)

func _update_hand_hover(global_pos: Vector2) -> void:
	if screen_overlay and screen_overlay.visible:
		_set_hovered_hand_card(null)
		return
	if preview_overlay and preview_overlay.visible:
		_set_hovered_hand_card(null)
		return
	if not is_point_over_hand_area(global_pos):
		_set_hovered_hand_card(null)
		return

	var hovered: CombatCard = null
	var best_z := -1000000
	for child in hand_container.get_children():
		if not (child is CombatCard):
			continue
		var card := child as CombatCard
		if card.is_dragging:
			continue
		var local_point = card.get_global_transform().affine_inverse() * global_pos
		var rect = Rect2(Vector2.ZERO, card.size)
		if not rect.has_point(local_point):
			continue
		if hovered == null or card.z_index >= best_z:
			hovered = card
			best_z = card.z_index
	_set_hovered_hand_card(hovered)

func _set_hovered_hand_card(card: CombatCard) -> void:
	if hovered_hand_card == card:
		return
	hovered_hand_card = card
	refresh_hand_layout()

func clear_hand_hover() -> void:
	_set_hovered_hand_card(null)

func _refresh_hover_under_mouse() -> void:
	_update_hand_hover(get_global_mouse_position())

func _on_enemy_intent_updated(intent_slots: Array) -> void:
	for child in intent_cards_container.get_children():
		child.queue_free()

	for index in range(intent_slots.size()):
		var intent_slot = intent_slots[index]
		var preview_data: Dictionary
		if bool(intent_slot.get("is_hidden", false)):
			preview_data = {
				"id": "__enemy_hidden__",
				"name": "Hidden",
				"cardImage": "",
				"type": "intent",
				"targeting": "enemy",
				"cost": 0,
				"description": "?",
				"compact_description": "?",
				"preview_description": "This card is hidden from you. Gain more insight to reveal it.",
				"compact_cost_text": "",
				"preview_cost_text": "",
				"effects": [],
				"preview_key": "__enemy_hidden_%d" % index,
				"preview_source_side": "enemy"
			}
		else:
			preview_data = intent_slot.get("card", {}).duplicate(true)
			preview_data["preview_key"] = "enemy_intent_%d_%s" % [index, str(preview_data.get("id", "unknown"))]
			preview_data["preview_source_side"] = "enemy"
		var preview_card: CombatCard = card_scene.instantiate()
		preview_card.custom_minimum_size = INTENT_CARD_SIZE
		preview_card.size = INTENT_CARD_SIZE
		intent_cards_container.add_child(preview_card)
		preview_card.setup(preview_data, combat_manager, enemy_panel_instance, "enemy", false)
		preview_card.preview_requested.connect(_on_card_preview_requested)

func _on_stats_updated() -> void:
	for child in hand_container.get_children():
		if child.has_method("refresh_display"):
			child.refresh_display()
	if player_panel_instance:
		player_panel_instance.update_actor(
			combat_manager.get_player_name(),
			str(current_player_data.get("portraitImage", "")),
			combat_manager.get_player_current_hp(),
			combat_manager.get_player_max_hp(),
			combat_manager.get_player_block(),
			"Energy: %d / %d" % [combat_manager.player_energy, combat_manager.get_player_max_energy()],
			combat_manager.get_display_buffs("player")
		)
	if enemy_panel_instance:
		enemy_panel_instance.update_actor(
			combat_manager.get_enemy_name(),
			str(combat_manager.enemy_data.get("portraitImage", "")),
			combat_manager.get_enemy_current_hp(),
			combat_manager.get_enemy_max_hp(),
			combat_manager.get_enemy_block(),
			"INS: %d" % combat_manager.get_enemy_insight(),
			combat_manager.get_display_buffs("enemy")
		)
	_update_pile_buttons()
	if overlay_state == "deck":
		_open_card_overlay("Deck", combat_manager.get_draw_pile_cards(), "deck")
	elif overlay_state == "discard":
		_open_card_overlay("Discard", combat_manager.get_discard_pile_cards(), "discard")
	elif overlay_state == "inventory":
		_render_inventory_overlay()

func _on_end_turn_pressed() -> void:
	hide_card_preview()
	combat_manager.end_turn()

func _on_combat_ended(victory: bool) -> void:
	end_turn_btn.disabled = true
	if victory:
		await get_tree().create_timer(1.0).timeout
		_show_loot()
	else:
		await get_tree().create_timer(1.0).timeout
		SceneManager.load_map(GameState.current_map_id)

func _show_loot() -> void:
	var loot_scene = preload("res://scenes/combat/LootScreen.tscn").instantiate()
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.add_child(loot_scene)
	add_child(canvas_layer)
	loot_scene.setup(combat_manager.enemy_data.get("lootTable", []))

func hide_card_preview() -> void:
	if is_instance_valid(preview_card_node):
		preview_card_node.queue_free()
	preview_card_node = null
	preview_card_id = ""
	if preview_overlay:
		preview_overlay.visible = false

func _on_card_preview_requested(card_data: Dictionary) -> void:
	var requested_card_id = str(card_data.get("preview_key", card_data.get("id", "")))
	if preview_overlay and preview_overlay.visible and not requested_card_id.is_empty() and requested_card_id == preview_card_id:
		hide_card_preview()
		return

	hide_card_preview()
	_set_hovered_hand_card(null)
	preview_card_id = requested_card_id
	preview_overlay.visible = true
	if preview_overlay.get_parent():
		preview_overlay.get_parent().move_child(preview_overlay, preview_overlay.get_parent().get_child_count() - 1)

	var preview_card: CombatCard = card_scene.instantiate()
	preview_card.custom_minimum_size = HAND_CARD_SIZE
	preview_card.size = HAND_CARD_SIZE
	preview_card_holder.add_child(preview_card)
	preview_card.setup(card_data, combat_manager, enemy_panel_instance, str(card_data.get("preview_source_side", "player")), false)
	preview_card.set_preview_mode(true)
	preview_card.scale = PREVIEW_SCALE
	var preview_size = preview_card.custom_minimum_size * PREVIEW_SCALE
	preview_card.position = (preview_overlay.get_viewport_rect().size - preview_size) * 0.5
	preview_card_node = preview_card

func _setup_preview_overlay() -> void:
	preview_overlay = Control.new()
	preview_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_overlay.visible = false

	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.58)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_preview_backdrop_input)
	preview_overlay.add_child(backdrop)

	preview_card_holder = Control.new()
	preview_card_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_overlay.add_child(preview_card_holder)

	hud_layer.add_child(preview_overlay)

func _on_preview_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		hide_card_preview()

func _setup_screen_overlay() -> void:
	screen_overlay = Control.new()
	screen_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	screen_overlay.visible = false

	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.03, 0.04, 0.82)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_screen_overlay_backdrop_input)
	screen_overlay.add_child(backdrop)

	var panel = PanelContainer.new()
	panel.anchor_left = 0.08
	panel.anchor_top = 0.08
	panel.anchor_right = 0.92
	panel.anchor_bottom = 0.92
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	screen_overlay.add_child(panel)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	overlay_content = VBoxContainer.new()
	overlay_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_content.add_theme_constant_override("separation", 12)
	margin.add_child(overlay_content)

	var header = HBoxContainer.new()
	overlay_content.add_child(header)

	overlay_title_label = Label.new()
	overlay_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_title_label.add_theme_font_size_override("font_size", 20)
	header.add_child(overlay_title_label)

	var close_button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_close_screen_overlay)
	header.add_child(close_button)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_content.add_child(scroll)

	overlay_body = VBoxContainer.new()
	overlay_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_body.add_theme_constant_override("separation", 12)
	scroll.add_child(overlay_body)

	inventory_context_menu = PopupMenu.new()
	inventory_context_menu.id_pressed.connect(_on_inventory_context_id_pressed)
	screen_overlay.add_child(inventory_context_menu)

	hud_layer.add_child(screen_overlay)

func _clear_overlay_body() -> void:
	for child in overlay_body.get_children():
		child.queue_free()

func _on_inventory_pressed() -> void:
	overlay_tab = "consumables"
	_render_inventory_overlay()

func _on_deck_pressed() -> void:
	_open_card_overlay("Deck", combat_manager.get_draw_pile_cards(), "deck")

func _on_discard_pressed() -> void:
	_open_card_overlay("Discard", combat_manager.get_discard_pile_cards(), "discard")

func _open_card_overlay(title: String, cards: Array, state: String) -> void:
	hide_card_preview()
	_set_hovered_hand_card(null)
	overlay_state = state
	screen_overlay.visible = true
	overlay_title_label.text = title
	_clear_overlay_body()

	var note = Label.new()
	note.text = "%d cards" % cards.size()
	note.modulate = Color(0.82, 0.82, 0.82)
	overlay_body.add_child(note)

	if cards.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No cards here."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(0, 240)
		overlay_body.add_child(empty_label)
		return

	var grid = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	overlay_body.add_child(grid)

	for index in range(cards.size()):
		var card_data = cards[index].duplicate(true)
		card_data["preview_key"] = "%s_%d_%s" % [state, index, str(card_data.get("id", "card"))]
		var card_node: CombatCard = card_scene.instantiate()
		card_node.custom_minimum_size = INSPECTOR_CARD_SIZE
		card_node.size = INSPECTOR_CARD_SIZE
		grid.add_child(card_node)
		card_node.setup(card_data, combat_manager, enemy_panel_instance, "player", false)
		card_node.preview_requested.connect(_on_card_preview_requested)

func _render_inventory_overlay() -> void:
	hide_card_preview()
	_set_hovered_hand_card(null)
	overlay_state = "inventory"
	screen_overlay.visible = true
	overlay_title_label.text = "Combat Inventory"
	_clear_overlay_body()

	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	overlay_body.add_child(tabs)

	var consumables_button = Button.new()
	consumables_button.text = "Consumables"
	consumables_button.disabled = overlay_tab == "consumables"
	consumables_button.pressed.connect(func(): _switch_inventory_tab("consumables"))
	tabs.add_child(consumables_button)

	var equipment_button = Button.new()
	equipment_button.text = "Equipment"
	equipment_button.disabled = overlay_tab == "equipment"
	equipment_button.pressed.connect(func(): _switch_inventory_tab("equipment"))
	tabs.add_child(equipment_button)

	match overlay_tab:
		"equipment":
			_render_inventory_equipment()
		_:
			_render_inventory_consumables()

func _switch_inventory_tab(tab_name: String) -> void:
	overlay_tab = tab_name
	_render_inventory_overlay()

func _render_inventory_consumables() -> void:
	var info = Label.new()
	info.text = "Click a consumable to open Use / Discard. Use is only enabled during your turn."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.modulate = Color(0.82, 0.82, 0.82)
	overlay_body.add_child(info)

	var seen: Dictionary = {}
	for consumable_id in GameState.consumables:
		seen[str(consumable_id)] = true

	if seen.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No consumables owned."
		empty_label.custom_minimum_size = Vector2(0, 180)
		overlay_body.add_child(empty_label)
		return

	for consumable_id in seen.keys():
		var item = GameData.get_consumable(str(consumable_id))
		if item.is_empty():
			continue
		var row = Button.new()
		row.text = "%s  x%d\n%s" % [
			str(item.get("name", consumable_id)),
			GameState.get_consumable_count(consumable_id),
			str(item.get("description", ""))
		]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(0, 68)
		row.pressed.connect(func(): _open_consumable_context(str(consumable_id), row))
		overlay_body.add_child(row)

func _render_inventory_equipment() -> void:
	var equipped_label = Label.new()
	equipped_label.text = "Equipped Reference"
	equipped_label.add_theme_font_size_override("font_size", 18)
	overlay_body.add_child(equipped_label)

	for slot_id in GameState.SLOT_ORDER:
		var equipment_id = GameState.get_slot_item(slot_id)
		var item = GameData.get_equipment(equipment_id)
		var row = Label.new()
		if item.is_empty():
			row.text = "%s: Empty" % SLOT_LABELS.get(slot_id, slot_id)
		else:
			row.text = "%s: %s" % [SLOT_LABELS.get(slot_id, slot_id), str(item.get("name", equipment_id))]
		overlay_body.add_child(row)

	var bag_label = Label.new()
	bag_label.text = "Owned Equipment"
	bag_label.add_theme_font_size_override("font_size", 18)
	overlay_body.add_child(bag_label)

	var counts: Dictionary = {}
	for equipment_id in GameState.equipment:
		counts[str(equipment_id)] = int(counts.get(str(equipment_id), 0)) + 1
	if counts.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No owned equipment."
		overlay_body.add_child(empty_label)
		return
	for equipment_id in counts.keys():
		var item = GameData.get_equipment(equipment_id)
		var row = Label.new()
		row.text = "%s x%d" % [str(item.get("name", equipment_id)), int(counts[equipment_id])]
		overlay_body.add_child(row)

func _open_consumable_context(consumable_id: String, source_button: Button) -> void:
	selected_consumable_id = consumable_id
	inventory_context_menu.clear()
	inventory_context_menu.add_item("Use", 0)
	inventory_context_menu.add_item("Discard", 1)
	inventory_context_menu.set_item_disabled(0, not combat_manager.can_use_consumable(consumable_id))
	inventory_context_menu.position = source_button.global_position + Vector2(18, 18)
	inventory_context_menu.popup()

func _on_inventory_context_id_pressed(id: int) -> void:
	match id:
		0:
			combat_manager.use_consumable(selected_consumable_id)
		1:
			combat_manager.discard_consumable(selected_consumable_id)
	_render_inventory_overlay()

func _close_screen_overlay() -> void:
	overlay_state = ""
	screen_overlay.visible = false
	inventory_context_menu.hide()

func _on_screen_overlay_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_close_screen_overlay()

func _update_pile_buttons() -> void:
	deck_button.text = "Deck (%d)" % combat_manager.draw_pile.size()
	discard_button.text = "Discard (%d)" % combat_manager.discard_pile.size()
	inventory_button.text = "Inventory (%d)" % GameState.consumables.size()

func _on_hand_full(message: String) -> void:
	hand_notice_serial += 1
	var notice_id = hand_notice_serial
	hand_full_label.text = message
	hand_full_label.visible = true
	_hide_hand_full_later(notice_id)

func _hide_hand_full_later(notice_id: int) -> void:
	await get_tree().create_timer(3.0).timeout
	if notice_id == hand_notice_serial:
		hand_full_label.visible = false
