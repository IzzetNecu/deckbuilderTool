extends Node
class_name CombatManager

enum Phase { BEGINNING, PLAY, END, WIN, LOSE }

var current_phase: Phase = Phase.BEGINNING
var enemy_data: Dictionary = {}

var player_actor: Dictionary = {}
var enemy_actor: Dictionary = {}

var player_energy: int = 0
var player_hand: Array = []
var draw_pile: Array = []
var discard_pile: Array = []
var exhaust_pile: Array = []

var enemy_draw_pile: Array = []
var enemy_discard_pile: Array = []
var enemy_pending_cards: Array = []
var enemy_intent_slots: Array = []

signal phase_changed(new_phase: Phase)
signal player_hand_updated(hand: Array)
signal enemy_intent_updated(intent_slots: Array)
signal stats_updated()
signal combat_ended(victory: bool)

func start_combat(enemy_id: String) -> void:
	enemy_data = GameData.get_enemy(enemy_id)
	if enemy_data.is_empty():
		push_error("CombatManager: Enemy not found: " + enemy_id)
		return

	var player_data = GameData.get_player(GameState.player_id)
	player_actor = {
		"name": str(player_data.get("name", "Player")),
		"current_hp": GameState.health,
		"max_hp": GameState.max_health,
		"block": 0,
		"stats": {
			"strength": GameState.strength,
			"dexterity": GameState.dexterity,
			"insight": GameState.insight,
			"max_energy": GameState.max_energy,
			"hand_size": GameState.hand_size
		}
	}
	var enemy_stats = enemy_data.get("stats", {})
	enemy_actor = {
		"name": enemy_data.get("name", "Enemy"),
		"current_hp": int(enemy_stats.get("maxHealth", enemy_data.get("hp", 10))),
		"max_hp": int(enemy_stats.get("maxHealth", enemy_data.get("hp", 10))),
		"block": 0,
		"stats": {
			"strength": int(enemy_stats.get("strength", 0)),
			"dexterity": int(enemy_stats.get("dexterity", 0)),
			"insight": int(enemy_stats.get("insight", 0)),
			"hand_size": int(enemy_data.get("handSize", enemy_data.get("hand_size", 2)))
		}
	}

	draw_pile = GameState.deck.duplicate()
	draw_pile.shuffle()
	discard_pile = []
	exhaust_pile = []
	player_hand = []

	var enemy_deck: Array = []
	for template_id in enemy_data.get("deckTemplateIds", []):
		var template = GameData.deck_templates.get(template_id, {})
		for card_id in template.get("cardIds", []):
			enemy_deck.append(card_id)
	for card_id in enemy_data.get("deckIds", []):
		enemy_deck.append(card_id)
	enemy_draw_pile = enemy_deck
	enemy_draw_pile.shuffle()
	enemy_discard_pile = []
	enemy_pending_cards = []
	enemy_intent_slots = []

	_begin_phase()

func _begin_phase() -> void:
	current_phase = Phase.BEGINNING
	phase_changed.emit(current_phase)

	player_actor["block"] = 0
	player_energy = get_player_max_energy()
	player_hand = []

	_draw_player_cards(get_player_hand_size())
	_prepare_enemy_intent()
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
		if not card_data.is_empty():
			player_hand.append(card_data)
	player_hand_updated.emit(player_hand)

func _prepare_enemy_intent() -> void:
	enemy_pending_cards = []
	var draw_count = int(enemy_actor["stats"].get("hand_size", 2))
	for i in range(draw_count):
		if enemy_draw_pile.is_empty():
			if enemy_discard_pile.is_empty():
				break
			enemy_draw_pile = enemy_discard_pile.duplicate()
			enemy_draw_pile.shuffle()
			enemy_discard_pile = []
		var card_id = enemy_draw_pile.pop_front()
		var card_data = GameData.get_card(card_id)
		if not card_data.is_empty():
			enemy_pending_cards.append(card_data)

	_refresh_enemy_reveal()

func _refresh_enemy_reveal() -> void:
	var insight_advantage = max(get_player_insight() - get_enemy_insight(), 0)
	var base_preview = int(enemy_data.get("intentPreviewCount", 0))
	var reveal_count = min(enemy_pending_cards.size(), base_preview + insight_advantage)
	enemy_intent_slots = []
	for index in range(enemy_pending_cards.size()):
		var is_revealed = index < reveal_count
		var intent_slot = {
			"is_hidden": not is_revealed
		}
		if is_revealed:
			intent_slot["card"] = enemy_pending_cards[index]
		enemy_intent_slots.append(intent_slot)
	enemy_intent_updated.emit(enemy_intent_slots)

func _go_to_play() -> void:
	current_phase = Phase.PLAY
	phase_changed.emit(current_phase)

func play_card(card_data: Dictionary, target: String = "enemy") -> bool:
	if current_phase != Phase.PLAY:
		return false
	if not _is_valid_play_target(card_data, target):
		return false
	var cost = int(card_data.get("cost", 0))
	if player_energy < cost:
		return false

	player_energy -= cost
	player_hand.erase(card_data)
	discard_pile.append(card_data.get("id", ""))

	for effect in card_data.get("effects", []):
		_apply_effect(effect, "player", target)
		if _check_win_lose():
			player_hand_updated.emit(player_hand)
			stats_updated.emit()
			return true

	player_hand_updated.emit(player_hand)
	stats_updated.emit()
	_check_win_lose()
	return true

func end_turn() -> void:
	if current_phase != Phase.PLAY:
		return
	_end_phase()

func _end_phase() -> void:
	current_phase = Phase.END
	phase_changed.emit(current_phase)

	for card in player_hand:
		discard_pile.append(card.get("id", ""))
	player_hand = []
	player_hand_updated.emit(player_hand)

	# Enemy block drops when the enemy turn begins, not at the start of the player's turn.
	enemy_actor["block"] = 0
	stats_updated.emit()

	for card in enemy_pending_cards:
		for effect in card.get("effects", []):
			_apply_effect(effect, "enemy")
			if _check_win_lose():
				return
		enemy_discard_pile.append(card.get("id", ""))
	enemy_pending_cards = []
	enemy_intent_slots = []
	enemy_intent_updated.emit(enemy_intent_slots)

	stats_updated.emit()
	if _check_win_lose():
		return

	await get_tree().create_timer(0.8).timeout
	_begin_phase()

func _apply_effect(effect: Dictionary, source_side: String, target_hint: String = "") -> void:
	var effect_target = str(effect.get("target", target_hint if not target_hint.is_empty() else "self"))
	var target_actor = _resolve_target_actor(source_side, effect_target)
	var amount = _resolve_effect_amount(effect, source_side)
	match str(effect.get("type", "")):
		"damage":
			_apply_damage(target_actor, amount)
		"block":
			target_actor["block"] = int(target_actor.get("block", 0)) + max(amount, 0)
		"heal":
			target_actor["current_hp"] = min(int(target_actor.get("max_hp", 0)), int(target_actor.get("current_hp", 0)) + amount)
		"draw":
			if source_side == "player":
				_draw_player_cards(amount)
		"discard":
			if source_side == "player":
				_discard_from_player_hand(amount)
		"gain_energy":
			if source_side == "player":
				player_energy += amount
		"modify_insight":
			var stats = target_actor.get("stats", {})
			stats["insight"] = int(stats.get("insight", 0)) + amount
			target_actor["stats"] = stats
			_refresh_enemy_reveal()
	_update_persistent_health()

func _apply_damage(target_actor: Dictionary, amount: int) -> void:
	var remaining = max(amount, 0)
	var absorbed = min(remaining, int(target_actor.get("block", 0)))
	target_actor["block"] = int(target_actor.get("block", 0)) - absorbed
	remaining -= absorbed
	target_actor["current_hp"] = max(0, int(target_actor.get("current_hp", 0)) - remaining)

func _discard_from_player_hand(count: int) -> void:
	for i in range(min(count, player_hand.size())):
		var card = player_hand.pop_back()
		discard_pile.append(card.get("id", ""))
	player_hand_updated.emit(player_hand)

func _resolve_effect_amount(effect: Dictionary, source_side: String) -> int:
	var source_actor = _get_actor(source_side)
	var scaling = str(effect.get("scaling", "none"))
	var amount = int(effect.get("amount", 0))
	if scaling != "none":
		amount += int(source_actor.get("stats", {}).get(scaling, 0))
	return amount

func _is_valid_play_target(card_data: Dictionary, played_target: String) -> bool:
	var targeting = str(card_data.get("targeting", "self"))
	match targeting:
		"single_enemy", "random_enemy", "all_enemies":
			return played_target == "enemy"
		"self", "none":
			return played_target == "self" or played_target.is_empty()
	return true

func _resolve_target_actor(source_side: String, target_key: String) -> Dictionary:
	if target_key == "enemy" or target_key == "all_enemies" or target_key == "random_enemy":
		return enemy_actor if source_side == "player" else player_actor
	return _get_actor(source_side)

func _get_actor(side: String) -> Dictionary:
	return player_actor if side == "player" else enemy_actor

func _update_persistent_health() -> void:
	GameState.health = get_player_current_hp()

func _check_win_lose() -> bool:
	_update_persistent_health()
	if get_enemy_current_hp() <= 0:
		current_phase = Phase.WIN
		phase_changed.emit(current_phase)
		combat_ended.emit(true)
		GameState.save()
		return true
	if get_player_current_hp() <= 0:
		current_phase = Phase.LOSE
		phase_changed.emit(current_phase)
		combat_ended.emit(false)
		GameState.save()
		return true
	return false

func get_player_current_hp() -> int:
	return int(player_actor.get("current_hp", 0))

func get_player_name() -> String:
	return str(player_actor.get("name", "Player"))

func get_player_max_hp() -> int:
	return int(player_actor.get("max_hp", 0))

func get_player_block() -> int:
	return int(player_actor.get("block", 0))

func get_player_strength() -> int:
	return int(player_actor.get("stats", {}).get("strength", 0))

func get_player_dexterity() -> int:
	return int(player_actor.get("stats", {}).get("dexterity", 0))

func get_player_insight() -> int:
	return int(player_actor.get("stats", {}).get("insight", 0))

func get_player_max_energy() -> int:
	return int(player_actor.get("stats", {}).get("max_energy", 0))

func get_player_hand_size() -> int:
	return int(player_actor.get("stats", {}).get("hand_size", 5))

func get_enemy_current_hp() -> int:
	return int(enemy_actor.get("current_hp", 0))

func get_enemy_max_hp() -> int:
	return int(enemy_actor.get("max_hp", 0))

func get_enemy_block() -> int:
	return int(enemy_actor.get("block", 0))

func get_enemy_strength() -> int:
	return int(enemy_actor.get("stats", {}).get("strength", 0))

func get_enemy_dexterity() -> int:
	return int(enemy_actor.get("stats", {}).get("dexterity", 0))

func get_enemy_insight() -> int:
	return int(enemy_actor.get("stats", {}).get("insight", 0))

func get_enemy_name() -> String:
	return str(enemy_actor.get("name", "Enemy"))

func get_enemy_hp_ratio() -> float:
	if get_enemy_max_hp() <= 0:
		return 0.0
	return float(get_enemy_current_hp()) / float(get_enemy_max_hp())

func get_card_text(card_data: Dictionary, source_side: String) -> String:
	var description = str(card_data.get("description", ""))
	for effect in card_data.get("effects", []):
		var amount = str(_resolve_effect_amount(effect, source_side))
		var effect_type = str(effect.get("type", ""))
		description = description.replace("{" + effect_type + "}", amount)
		description = description.replace("{" + _legacy_token_for_effect(effect_type) + "}", amount)
	return description

func _legacy_token_for_effect(effect_type: String) -> String:
	match effect_type:
		"damage":
			return "ATTACK"
		"block":
			return "DEFEND"
		"heal":
			return "HEAL"
		"draw":
			return "DRAW"
		"discard":
			return "DISCARD"
		"gain_energy":
			return "GAIN_ENERGY"
		"modify_insight":
			return "INSIGHT"
	return effect_type.to_upper()
