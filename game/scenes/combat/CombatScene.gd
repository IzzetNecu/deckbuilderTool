extends Control

@onready var combat_manager: Node = $CombatManager
@onready var hand_container: HBoxContainer = $HandArea/HandContainer
@onready var play_zone: Panel = $PlayZone
@onready var enemy_area: VBoxContainer = $EnemyArea
@onready var end_turn_btn: Button = $HUD/EndTurnButton
@onready var energy_label: Label = $HUD/EnergyLabel
@onready var player_hp_label: Label = $HUD/PlayerHPLabel
@onready var player_block_label: Label = $HUD/PlayerBlockLabel
@onready var phase_label: Label = $HUD/PhaseLabel

var card_scene = preload("res://scenes/combat/Card.tscn")
var enemy_unit_scene = preload("res://scenes/combat/EnemyUnit.tscn")
var enemy_unit_instance: Node = null

func _ready() -> void:
	combat_manager.phase_changed.connect(_on_phase_changed)
	combat_manager.player_hand_updated.connect(_on_hand_updated)
	combat_manager.enemy_hand_updated.connect(_on_enemy_hand_updated)
	combat_manager.stats_updated.connect(_on_stats_updated)
	combat_manager.combat_ended.connect(_on_combat_ended)

	end_turn_btn.pressed.connect(_on_end_turn_pressed)

	# Spawn enemy
	enemy_unit_instance = enemy_unit_scene.instantiate()
	enemy_area.add_child(enemy_unit_instance)
	enemy_unit_instance.combat_manager = combat_manager

	# Start combat
	combat_manager.start_combat(SceneManager.current_enemy_id)

func _on_phase_changed(phase: CombatManager.Phase) -> void:
	match phase:
		CombatManager.Phase.BEGINNING:
			phase_label.text = "Beginning Phase"
			end_turn_btn.disabled = true
		CombatManager.Phase.PLAY:
			phase_label.text = "Your Turn"
			end_turn_btn.disabled = false
		CombatManager.Phase.END:
			phase_label.text = "End Phase"
			end_turn_btn.disabled = true
		CombatManager.Phase.WIN:
			phase_label.text = "Victory!"
			end_turn_btn.disabled = true
		CombatManager.Phase.LOSE:
			phase_label.text = "Defeated..."
			end_turn_btn.disabled = true

func _on_hand_updated(hand: Array) -> void:
	# Clear existing hand cards
	for child in hand_container.get_children():
		child.queue_free()
	# Spawn card nodes
	for card_data in hand:
		var card_node = card_scene.instantiate()
		hand_container.add_child(card_node)
		card_node.setup(card_data, combat_manager, enemy_unit_instance)

func _on_enemy_hand_updated(hand: Array) -> void:
	if enemy_unit_instance:
		enemy_unit_instance.update_revealed_cards(hand)

func _on_stats_updated() -> void:
	energy_label.text = "Energy: %d / %d" % [combat_manager.player_energy, GameState.max_energy]
	player_hp_label.text = "HP: %d / %d" % [GameState.health, GameState.max_health]
	player_block_label.text = "Block: %d" % combat_manager.player_block
	$HUD/PlayerStrLabel.text = "STR: %d" % GameState.strength
	$HUD/PlayerDexLabel.text = "DEX: %d" % GameState.dexterity
	if enemy_unit_instance:
		enemy_unit_instance.update_stats(combat_manager.enemy_hp, combat_manager.enemy_max_hp, combat_manager.enemy_block)

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
