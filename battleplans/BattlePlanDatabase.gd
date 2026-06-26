class_name BattlePlanDatabase
extends RefCounted

const DEFINITIONS_PATH := "res://battleplans/definitions"


static func get_all_battle_plans() -> Array[BattlePlanData]:
	var battle_plans: Array[BattlePlanData] = []
	_collect_battle_plans(DEFINITIONS_PATH, battle_plans)
	battle_plans.sort_custom(func(a: BattlePlanData, b: BattlePlanData) -> bool:
		return a.battle_plan_name.naturalnocasecmp_to(b.battle_plan_name) < 0
	)
	print("BattlePlanDatabase loaded battleplans: ", battle_plans.size())
	return battle_plans


static func get_battle_plan_by_id(battle_plan_id: String) -> BattlePlanData:
	for battle_plan in get_all_battle_plans():
		if battle_plan.battle_plan_id == battle_plan_id:
			return battle_plan
	return null


static func get_all_battle_plan_dictionaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for battle_plan in get_all_battle_plans():
		result.append(battle_plan.to_dictionary())
	return result


static func _collect_battle_plans(path: String, output: Array[BattlePlanData]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		push_error("BattlePlanDatabase could not open " + path)
		return

	directory.list_dir_begin()
	var entry_name := directory.get_next()

	while not entry_name.is_empty():
		if entry_name != "." and entry_name != "..":
			var entry_path := path.path_join(entry_name)

			if directory.current_is_dir():
				_collect_battle_plans(entry_path, output)
			elif entry_name.get_extension().to_lower() == "tres":
				_register_battle_plan(entry_path, output)
			elif entry_name.ends_with(".tres.remap"):
				_register_battle_plan(entry_path.trim_suffix(".remap"), output)

		entry_name = directory.get_next()

	directory.list_dir_end()


static func _register_battle_plan(path: String, output: Array[BattlePlanData]) -> void:
	var resource := ResourceLoader.load(path)
	if not resource is BattlePlanData:
		return

	var battle_plan := resource as BattlePlanData
	if battle_plan.is_valid():
		output.append(battle_plan)
	else:
		push_warning("Ignoring invalid BattlePlanData: " + path)
