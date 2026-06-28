class_name BattlefieldManagerVolleyPatch3
extends "res://battlefield/BattlefieldManagerVolleyPatch2.gd"

# Follow-up runtime fix for Vanish.
# Godot 4.7 rejects an untyped Array when calling Card3DTest.set_usable_ability_ids(Array[StringName]).
# The base manager used raw [] / [&"vanish"] through call(), so this override keeps the same rule
# but sends properly typed Array[StringName] values.

func resolve_vanish_when_targeted(slot: Node, card_data: CardData, player_defender: bool) -> bool:
	var ability := slot_has_mobility_ability(slot, &"vanish")
	if ability == null or bool(slot.get_meta("vanish_used", false)):
		return false

	var use_vanish := true
	if player_defender:
		var visual := slot.call("get_placed_card_visual") as Node if slot.has_method("get_placed_card_visual") else null
		if visual != null and visual.has_method("set_usable_ability_ids"):
			var vanish_ids: Array[StringName] = [&"vanish"]
			visual.call("set_usable_ability_ids", vanish_ids)
		use_vanish = await prompt_mobility_choice(ability.ability_name + "  -  Return " + card_data.card_name + " to your hand?", "VANISH", "STAY")
		if visual != null and is_instance_valid(visual) and visual.has_method("set_usable_ability_ids"):
			var no_ids: Array[StringName] = []
			visual.call("set_usable_ability_ids", no_ids)

	if not use_vanish:
		return false

	slot.set_meta("vanish_used", true)
	await return_board_card_to_hand(slot, card_data, "player" if player_defender else "enemy")
	return true
