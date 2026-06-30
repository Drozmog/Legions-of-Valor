class_name BattlefieldBattleplanObjectiveController
extends RefCounted

## Tracks round events and evaluates every Battleplan objective. The controller
## deliberately receives semantic events from combat/deployment instead of
## scraping the game log.

var bf: BattlefieldManager
var plans: Dictionary = {}
var states: Dictionary = {}


func _init(owner_battlefield: BattlefieldManager) -> void:
	bf = owner_battlefield
	reset_round({}, {})


func fresh_state() -> Dictionary:
	return {
		"promoted_cards": [],
		"promotion_inherited_equipment": false,
		"promoted_unit_defeated_enemy": false,
		"gambit_tributed": false,
		"deployment_met": {},
		"checks": 0,
		"gambits_checked": 0,
		"face_down_probed": false,
		"units_lost": 0,
		"successful_side_parry": false,
		"successful_three_card_parry": false,
		"passed_lanes": {},
		"attacks_declared": 0,
		"monarch_strike": false,
		"ap_margin_win": false,
		"interception_win": false,
		"center_start_card": null,
	}


func reset_round(player_plan: Dictionary, enemy_plan: Dictionary) -> void:
	plans = {"player": player_plan, "enemy": enemy_plan}
	states = {"player": fresh_state(), "enemy": fresh_state()}


func clean_owner(owner_name: String) -> String:
	return "enemy" if owner_name.to_lower() in ["enemy", "ai", "opponent"] else "player"


func note_promotion(owner_name: String, promoted_card: CardData, inherited_equipment: int) -> void:
	var owner := clean_owner(owner_name)
	(states[owner]["promoted_cards"] as Array).append(promoted_card)
	if inherited_equipment > 0:
		states[owner]["promotion_inherited_equipment"] = true


func note_tribute(owner_name: String, card_data: CardData) -> void:
	if card_data != null and bf.is_gambit_card(card_data):
		states[clean_owner(owner_name)]["gambit_tributed"] = true


func note_attack(owner_name: String) -> void:
	var owner := clean_owner(owner_name)
	states[owner]["attacks_declared"] = int(states[owner]["attacks_declared"]) + 1


func note_pass(owner_name: String, lane: String) -> void:
	states[clean_owner(owner_name)]["passed_lanes"][lane] = true


func note_check(owner_name: String, was_gambit: bool) -> void:
	var owner := clean_owner(owner_name)
	states[owner]["checks"] = int(states[owner]["checks"]) + 1
	if was_gambit:
		states[owner]["gambits_checked"] = int(states[owner]["gambits_checked"]) + 1


func note_face_down_probed(owner_name: String) -> void:
	states[clean_owner(owner_name)]["face_down_probed"] = true


func note_parry_success(owner_name: String, lane: String, card_count: int) -> void:
	var owner := clean_owner(owner_name)
	if lane in ["left", "right"]:
		states[owner]["successful_side_parry"] = true
	if card_count >= 3:
		states[owner]["successful_three_card_parry"] = true


func note_monarch_strike(owner_name: String) -> void:
	states[clean_owner(owner_name)]["monarch_strike"] = true


func note_unit_defeated(victim_owner_name: String, defeated_card: CardData, winner_owner_name: String = "") -> void:
	var victim := clean_owner(victim_owner_name)
	states[victim]["units_lost"] = int(states[victim]["units_lost"]) + 1


func note_clash_win(owner_name: String, winning_card: CardData, ap_margin: int, used_interception: bool = false, attacking_win: bool = true) -> void:
	var owner := clean_owner(owner_name)
	if attacking_win and ap_margin >= 3:
		states[owner]["ap_margin_win"] = true
	if used_interception:
		states[owner]["interception_win"] = true
	if winning_card != null and (states[owner]["promoted_cards"] as Array).has(winning_card):
		states[owner]["promoted_unit_defeated_enemy"] = true


func capture_deployment_end() -> void:
	for owner in ["player", "enemy"]:
		var center := bf.find_slot_by_owner_row_lane(owner, "front", "middle")
		states[owner]["center_start_card"] = bf.get_slot_card_data(center)
		var plan := plans.get(owner, {}) as Dictionary
		var id := String(plan.get("id", ""))
		states[owner]["deployment_met"][id] = evaluate_deployment_objective(owner, id)


func evaluate_deployment_objective(owner: String, id: String) -> bool:
	match id:
		"cursed_by_aurion":
			var remaining := bf.tribute_manager.current_tribute_points if owner == "player" and bf.tribute_manager != null else bf.ai_current_tp
			return bool(states[owner]["gambit_tributed"]) and remaining == 0
		"hold_your_formations":
			for lane in ["left", "middle", "right"]:
				if not bf.is_unit_card(bf.get_slot_card_data(bf.find_slot_by_owner_row_lane(owner, "front", lane))):
					return false
			return true
		"standard_of_naereons_hearth":
			var faction_counts: Dictionary = {}
			var tribute_cards: Array = bf.tribute_pile.tribute_cards if owner == "player" and bf.tribute_pile != null else bf.ai_tribute
			for card_variant in tribute_cards:
				var card := card_variant as CardData
				if card == null:
					continue
				var faction := card.race.to_lower().strip_edges()
				faction_counts[faction] = int(faction_counts.get(faction, 0)) + 1
				if faction != "" and int(faction_counts[faction]) >= 3:
					return true
			return false
		"brugos_onslaught":
			for lane in ["left", "middle", "right"]:
				if bf.get_slot_combat_ap(bf.find_slot_by_owner_row_lane(owner, "front", lane)) >= 6:
					return true
			return false
	return false


func resolve_end_of_round() -> void:
	for owner in ["player", "enemy"]:
		var plan := plans.get(owner, {}) as Dictionary
		if plan.is_empty():
			continue
		var id := String(plan.get("id", ""))
		if not objective_met(owner, id):
			bf.log_msg(String(plan.get("name", "Battleplan")) + " objective was not completed.")
			continue
		var reward := int(plan.get("aurion_reward", 0))
		if reward <= 0:
			continue
		bf.add_aurion("player" if owner == "player" else "ai", reward, "Battleplan completed: " + String(plan.get("name", id)) + ".")


func objective_met(owner: String, id: String) -> bool:
	var state := states[owner] as Dictionary
	match id:
		"ascension_of_the_sylverin_courts":
			return any_promoted_unit_survives(owner)
		"assassins_guilds_heritage":
			return bool(state["promotion_inherited_equipment"])
		"cursed_by_aurion", "hold_your_formations", "standard_of_naereons_hearth", "brugos_onslaught":
			return bool(state["deployment_met"].get(id, false))
		"vornvek_masterwork":
			return has_weapon_and_armor(owner)
		"a_seers_incredible_foresight":
			return int(state["gambits_checked"]) > 0
		"gravemarch_recon":
			return int(state["checks"]) > 0
		"jormunds_iron_gate":
			return bool(state["interception_win"])
		"liorvynn_mirage_deception":
			return bool(state["face_down_probed"])
		"solkaran_hollow":
			return int(state["units_lost"]) >= 2
		"tenacity_of_the_orcs":
			return bool(state["successful_side_parry"])
		"the_last_stand_of_vornvek":
			return bool(state["successful_three_card_parry"])
		"the_skar_river_standoff":
			return int(state["attacks_declared"]) == 0 and (state["passed_lanes"] as Dictionary).size() >= 3
		"veil_of_mists":
			return untouched_face_down_backrows(owner) >= 2
		"youthful_knights_resolve":
			var center := bf.find_slot_by_owner_row_lane(owner, "front", "middle")
			return state["center_start_card"] != null and bf.get_slot_card_data(center) == state["center_start_card"]
		"all_are_not_born_equal":
			return bool(state["ap_margin_win"])
		"leonards_signature_pincer_movement":
			var opponent := "enemy" if owner == "player" else "player"
			return bf.get_front_lane_ap_total(owner, "left") > bf.get_front_lane_ap_total(opponent, "left") and bf.get_front_lane_ap_total(owner, "right") > bf.get_front_lane_ap_total(opponent, "right")
		"rites_of_ascension":
			return bool(state["promoted_unit_defeated_enemy"])
		"the_red_morning_at_skarfield":
			return bool(state["monarch_strike"])
	return false


func any_promoted_unit_survives(owner: String) -> bool:
	var promoted_cards := states[owner]["promoted_cards"] as Array
	for lane in ["left", "middle", "right"]:
		if promoted_cards.has(bf.get_slot_card_data(bf.find_slot_by_owner_row_lane(owner, "front", lane))):
			return true
	return false


func has_weapon_and_armor(owner: String) -> bool:
	for lane in ["left", "middle", "right"]:
		var slot := bf.find_slot_by_owner_row_lane(owner, "front", lane)
		if not bf.is_unit_card(bf.get_slot_card_data(slot)) or not slot.has_method("get_equipment_cards"):
			continue
		var has_weapon := false
		var has_armor := false
		for equipment_variant in slot.call("get_equipment_cards"):
			var equipment := equipment_variant as CardData
			var name := equipment.card_name.to_lower() if equipment != null else ""
			has_weapon = has_weapon or ["cleaver", "blade", "sword", "maul", "bow", "axe", "spear"].any(func(word: String) -> bool: return name.contains(word))
			has_armor = has_armor or ["armor", "armour", "breastplate", "cuirass", "bracers", "shield"].any(func(word: String) -> bool: return name.contains(word))
		if has_weapon and has_armor:
			return true
	return false


func untouched_face_down_backrows(owner: String) -> int:
	var count := 0
	for lane in ["left", "middle", "right"]:
		var slot := bf.find_slot_by_owner_row_lane(owner, "back", lane)
		if slot != null and bf.get_slot_card_data(slot) != null and bool(slot.get_meta("face_down", false)) and not bool(slot.get_meta("interacted_this_round", false)):
			count += 1
	return count
