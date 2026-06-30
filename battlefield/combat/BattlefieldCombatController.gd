class_name BattlefieldCombatController
extends RefCounted

## Domain controller extracted from BattlefieldManager. The manager facade preserves
## scene callbacks and dynamic-call compatibility.

var bf: BattlefieldManager


func _init(owner_battlefield: BattlefieldManager) -> void:
	bf = owner_battlefield


func reset_combat_state() -> void:
	bf.combat_direction_selected = false
	bf.combat_lane_order.clear()
	bf.combat_next_lane_index = 0
	bf.original_combat_priority_owner = bf.get_initiative_priority_owner()
	bf.combat_priority_owner = bf.original_combat_priority_owner
	bf.player_passed_current_lane = false
	bf.ai_passed_current_lane = false
	bf.enemy_fortified_lanes.clear()
	bf.player_fortified_lanes.clear()
	bf.combat_resolution_running = false
	bf.active_combat_lane = ""

func set_combat_lane_order_from_left() -> void:
	bf.combat_direction_selected = true
	bf.combat_lane_order.clear()
	bf.combat_lane_order.append("left")
	bf.combat_lane_order.append("middle")
	bf.combat_lane_order.append("right")
	bf.combat_next_lane_index = 0
	if bf.original_combat_priority_owner == "":
		bf.original_combat_priority_owner = bf.get_initiative_priority_owner()
	bf.reset_priority_for_current_lane()
	bf.set_active_combat_lane_highlight(bf.current_combat_lane())

	bf.log_msg("Combat direction selected: left to right.")

func set_combat_lane_order_from_right() -> void:
	bf.combat_direction_selected = true
	bf.combat_lane_order.clear()
	bf.combat_lane_order.append("right")
	bf.combat_lane_order.append("middle")
	bf.combat_lane_order.append("left")
	bf.combat_next_lane_index = 0
	if bf.original_combat_priority_owner == "":
		bf.original_combat_priority_owner = bf.get_initiative_priority_owner()
	bf.reset_priority_for_current_lane()
	bf.set_active_combat_lane_highlight(bf.current_combat_lane())

	bf.log_msg("Combat direction selected: right to left.")

func resolve_lane_combat(lane: String, player_slot: Node, opponent_slot: Node) -> void:
	var player_card: CardData = bf.get_slot_card_data(player_slot)
	var opponent_card: CardData = bf.get_slot_card_data(opponent_slot)

	var player_has_unit: bool = bf.is_unit_card(player_card)
	var opponent_has_unit: bool = bf.is_unit_card(opponent_card)

	if not player_has_unit and not opponent_has_unit:
		bf.log_msg(lane.capitalize() + " lane: no front-row units on either side.")
		return

	if player_has_unit and not opponent_has_unit:
		bf.resolve_monarch_strike(lane, player_card)
		return

	if not player_has_unit and opponent_has_unit:
		bf.resolve_ai_monarch_strike(lane, opponent_card)
		return

	if bf.player_has_initiative:
		await bf.resolve_directed_clash(lane, player_slot, player_card, opponent_slot, opponent_card, true)
	else:
		await bf.resolve_directed_clash(lane, opponent_slot, opponent_card, player_slot, player_card, false)


func resolve_directed_clash(
	lane: String,
	_attacker_slot: Node,
	attacker_card: CardData,
	defender_slot: Node,
	defender_card: CardData,
	player_is_attacker: bool
) -> void:
	if attacker_card == null or defender_card == null:
		return
	var interception := await choose_center_interceptor(lane, _attacker_slot, defender_slot)
	var used_interception := not interception.is_empty()
	if used_interception:
		defender_slot = interception.get("slot") as Node
		defender_card = interception.get("card") as CardData
	if await bf.resolve_vanish_when_targeted(defender_slot, defender_card, not player_is_attacker):
		return

	var precision := bf.slot_has_control_ability(_attacker_slot, &"precision")
	var ignores_protection := precision != null
	if precision != null:
		await bf.show_control_trigger(precision, "Defender's Protection abilities ignored")
	var attacker_ap: int = await bf.get_slot_combat_ap_with_protection_announcements(_attacker_slot)
	var defender_ap: int = await bf.get_slot_combat_ap_with_protection_announcements(defender_slot, ignores_protection)
	var equalizer := bf.slot_has_protection_ability(defender_slot, &"equalizer") if not ignores_protection else null
	if equalizer != null and attacker_ap == defender_ap + 1:
		await bf.show_protection_trigger(equalizer, "Both units defeated")
		var defender_destroyed := await bf.destroy_unit_with_protection(defender_slot, _attacker_slot, true, ignores_protection)
		var attacker_destroyed := await bf.destroy_unit_with_protection(_attacker_slot, defender_slot, true)
		award_mutual_clash_aurion(attacker_card, defender_card, player_is_attacker, attacker_destroyed, defender_destroyed)
		return

	var attacker_label: String = "Player" if player_is_attacker else "Opponent"
	var defender_label: String = "Opponent" if player_is_attacker else "Player"

	bf.log_msg(
		lane.capitalize()
		+ " lane attack: "
		+ attacker_label
		+ " "
		+ attacker_card.card_name
		+ " AP "
		+ str(attacker_ap)
		+ " vs "
		+ defender_label
		+ " "
		+ defender_card.card_name
		+ " AP "
		+ str(defender_ap)
	)

	if attacker_ap == defender_ap:
		var defender_destroyed := await bf.destroy_unit_with_protection(defender_slot, _attacker_slot, true, ignores_protection)
		var attacker_destroyed := await bf.destroy_unit_with_protection(_attacker_slot, defender_slot, true)
		award_mutual_clash_aurion(attacker_card, defender_card, player_is_attacker, attacker_destroyed, defender_destroyed)

		bf.log_msg(
			lane.capitalize()
			+ " lane kamikaze clash: "
			+ attacker_label
			+ " "
			+ attacker_card.card_name
			+ " and "
			+ defender_label
			+ " "
			+ defender_card.card_name
			+ " destroyed each other."
		)

		return

	if attacker_ap > defender_ap:
		if not await bf.control_can_parry(_attacker_slot, defender_slot, attacker_ap, defender_ap):
			var destroyed := await bf.destroy_unit_with_protection(defender_slot, _attacker_slot, true, ignores_protection)
			if destroyed:
				var scorer := "player" if player_is_attacker else "ai"
				bf.add_aurion(scorer, bf.get_unit_defeat_aurion_reward(defender_card), "Destroyed " + defender_card.card_name + " with an unparryable attack.")
				bf.battleplan_objective_controller.note_clash_win("player" if player_is_attacker else "enemy", attacker_card, attacker_ap - defender_ap)
			return
		if not player_is_attacker:
			bf.parry_system.begin(lane, _attacker_slot, attacker_card, defender_slot, defender_card, attacker_ap, defender_ap, ignores_protection)
			return

		await bf.resolve_ai_parry_attempt(attacker_card, defender_slot, defender_card, attacker_ap, defender_ap, ignores_protection)
		return

	# The attacker knowingly chose to fight into a stronger unit.
	# Voluntary lower-AP attacks are suicide and do not open the Parry Chain.
	var attacker_destroyed := await bf.destroy_unit_with_protection(_attacker_slot, defender_slot, true)
	if not attacker_destroyed:
		return
	bf.battleplan_objective_controller.note_clash_win("enemy" if player_is_attacker else "player", defender_card, defender_ap - attacker_ap, used_interception, false)
	bf.log_msg(
		"Suicide attack: "
		+ attacker_label
		+ " "
		+ attacker_card.card_name
		+ " AP "
		+ str(attacker_ap)
		+ " attacked into "
		+ defender_label
		+ " "
		+ defender_card.card_name
		+ " AP "
		+ str(defender_ap)
		+ " and was destroyed."
	)

	var defender_score_owner: String = "ai" if player_is_attacker else "player"
	bf.add_aurion(defender_score_owner, bf.get_unit_defeat_aurion_reward(attacker_card), "Destroyed " + attacker_card.card_name + " after it knowingly attacked a higher-AP unit.")
	return


func choose_center_interceptor(lane: String, attacker_slot: Node, original_defender_slot: Node) -> Dictionary:
	if lane == "middle" or lane not in ["left", "right"]:
		return {}

	var attacker := bf.get_slot_card_data(attacker_slot)

	var siege := bf.slot_has_mobility_ability(attacker_slot, &"siege")
	if siege != null:
		await bf.show_timed_mobility_message("SIEGE  -  Centre interception blocked")
		return {}

	var defender_owner := String(original_defender_slot.get_meta("owner", ""))
	var center := bf.find_slot_by_owner_row_lane(defender_owner, "front", "middle")
	var center_card := bf.get_slot_card_data(center)

	if center == null:
		return {}

	if center == original_defender_slot:
		return {}

	if not bf.is_unit_card(center_card):
		return {}

	if bf.is_unit_chained_down(center):
		return {}

	var intercept := true

	if defender_owner == "player":
		var original_defender_card := bf.get_slot_card_data(original_defender_slot)
		var original_name := "side unit"

		if original_defender_card != null:
			original_name = original_defender_card.card_name

		intercept = await bf.prompt_mobility_choice(
			"CENTER INTERCEPTION  -  "
			+ center_card.card_name
			+ " can take the hit for your "
			+ lane.capitalize()
			+ " lane unit, "
			+ original_name
			+ ". Choose INTERCEPT to move the clash/parry chain to the center unit, or PARRY to keep defending with the side unit.",
			"INTERCEPT",
			"PARRY"
		)
	else:
		var attacker_ap := bf.get_slot_combat_ap(attacker_slot)
		var original_defender_ap := bf.get_slot_combat_ap(original_defender_slot)
		var center_ap := bf.get_slot_combat_ap(center)

		# AI uses the center if it improves the defense or can outright beat/survive the attacker.
		intercept = center_ap >= attacker_ap or center_ap > original_defender_ap

	if not intercept:
		return {}

	await bf.show_timed_mobility_message(
		"CENTER INTERCEPTION  -  "
		+ center_card.card_name
		+ " protects the "
		+ lane.capitalize()
		+ " lane"
	)

	return {
		"slot": center,
		"card": center_card,
		"attacker": attacker
	}


func award_mutual_clash_aurion(
	attacker_card: CardData,
	defender_card: CardData,
	player_is_attacker: bool,
	attacker_destroyed: bool,
	defender_destroyed: bool
) -> void:
	if defender_destroyed:
		var attacker_owner := "player" if player_is_attacker else "ai"
		bf.add_aurion(attacker_owner, bf.get_unit_defeat_aurion_reward(defender_card), "Mutual clash defeated " + defender_card.card_name + ".")
	if attacker_destroyed:
		var defender_owner := "ai" if player_is_attacker else "player"
		bf.add_aurion(defender_owner, bf.get_unit_defeat_aurion_reward(attacker_card), "Mutual clash defeated " + attacker_card.card_name + ".")


func resolve_ai_parry_attempt(
	attacker_card: CardData,
	defender_slot: Node,
	defender_card: CardData,
	attacker_ap: int = -1,
	defender_ap: int = -1,
	ignore_protection: bool = false
) -> void:
	var attack_power := attacker_ap if attacker_ap >= 0 else attacker_card.ap
	var defense_power := defender_ap if defender_ap >= 0 else defender_card.ap
	var required: int = maxi(attack_power - defense_power, 1)
	var available_dp := 0

	for hand_card in bf.ai_hand:
		if hand_card != null:
			available_dp += get_ai_parry_card_dp(hand_card)

	if available_dp < required:
		var destroyed := await bf.destroy_unit_with_protection(defender_slot, null, true, ignore_protection)

		if destroyed:
			bf.log_msg("Opponent could not parry. " + defender_card.card_name + " was destroyed.")
			bf.add_aurion("player", bf.get_unit_defeat_aurion_reward(defender_card), "Destroyed " + defender_card.card_name + " in combat.")
			bf.battleplan_objective_controller.note_clash_win("player", attacker_card, attack_power - defense_power)

		return

	bf.log_msg("Opponent opens a Parry and needs " + str(required) + " DP.")

	var gathered := 0
	var parry_cards: Array[CardData] = []
	var parry_target := bf.get_enemy_visual_target("EnemyParryPitVisual")

	while gathered < required:
		var remaining := required - gathered
		var hand_index := bf.find_ai_parry_card_index(remaining)

		if hand_index < 0:
			break

		var sacrifice: CardData = bf.ai_hand[hand_index]

		await bf.play_enemy_hand_to_node_animation(sacrifice, parry_target, false)

		bf.ai_hand.pop_at(hand_index)
		bf.ai_discard.append(sacrifice)

		var base_dp := maxi(sacrifice.dp, 0)
		var gained_dp := get_ai_parry_card_dp(sacrifice)

		var solidarity := bf.get_card_protection_ability(sacrifice, &"solidarity")

		if solidarity != null:
			var solidarity_bonus := maxi(gained_dp - base_dp, 0)

			if solidarity_bonus > 0:
				await bf.show_protection_trigger(solidarity, "Opponent +" + str(solidarity_bonus) + " DP from frontline units")

		if parry_cards.is_empty():
			var deflect := bf.slot_has_protection_ability(defender_slot, &"deflect")

			if deflect != null:
				gained_dp += 2
				await bf.show_protection_trigger(deflect, "First Parry card gains +2 DP")

		gathered += gained_dp
		parry_cards.append(sacrifice)

		if bf.opponent_visuals != null and bf.opponent_visuals.has_method("add_parry_card"):
			bf.opponent_visuals.add_parry_card(sacrifice)

		bf.update_ai_visuals()
		bf.log_msg("Opponent parries with " + sacrifice.card_name + " for " + str(gained_dp) + " DP.")
		await bf.get_tree().create_timer(0.28).timeout

	if gathered >= required:
		bf.log_msg("Opponent Parry succeeds. " + defender_card.card_name + " survives.")
		await bf.resolve_ai_successful_parry_abilities(parry_cards)
		bf.battleplan_objective_controller.note_parry_success("enemy", bf.get_slot_lane(defender_slot), parry_cards.size())
	else:
		var destroyed := await bf.destroy_unit_with_protection(defender_slot, null, true, ignore_protection)

		if destroyed:
			bf.log_msg("Opponent Parry fails. " + defender_card.card_name + " was destroyed.")
			bf.add_aurion("player", bf.get_unit_defeat_aurion_reward(defender_card), "Destroyed " + defender_card.card_name + " in combat.")
			bf.battleplan_objective_controller.note_clash_win("player", attacker_card, attack_power - defense_power)

	await bf.get_tree().create_timer(0.55).timeout

	if bf.opponent_visuals != null and bf.opponent_visuals.has_method("clear_parry_cards"):
		bf.opponent_visuals.clear_parry_cards()


func get_ai_parry_card_dp(card_data: CardData) -> int:
	if card_data == null:
		return 0

	var total := maxi(card_data.dp, 0)
	var solidarity := bf.get_card_protection_ability(card_data, &"solidarity")

	if solidarity != null:
		total += bf.count_frontline_units("enemy")

	return total


func resolve_ai_successful_parry_abilities(parry_cards: Array[CardData]) -> void:
	var draw_count := 0
	var trigger: AbilityData = null
	if parry_cards.size() == 1:
		trigger = bf.get_card_protection_ability(parry_cards[0], &"shield_burst")
		if trigger != null:
			draw_count = 2
	if parry_cards.size() >= 3:
		var last_stand := bf.get_card_protection_ability(parry_cards[2], &"last_stand")
		if last_stand != null:
			trigger = last_stand
			draw_count += 3
	if trigger != null and draw_count > 0:
		await bf.show_protection_trigger(trigger, "Opponent draws %d cards" % draw_count)
		for i in range(draw_count):
			if bf.ai_deck.is_empty():
				break
			bf.ai_hand.append(bf.ai_deck.pop_back() as CardData)
		bf.update_ai_visuals()
	await bf.resolve_ambush_from_parry(parry_cards, "enemy")


func find_ai_parry_card_index(remaining_dp: int) -> int:
	var exact_or_smallest := -1
	var exact_or_smallest_dp := 1_000_000
	var largest := -1
	var largest_dp := -1

	for index in range(bf.ai_hand.size()):
		var card_data: CardData = bf.ai_hand[index]

		if card_data == null:
			continue

		var card_parry_dp := get_ai_parry_card_dp(card_data)

		if card_parry_dp <= 0:
			continue

		if card_parry_dp >= remaining_dp and card_parry_dp < exact_or_smallest_dp:
			exact_or_smallest = index
			exact_or_smallest_dp = card_parry_dp

		if card_parry_dp > largest_dp:
			largest = index
			largest_dp = card_parry_dp

	return exact_or_smallest if exact_or_smallest >= 0 else largest


func get_slot_card_data(slot: Node) -> CardData:
	if slot == null:
		return null

	if slot.has_method("get_placed_card_data"):
		return slot.get_placed_card_data()

	return null


func get_slot_combat_ap(slot: Node, ignore_protection: bool = false) -> int:
	if slot == null:
		return 0

	var card_data := bf.get_slot_card_data(slot)

	if not bf.is_unit_card(card_data):
		return 0

	var total := maxi(card_data.ap, 0)
	var owner_name := String(slot.get_meta("owner", ""))

	if not ignore_protection and bf.slot_has_protection_ability(slot, &"shielded") != null and owner_name != bf.combat_priority_owner:
		total += 2

	if bf.control_owner_has_handicap(owner_name):
		total -= 1
	if int(slot.get_meta("control_wrong_check_penalty_turn", -1)) == bf.turn_number:
		total -= 2

	# Solidarity is DP-only. Do not add it to combat AP.

	if slot != null and int(slot.get_meta("vortex_bonus_turn", -1)) == bf.turn_number and slot.has_method("get_stacked_unit_cards"):
		for stacked in slot.call("get_stacked_unit_cards"):
			var stacked_card := stacked as CardData

			if stacked_card != null:
				total += maxi(stacked_card.ap, 0)

	return maxi(total, 0)


func count_frontline_units(owner_name: String) -> int:
	var count := 0
	for lane_name in ["left", "middle", "right"]:
		if bf.lane_has_front_unit(owner_name, lane_name):
			count += 1
	return count


func find_slot_by_owner_row_lane(owner_name: String, row: String, lane: String) -> Node:
	if bf.board_slots == null:
		return null

	for slot in bf.board_slots.get_children():
		if String(slot.get_meta("owner", "")) == owner_name and String(slot.get_meta("row", "")) == row and bf.get_slot_lane(slot) == lane:
			return slot

	return null


func lane_has_front_unit(owner_name: String, lane: String) -> bool:
	var slot: Node = bf.find_slot_by_owner_row_lane(owner_name, "front", lane)
	var card_data: CardData = bf.get_slot_card_data(slot)
	return bf.is_unit_card(card_data)


func lane_has_any_front_unit(lane: String) -> bool:
	return bf.lane_has_front_unit("player", lane) or bf.lane_has_front_unit("enemy", lane)


func get_slot_lane(slot: Node) -> String:
	if slot == null:
		return ""

	var slot_id: String = String(slot.get_meta("slot_id", "")).to_lower()

	if slot_id.contains("left"):
		return "left"

	if slot_id.contains("middle"):
		return "middle"

	if slot_id.contains("right"):
		return "right"

	var column: String = String(slot.get_meta("column", "")).to_lower()

	if column == "left" or column == "middle" or column == "right":
		return column

	return ""


func promote_slot_unit_preserving_equipment(slot: Node, new_unit: CardData, slot_owner: String) -> bool:
	if slot == null or new_unit == null:
		return false

	var old_unit: CardData = bf.get_slot_card_data(slot)
	var equipment_cards: Array[CardData] = []

	if slot.has_method("get_equipment_cards"):
		var raw_equipment_cards: Array = slot.get_equipment_cards()

		for equipment_card in raw_equipment_cards:
			if equipment_card == null:
				continue

			equipment_cards.append(equipment_card as CardData)

	if old_unit != null:
		bf.discard_cards_with_animation([old_unit], slot, slot_owner)

	if slot.has_method("clear_slot"):
		slot.clear_slot()

	if not slot.has_method("place_card"):
		return false

	var placed_successfully: bool = slot.place_card(bf.TEST_CARD_SCENE, new_unit, false)

	if not placed_successfully:
		bf.update_ai_visuals()
		return false

	for equipment_card in equipment_cards:
		if equipment_card == null:
			continue

		if not slot.has_method("attach_equipment"):
			continue

		if slot.has_method("can_attach_equipment") and not slot.can_attach_equipment():
			continue

		slot.attach_equipment(bf.TEST_CARD_SCENE, equipment_card)
	var inherited_count := 0
	if slot.has_method("get_equipment_cards"):
		inherited_count = (slot.call("get_equipment_cards") as Array).size()
	bf.battleplan_objective_controller.note_promotion(slot_owner, new_unit, inherited_count)

	bf.update_ai_visuals()
	return true


func send_slot_card_to_discard(slot: Node) -> void:
	if slot == null:
		return

	var slot_owner: String = String(slot.get_meta("owner", ""))
	var card_data: CardData = bf.get_slot_card_data(slot)
	var cards_to_discard: Array[CardData] = []

	if card_data != null:
		cards_to_discard.append(card_data)

	if slot.has_method("get_equipment_cards"):
		var equipment_cards: Array = slot.get_equipment_cards()

		for equipment_card in equipment_cards:
			if equipment_card == null:
				continue

			cards_to_discard.append(equipment_card as CardData)

	if slot.has_method("get_stacked_unit_cards"):
		var stacked_cards: Array = slot.call("get_stacked_unit_cards")
		for stacked_card in stacked_cards:
			if stacked_card == null:
				continue
			cards_to_discard.append(stacked_card as CardData)

	if not cards_to_discard.is_empty():
		bf.discard_cards_with_animation(cards_to_discard, slot, slot_owner)

	if slot.has_method("clear_slot"):
		slot.clear_slot()


func advance_combat_lane_after_resolution() -> void:
	bf.clear_active_combat_lane_highlight()
	bf.combat_next_lane_index += 1
	bf.player_passed_current_lane = false
	bf.ai_passed_current_lane = false

	if bf.current_phase != bf.BattlePhase.COMBAT:
		return

	if bf.parry_system.active:
		return

	await bf.skip_empty_combat_lanes_with_pause()

	if bf.combat_next_lane_index >= bf.combat_lane_order.size():
		bf.combat_priority_owner = ""
		bf.log_msg("All combat lanes resolved. Starting the next round.")
		return

	bf.reset_priority_for_current_lane()
	var next_lane: String = bf.combat_lane_order[bf.combat_next_lane_index]
	bf.set_active_combat_lane_highlight(next_lane)

	if bf.combat_priority_owner == "ai":
		bf.log_msg("Next lane: " + next_lane + ". Initiative returns to AI.")
		await bf.resolve_ai_current_priority_lane(next_lane)
	else:
		bf.set_lane_priority_to_player(next_lane, "Next lane: " + next_lane + ". Initiative returns to Player.")

func skip_empty_combat_lanes_with_pause() -> void:
	while bf.current_phase == bf.BattlePhase.COMBAT and bf.combat_next_lane_index < bf.combat_lane_order.size():
		var lane: String = bf.combat_lane_order[bf.combat_next_lane_index]

		if bf.lane_has_any_front_unit(lane):
			return

		bf.set_active_combat_lane_highlight(lane)
		bf.log_msg(lane.capitalize() + " lane has no front-row units on either side. Skipping after a short pause.")
		await bf.get_tree().create_timer(bf.COMBAT_LANE_START_DELAY).timeout
		bf.clear_active_combat_lane_highlight()
		bf.combat_next_lane_index += 1


func can_player_attack_lane_from_menu(lane: String) -> bool:
	if not bf.can_player_take_priority_action_in_lane(lane):
		return false
	if bf.control_lane_attack_is_disabled("player", lane):
		return false
	return not bf.get_player_attackers_for_lane(lane).is_empty()


func get_player_attackers_for_lane(target_lane: String) -> Array[Node]:
	var attackers: Array[Node] = []
	var direct := bf.find_slot_by_owner_row_lane("player", "front", target_lane)
	if bf.is_unit_card(bf.get_slot_card_data(direct)) and not bf.is_unit_chained_down(direct):
		attackers.append(direct)
	return attackers

func can_player_check_lane_from_menu(lane: String) -> bool:
	if not bf.can_player_take_priority_action_in_lane(lane):
		return false

	var player_front_slot: Node = bf.find_slot_by_owner_row_lane("player", "front", lane)
	var player_card: CardData = bf.get_slot_card_data(player_front_slot)
	if bf.control_unit_must_attack(player_front_slot):
		return false

	# Checking a hidden back-row card requires your front-row unit in that lane.
	return bf.is_unit_card(player_card)


func can_player_pass_lane_from_menu(lane: String) -> bool:
	if not bf.can_player_take_priority_action_in_lane(lane):
		return false
	var player_slot := bf.find_slot_by_owner_row_lane("player", "front", lane)
	if bf.control_unit_must_attack(player_slot) and bf.can_player_attack_lane_from_menu(lane):
		return false
	return true


func can_player_take_priority_action_in_lane(lane: String) -> bool:
	if bf.current_phase != bf.BattlePhase.COMBAT:
		return false

	if bf.parry_system.active:
		return false

	if lane == "":
		return false

	if not bf.is_lane_current_or_valid_combat_start(lane):
		return false

	if not bf.combat_direction_selected:
		return bf.player_has_initiative or bf.combat_priority_owner == "player"

	return bf.combat_priority_owner == "player"


func is_lane_current_or_valid_combat_start(lane: String) -> bool:
	if lane == "":
		return false

	if not bf.combat_direction_selected:
		return lane == "left" or lane == "right"

	if bf.combat_next_lane_index >= bf.combat_lane_order.size():
		return false

	var expected_lane: String = bf.combat_lane_order[bf.combat_next_lane_index]
	return lane == expected_lane


func get_initiative_priority_owner() -> String:
	return "player" if bf.player_has_initiative else "ai"


func reset_priority_for_current_lane() -> void:
	if bf.original_combat_priority_owner == "":
		bf.original_combat_priority_owner = bf.get_initiative_priority_owner()
	bf.combat_priority_owner = bf.original_combat_priority_owner
	bf.player_passed_current_lane = false
	bf.ai_passed_current_lane = false

func current_combat_lane() -> String:
	if bf.combat_next_lane_index < 0 or bf.combat_next_lane_index >= bf.combat_lane_order.size():
		return ""

	return bf.combat_lane_order[bf.combat_next_lane_index]


func set_lane_priority_to_player(lane: String, reason: String = "") -> void:
	bf.combat_priority_owner = "player"
	bf.set_active_combat_lane_highlight(lane)
	if reason != "":
		bf.log_msg(reason)

	var player_front_slot: Node = bf.find_slot_by_owner_row_lane("player", "front", lane)
	var enemy_back_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "back", lane)
	var player_card: CardData = bf.get_slot_card_data(player_front_slot)
	var enemy_back_card: CardData = bf.get_slot_card_data(enemy_back_slot)
	var enemy_back_face_down: bool = enemy_back_card != null and enemy_back_slot != null and bool(enemy_back_slot.get_meta("face_down", false))

	if bf.is_unit_card(player_card):
		if enemy_back_face_down:
			bf.log_msg("Player has priority in the " + lane + " lane. Right-click and choose Attack, Check, or Pass.")
		else:
			bf.log_msg("Player has priority in the " + lane + " lane. Right-click and choose Attack or Pass.")
	else:
		bf.log_msg("Player has priority in the " + lane + " lane, but has no front-row unit. Right-click and choose Pass.")


func set_lane_priority_to_ai(lane: String, reason: String = "") -> void:
	bf.combat_priority_owner = "ai"
	bf.set_active_combat_lane_highlight(lane)
	if reason != "":
		bf.log_msg(reason)
	bf.log_msg("AI has priority in the " + lane + " lane.")

func attack_from_board_action_menu(slot: Node) -> void:
	if bf.combat_resolution_running:
		bf.log_msg("Combat is already resolving. Wait for the current lane.")
		return

	if slot == null:
		return

	if bf.current_phase != bf.BattlePhase.COMBAT:
		bf.log_msg("Attack is only available during Combat.")
		return

	if bf.parry_system.active:
		bf.log_msg("Resolve the current parry prompt first.")
		return

	var lane: String = bf.get_slot_lane(slot)

	if lane == "":
		return

	if not bf.can_player_attack_lane_from_menu(lane):
		bf.log_msg("You do not have priority to attack in this lane.")
		return

	await bf.resolve_player_attack_lane_with_visuals(lane)


func pass_from_board_action_menu(slot: Node) -> void:
	if bf.combat_resolution_running:
		bf.log_msg("Combat is already resolving. Wait for the current lane.")
		return

	if slot == null:
		return

	if bf.current_phase != bf.BattlePhase.COMBAT:
		bf.log_msg("Pass is only available during Combat.")
		return

	if bf.parry_system.active:
		bf.log_msg("Resolve the current parry prompt first.")
		return

	var lane: String = bf.get_slot_lane(slot)

	if lane == "":
		return

	if not bf.can_player_pass_lane_from_menu(lane):
		bf.log_msg("You do not have priority to pass in this lane.")
		return

	await bf.resolve_player_pass_lane_with_visuals(lane)

func resolve_monarch_strike(lane: String, attacker_card: CardData) -> void:
	if attacker_card == null:
		return

	bf.add_aurion("player", 1, "Monarch Strike through the " + lane + " lane by " + attacker_card.card_name + ".")
	bf.battleplan_objective_controller.note_monarch_strike("player")
	bf.log_msg(lane.capitalize() + " lane: Player Monarch Strike successful.")


func resolve_ai_monarch_strike(lane: String, attacker_card: CardData) -> void:
	if attacker_card == null:
		return

	bf.add_aurion("ai", 1, "Monarch Strike through the " + lane + " lane by " + attacker_card.card_name + ".")
	bf.battleplan_objective_controller.note_monarch_strike("enemy")
	bf.log_msg(lane.capitalize() + " lane: AI Monarch Strike successful.")


func resolve_player_attack_lane_with_visuals(lane: String) -> void:
	if bf.combat_resolution_running:
		return

	bf.combat_resolution_running = true

	if not bf.prepare_player_lane_action(lane):
		bf.combat_resolution_running = false
		return

	bf.player_passed_current_lane = false
	bf.set_active_combat_lane_highlight(lane)
	bf.log_msg("Resolving player attack in the " + lane + " lane.")
	await bf.get_tree().create_timer(bf.COMBAT_LANE_START_DELAY).timeout

	var attacker_candidates := bf.get_player_attackers_for_lane(lane)
	var player_front_slot: Node = null
	if attacker_candidates.size() == 1:
		player_front_slot = attacker_candidates[0]
	var enemy_front_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "front", lane)
	var enemy_back_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "back", lane)

	var player_card: CardData = bf.get_slot_card_data(player_front_slot)
	var enemy_front_card: CardData = bf.get_slot_card_data(enemy_front_slot)
	var enemy_back_card: CardData = bf.get_slot_card_data(enemy_back_slot)
	var enemy_back_is_face_down: bool = enemy_back_card != null and enemy_back_slot != null and bool(enemy_back_slot.get_meta("face_down", false))

	if not bf.is_unit_card(player_card):
		bf.log_msg(lane.capitalize() + " lane: you have no front-row unit to attack with. Use Pass instead.")
		bf.combat_resolution_running = false
		return
	bf.battleplan_objective_controller.note_attack("player")

	if bf.get_slot_lane(player_front_slot) != lane:
		await bf.show_timed_mobility_message("VOLLEY  -  Diagonal attack")
	if bf.get_slot_lane(player_front_slot) != "middle" and bf.slot_has_mobility_ability(player_front_slot, &"siege") != null:
		await bf.show_timed_mobility_message("SIEGE  -  Centre interception blocked")
	var infiltrator := bf.slot_has_protection_ability(player_front_slot, &"infiltrator")
	if enemy_back_is_face_down and infiltrator != null:
		await bf.show_protection_trigger(infiltrator, "Backline bypassed")
		enemy_back_is_face_down = false

	if enemy_back_is_face_down:
		# Attacking a lane with a hidden enemy back-row card always resolves the bluff first.
		# If it is not a Gambit, the decoy is discarded and the player keeps priority,
		# then the player may right-click again to attack the front row or Monarch.
		await bf.resolve_attack_into_face_down_backrow(lane, player_card, enemy_front_slot, enemy_back_slot, enemy_back_card)
		bf.combat_resolution_running = false
		return

	if enemy_front_card == null:
		# Back-row cards do not protect the Monarch once there is no hidden card to resolve.
		# If the player has the only front unit in this lane, the player gets Monarch Strike.
		bf.resolve_monarch_strike(lane, player_card)
		await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
		await bf.advance_combat_lane_after_resolution()
		bf.combat_resolution_running = false
		return

	if enemy_front_card != null:
		await bf.resolve_lane_combat(lane, player_front_slot, enemy_front_slot)

		if bf.parry_system.active:
			bf.combat_resolution_running = false
			return

		await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
		await bf.advance_combat_lane_after_resolution()
		bf.combat_resolution_running = false
		return

	bf.log_msg(lane.capitalize() + " lane: enemy back row is occupied but not face down. Attack cannot resolve yet.")
	bf.combat_resolution_running = false


func resolve_player_pass_lane_with_visuals(lane: String) -> void:
	if bf.combat_resolution_running:
		return

	bf.combat_resolution_running = true

	if not bf.prepare_player_lane_action(lane):
		bf.combat_resolution_running = false
		return

	bf.set_active_combat_lane_highlight(lane)
	bf.player_passed_current_lane = true
	bf.battleplan_objective_controller.note_pass("player", lane)
	bf.log_msg("Player passes priority in the " + lane + " lane.")
	await bf.get_tree().create_timer(bf.COMBAT_LANE_START_DELAY).timeout

	if bf.ai_passed_current_lane:
		bf.log_msg("Both players passed in the " + lane + " lane. Moving to next lane.")
		await bf.advance_combat_lane_after_resolution()
		bf.combat_resolution_running = false
		return

	bf.set_lane_priority_to_ai(lane, "Priority passes to AI.")
	await bf.resolve_ai_current_priority_lane(lane)
	bf.combat_resolution_running = false

func resolve_ai_current_priority_lane(lane: String) -> void:
	if bf.current_phase != bf.BattlePhase.COMBAT:
		return

	if bf.parry_system.active:
		return

	if bf.combat_next_lane_index >= bf.combat_lane_order.size():
		return

	var expected_lane: String = bf.combat_lane_order[bf.combat_next_lane_index]

	if lane != expected_lane:
		return

	if bf.combat_priority_owner != "ai":
		return

	if bf.ai_passed_current_lane and bf.player_passed_current_lane:
		await bf.advance_combat_lane_after_resolution()
		return

	bf.set_active_combat_lane_highlight(lane)
	bf.log_msg("AI considers action in the " + lane + " lane.")
	await bf.get_tree().create_timer(bf.COMBAT_LANE_START_DELAY).timeout

	if not bf.lane_has_any_front_unit(lane):
		bf.log_msg(lane.capitalize() + " lane has no front-row units on either side. Skipping after a short pause.")
		await bf.get_tree().create_timer(bf.COMBAT_LANE_START_DELAY).timeout
		await bf.advance_combat_lane_after_resolution()
		return

	var ai_front_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "front", lane)
	var ai_card: CardData = bf.get_slot_card_data(ai_front_slot)

	if not bf.is_unit_card(ai_card):
		await bf.resolve_ai_pass_lane_with_visuals(lane)
		return

	if await bf.ai_try_activate_control(lane):
		return

	var active_result: Dictionary = await bf.ai_try_use_active_ability_before_combat(lane)

	if String(active_result.get("result", "")) == "consumed":
		return

	if bool(active_result.get("used", false)):
		await bf.get_tree().create_timer(bf.COMBAT_LANE_START_DELAY).timeout

		ai_front_slot = bf.find_slot_by_owner_row_lane("enemy", "front", lane)
		ai_card = bf.get_slot_card_data(ai_front_slot)

		if not bf.is_unit_card(ai_card):
			await bf.resolve_ai_pass_lane_with_visuals(lane)
			return

	var chosen_action: String = bf.ai_choose_combat_action(lane)

	match chosen_action:
		"check":
			bf.log_msg("AI chooses Check in the " + lane + " lane.")
			await bf.resolve_ai_check_lane_with_visuals(lane)

		"attack":
			bf.log_msg("AI chooses Attack in the " + lane + " lane.")
			await bf.resolve_ai_attack_lane_with_visuals(lane)

		"pass":
			bf.log_msg("AI chooses Pass in the " + lane + " lane.")
			await bf.resolve_ai_pass_lane_with_visuals(lane)

		_:
			bf.log_msg("AI has no clear combat action and passes in the " + lane + " lane.")
			await bf.resolve_ai_pass_lane_with_visuals(lane)


func resolve_ai_pass_lane_with_visuals(lane: String) -> void:
	bf.set_active_combat_lane_highlight(lane)
	bf.ai_passed_current_lane = true
	bf.battleplan_objective_controller.note_pass("enemy", lane)
	bf.log_msg("AI passes priority in the " + lane + " lane.")
	await bf.get_tree().create_timer(bf.COMBAT_LANE_START_DELAY).timeout

	if bf.player_passed_current_lane:
		bf.log_msg("Both players passed in the " + lane + " lane. Moving to next lane.")
		await bf.advance_combat_lane_after_resolution()
		return

	bf.set_lane_priority_to_player(lane, "Priority passes to Player.")


func resolve_ai_check_lane_with_visuals(lane: String) -> void:
	var checking_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "front", lane)
	var back_slot: Node = bf.find_slot_by_owner_row_lane("player", "back", lane)
	var back_card: CardData = bf.get_slot_card_data(back_slot)

	if back_slot == null or back_card == null or not bool(back_slot.get_meta("face_down", false)):
		await bf.resolve_ai_pass_lane_with_visuals(lane)
		return

	back_slot.set_meta("interacted_this_round", true)
	bf.battleplan_objective_controller.note_face_down_probed("player")

	if back_slot.has_method("reveal_card"):
		back_slot.reveal_card()

	bf.log_msg("AI checks your hidden back-row card in the " + lane + " lane.")
	await bf.get_tree().create_timer(bf.BLUFF_REVEAL_DELAY).timeout

	bf.ai_memory_note_player_hidden_reveal(back_card, lane, "ai_check")

	if bf.is_gambit_card(back_card):
		bf.battleplan_objective_controller.note_check("enemy", true)
		bf.add_aurion("ai", 1, "Successful Check: " + back_card.card_name + " was a Gambit.")
		bf.log_msg("AI Check successful. Your Gambit is denied and discarded. AI keeps priority in this lane.")
		bf.send_slot_card_to_discard(back_slot)
		await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
		bf.set_lane_priority_to_ai(lane)
		await bf.resolve_ai_current_priority_lane(lane)
		return

	bf.battleplan_objective_controller.note_check("enemy", false)
	bf.add_aurion("player", 1, "AI failed Check: " + back_card.card_name + " was a decoy.")
	var ai_feint := bf.slot_has_control_ability(checking_slot, &"feint")
	if ai_feint != null:
		await bf.show_control_trigger(ai_feint, "Wrong Check AP penalty ignored")
	elif checking_slot != null:
		checking_slot.set_meta("control_wrong_check_penalty_turn", bf.turn_number)
	bf.player_fortified_lanes[lane] = true
	bf.ai_passed_current_lane = true
	bf.log_msg("AI Check failed. Your decoy returns to hand. Player is fortified and gains priority in this lane.")
	bf.return_setup_card(back_slot, back_card, "player")
	await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
	bf.set_lane_priority_to_player(lane)


func resolve_ai_attack_lane_with_visuals(lane: String) -> void:
	var ai_front_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "front", lane)
	var player_front_slot: Node = bf.find_slot_by_owner_row_lane("player", "front", lane)
	var player_back_slot: Node = bf.find_slot_by_owner_row_lane("player", "back", lane)

	var ai_card: CardData = bf.get_slot_card_data(ai_front_slot)
	var player_front_card: CardData = bf.get_slot_card_data(player_front_slot)
	var player_back_card: CardData = bf.get_slot_card_data(player_back_slot)
	var player_back_is_face_down: bool = player_back_card != null and player_back_slot != null and bool(player_back_slot.get_meta("face_down", false))

	if not bf.is_unit_card(ai_card):
		await bf.resolve_ai_pass_lane_with_visuals(lane)
		return
	bf.battleplan_objective_controller.note_attack("enemy")
	var infiltrator := bf.slot_has_protection_ability(ai_front_slot, &"infiltrator")
	if player_back_is_face_down and infiltrator != null:
		await bf.show_protection_trigger(infiltrator, "Backline bypassed")
		player_back_is_face_down = false

	# Hidden back-row cards must be resolved before AI can hit the Monarch.
	if player_back_is_face_down:
		player_back_slot.set_meta("interacted_this_round", true)
		if not bf.is_gambit_card(player_back_card) and bf.get_card_insight_ability(player_back_card, &"stealth") != null:
			if bf.resolve_stealth_hidden_decoy(player_back_slot, player_back_card, "player", lane):
				await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
				await bf.advance_combat_lane_after_resolution()
				return

		if player_back_slot.has_method("reveal_card"):
			player_back_slot.reveal_card()

		bf.log_msg("AI attacks into your hidden back-row card in the " + lane + " lane.")
		await bf.get_tree().create_timer(bf.BLUFF_REVEAL_DELAY).timeout

		bf.ai_memory_note_player_hidden_reveal(player_back_card, lane, "ai_attack")

		if bf.is_gambit_card(player_back_card):
			var precision := bf.slot_has_control_ability(ai_front_slot, &"precision")
			if precision != null:
				await bf.show_control_trigger(precision, "Gambit Protection ignored")
			var protection := bf.get_gambit_attack_protection(ai_front_slot)
			if protection != null:
				await bf.show_protection_trigger(protection, "Gambit ignored")
				bf.send_slot_card_to_discard(player_back_slot)
				bf.set_lane_priority_to_ai(lane)
				await bf.resolve_ai_current_priority_lane(lane)
				return
			bf.log_msg("AI Attack failed: " + player_back_card.card_name + " was your hidden Gambit.")
			var mobility_returned := await bf.resolve_immediate_hidden_gambit_cast(player_back_card, "player", lane, player_back_slot)
			if not mobility_returned:
				bf.send_slot_card_to_discard(player_back_slot)
			await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
			await bf.advance_combat_lane_after_resolution()
			return

		bf.add_aurion("ai", 1, "Successful Attack read: " + player_back_card.card_name + " was not a Gambit.")
		bf.log_msg("AI Attack read correctly. Your decoy is discarded. AI keeps priority in this lane.")
		bf.send_slot_card_to_discard(player_back_slot)
		await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
		bf.set_lane_priority_to_ai(lane)
		await bf.resolve_ai_current_priority_lane(lane)
		return

	# Phase 13: once no hidden back row protects the lane, an empty player front row is an open Monarch.
	if player_front_card == null:
		bf.log_msg("AI takes open-lane Monarch Strike in the " + lane + " lane.")
		bf.resolve_ai_monarch_strike(lane, ai_card)
		await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
		await bf.advance_combat_lane_after_resolution()
		return

	# AI is the active attacker here, regardless of who had the original Battleplan initiative.
	await bf.resolve_directed_clash(lane, ai_front_slot, ai_card, player_front_slot, player_front_card, false)

	if bf.parry_system.active:
		return

	await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
	await bf.advance_combat_lane_after_resolution()

func set_active_combat_lane_highlight(lane: String) -> void:
	if lane == "":
		return

	bf.clear_active_combat_lane_highlight()
	bf.active_combat_lane = lane

	if bf.board_slots == null:
		return

	for slot in bf.board_slots.get_children():
		if slot == null:
			continue

		if bf.get_slot_lane(slot) != lane:
			continue

		if slot.has_method("set_highlight"):
			slot.set_highlight(true)

		if slot.has_method("set_outline_color"):
			slot.set_outline_color(bf.COMBAT_LANE_GLOW)


func clear_active_combat_lane_highlight() -> void:
	if bf.board_slots == null:
		bf.active_combat_lane = ""
		return

	for slot in bf.board_slots.get_children():
		if slot == null:
			continue

		if bf.active_combat_lane != "" and bf.get_slot_lane(slot) != bf.active_combat_lane:
			continue

		if slot.has_method("set_highlight"):
			slot.set_highlight(false)

	bf.active_combat_lane = ""


func check_from_board_action_menu(slot: Node) -> void:
	if bf.combat_resolution_running:
		bf.log_msg("Combat is already resolving. Wait for the current lane.")
		return

	if slot == null:
		return

	if bf.current_phase != bf.BattlePhase.COMBAT:
		bf.log_msg("Check is only available during Combat.")
		return

	if bf.parry_system.active:
		bf.log_msg("Resolve the current parry prompt first.")
		return

	var lane: String = bf.get_slot_lane(slot)

	if lane == "":
		return

	if not bf.can_player_check_lane_from_menu(lane):
		bf.log_msg("Check requires your front-row unit and player priority in the current combat lane.")
		return

	await bf.resolve_player_check_lane_with_visuals(lane)

func resolve_player_check_lane_with_visuals(lane: String) -> void:
	if bf.combat_resolution_running:
		return

	bf.combat_resolution_running = true

	if not bf.prepare_player_lane_action(lane):
		bf.combat_resolution_running = false
		return

	bf.player_passed_current_lane = false
	bf.set_active_combat_lane_highlight(lane)
	bf.log_msg("Checking hidden back-row card in the " + lane + " lane.")
	await bf.get_tree().create_timer(bf.COMBAT_LANE_START_DELAY).timeout

	var back_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "back", lane)
	var back_card: CardData = bf.get_slot_card_data(back_slot)

	if back_slot == null or back_card == null or not bool(back_slot.get_meta("face_down", false)):
		bf.log_msg(lane.capitalize() + " lane: no face-down back-row card to check.")
		bf.combat_resolution_running = false
		return

	back_slot.set_meta("interacted_this_round", true)
	bf.battleplan_objective_controller.note_face_down_probed("enemy")

	if back_slot.has_method("reveal_card"):
		back_slot.reveal_card()

	await bf.get_tree().create_timer(bf.BLUFF_REVEAL_DELAY).timeout

	if bf.is_gambit_card(back_card):
		bf.battleplan_objective_controller.note_check("player", true)
		bf.ai_memory_note_player_check_result(lane, true)
		bf.add_aurion("player", 1, "Successful Check: " + back_card.card_name + " was a Gambit.")
		bf.log_msg("Check successful. Gambit is denied and discarded. Player keeps priority in this lane.")
		bf.send_slot_card_to_discard(back_slot)
		await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
		bf.set_lane_priority_to_player(lane)
		bf.combat_resolution_running = false
		return

	bf.battleplan_objective_controller.note_check("player", false)
	bf.ai_memory_note_player_check_result(lane, false)
	bf.add_aurion("ai", 1, "Failed Check: " + back_card.card_name + " was a decoy.")
	var checking_slot := bf.find_slot_by_owner_row_lane("player", "front", lane)
	var feint := bf.slot_has_control_ability(checking_slot, &"feint")
	if feint != null:
		await bf.show_control_trigger(feint, "Wrong Check AP penalty ignored")
	elif checking_slot != null:
		checking_slot.set_meta("control_wrong_check_penalty_turn", bf.turn_number)
	bf.enemy_fortified_lanes[lane] = true
	bf.player_passed_current_lane = true
	bf.log_msg("Check failed. Decoy returns to enemy hand. Enemy is fortified and gains priority in this lane.")
	bf.return_setup_card(back_slot, back_card, "enemy")
	await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
	bf.set_lane_priority_to_ai(lane)
	await bf.resolve_ai_current_priority_lane(lane)
	bf.combat_resolution_running = false


func resolve_player_check_lane_from_specific_attacker(lane: String, checking_slot: Node, ability_name: String = "Volley") -> bool:
	if bf.combat_resolution_running or checking_slot == null:
		return false
	var source_lane := bf.get_slot_lane(checking_slot)
	if not bf.prepare_player_volley_lane_action(source_lane, lane):
		return false
	var back_slot := bf.find_slot_by_owner_row_lane("enemy", "back", lane)
	var back_card := bf.get_slot_card_data(back_slot)
	if back_slot == null or back_card == null or not bool(back_slot.get_meta("face_down", false)):
		bf.log_msg(ability_name + ": no face-down back-row card to Check in the " + lane + " lane.")
		return true

	bf.combat_resolution_running = true
	bf.player_passed_current_lane = false
	bf.set_active_combat_lane_highlight(lane)
	bf.log_msg(ability_name + ": checking the " + lane + " backline from the " + source_lane + " lane.")
	await bf.get_tree().create_timer(bf.COMBAT_LANE_START_DELAY).timeout
	back_slot.set_meta("interacted_this_round", true)
	bf.battleplan_objective_controller.note_face_down_probed("enemy")
	back_slot.reveal_card()
	await bf.get_tree().create_timer(bf.BLUFF_REVEAL_DELAY).timeout

	if bf.is_gambit_card(back_card):
		bf.battleplan_objective_controller.note_check("player", true)
		bf.ai_memory_note_player_check_result(lane, true)
		bf.add_aurion("player", 1, "Successful " + ability_name + " Check: " + back_card.card_name + " was a Gambit.")
		bf.log_msg(ability_name + " Check succeeded. The Gambit is discarded; Volley keeps priority.")
		bf.send_slot_card_to_discard(back_slot)
		await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
		bf.combat_priority_owner = "player"
		bf.combat_resolution_running = false
		return true

	bf.battleplan_objective_controller.note_check("player", false)
	bf.ai_memory_note_player_check_result(lane, false)
	bf.add_aurion("ai", 1, "Failed " + ability_name + " Check: " + back_card.card_name + " was a decoy.")
	var feint := bf.slot_has_control_ability(checking_slot, &"feint")
	if feint != null:
		await bf.show_control_trigger(feint, "Wrong Check AP penalty ignored")
	else:
		checking_slot.set_meta("control_wrong_check_penalty_turn", bf.turn_number)
	bf.enemy_fortified_lanes[lane] = true
	bf.player_passed_current_lane = true
	bf.return_setup_card(back_slot, back_card, "enemy")
	await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
	bf.set_lane_priority_to_ai(source_lane, ability_name + " Check failed; priority passes to AI.")
	await bf.resolve_ai_current_priority_lane(source_lane)
	bf.combat_resolution_running = false
	return false

func prepare_player_lane_action(lane: String) -> bool:
	if lane == "":
		return false

	if not bf.combat_direction_selected:
		if not bf.player_has_initiative and bf.combat_priority_owner != "player":
			bf.log_msg("AI has initiative. You cannot choose the starting lane yet.")
			return false

		if lane == "left":
			bf.set_combat_lane_order_from_left()
		elif lane == "right":
			bf.set_combat_lane_order_from_right()
		else:
			bf.log_msg("Choose the leftmost or rightmost lane first to set combat direction.")
			return false

	if bf.combat_next_lane_index >= bf.combat_lane_order.size():
		bf.log_msg("All combat lanes are already resolved.")
		return false

	var expected_lane: String = bf.combat_lane_order[bf.combat_next_lane_index]

	if lane != expected_lane:
		bf.log_msg("Next combat must resolve in the " + expected_lane + " lane.")
		return false

	if bf.combat_priority_owner != "player":
		bf.log_msg("AI has priority in the " + lane + " lane. You can act after AI passes or resolves its action.")
		return false

	return true

func return_setup_card(slot: Node, card_data: CardData, owner_name: String) -> void:
	if slot == null or card_data == null:
		return

	if slot.has_method("clear_slot"):
		slot.clear_slot()

	if owner_name == "enemy":
		bf.ai_hand.append(card_data)
		bf.update_ai_visuals()
		return

	if bf.hand != null:
		bf.hand.add_card_to_hand(card_data)


func resolve_attack_into_face_down_backrow(
	lane: String,
	_attacker_card: CardData,
	_enemy_front_slot: Node,
	enemy_back_slot: Node,
	enemy_back_card: CardData
) -> void:
	if enemy_back_slot == null or enemy_back_card == null:
		return

	enemy_back_slot.set_meta("interacted_this_round", true)

	if enemy_back_slot.has_method("reveal_card"):
		enemy_back_slot.reveal_card()

	await bf.get_tree().create_timer(bf.BLUFF_REVEAL_DELAY).timeout

	bf.ai_memory_note_player_attacked_hidden(lane, bf.is_gambit_card(enemy_back_card))

	if bf.is_gambit_card(enemy_back_card):
		var attacker_slot := bf.find_slot_by_owner_row_lane("player", "front", lane)
		var precision := bf.slot_has_control_ability(attacker_slot, &"precision")
		if precision != null:
			await bf.show_control_trigger(precision, "Gambit Protection ignored")
		var protection := bf.get_gambit_attack_protection(attacker_slot)
		if protection != null:
			await bf.show_protection_trigger(protection, "Gambit ignored")
			bf.send_slot_card_to_discard(enemy_back_slot)
			bf.set_lane_priority_to_player(lane)
			return
		bf.log_msg("Attack failed: " + enemy_back_card.card_name + " was a hidden Gambit.")
		var mobility_returned := await bf.resolve_immediate_hidden_gambit_cast(enemy_back_card, "enemy", lane, enemy_back_slot)
		if not mobility_returned:
			bf.send_slot_card_to_discard(enemy_back_slot)
		await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
		await bf.advance_combat_lane_after_resolution()
		return

	if bf.resolve_stealth_hidden_decoy(enemy_back_slot, enemy_back_card, "enemy", lane):
		await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
		bf.set_lane_priority_to_player(lane)
		bf.log_msg("Right-click the " + lane + " lane again to attack the front row, Monarch, or Pass.")
		return

	bf.add_aurion("player", 1, "Successful Attack read: " + enemy_back_card.card_name + " was not a Gambit.")
	bf.log_msg("Attack read correctly: " + enemy_back_card.card_name + " was not a Gambit. Decoy is discarded. Player keeps priority in this lane.")
	bf.send_slot_card_to_discard(enemy_back_slot)
	await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
	bf.set_lane_priority_to_player(lane)
	bf.log_msg("Right-click the " + lane + " lane again to attack the front row, Monarch, or Pass.")
