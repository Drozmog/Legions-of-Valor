class_name BattlefieldAbilityPresentationController
extends RefCounted

const MINIMUM_MESSAGE_SECONDS := 2.0

var bf: BattlefieldManager


func _init(owner_battlefield: BattlefieldManager) -> void:
	bf = owner_battlefield


func icon_path(category: String) -> String:
	return "res://ui/ability_icons/" + category.to_lower() + ".png"


func show_trigger(ability: AbilityData, detail: String = "", include_description: bool = false, duration: float = MINIMUM_MESSAGE_SECONDS) -> void:
	if ability == null:
		return
	var message := ability.ability_name.to_upper()
	if detail != "":
		message += "  -  " + detail
	if include_description and ability.rules_text.strip_edges() != "":
		message += "\n" + ability.rules_text.strip_edges()
	bf.log_msg(ability.category.capitalize() + " triggered: " + ability.ability_name + (" - " + detail if detail != "" else ""))
	_play_ability_label_sfx(ability.category)
	bf.show_mobility_prompt(message, icon_path(ability.category))
	await bf.get_tree().create_timer(maxf(duration, MINIMUM_MESSAGE_SECONDS)).timeout
	await bf.hide_mobility_prompt()


func choose_slot(candidates: Array[Node], ability: AbilityData, instruction: String) -> Node:
	if ability == null:
		return null
	return await bf.choose_mobility_slot(
		candidates,
		ability.ability_name.to_upper() + "  -  " + instruction,
		icon_path(ability.category),
		ability.rules_text,
		ability.category
	)


func choose_card(cards: Array[CardData], ability: AbilityData, source_position: Vector3, destination: Vector3) -> Dictionary:
	if cards.is_empty() or ability == null:
		return {"success": false, "reason": "no_cards"}
	return await bf.present_insight_cards(cards, {
		"mode": "choose",
		"ability_name": ability.ability_name,
		"ability_description": ability.rules_text,
		"ability_icon_path": icon_path(ability.category),
		"display_scale": 1.45,
		"source_position": source_position,
		"chosen_destination": destination,
		"other_destination": source_position,
	})


func _play_ability_label_sfx(category: String) -> void:
	if SceneLoader != null and SceneLoader.has_method("play_ability_label"):
		SceneLoader.play_ability_label(category)
