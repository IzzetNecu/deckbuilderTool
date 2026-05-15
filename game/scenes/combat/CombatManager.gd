extends Node
class_name CombatManager

enum Phase { BEGINNING, PLAY, END, WIN, LOSE }

const STATUS_DISPLAY_ORDER := [
	"buff_heat",
	"debuff_burning",
	"buff_flow",
	"debuff_slippery",
	"buff_regen",
	"debuff_poison",
	"buff_haste",
	"debuff_slowed",
	"buff_scaled",
	"debuff_chill",
	"buff_energized",
	"debuff_jolted"
]

const STATUS_OPPOSITES := {
	"buff_heat": "debuff_burning",
	"debuff_burning": "buff_heat",
	"buff_flow": "debuff_slippery",
	"debuff_slippery": "buff_flow",
	"buff_regen": "debuff_poison",
	"debuff_poison": "buff_regen",
	"buff_haste": "debuff_slowed",
	"debuff_slowed": "buff_haste",
	"buff_scaled": "debuff_chill",
	"debuff_chill": "buff_scaled",
	"buff_energized": "debuff_jolted",
	"debuff_jolted": "buff_energized"
}

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

var _warned_status_ids: Dictionary = {}

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
		"statuses": {},
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
		"statuses": {},
		"stats": {
			"strength": int(enemy_stats.get("strength", 0)),
			"dexterity": int(enemy_stats.get("dexterity", 0)),
			"insight": int(enemy_stats.get("insight", 0)),
			"hand_size": int(enemy_data.get("handSize", enemy_data.get("hand_size", 2)))
		}
	}

	draw_pile = GameState.get_effective_deck().duplicate()
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

	var bonus_draw = _consume_haste_for_draw(player_actor)
	var slowed_draw_penalty = _get_slowed_draw_penalty(player_actor)
	_draw_player_cards(max(get_player_hand_size() + bonus_draw - slowed_draw_penalty, 0))
	_consume_slowed_after_draw(player_actor)
	if _resolve_turn_start_statuses(player_actor, "player"):
		stats_updated.emit()
		return
	_prepare_enemy_intent()
	stats_updated.emit()
	if _check_win_lose():
		return
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
	var draw_count = int(enemy_actor["stats"].get("hand_size", 2)) + _consume_haste_for_draw(enemy_actor) - _get_slowed_draw_penalty(enemy_actor)
	draw_count = max(draw_count, 0)
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

	_consume_slowed_after_draw(enemy_actor)
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

	if _resolve_played_card(card_data, "player", target):
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

	if _resolve_turn_end_statuses(player_actor):
		stats_updated.emit()
		return

	# Enemy block drops when the enemy turn begins, not at the start of the player's turn.
	enemy_actor["block"] = 0
	if _resolve_turn_start_statuses(enemy_actor, "enemy"):
		stats_updated.emit()
		return
	stats_updated.emit()

	while not enemy_pending_cards.is_empty():
		var card = enemy_pending_cards.pop_front()
		_refresh_enemy_reveal()
		if _resolve_played_card(card, "enemy", "enemy"):
			enemy_discard_pile.append(card.get("id", ""))
			enemy_pending_cards = []
			enemy_intent_slots = []
			enemy_intent_updated.emit(enemy_intent_slots)
			stats_updated.emit()
			return
		enemy_discard_pile.append(card.get("id", ""))
	enemy_pending_cards = []
	enemy_intent_slots = []
	enemy_intent_updated.emit(enemy_intent_slots)

	if _resolve_turn_end_statuses(enemy_actor):
		stats_updated.emit()
		return
	stats_updated.emit()
	if _check_win_lose():
		return

	await get_tree().create_timer(0.8).timeout
	_begin_phase()

func _apply_effect(effect: Dictionary, source_side: String, target_hint: String = "", resolution_context: Dictionary = {}) -> void:
	var effect_target = str(effect.get("target", target_hint if not target_hint.is_empty() else "self"))
	var target_actor = _resolve_target_actor(source_side, effect_target)
	var amount = _resolve_effect_amount(effect, source_side)
	match str(effect.get("type", "")):
		"damage":
			amount = _apply_next_damage_modifier(_get_actor(source_side), amount, resolution_context)
			_apply_damage(target_actor, amount)
		"block":
			amount = _apply_next_block_modifier(_get_actor(source_side), amount, resolution_context)
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
		"apply_status":
			_apply_status(target_actor, str(effect.get("statusId", "")), amount)
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

func _discard_from_enemy_pending(count: int) -> void:
	for i in range(min(count, enemy_pending_cards.size())):
		var card = enemy_pending_cards.pop_back()
		enemy_discard_pile.append(card.get("id", ""))
	_refresh_enemy_reveal()

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
		GameState.health = max(1, get_player_current_hp())
		combat_ended.emit(false)
		GameState.save()
		return true
	return false

func _resolve_played_card(card_data: Dictionary, source_side: String, target_hint: String = "") -> bool:
	var source_actor = _get_actor(source_side)
	_normalize_all_status_pairs(source_actor)
	var effect_passes = 2 if _get_status_value(source_actor, "buff_energized") > 0 else 1
	for pass_index in range(effect_passes):
		var resolution_context := {
			"damage_status_consumed": false,
			"block_status_consumed": false
		}
		for effect in card_data.get("effects", []):
			_apply_effect(effect, source_side, target_hint, resolution_context)
			if _check_win_lose():
				return true
	if effect_passes > 1:
		_remove_status_stacks(source_actor, "buff_energized", 1)
	if _resolve_jolted(source_actor, source_side):
		return true
	return _check_win_lose()

func _resolve_turn_start_statuses(actor: Dictionary, side: String) -> bool:
	_normalize_all_status_pairs(actor)
	var poison = _get_status_value(actor, "debuff_poison")
	if poison > 0:
		_apply_damage(actor, poison)
		_remove_status_stacks(actor, "debuff_poison", 1)
		if _check_win_lose():
			return true
	return false

func _resolve_turn_end_statuses(actor: Dictionary) -> bool:
	_normalize_all_status_pairs(actor)
	var regen = _get_status_value(actor, "buff_regen")
	if regen > 0:
		actor["current_hp"] = min(int(actor.get("max_hp", 0)), int(actor.get("current_hp", 0)) + regen)
		_remove_status_stacks(actor, "buff_regen", 1)
		if _check_win_lose():
			return true

	var scaled = _get_status_value(actor, "buff_scaled")
	if scaled > 0:
		actor["block"] = int(actor.get("block", 0)) + scaled
		_remove_status_stacks(actor, "buff_scaled", 1)
		if _check_win_lose():
			return true

	var chill = _get_status_value(actor, "debuff_chill")
	if chill > 0:
		actor["block"] = max(0, int(actor.get("block", 0)) - chill)
		_remove_status_stacks(actor, "debuff_chill", 1)
		if _check_win_lose():
			return true
	return false

func _consume_haste_for_draw(actor: Dictionary) -> int:
	_normalize_status_pairs(actor, "buff_haste")
	var haste = _get_status_value(actor, "buff_haste")
	if haste > 0:
		_remove_status_stacks(actor, "buff_haste", 1)
	return haste

func _get_slowed_draw_penalty(actor: Dictionary) -> int:
	_normalize_status_pairs(actor, "debuff_slowed")
	return _get_status_value(actor, "debuff_slowed")

func _consume_slowed_after_draw(actor: Dictionary) -> void:
	if _get_status_value(actor, "debuff_slowed") > 0:
		_remove_status_stacks(actor, "debuff_slowed", 1)

func _resolve_jolted(actor: Dictionary, source_side: String) -> bool:
	_normalize_status_pairs(actor, "debuff_jolted")
	if _get_status_value(actor, "debuff_jolted") <= 0:
		return false
	if source_side == "player":
		player_energy = max(0, player_energy - 1)
	_remove_status_stacks(actor, "debuff_jolted", 1)
	return _check_win_lose()

func _apply_next_damage_modifier(actor: Dictionary, amount: int, resolution_context: Dictionary) -> int:
	if bool(resolution_context.get("damage_status_consumed", false)):
		return max(amount, 0)
	_normalize_status_pairs(actor, "buff_heat")
	_normalize_status_pairs(actor, "debuff_burning")
	var heat = _get_status_value(actor, "buff_heat")
	if heat > 0:
		resolution_context["damage_status_consumed"] = true
		_halve_status_after_trigger(actor, "buff_heat")
		return max(amount + heat, 0)
	var burning = _get_status_value(actor, "debuff_burning")
	if burning > 0:
		resolution_context["damage_status_consumed"] = true
		_halve_status_after_trigger(actor, "debuff_burning")
		return max(amount - burning, 0)
	return max(amount, 0)

func _apply_next_block_modifier(actor: Dictionary, amount: int, resolution_context: Dictionary) -> int:
	if bool(resolution_context.get("block_status_consumed", false)):
		return max(amount, 0)
	_normalize_status_pairs(actor, "buff_flow")
	_normalize_status_pairs(actor, "debuff_slippery")
	var flow = _get_status_value(actor, "buff_flow")
	if flow > 0:
		resolution_context["block_status_consumed"] = true
		_halve_status_after_trigger(actor, "buff_flow")
		return max(amount + flow, 0)
	var slippery = _get_status_value(actor, "debuff_slippery")
	if slippery > 0:
		resolution_context["block_status_consumed"] = true
		_halve_status_after_trigger(actor, "debuff_slippery")
		return max(amount - slippery, 0)
	return max(amount, 0)

func _apply_status(actor: Dictionary, status_id: String, amount: int) -> void:
	if amount <= 0:
		return
	if not _is_known_status(status_id):
		_warn_unknown_status(status_id)
		return
	_normalize_status_pairs(actor, status_id)
	var opposite = str(STATUS_OPPOSITES.get(status_id, ""))
	if not opposite.is_empty():
		var canceled = min(amount, _get_status_value(actor, opposite))
		if canceled > 0:
			_remove_status_stacks(actor, opposite, canceled)
			amount -= canceled
	if amount <= 0:
		return
	var statuses = _get_statuses(actor)
	statuses[status_id] = _get_status_value(actor, status_id) + amount
	actor["statuses"] = statuses
	_refresh_enemy_reveal()

func _get_statuses(actor: Dictionary) -> Dictionary:
	if not actor.has("statuses") or typeof(actor["statuses"]) != TYPE_DICTIONARY:
		actor["statuses"] = {}
	return actor["statuses"]

func _get_status_value(actor: Dictionary, status_id: String) -> int:
	return int(_get_statuses(actor).get(status_id, 0))

func _remove_status_stacks(actor: Dictionary, status_id: String, amount: int) -> void:
	if amount <= 0:
		return
	var statuses = _get_statuses(actor)
	var next_value = max(0, int(statuses.get(status_id, 0)) - amount)
	if next_value <= 0:
		statuses.erase(status_id)
	else:
		statuses[status_id] = next_value
	actor["statuses"] = statuses

func _halve_status_after_trigger(actor: Dictionary, status_id: String) -> void:
	var current = _get_status_value(actor, status_id)
	if current <= 0:
		return
	_remove_status_stacks(actor, status_id, int(ceil(float(current) / 2.0)))

func _normalize_status_pairs(actor: Dictionary, status_id: String) -> void:
	var opposite = str(STATUS_OPPOSITES.get(status_id, ""))
	if opposite.is_empty():
		return
	var statuses = _get_statuses(actor)
	var amount = int(statuses.get(status_id, 0))
	var opposite_amount = int(statuses.get(opposite, 0))
	if amount <= 0 or opposite_amount <= 0:
		return
	var canceled = min(amount, opposite_amount)
	amount -= canceled
	opposite_amount -= canceled
	if amount <= 0:
		statuses.erase(status_id)
	else:
		statuses[status_id] = amount
	if opposite_amount <= 0:
		statuses.erase(opposite)
	else:
		statuses[opposite] = opposite_amount
	actor["statuses"] = statuses

func _normalize_all_status_pairs(actor: Dictionary) -> void:
	for status_id in STATUS_DISPLAY_ORDER:
		_normalize_status_pairs(actor, status_id)

func _is_known_status(status_id: String) -> bool:
	return not GameData.get_buff(status_id).is_empty()

func _warn_unknown_status(status_id: String) -> void:
	if _warned_status_ids.has(status_id):
		return
	_warned_status_ids[status_id] = true
	push_warning("CombatManager: Unknown status id ignored: %s" % status_id)

func get_display_buffs(side: String) -> Array:
	var actor = _get_actor(side)
	var buff_values: Array = [
		{"id": "buff_strength", "value": int(actor.get("stats", {}).get("strength", 0))},
		{"id": "buff_dexterity", "value": int(actor.get("stats", {}).get("dexterity", 0))},
		{"id": "buff_insight", "value": int(actor.get("stats", {}).get("insight", 0))}
	]
	_normalize_all_status_pairs(actor)
	for status_id in STATUS_DISPLAY_ORDER:
		var value = _get_status_value(actor, status_id)
		if value > 0:
			buff_values.append({"id": status_id, "value": value})
	return buff_values

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

func get_card_text(card_data: Dictionary, source_side: String, detailed: bool = false) -> String:
	var preview_effects = _build_card_preview_effects(card_data, source_side)
	if detailed:
		return _build_card_breakdown_text(card_data, preview_effects)
	var description = str(card_data.get("description", ""))
	for preview in preview_effects:
		var amount = str(int(preview.get("final_amount", 0)))
		var effect_type = str(preview.get("effect_type", ""))
		description = description.replace("{" + effect_type + "}", amount)
		description = description.replace("{" + _legacy_token_for_effect(effect_type) + "}", amount)
	return description

func _build_card_preview_effects(card_data: Dictionary, source_side: String) -> Array:
	var preview_effects: Array = []
	var preview_context := {
		"damage_status_consumed": false,
		"block_status_consumed": false
	}
	var source_actor = _get_actor(source_side) if source_side == "player" or source_side == "enemy" else {}
	if not source_actor.is_empty():
		_normalize_all_status_pairs(source_actor)
	for effect in card_data.get("effects", []):
		var effect_type = str(effect.get("type", ""))
		var scaling = str(effect.get("scaling", "none"))
		var base_amount = int(effect.get("amount", 0))
		var scaling_amount = 0
		if scaling != "none":
			scaling_amount = int(source_actor.get("stats", {}).get(scaling, 0))
		var status_preview = _get_preview_status_modifier(source_actor, effect_type, preview_context)
		var status_amount = int(status_preview.get("amount", 0))
		var final_amount = base_amount + scaling_amount + status_amount
		if effect_type == "damage" or effect_type == "block":
			final_amount = max(final_amount, 0)
		preview_effects.append({
			"effect": effect,
			"effect_type": effect_type,
			"base_amount": base_amount,
			"scaling": scaling,
			"scaling_amount": scaling_amount,
			"status_name": str(status_preview.get("name", "")),
			"status_amount": status_amount,
			"final_amount": final_amount
		})
	return preview_effects

func _get_preview_status_modifier(actor: Dictionary, effect_type: String, preview_context: Dictionary) -> Dictionary:
	match effect_type:
		"damage":
			if bool(preview_context.get("damage_status_consumed", false)):
				return {"name": "", "amount": 0}
			preview_context["damage_status_consumed"] = true
			var heat = _get_status_value(actor, "buff_heat")
			if heat > 0:
				return {"name": "heat", "amount": heat}
			var burning = _get_status_value(actor, "debuff_burning")
			if burning > 0:
				return {"name": "burning", "amount": -burning}
		"block":
			if bool(preview_context.get("block_status_consumed", false)):
				return {"name": "", "amount": 0}
			preview_context["block_status_consumed"] = true
			var flow = _get_status_value(actor, "buff_flow")
			if flow > 0:
				return {"name": "flow", "amount": flow}
			var slippery = _get_status_value(actor, "debuff_slippery")
			if slippery > 0:
				return {"name": "slippery", "amount": -slippery}
	return {"name": "", "amount": 0}

func _build_card_breakdown_text(card_data: Dictionary, preview_effects: Array) -> String:
	var lines: Array = []
	for preview in preview_effects:
		var line = _format_effect_breakdown_line(preview)
		if not line.is_empty():
			lines.append(line)
	if lines.is_empty():
		return str(card_data.get("description", ""))
	return "\n".join(lines)

func _format_effect_breakdown_line(preview: Dictionary) -> String:
	var effect = preview.get("effect", {})
	var effect_type = str(preview.get("effect_type", ""))
	var final_amount = int(preview.get("final_amount", 0))
	var parts: Array = ["base %d" % int(preview.get("base_amount", 0))]
	var scaling = str(preview.get("scaling", "none"))
	var scaling_amount = int(preview.get("scaling_amount", 0))
	if scaling != "none" and scaling_amount != 0:
		parts.append(_format_named_modifier(scaling, scaling_amount))
	var status_name = str(preview.get("status_name", ""))
	var status_amount = int(preview.get("status_amount", 0))
	if not status_name.is_empty() and status_amount != 0:
		parts.append(_format_named_modifier(status_name, status_amount))

	match effect_type:
		"damage":
			return "Deal %d (%s) damage." % [final_amount, " ".join(parts)]
		"block":
			return "Gain %d (%s) block." % [final_amount, " ".join(parts)]
		"heal":
			return "Heal %d (%s)." % [final_amount, " ".join(parts)]
		"draw":
			return "Draw %d card%s." % [final_amount, "" if final_amount == 1 else "s"]
		"discard":
			return "Discard %d card%s." % [final_amount, "" if final_amount == 1 else "s"]
		"gain_energy":
			return "Gain %d energy." % final_amount
		"modify_insight":
			return "Gain %d insight." % final_amount
		"apply_status":
			var target = str(effect.get("target", "self"))
			var status_id = str(effect.get("statusId", ""))
			var status_name_display = str(GameData.get_buff(status_id).get("name", status_id))
			return "Apply %d %s to %s." % [final_amount, status_name_display, target]
	return ""

func _format_named_modifier(name: String, amount: int) -> String:
	if amount >= 0:
		return "+ %s %d" % [name, amount]
	return "- %s %d" % [name, abs(amount)]

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
