extends Node

enum Phase { BEGINNING, PLAY, END, WIN, LOSE }

var current_phase: Phase = Phase.BEGINNING
var enemy_data: Dictionary = {}
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var enemy_block: int = 0
var enemy_deck: Array = []       # full card id list (shuffled at start)
var enemy_draw_pile: Array = []
var enemy_discard_pile: Array = []
var enemy_hand: Array = []       # card dicts revealed to player this turn

var player_block: int = 0
var player_energy: int = 0
var player_hand: Array = []      # card dicts in hand
var draw_pile: Array = []
var discard_pile: Array = []

signal phase_changed(new_phase: Phase)
signal player_hand_updated(hand: Array)
signal enemy_hand_updated(hand: Array)
signal stats_updated()
signal combat_ended(victory: bool)

# ──────────────────────────────────────────────
#  Setup
# ──────────────────────────────────────────────
func start_combat(enemy_id: String) -> void:
	enemy_data = GameData.get_enemy(enemy_id)
	enemy_hp = enemy_data.get("hp", 10)
	enemy_max_hp = enemy_hp
	enemy_block = 0
	player_block = 0

	# Build enemy deck from templates first, then individual extra cards
	enemy_deck = []
	for tmpl_id in enemy_data.get("deckTemplateIds", []):
		var tmpl = GameData.deck_templates.get(tmpl_id, {})
		for card_id in tmpl.get("cardIds", []):
			enemy_deck.append(card_id)
	# Then add individual extra cards
	for card_id in enemy_data.get("deckIds", []):
		enemy_deck.append(card_id)
	enemy_draw_pile = enemy_deck.duplicate()
	enemy_draw_pile.shuffle()
	enemy_discard_pile = []
	enemy_hand = []

	# Build player draw pile from GameState deck
	draw_pile = GameState.deck.duplicate()
	draw_pile.shuffle()
	discard_pile = []
	player_hand = []

	_begin_phase()

# ──────────────────────────────────────────────
#  Phase: BEGINNING
# ──────────────────────────────────────────────
func _begin_phase() -> void:
	current_phase = Phase.BEGINNING
	phase_changed.emit(current_phase)

	player_block = 0
	enemy_block = 0
	player_energy = GameState.max_energy

	# Player draws hand
	_draw_player_cards(GameState.hand_size)

	# Enemy draws and reveals their hand
	_draw_enemy_cards(enemy_data.get("hand_size", 3))

	stats_updated.emit()
	_go_to_play()

func _draw_player_cards(count: int) -> void:
	for i in range(count):
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			draw_pile.shuffle()
			discard_pile = []
		var card_id = draw_pile.pop_front()
		var card_data = GameData.get_card(card_id)
		if card_data:
			player_hand.append(card_data)
	player_hand_updated.emit(player_hand)

func _draw_enemy_cards(count: int) -> void:
	enemy_hand = []
	for i in range(count):
		if enemy_draw_pile.is_empty():
			if enemy_discard_pile.is_empty():
				break
			enemy_draw_pile = enemy_discard_pile.duplicate()
			enemy_draw_pile.shuffle()
			enemy_discard_pile = []
		var card_id = enemy_draw_pile.pop_front()
		var card_data = GameData.get_card(card_id)
		if card_data:
			enemy_hand.append(card_data)
	enemy_hand_updated.emit(enemy_hand)

# ──────────────────────────────────────────────
#  Phase: PLAY
# ──────────────────────────────────────────────
func _go_to_play() -> void:
	current_phase = Phase.PLAY
	phase_changed.emit(current_phase)

func play_card(card_data: Dictionary, target: String = "enemy") -> bool:
	if current_phase != Phase.PLAY:
		return false
	var cost = card_data.get("cost", 0)
	if player_energy < cost:
		return false

	player_energy -= cost
	player_hand.erase(card_data)
	discard_pile.append(card_data.get("id", ""))

	for effect in card_data.get("effects", []):
		_apply_effect(effect, "player", target)

	player_hand_updated.emit(player_hand)
	stats_updated.emit()
	_check_win_lose()
	return true

func end_turn() -> void:
	if current_phase != Phase.PLAY:
		return
	_end_phase()

# ──────────────────────────────────────────────
#  Phase: END
# ──────────────────────────────────────────────
func _end_phase() -> void:
	current_phase = Phase.END
	phase_changed.emit(current_phase)

	# Discard player hand
	for card in player_hand:
		discard_pile.append(card.get("id", ""))
	player_hand = []
	player_hand_updated.emit(player_hand)

	# Enemy plays their revealed hand in order
	for card in enemy_hand:
		for effect in card.get("effects", []):
			_apply_effect(effect, "enemy", "player")
		enemy_discard_pile.append(card.get("id", ""))
	enemy_hand = []
	enemy_hand_updated.emit(enemy_hand)

	stats_updated.emit()

	if _check_win_lose():
		return

	# Small delay then next turn
	await get_tree().create_timer(0.8).timeout
	_begin_phase()

# ──────────────────────────────────────────────
#  Effect application
# ──────────────────────────────────────────────
func _apply_effect(effect, source: String, target: String) -> void:
	# Effects can be plain strings OR objects {value, scalesWith}
	var effect_str: String
	var scales_with: String = "none"
	if effect is Dictionary:
		effect_str = effect.get("value", "")
		scales_with = effect.get("scalesWith", "none")
	else:
		effect_str = str(effect)

	var parts = effect_str.split(":")
	if parts.size() < 2:
		return
	var type = parts[0]
	var base_value = int(parts[1])

	# Apply stat scaling
	var bonus = 0
	if scales_with != "none":
		if source == "player":
			bonus = int(GameState.get(scales_with) if GameState.get(scales_with) != null else 0)
		else:
			# Enemies don't have individual stats — no bonus for now
			bonus = 0
	var value = base_value + bonus

	match type:
		"ATTACK":
			var dmg = max(0, value)
			if target == "enemy":
				var absorbed = min(dmg, enemy_block)
				enemy_block -= absorbed
				dmg -= absorbed
				enemy_hp = max(0, enemy_hp - dmg)
			elif target == "player":
				var absorbed = min(dmg, player_block)
				player_block -= absorbed
				dmg -= absorbed
				GameState.health = max(0, GameState.health - dmg)

		"DEFEND":
			var shield = max(0, value)
			if source == "player":
				player_block += shield
			else:
				enemy_block += shield

		"HEAL":
			if source == "player":
				GameState.health = min(GameState.max_health, GameState.health + value)
			else:
				enemy_hp = min(enemy_max_hp, enemy_hp + value)

# ──────────────────────────────────────────────
#  Win / Lose check
# ──────────────────────────────────────────────
func _check_win_lose() -> bool:
	if enemy_hp <= 0:
		current_phase = Phase.WIN
		phase_changed.emit(current_phase)
		combat_ended.emit(true)
		return true
	if GameState.health <= 0:
		current_phase = Phase.LOSE
		phase_changed.emit(current_phase)
		combat_ended.emit(false)
		return true
	return false

# Helper for UI
func get_enemy_hp_ratio() -> float:
	if enemy_max_hp <= 0:
		return 0.0
	return float(enemy_hp) / float(enemy_max_hp)
