class_name BattlePlanManager
extends Node

signal battle_plan_selected(plan: Dictionary)

var current_battle_plan: Dictionary = {}
var current_round: int = 1


func get_random_battle_plan_choices(choice_count: int = 3) -> Array[Dictionary]:
	var pool: Array[Dictionary] = BattlePlanDatabase.get_all_battle_plan_dictionaries()
	pool.shuffle()

	var amount := mini(choice_count, pool.size())
	return pool.slice(0, amount)


func get_all_battle_plans() -> Array[Dictionary]:
	return BattlePlanDatabase.get_all_battle_plan_dictionaries()


func select_battle_plan(plan: Dictionary) -> void:
	current_battle_plan = plan
	battle_plan_selected.emit(plan)


func clear_current_battle_plan() -> void:
	current_battle_plan = {}


func advance_round() -> void:
	current_round += 1
	clear_current_battle_plan()


func get_current_battle_plan_name() -> String:
	if current_battle_plan.is_empty():
		return "None"

	return str(current_battle_plan.get("name", "Unknown Battle Plan"))


func get_current_max_hand_size() -> int:
	if current_battle_plan.is_empty():
		return 7

	return int(current_battle_plan.get("max_hand_size", 7))
