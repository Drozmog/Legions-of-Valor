class_name AbilityDatabase
extends RefCounted

const DEFINITIONS_PATH := "res://abilities/definitions"
const CATEGORIES: PackedStringArray = [
	"assault", "attrition", "control", "economy", "insight", "mobility", "protection"
]

static var _all_abilities: Array[AbilityData] = []
static var _abilities_by_id: Dictionary = {}
static var _cache_built := false


static func get_all_abilities() -> Array[AbilityData]:
	_ensure_cache()
	return _all_abilities.duplicate()


static func get_ability_by_id(ability_id: StringName) -> AbilityData:
	_ensure_cache()
	return _abilities_by_id.get(String(ability_id).to_lower()) as AbilityData


static func get_abilities_by_category(category: String) -> Array[AbilityData]:
	var wanted := category.strip_edges().to_lower()
	var result: Array[AbilityData] = []
	for ability in get_all_abilities():
		if ability.category.to_lower() == wanted:
			result.append(ability)
	return result


static func reload() -> void:
	_cache_built = false
	_all_abilities.clear()
	_abilities_by_id.clear()
	_ensure_cache()


static func _ensure_cache() -> void:
	if _cache_built:
		return
	_cache_built = true
	_collect_abilities(DEFINITIONS_PATH)
	_all_abilities.sort_custom(func(a: AbilityData, b: AbilityData) -> bool:
		return a.ability_name.naturalnocasecmp_to(b.ability_name) < 0
	)


static func _collect_abilities(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		push_error("AbilityDatabase could not open " + path)
		return
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if entry_name != "." and entry_name != "..":
			var entry_path := path.path_join(entry_name)
			if directory.current_is_dir():
				_collect_abilities(entry_path)
			elif entry_name.get_extension().to_lower() == "tres":
				_register_ability(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()


static func _register_ability(path: String) -> void:
	var resource := ResourceLoader.load(path)
	if not resource is AbilityData:
		return
	var ability := resource as AbilityData
	if not ability.is_valid():
		push_warning("Ignoring invalid AbilityData: " + path)
		return
	var key := String(ability.ability_id).to_lower()
	if _abilities_by_id.has(key):
		push_error("Duplicate ability_id '%s' in %s" % [ability.ability_id, path])
		return
	_abilities_by_id[key] = ability
	_all_abilities.append(ability)
