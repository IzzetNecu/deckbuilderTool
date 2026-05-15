extends Control

@onready var combat_manager: Node = $CombatManager
@onready var hand_container: HBoxContainer = $HandArea/HandContainer
@onready var player_area: Control = $Battlefield/PlayerArea
@onready var enemy_area: Control = $Battlefield/EnemyArea
@onready var end_turn_btn: Button = $HUD/EndTurnButton
@onready var phase_label: Label = $HUD/TopLeft/PhaseLabel

var card_scene = preload("res://scenes/combat/Card.tscn")
var combatant_panel_scene = preload("res://scenes/combat/CombatantPanel.tscn")
var player_panel_instance: Control = null
var enemy_panel_instance: Control = null
var current_player_data: Dictionary = {}

func _ready() -> void:
	combat_manager.phase_changed.connect(_on_phase_changed)
	combat_manager.player_hand_updated.connect(_on_hand_updated)
	combat_manager.enemy_intent_updated.connect(_on_enemy_intent_updated)
	combat_manager.stats_updated.connect(_on_stats_updated)
	combat_manager.combat_ended.connect(_on_combat_ended)

	end_turn_btn.pressed.connect(_on_end_turn_pressed)

	current_player_data = GameData.get_player(GameState.player_id)

	player_panel_instance = combatant_panel_scene.instantiate()
	player_area.add_child(player_panel_instance)
	player_panel_instance.combat_manager = combat_manager
	player_panel_instance.configure("player", false)

	enemy_panel_instance = combatant_panel_scene.instantiate()
	enemy_area.add_child(enemy_panel_instance)
	enemy_panel_instance.combat_manager = combat_manager
	enemy_panel_instance.configure("enemy", true)
	_move_end_turn_button_to_enemy_panel()

	combat_manager.start_combat(SceneManager.current_enemy_id)

func _move_end_turn_button_to_enemy_panel() -> void:
	if not enemy_panel_instance:
		return
	var enemy_action_slot: Node = enemy_panel_instance.call("get_action_slot")
	if enemy_action_slot == null or end_turn_btn.get_parent() == enemy_action_slot:
		return
	end_turn_btn.get_parent().remove_child(end_turn_btn)
	enemy_action_slot.add_child(end_turn_btn)

func _on_phase_changed(phase: CombatManager.Phase) -> void:
	match phase:
		CombatManager.Phase.BEGINNING:
			phase_label.text = "Beginning Phase"
			end_turn_btn.disabled = true
		CombatManager.Phase.PLAY:
			phase_label.text = "Your Turn"
			end_turn_btn.disabled = false
		CombatManager.Phase.END:
			phase_label.text = "Enemy Turn"
			end_turn_btn.disabled = true
		CombatManager.Phase.WIN:
			phase_label.text = "Victory!"
			end_turn_btn.disabled = true
		CombatManager.Phase.LOSE:
			phase_label.text = "Defeated..."
			end_turn_btn.disabled = true

func _on_hand_updated(hand: Array) -> void:
	for child in hand_container.get_children():
		child.queue_free()

	for card_data in hand:
		var card_node = card_scene.instantiate()
		hand_container.add_child(card_node)
		card_node.setup(card_data, combat_manager, enemy_panel_instance)

func _on_enemy_intent_updated(intent_slots: Array) -> void:
	if enemy_panel_instance:
		enemy_panel_instance.update_intent_slots(intent_slots)

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
			_build_player_buffs()
		)
	if enemy_panel_instance:
		enemy_panel_instance.update_actor(
			combat_manager.get_enemy_name(),
			str(combat_manager.enemy_data.get("portraitImage", "")),
			combat_manager.get_enemy_current_hp(),
			combat_manager.get_enemy_max_hp(),
			combat_manager.get_enemy_block(),
			"",
			_build_enemy_buffs()
		)

func _build_player_buffs() -> Array:
	return combat_manager.get_display_buffs("player")

func _build_enemy_buffs() -> Array:
	return combat_manager.get_display_buffs("enemy")

func _on_end_turn_pressed() -> void:
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
