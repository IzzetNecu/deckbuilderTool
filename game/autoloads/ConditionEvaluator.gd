extends Node

func evaluate_all(conditions: Array) -> bool:
	for cond in conditions:
		if not evaluate_one(cond):
			return false
	return true

func evaluate_one(cond: Dictionary) -> bool:
	var target = cond.get("target", "")
	var op = cond.get("operator", "==")
	var value = cond.get("value", "")
	
	match cond.get("type"):
		"hasStat":
			return _compare(GameState.get_stat(target), op, int(value))
		"hasMoney":
			return _compare(GameState.gold, op, int(value))
		"hasKeyItem":
			return target in GameState.key_items
		"lacksKeyItem":
			return target not in GameState.key_items
		"hasConsumable":
			return _compare(GameState.get_consumable_count(target), op, max(1, int(value)))
		"lacksConsumable":
			return GameState.get_consumable_count(target) == 0
		"hasEquipment":
			return _compare(GameState.get_equipment_count(target), op, max(1, int(value)))
		"lacksEquipment":
			return GameState.get_equipment_count(target) == 0
		"hasFactionRank":
			# Future implementation
			return false
		"checkFlag":
			var expected = value.to_lower() == "true"
			return GameState.get_flag(target) == expected
	return false

func _compare(val1: int, op: String, val2: int) -> bool:
	match op:
		">=": return val1 >= val2
		"<=": return val1 <= val2
		"==": return val1 == val2
		">": return val1 > val2
		"<": return val1 < val2
	return false
