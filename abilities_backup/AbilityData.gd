@tool
class_name AbilityData
extends Resource

const VALID_CATEGORIES: PackedStringArray = [
	"assault", "attrition", "control", "economy", "insight", "mobility", "protection"
]

@export var ability_id: StringName = &""
@export var ability_name: String = ""
@export_enum("assault", "attrition", "control", "economy", "insight", "mobility", "protection") var category: String = "assault"
@export var point_cost: float = 0.0
@export_enum(
	"passive",
	"active",
	"on_deploy",
	"on_destroyed",
	"on_discard",
	"on_draw",
	"on_attack",
	"on_defense",
	"on_clash_won",
	"on_clash_lost",
	"on_monarch_strike",
	"on_turn_start",
	"on_turn_end",
	"attack_targeting",
	"combat_power",
	"deployment_cost",
	"parry_check",
	"protection_check"
) var trigger: String = "passive"
@export_multiline var rules_text: String = ""
@export var icon: Texture2D
@export var handler_id: StringName = &""


func is_valid() -> bool:
	return ability_id != &"" and not ability_name.strip_edges().is_empty() and VALID_CATEGORIES.has(category.to_lower())


func get_handler_id() -> StringName:
	return handler_id if handler_id != &"" else ability_id


func get_display_text() -> String:
	if rules_text.strip_edges().is_empty():
		return ability_name
	return "%s · %s" % [ability_name, rules_text]
