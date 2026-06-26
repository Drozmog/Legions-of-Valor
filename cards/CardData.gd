extends Resource
class_name CardData

@export var card_id: String = ""
@export var card_name: String = ""

@export var race: String = ""
@export var card_type: String = "" # unit, ruse, trap, spell, equipment
@export var rarity: String = "" # common, rare, elite

@export var tribute_cost: int = 0
@export var ap: int = 0
@export var dp: int = 0

@export_group("Abilities")
@export var abilities: Array[AbilityData] = []

@export_group("Legacy Ability Data")
@export_multiline var ability_text: String = ""
@export var ability_types: Array[String] = []

@export_group("Presentation")
@export var role: String = ""
@export_multiline var lore_text: String = ""

@export var card_art: Texture2D


func get_abilities() -> Array[AbilityData]:
	if not abilities.is_empty():
		return abilities.duplicate()
	# During migration, recognize canonical ability names in old card text so
	# resolver-backed abilities (such as Volley) work before every .tres is edited.
	var inferred: Array[AbilityData] = []
	var legacy_text := ability_text.to_lower()
	for ability in AbilityDatabase.get_all_abilities():
		if legacy_text.contains(ability.ability_name.to_lower()):
			inferred.append(ability)
	return inferred


func get_ability_text() -> String:
	if abilities.is_empty():
		return ability_text
	var lines: PackedStringArray = []
	for ability in abilities:
		if ability != null:
			lines.append(ability.get_display_text())
	return "\n\n".join(lines)


func get_ability_categories() -> Array[String]:
	if abilities.is_empty():
		return ability_types.duplicate()
	var categories: Array[String] = []
	for ability in abilities:
		if ability == null:
			continue
		var category := ability.category.to_lower().strip_edges()
		if category != "":
			categories.append(category)
	return categories


func has_ability(ability_id: StringName) -> bool:
	for ability in abilities:
		if ability != null and ability.ability_id == ability_id:
			return true
	# Compatibility while legacy cards are migrated to AbilityData resources.
	var legacy_name := String(ability_id).replace("_", " ").to_lower()
	return get_ability_text().to_lower().contains(legacy_name)


func is_valid() -> bool:
	return not card_id.strip_edges().is_empty() and not card_name.strip_edges().is_empty()
