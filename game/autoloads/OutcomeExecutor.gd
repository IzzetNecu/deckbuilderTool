extends Node

func execute_all(outcomes: Array) -> void:
	for out in outcomes:
		execute_one(out)

func execute_one(out: Dictionary) -> void:
	var target = out.get("target", "")
	var value = out.get("value", "")
	
	match out.get("type"):
		"addMoney":
			GameState.gold += int(value)
		"removeMoney":
			GameState.gold = max(0, GameState.gold - int(value))
		"damage":
			GameState.health = max(0, GameState.health - int(value))
			if GameState.health == 0:
				# Trigger game over or death logic later
				pass
		"heal":
			GameState.health = min(GameState.max_health, GameState.health + int(value))
		"modifyStat":
			var current = GameState.get(target)
			if current != null:
				GameState.set(target, current + int(value))
		"addKeyItem":
			GameState.add_key_item(target, max(1, int(value)))
		"removeKeyItem":
			GameState.remove_key_item(target, max(1, int(value)))
		"addEquipment":
			GameState.add_equipment(target, max(1, int(value)))
		"removeEquipment":
			GameState.remove_equipment(target, max(1, int(value)))
		"addConsumable":
			GameState.add_consumable(target, max(1, int(value)))
		"removeConsumable":
			GameState.remove_consumable(target, max(1, int(value)))
		"addCard":
			GameState.add_owned_card(target, true)
		"removeCard":
			GameState.remove_owned_card(target)
		"travelToMap":
			SceneManager.load_map(target)
		"startCombat":
			SceneManager.start_combat(target)
		"startEvent":
			SceneManager.start_event(target)
		"setFlag":
			GameState.set_flag(target, value.to_lower() == "true")
		"text":
			SceneManager.show_text(value)
