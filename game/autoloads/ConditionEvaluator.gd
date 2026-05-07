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
			return target in GameState.consumables
		"lacksConsumable":
			return target not in GameState.consumables
		"hasEquipment":
			return target in GameState.equipment
		"lacksEquipment":
			return target not in GameState.equipment
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
