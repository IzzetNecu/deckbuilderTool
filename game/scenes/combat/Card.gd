extends Panel

var card_data: Dictionary = {}
var combat_manager: Node = null
var enemy_unit: Node = null

# Drag state
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO
var original_parent: Node = null

@onready var name_label: Label = $VBox/NameLabel
@onready var cost_label: Label = $VBox/CostLabel
@onready var effects_label: Label = $VBox/EffectsLabel

func setup(data: Dictionary, mgr: Node, enemy: Node) -> void:
	card_data = data
	combat_manager = mgr
	enemy_unit = enemy

	name_label.text = data.get("name", "?")
	cost_label.text = "Cost: %d" % data.get("cost", 0)

	var effects = data.get("effects", [])
	effects_label.text = "\n".join(effects) if effects.size() > 0 else ""

func _is_targeted() -> bool:
	# Cards with ATTACK effects need a target (enemy)
	for effect in card_data.get("effects", []):
		if effect.begins_with("ATTACK"):
			return true
	return false

func _can_afford() -> bool:
	if not combat_manager:
		return false
	return combat_manager.player_energy >= card_data.get("cost", 0) \
		and combat_manager.current_phase == CombatManager.Phase.PLAY

# ──────────────────────────────────────────────
#  Drag & Drop
# ──────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if not _can_afford():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event.global_position)
			else:
				_release_drag(event.global_position)

	elif event is InputEventMouseMotion and is_dragging:
		global_position = event.global_position + drag_offset
		_check_hover(event.global_position)

func _start_drag(global_pos: Vector2) -> void:
	is_dragging = true
	original_position = global_position
	original_parent = get_parent()
	drag_offset = global_position - global_pos

	# Reparent to top level so it draws on top
	var canvas = get_tree().current_scene
	original_parent.remove_child(self)
	canvas.add_child(self)
	global_position = original_position

func _release_drag(global_pos: Vector2) -> void:
	if not is_dragging:
		return
	is_dragging = false

	var played = false

	if _is_targeted():
		# Must drop on enemy
		if enemy_unit and _is_over_node(enemy_unit, global_pos):
			played = combat_manager.play_card(card_data, "enemy")
	else:
		# Drop anywhere in play zone (not on the hand area)
		var hand_area = get_tree().current_scene.get_node_or_null("HandArea")
		var over_hand = hand_area and _is_over_node(hand_area, global_pos)
		if not over_hand:
			played = combat_manager.play_card(card_data, "self")

	if played:
		# CombatScene will rebuild hand from signal — just remove this node
		queue_free()
	else:
		# Snap back to hand
		_snap_back()

	# Clear enemy highlight
	if enemy_unit:
		enemy_unit.set_highlight(false)

func _check_hover(global_pos: Vector2) -> void:
	if enemy_unit and _is_targeted():
		enemy_unit.set_highlight(_is_over_node(enemy_unit, global_pos))

func _snap_back() -> void:
	# Re-parent back to original container
	get_parent().remove_child(self)
	original_parent.add_child(self)
	position = Vector2.ZERO # HBoxContainer will re-layout

func _is_over_node(target_node: Control, global_pos: Vector2) -> bool:
	var rect = Rect2(target_node.global_position, target_node.size)
	return rect.has_point(global_pos)
