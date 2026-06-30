class_name BattlefieldAIController
extends RefCounted

## Extracted domain controller. BattlefieldManager remains the compatibility facade
## for scene signals, dynamic calls, and cross-domain orchestration.

var bf: BattlefieldManager


func _init(owner_battlefield: BattlefieldManager) -> void:
	bf = owner_battlefield


func ai_get_difficulty_name() -> String:
	return AIDifficultyProfile.display_name(bf.ai_difficulty)

func ai_get_phase_name() -> String:
	match bf.current_phase:
		bf.BattlePhase.BATTLEPLAN:
			return "Battleplan"
		bf.BattlePhase.TRIBUTE:
			return "Tribute"
		bf.BattlePhase.DEPLOYMENT:
			return "Deployment"
		bf.BattlePhase.COMBAT:
			return "Combat"

	return "Unknown"


func ai_get_difficulty_profile() -> Dictionary:
	return AIDifficultyProfile.values(bf.ai_difficulty)

func ai_get_active_ability_lane_attempt_key(lane: String) -> String:
	return str(bf.turn_number) + ":" + lane


func ai_get_active_ability_turn_key() -> String:
	return str(bf.turn_number)


func ai_max_active_ability_uses_per_turn() -> int:
	return int(bf.ai_get_difficulty_profile().get("max_active_ability_uses_per_turn", 1))


func ai_can_try_active_ability_in_lane(lane: String) -> bool:
	if lane == "":
		return false

	if bf.ai_active_ability_lane_attempt_keys.has(bf.ai_get_active_ability_lane_attempt_key(lane)):
		return false

	var turn_key := bf.ai_get_active_ability_turn_key()
	var used_count := int(bf.ai_active_ability_turn_use_counts.get(turn_key, 0))

	if used_count >= bf.ai_max_active_ability_uses_per_turn():
		return false

	return true


func ai_mark_active_ability_lane_attempted(lane: String) -> void:
	if lane == "":
		return

	bf.ai_active_ability_lane_attempt_keys[bf.ai_get_active_ability_lane_attempt_key(lane)] = true


func ai_mark_active_ability_turn_used() -> void:
	var turn_key := bf.ai_get_active_ability_turn_key()
	var used_count := int(bf.ai_active_ability_turn_use_counts.get(turn_key, 0))
	bf.ai_active_ability_turn_use_counts[turn_key] = used_count + 1


func ai_is_supported_ai_active_mobility(handler_id: StringName) -> bool:
	match handler_id:
		&"lane_shift", &"mobilize", &"tactic_flow", &"flank_swap", &"imperial_decree", &"vortex":
			return true

	return false


func ai_can_place_back_row_in_lane(owner_name: String, lane: String) -> bool:
	if lane == "":
		return false

	var front_slot := bf.find_slot_by_owner_row_lane(owner_name, "front", lane)
	var front_card := bf.get_slot_card_data(front_slot)

	if not bf.is_unit_card(front_card):
		return false

	if bool(front_slot.get_meta("face_down", false)):
		return false

	return true


func ai_get_empty_legal_enemy_back_slots() -> Array[Node]:
	var result: Array[Node] = []

	for slot in bf.ai_get_empty_enemy_slots("back"):
		var lane := bf.get_slot_lane(slot)

		if bf.ai_can_place_back_row_in_lane("enemy", lane):
			result.append(slot)

	return result


func ai_min_deployment_score() -> int:
	return int(bf.ai_get_difficulty_profile().get("min_deployment_score", 12))
	
func ai_memory_decay_amount() -> int:
	match bf.ai_difficulty:
		bf.AI_DIFFICULTY_NOVICE:
			return 6
		bf.AI_DIFFICULTY_SOLDIER:
			return 4
		bf.AI_DIFFICULTY_COMMANDER:
			return 3
		bf.AI_DIFFICULTY_WARLORD:
			return 2
		bf.AI_DIFFICULTY_GRANDMASTER:
			return 1

	return 3


func ai_decay_memory_dictionary_values(memory_dict: Dictionary, amount: int) -> Dictionary:
	var result: Dictionary = {}

	for key in memory_dict.keys():
		var current := int(memory_dict.get(key, 0))
		result[key] = maxi(0, current - amount)

	return result


func ai_decay_player_memory_pressure() -> void:
	var decay := bf.ai_memory_decay_amount()

	bf.ai_memory_player_lane_pressure = bf.ai_decay_memory_dictionary_values(bf.ai_memory_player_lane_pressure, decay)
	bf.ai_memory_player_backrow_pressure = bf.ai_decay_memory_dictionary_values(bf.ai_memory_player_backrow_pressure, decay)


func ai_card_passes_faction_gate(card_data: CardData, show_log: bool = false) -> bool:
	if card_data == null:
		return false

	var clean_race: String = bf.get_clean_card_race(card_data)

	if clean_race == "" or clean_race == "neutral":
		return true

	for tribute_card in bf.ai_tribute:
		if tribute_card == null:
			continue

		# AI Gambits are temporary Tribute, so they do not unlock faction access.
		if bf.is_gambit_card(tribute_card):
			continue

		if bf.get_clean_card_race(tribute_card) == clean_race:
			return true

	if show_log:
		bf.log_msg("AI Faction Gate locked: AI needs at least 1 " + clean_race.capitalize() + " card in permanent Tribute to play " + card_data.card_name + ".")

	return false



func ai_build_selected_deck_cards() -> Array[CardData]:
	var result: Array[CardData] = []

	match bf.ai_deck_source_mode:
		bf.AI_DECK_SOURCE_RANDOM_SYNERGY:
			result = bf.ai_random_deck_builder.ai_build_random_synergy_deck()

		bf.AI_DECK_SOURCE_SAVED:
			if bf.player_deck != null:
				result = bf.player_deck.get_saved_deck_slot_cards(bf.ai_selected_saved_deck_slot)

		_:
			result.clear()

	return result


func ai_draw_cards(amount: int) -> void:
	for i in range(amount):
		if bf.ai_deck.is_empty():
			return

		var drawn_card: CardData = bf.ai_deck.pop_back()

		if drawn_card != null:
			bf.ai_hand.append(drawn_card)
		bf.update_ai_visuals()


func ai_start_tribute_phase() -> void:
	bf.ai_decay_player_memory_pressure()

	bf.ai_current_perm_tp = bf.ai_perm_tp
	bf.ai_temp_tp = 0
	bf.ai_current_tp = bf.ai_current_perm_tp
	bf.ai_tribute_used_this_turn = false
	bf.ai_tribute_finished_this_turn = false

	if bf.next_phase_button != null:
		bf.next_phase_button.disabled = true

	await bf.ai_offer_one_card_to_tribute()
	bf.ai_tribute_finished_this_turn = true

	if bf.next_phase_button != null:
		bf.next_phase_button.disabled = false

	bf.try_auto_advance_tribute_phase()


func ai_offer_one_card_to_tribute() -> void:
	if bf.ai_tribute_used_this_turn:
		return

	if bf.ai_hand.is_empty():
		bf.log_msg("AI has no cards to offer as Tribute.")
		return

	var tribute_index: int = bf.ai_choose_tribute_card_index()

	if tribute_index < 0:
		bf.log_msg("AI found no valid Tribute card.")
		return

	var tribute_card: CardData = bf.ai_hand[tribute_index]

	if tribute_card == null:
		return

	await bf.play_enemy_hand_to_node_animation(
		tribute_card,
		bf.get_enemy_visual_target("EnemyTributePileVisual"),
		false
	)

	bf.ai_hand.pop_at(tribute_index)
	bf.ai_tribute.append(tribute_card)
	bf.ai_tribute_used_this_turn = true

	var card_type: String = bf.get_clean_card_type(tribute_card)

	if card_type == "gambit":
		bf.ai_temp_tp += 2
		bf.ai_current_tp += 2
		bf.log_msg("AI offered " + tribute_card.card_name + " for +2 temporary TP.")
	else:
		bf.ai_perm_tp += 1
		bf.ai_current_perm_tp += 1
		bf.ai_current_tp += 1
		bf.log_msg("AI offered " + tribute_card.card_name + " for +1 permanent TP.")

	bf.log_msg("AI TP: " + str(bf.ai_current_tp) + "/" + str(bf.ai_perm_tp) + " Temp +" + str(bf.ai_temp_tp))
	bf.update_ai_visuals()


func ai_choose_tribute_card_index() -> int:
	var best_index: int = -1
	var best_score: int = -999999

	for i in range(bf.ai_hand.size()):
		var card_data: CardData = bf.ai_hand[i]

		if card_data == null:
			continue

		var score: int = bf.ai_score_tribute_card(i, card_data)

		if score > best_score:
			best_score = score
			best_index = i

	if best_index >= 0 and best_index < bf.ai_hand.size():
		var chosen_card: CardData = bf.ai_hand[best_index]
		if chosen_card != null:
			bf.ai_last_tribute_decision = chosen_card.card_name + " | score " + str(best_score)

	return best_index


func ai_score_tribute_card(card_index: int, card_data: CardData) -> int:
	if card_data == null:
		return -999999

	var score: int = 0
	var card_type: String = bf.get_clean_card_type(card_data)
	var race: String = bf.get_clean_card_race(card_data)

	# Permanent Tribute is usually better than temporary Tribute,
	# especially early, because it builds max TP and faction access.
	if card_type == "unit" or card_type == "equipment":
		score += 70

		if bf.ai_perm_tp < 3:
			score += 35

		if race != "" and race != "neutral" and not bf.ai_card_passes_faction_gate(card_data, false):
			score += 30

	elif bf.is_gambit_card(card_data):
		score += 35

		# Early game: avoid relying on temporary TP unless no better option exists.
		if bf.ai_perm_tp < 3:
			score -= 25

	# Prefer sacrificing weaker cards.
	score -= card_data.ap * 4
	score -= card_data.dp * 2
	score -= card_data.tribute_cost * 2

	# Duplicates are safer to sacrifice.
	if bf.ai_count_matching_cards_in_hand(card_data) > 1:
		score += 24

	# Do not throw away the only unit if AI has no board presence.
	if bf.is_unit_card(card_data):
		if bf.ai_count_hand_units() <= 1 and bf.ai_count_front_units("enemy") <= 0:
			score -= 55

	# Equipment is less valuable if AI has no units to attach it to.
	if bf.is_equipment_card(card_data):
		if bf.ai_count_front_units("enemy") <= 0:
			score += 18
		else:
			score -= 18

	# Preserve high-value ability cards more on higher difficulties.
	score -= bf.ai_score_tribute_ability_preservation(card_data)

	score += bf.ai_tactical_noise(6)

	return score


func ai_count_matching_cards_in_hand(card_data: CardData) -> int:
	if card_data == null:
		return 0

	var count: int = 0

	for hand_card in bf.ai_hand:
		var other := hand_card as CardData

		if other == null:
			continue

		if other.card_name == card_data.card_name:
			count += 1

	return count


func ai_count_hand_units() -> int:
	var count: int = 0

	for hand_card in bf.ai_hand:
		var card_data := hand_card as CardData

		if bf.is_unit_card(card_data):
			count += 1

	return count


func ai_reset_memory() -> void:
	bf.ai_memory_player_hidden_cards_seen = 0
	bf.ai_memory_player_hidden_gambits_seen = 0
	bf.ai_memory_player_hidden_decoys_seen = 0

	bf.ai_memory_player_checks_seen = 0
	bf.ai_memory_player_successful_checks = 0
	bf.ai_memory_player_failed_checks = 0

	bf.ai_memory_player_attacks_into_hidden = 0
	bf.ai_memory_player_triggered_hidden_gambits = 0

	bf.ai_memory_player_lane_pressure = {
		"left": 0,
		"middle": 0,
		"right": 0
	}

	bf.ai_memory_player_backrow_pressure = {
		"left": 0,
		"middle": 0,
		"right": 0
	}

	bf.ai_active_ability_lane_attempt_keys.clear()
	bf.ai_active_ability_turn_use_counts.clear()


func ai_memory_weight() -> float:
	return float(bf.ai_get_difficulty_profile().get("memory_weight", 0.65))


func ai_randomness_multiplier() -> float:
	return float(bf.ai_get_difficulty_profile().get("randomness_multiplier", 1.35))


func ai_apply_memory_bonus(base_score: int) -> int:
	return int(round(float(base_score) * bf.ai_memory_weight()))


func ai_tactical_noise(max_amount: int) -> int:
	if max_amount <= 0:
		return 0

	var adjusted_amount := maxi(1, int(round(float(max_amount) * bf.ai_randomness_multiplier())))
	return randi() % adjusted_amount


func ai_memory_player_hidden_gambit_rate() -> float:
	var total_seen := bf.ai_memory_player_hidden_gambits_seen + bf.ai_memory_player_hidden_decoys_seen

	if total_seen <= 0:
		return 0.50

	return clampf(float(bf.ai_memory_player_hidden_gambits_seen) / float(total_seen), 0.05, 0.95)


func ai_memory_player_check_success_rate() -> float:
	if bf.ai_memory_player_checks_seen <= 0:
		return 0.50

	return clampf(float(bf.ai_memory_player_successful_checks) / float(bf.ai_memory_player_checks_seen), 0.05, 0.95)


func ai_memory_player_lane_pressure_score(lane: String) -> int:
	if lane == "":
		return 0

	return int(bf.ai_memory_player_lane_pressure.get(lane, 0)) + int(bf.ai_memory_player_backrow_pressure.get(lane, 0))


func ai_memory_add_lane_pressure(lane: String, amount: int) -> void:
	if lane == "":
		return

	var current := int(bf.ai_memory_player_lane_pressure.get(lane, 0))
	bf.ai_memory_player_lane_pressure[lane] = clampi(current + amount, 0, 40)


func ai_memory_add_backrow_pressure(lane: String, amount: int) -> void:
	if lane == "":
		return

	var current := int(bf.ai_memory_player_backrow_pressure.get(lane, 0))
	bf.ai_memory_player_backrow_pressure[lane] = clampi(current + amount, 0, 40)


func ai_memory_note_player_deployment(card_data: CardData, slot: Node) -> void:
	if card_data == null or slot == null:
		return

	if String(slot.get_meta("owner", "")) != "player":
		return

	var lane := bf.get_slot_lane(slot)

	if lane == "":
		return

	var row := String(slot.get_meta("row", ""))
	var face_down := bool(slot.get_meta("face_down", false))

	if row == "front":
		var pressure_gain := 2

		if bf.is_unit_card(card_data):
			pressure_gain += 3
			pressure_gain += mini(maxi(card_data.ap, 0), 8)

		if bf.is_equipment_card(card_data):
			pressure_gain += 2

		bf.ai_memory_add_lane_pressure(lane, pressure_gain)

	elif row == "back":
		var pressure_gain := 2

		if face_down:
			pressure_gain += 4

		if bf.is_gambit_card(card_data):
			pressure_gain += 3

		if bf.is_equipment_card(card_data):
			pressure_gain += 1

		bf.ai_memory_add_backrow_pressure(lane, pressure_gain)


func ai_memory_note_player_hidden_reveal(card_data: CardData, lane: String, _source: String = "") -> void:
	if card_data == null:
		return

	bf.ai_memory_player_hidden_cards_seen += 1

	if bf.is_gambit_card(card_data):
		bf.ai_memory_player_hidden_gambits_seen += 1
	else:
		bf.ai_memory_player_hidden_decoys_seen += 1

	if lane != "":
		var current_backrow_pressure := int(bf.ai_memory_player_backrow_pressure.get(lane, 0))
		bf.ai_memory_player_backrow_pressure[lane] = clampi(current_backrow_pressure - 3, 0, 40)


func ai_memory_note_player_check_result(lane: String, successful: bool) -> void:
	bf.ai_memory_player_checks_seen += 1

	if successful:
		bf.ai_memory_player_successful_checks += 1
	else:
		bf.ai_memory_player_failed_checks += 1

	if lane != "":
		bf.ai_memory_add_backrow_pressure(lane, 2)


func ai_memory_note_player_attacked_hidden(lane: String, revealed_gambit: bool) -> void:
	bf.ai_memory_player_attacks_into_hidden += 1

	if revealed_gambit:
		bf.ai_memory_player_triggered_hidden_gambits += 1

	if lane != "":
		bf.ai_memory_add_lane_pressure(lane, 2)


func ai_lookahead_weight() -> float:
	return float(bf.ai_get_difficulty_profile().get("lookahead_weight", 0.50))


func ai_apply_lookahead_bonus(base_score: int) -> int:
	return int(round(float(base_score) * bf.ai_lookahead_weight()))


func ai_card_has_ability_id(card_data: CardData, ability_id: StringName) -> bool:
	if card_data == null:
		return false

	for ability in card_data.get_abilities():
		if ability != null and ability.ability_id == ability_id:
			return true

	return false


func ai_estimate_card_value(card_data: CardData) -> int:
	if card_data == null:
		return 0

	var score: int = 0
	score += maxi(card_data.ap, 0) * 8
	score += maxi(card_data.dp, 0) * 4
	score += maxi(card_data.tribute_cost, 0) * 2
	score += bf.get_unit_defeat_aurion_reward(card_data) * 10
	score += bf.ai_apply_ability_awareness_bonus(bf.ai_score_card_ability_value(card_data, null, "value", false))

	return score


func ai_score_projected_lane_control(lane: String, projected_ai_ap: int, projected_ai_dp: int, ai_has_front_unit: bool) -> int:
	var player_front_slot: Node = bf.find_slot_by_owner_row_lane("player", "front", lane)
	var player_back_slot: Node = bf.find_slot_by_owner_row_lane("player", "back", lane)

	var player_front_card: CardData = bf.get_slot_card_data(player_front_slot)
	var player_back_card: CardData = bf.get_slot_card_data(player_back_slot)
	var player_back_is_face_down := player_back_card != null and player_back_slot != null and bool(player_back_slot.get_meta("face_down", false))

	var score: int = 0

	if not ai_has_front_unit:
		if bf.is_unit_card(player_front_card):
			score -= 42
		else:
			score -= 8

		return score

	if not bf.is_unit_card(player_front_card):
		score += 55
		score += projected_ai_ap * 4

		if player_back_is_face_down:
			score -= 18

		if lane == "left" or lane == "right":
			score += 16

		return score

	var player_ap: int = bf.get_slot_combat_ap(player_front_slot)
	var ap_gap: int = projected_ai_ap - player_ap

	if ap_gap > 0:
		score += 42
		score += ap_gap * 12
		score += bf.get_unit_defeat_aurion_reward(player_front_card) * 8

		if lane == "left" or lane == "right":
			score += 14

	elif ap_gap == 0:
		score += 8
		score += bf.get_unit_defeat_aurion_reward(player_front_card) * 4

	else:
		score -= 36
		score += ap_gap * 10
		score += projected_ai_dp * 2

	if player_back_is_face_down:
		var hidden_gambit_penalty := int(round((bf.ai_memory_player_hidden_gambit_rate() - 0.50) * 70.0))
		score -= bf.ai_apply_memory_bonus(hidden_gambit_penalty)

	return score


func ai_score_deployment_lookahead(card_data: CardData, slot: Node, action_type: String, face_down: bool) -> int:
	if card_data == null or slot == null:
		return 0

	if bf.ai_lookahead_weight() <= 0.0:
		return 0

	var lane := bf.get_slot_lane(slot)
	var row := String(slot.get_meta("row", ""))
	var score: int = 0

	match action_type:
		"promotion":
			score += bf.ai_score_projected_lane_control(lane, card_data.ap, card_data.dp, true)
			score += bf.ai_estimate_card_value(card_data) / 3

		"unit":
			if face_down or row == "back":
				var enemy_front := bf.get_slot_card_data(bf.find_slot_by_owner_row_lane("enemy", "front", lane))
				score += 16
				score += card_data.dp * 3

				if bf.is_unit_card(enemy_front):
					score += 22

				if bf.ai_get_empty_enemy_slots("front").is_empty():
					score += 18
				else:
					score -= 14
			else:
				score += bf.ai_score_projected_lane_control(lane, card_data.ap, card_data.dp, true)
				score += bf.ai_estimate_card_value(card_data) / 4

		"equipment":
			var equipped_unit := bf.get_slot_card_data(slot)

			if bf.is_unit_card(equipped_unit):
				var projected_ap := equipped_unit.ap + card_data.ap
				var projected_dp := equipped_unit.dp + card_data.dp
				score += bf.ai_score_projected_lane_control(lane, projected_ap, projected_dp, true)

				if bf.ai_card_has_ability_id(card_data, &"plated"):
					score += 24

				if bf.ai_card_has_ability_id(card_data, &"spiked"):
					score += 20

				if bf.ai_card_has_ability_id(card_data, &"shielded"):
					score += 18

		"equipment_setup":
			var enemy_front := bf.get_slot_card_data(bf.find_slot_by_owner_row_lane("enemy", "front", lane))
			score += 10

			if bf.is_unit_card(enemy_front):
				score += 20
			else:
				score -= 12

			score += card_data.dp * 2

		"gambit":
			if face_down:
				score += 35
				score += bf.ai_memory_player_lane_pressure_score(lane)

				var enemy_front := bf.get_slot_card_data(bf.find_slot_by_owner_row_lane("enemy", "front", lane))

				if bf.is_unit_card(enemy_front):
					score += 22

				if lane == "left" or lane == "right":
					score += 8
			else:
				score += 12
				score += card_data.ap * 2
				score += card_data.dp

	return bf.ai_apply_lookahead_bonus(score)


func ai_score_combat_action_lookahead(lane: String, action_type: String) -> int:
	if bf.ai_lookahead_weight() <= 0.0:
		return 0

	match action_type:
		"attack":
			return bf.ai_apply_lookahead_bonus(bf.ai_score_attack_lookahead(lane))
		"check":
			return bf.ai_apply_lookahead_bonus(bf.ai_score_check_lookahead(lane))
		"pass":
			return bf.ai_apply_lookahead_bonus(bf.ai_score_pass_lookahead(lane))

	return 0


func ai_score_attack_lookahead(lane: String) -> int:
	var ai_front_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "front", lane)
	var player_front_slot: Node = bf.find_slot_by_owner_row_lane("player", "front", lane)
	var player_back_slot: Node = bf.find_slot_by_owner_row_lane("player", "back", lane)

	var ai_card: CardData = bf.get_slot_card_data(ai_front_slot)
	var player_front_card: CardData = bf.get_slot_card_data(player_front_slot)
	var player_back_card: CardData = bf.get_slot_card_data(player_back_slot)
	var player_back_is_face_down := player_back_card != null and player_back_slot != null and bool(player_back_slot.get_meta("face_down", false))

	if not bf.is_unit_card(ai_card):
		return -120

	var score: int = 0

	if player_back_is_face_down:
		var gambit_bias := int(round((bf.ai_memory_player_hidden_gambit_rate() - 0.50) * 100.0))

		if bf.get_gambit_attack_protection(ai_front_slot) != null:
			score += 40
		else:
			score -= gambit_bias

	if not bf.is_unit_card(player_front_card):
		score += 75

		if player_back_is_face_down:
			score -= 25

		return score

	var ai_ap := bf.get_slot_combat_ap(ai_front_slot)
	var player_ap := bf.get_slot_combat_ap(player_front_slot)
	var ap_gap := ai_ap - player_ap

	var ai_value := bf.ai_estimate_card_value(ai_card)
	var player_value := bf.ai_estimate_card_value(player_front_card)

	if ap_gap > 0:
		score += 55
		score += ap_gap * 14
		score += player_value / 5

		if ap_gap == 1:
			score -= 14

	elif ap_gap == 0:
		score += 10
		score += player_value / 6
		score -= ai_value / 7

	else:
		score -= 55
		score -= ai_value / 5

		if bf.slot_has_protection_ability(ai_front_slot, &"plated") != null:
			score += 42

		if bf.slot_has_protection_ability(ai_front_slot, &"spiked") != null:
			score += 34

	if lane == "left" or lane == "right":
		score += 10

	return score


func ai_score_check_lookahead(lane: String) -> int:
	var ai_front_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "front", lane)
	var player_back_slot: Node = bf.find_slot_by_owner_row_lane("player", "back", lane)

	var ai_card: CardData = bf.get_slot_card_data(ai_front_slot)
	var player_back_card: CardData = bf.get_slot_card_data(player_back_slot)
	var player_back_is_face_down := player_back_card != null and player_back_slot != null and bool(player_back_slot.get_meta("face_down", false))

	if not bf.is_unit_card(ai_card):
		return -120

	if not player_back_is_face_down:
		return -120

	var score: int = 0
	var gambit_rate := bf.ai_memory_player_hidden_gambit_rate()

	score += int(round((gambit_rate - 0.50) * 120.0))
	score += bf.ai_memory_player_lane_pressure_score(lane) * 2

	if bf.get_gambit_attack_protection(ai_front_slot) != null:
		score -= 45

	return score


func ai_score_pass_lookahead(lane: String) -> int:
	var ai_front_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "front", lane)
	var player_front_slot: Node = bf.find_slot_by_owner_row_lane("player", "front", lane)

	var ai_card: CardData = bf.get_slot_card_data(ai_front_slot)
	var player_front_card: CardData = bf.get_slot_card_data(player_front_slot)

	if not bf.is_unit_card(ai_card):
		return 35

	var score: int = 0
	var lane_pressure := bf.ai_memory_player_lane_pressure_score(lane)

	if bf.player_passed_current_lane:
		score += 30

	if bf.is_unit_card(player_front_card):
		var ai_ap := bf.get_slot_combat_ap(ai_front_slot)
		var player_ap := bf.get_slot_combat_ap(player_front_slot)

		if ai_ap > player_ap:
			score -= 35
			score -= lane_pressure
		elif ai_ap < player_ap:
			score += 22
			score += lane_pressure

	else:
		score -= 55

	return score


func ai_ability_awareness_weight() -> float:
	return float(bf.ai_get_difficulty_profile().get("ability_awareness_weight", 0.60))


func ai_apply_ability_awareness_bonus(base_score: int) -> int:
	return int(round(float(base_score) * bf.ai_ability_awareness_weight()))


func ai_slot_has_any_ability(slot: Node, ability_id: StringName) -> AbilityData:
	if slot == null:
		return null

	var entries: Array = []

	if slot.has_method("get_ability_visual_entries"):
		entries = slot.call("get_ability_visual_entries")

	if entries.is_empty():
		var main_card := bf.get_slot_card_data(slot)

		if main_card != null:
			for ability in main_card.get_abilities():
				if ability != null and ability.ability_id == ability_id:
					return ability

		return null

	for entry in entries:
		var card_data := entry.get("card") as CardData

		if card_data == null:
			continue

		for ability in card_data.get_abilities():
			if ability != null and ability.ability_id == ability_id:
				return ability

	return null


func ai_count_player_front_units_at_or_below(max_ap: int) -> int:
	var count := 0

	for lane in ["left", "middle", "right"]:
		var slot := bf.find_slot_by_owner_row_lane("player", "front", lane)
		var card := bf.get_slot_card_data(slot)

		if bf.is_unit_card(card) and bf.get_slot_combat_ap(slot) <= max_ap:
			count += 1

	return count


func ai_count_enemy_empty_adjacent_front_slots(lane: String) -> int:
	var count := 0

	for adjacent_lane in bf.get_adjacent_lanes(lane):
		var slot := bf.find_slot_by_owner_row_lane("enemy", "front", adjacent_lane)

		if slot != null and bf.get_slot_card_data(slot) == null:
			count += 1

	return count


func ai_count_player_hidden_backrow_cards() -> int:
	var count := 0

	for lane in ["left", "middle", "right"]:
		var slot := bf.find_slot_by_owner_row_lane("player", "back", lane)
		var card := bf.get_slot_card_data(slot)

		if card != null and slot != null and bool(slot.get_meta("face_down", false)):
			count += 1

	return count


func ai_score_card_ability_value(card_data: CardData, slot: Node = null, context: String = "", face_down: bool = false) -> int:
	if card_data == null:
		return 0

	var score := 0

	for ability in card_data.get_abilities():
		if ability == null:
			continue

		var category := String(ability.category).to_lower()
		var handler_id := ability.get_handler_id()

		match category:
			"protection":
				score += bf.ai_score_protection_ability_value(ability, card_data, slot, context, face_down)

			"mobility":
				score += bf.ai_score_mobility_ability_value(ability, card_data, slot, context, face_down)

			"insight":
				score += bf.ai_score_insight_ability_value(ability, card_data, slot, context, face_down)

			"control":
				score += ai_score_control_ability_value(ability, card_data, slot, context, face_down)

	return score


func ai_score_control_ability_value(ability: AbilityData, _card_data: CardData, slot: Node, context: String, face_down: bool) -> int:
	if ability == null:
		return 0

	var score := 10
	var lane := bf.get_slot_lane(slot) if slot != null else ""
	match ability.get_handler_id():
		&"lockdown", &"dampen":
			score += 34
			if lane != "" and bf.get_slot_card_data(bf.find_slot_by_owner_row_lane("player", "front", lane)) != null:
				score += 18
		&"halt":
			score += 28
		&"dominance", &"swift":
			score += 26
		&"precision":
			score += 30
		&"chain_down", &"order", &"siren":
			score += 28
		&"fog_of_war", &"handicap":
			score += 24
		&"ambush":
			score += 22
		&"burdened", &"feint":
			score += 18
		_:
			score += 10

	if face_down and context == "gambit":
		score += 12
	return score


func ai_score_protection_ability_value(ability: AbilityData, card_data: CardData, slot: Node, context: String, face_down: bool) -> int:
	if ability == null:
		return 0

	var handler_id := ability.get_handler_id()
	var score := 8

	var lane := ""
	var player_front: CardData = null
	var player_ap := 0
	var projected_ai_ap := card_data.ap

	if slot != null:
		lane = bf.get_slot_lane(slot)
		var player_front_slot := bf.find_slot_by_owner_row_lane("player", "front", lane)
		player_front = bf.get_slot_card_data(player_front_slot)
		player_ap = bf.get_slot_combat_ap(player_front_slot)

		if context == "equipment":
			var equipped_unit := bf.get_slot_card_data(slot)

			if bf.is_unit_card(equipped_unit):
				projected_ai_ap = equipped_unit.ap + card_data.ap

	match handler_id:
		&"plated":
			score += 30

			if bf.is_unit_card(player_front):
				score += 16

				if projected_ai_ap <= player_ap:
					score += 22

			if context == "equipment":
				score += 12

		&"spiked":
			score += 26

			if bf.is_unit_card(player_front):
				score += 18

				if projected_ai_ap <= player_ap:
					score += 22

		&"shielded":
			score += 24

			if bf.is_unit_card(player_front):
				score += 16

			if lane != "":
				score += bf.ai_memory_player_lane_pressure_score(lane)

		&"deflect":
			score += 18

			if bf.is_unit_card(player_front) and projected_ai_ap < player_ap:
				score += 20

		&"shield_burst":
			score += 16

			if bf.is_unit_card(player_front) and projected_ai_ap < player_ap:
				score += 16

		&"last_stand":
			score += 18

			if bf.is_unit_card(player_front) and projected_ai_ap < player_ap:
				score += 22

		&"equalizer":
			score += 20

			if bf.is_unit_card(player_front) and player_ap == projected_ai_ap + 1:
				score += 40

		&"infiltrator", &"spell_shield":
			score += 18

			if bf.ai_count_player_hidden_backrow_cards() > 0:
				score += 26

		_:
			score += 8

	if face_down:
		score -= 8

	return score


func ai_score_mobility_ability_value(ability: AbilityData, card_data: CardData, slot: Node, context: String, face_down: bool) -> int:
	if ability == null:
		return 0

	var handler_id := ability.get_handler_id()
	var score := 8

	var lane := ""

	if slot != null:
		lane = bf.get_slot_lane(slot)

	match handler_id:
		&"lane_shift":
			score += 22

			if lane != "":
				score += bf.ai_count_enemy_empty_adjacent_front_slots(lane) * 18

		&"mobilize":
			score += 20

			if lane != "":
				score += bf.ai_count_enemy_empty_adjacent_front_slots(lane) * 16

		&"tactic_flow":
			score += 18

			var left_slot := bf.find_slot_by_owner_row_lane("enemy", "front", "left")
			var right_slot := bf.find_slot_by_owner_row_lane("enemy", "front", "right")

			if bf.get_slot_card_data(left_slot) == null:
				score += 12

			if bf.get_slot_card_data(right_slot) == null:
				score += 12

		&"reassign":
			score += 24

			if bf.ai_count_front_units("enemy") >= 2:
				score += 18

		&"flank_swap":
			score += 30

			if bf.ai_count_front_units("enemy") >= 2:
				score += 24

		&"vortex":
			score += 34

			if bf.ai_count_front_units("enemy") >= 2:
				score += 28

		&"imperial_decree":
			score += 24
			score += bf.ai_count_player_front_units_at_or_below(6) * 20

		&"volley":
			score += 22

			if lane == "left" or lane == "right":
				score += 12

			if bf.ai_count_front_units("enemy") >= 2:
				score += 10

		_:
			score += 8

	if face_down and context == "gambit":
		score += 12

	return score


func ai_score_insight_ability_value(ability: AbilityData, _card_data: CardData, slot: Node, context: String, face_down: bool) -> int:
	if ability == null:
		return 0

	var handler_id := ability.get_handler_id()
	var score := 8
	var hidden_player_backrow_count := bf.ai_count_player_hidden_backrow_cards()

	match handler_id:
		&"stealth":
			score += 26

			if face_down:
				score += 30

			if context == "gambit" or context == "unit":
				score += 10

		&"true_sight":
			score += 26
			score += hidden_player_backrow_count * 18

		&"vantage":
			score += 22
			score += hidden_player_backrow_count * 14

		&"intuition":
			score += 20
			score += hidden_player_backrow_count * 12

		&"intel", &"intelligence", &"secrecy", &"seer", &"vision":
			score += 18

			if bf.ai_difficulty >= bf.AI_DIFFICULTY_COMMANDER:
				score += 8

		_:
			score += 8

	if slot != null:
		var lane := bf.get_slot_lane(slot)

		if lane != "":
			score += bf.ai_memory_player_lane_pressure_score(lane) / 2

	return score


func ai_score_card_abilities_for_deployment(card_data: CardData, slot: Node, action_type: String, face_down: bool) -> int:
	if card_data == null:
		return 0

	var raw_score := bf.ai_score_card_ability_value(card_data, slot, action_type, face_down)

	if action_type == "equipment":
		raw_score += 12

	if action_type == "promotion":
		raw_score += 10

	if face_down:
		if bf.is_gambit_card(card_data):
			raw_score += 16

		if bf.ai_card_has_ability_id(card_data, &"stealth"):
			raw_score += 20

	return bf.ai_apply_ability_awareness_bonus(raw_score)


func ai_score_tribute_ability_preservation(card_data: CardData) -> int:
	if card_data == null:
		return 0

	var raw_score := bf.ai_score_card_ability_value(card_data, null, "tribute", false)

	# If the card is currently faction-locked, sacrificing it can be useful,
	# so preserve it less aggressively.
	if not bf.ai_card_passes_faction_gate(card_data, false):
		raw_score = int(round(float(raw_score) * 0.45))

	# Equipment is less urgent to preserve if there is no AI unit to equip.
	if bf.is_equipment_card(card_data) and bf.ai_count_front_units("enemy") <= 0:
		raw_score = int(round(float(raw_score) * 0.55))

	return bf.ai_apply_ability_awareness_bonus(raw_score)


func ai_score_combat_ability_awareness(lane: String, action_type: String) -> int:
	var ai_front_slot := bf.find_slot_by_owner_row_lane("enemy", "front", lane)
	var player_front_slot := bf.find_slot_by_owner_row_lane("player", "front", lane)
	var player_back_slot := bf.find_slot_by_owner_row_lane("player", "back", lane)

	var ai_card := bf.get_slot_card_data(ai_front_slot)
	var player_front_card := bf.get_slot_card_data(player_front_slot)
	var player_back_card := bf.get_slot_card_data(player_back_slot)
	var player_back_is_face_down := player_back_card != null and player_back_slot != null and bool(player_back_slot.get_meta("face_down", false))

	if not bf.is_unit_card(ai_card):
		return 0

	var raw_score := 0
	var ai_ap := bf.get_slot_combat_ap(ai_front_slot)
	var player_ap := bf.get_slot_combat_ap(player_front_slot)

	match action_type:
		"attack":
			if player_back_is_face_down:
				if bf.get_gambit_attack_protection(ai_front_slot) != null:
					raw_score += 32
				else:
					raw_score -= int(round((bf.ai_memory_player_hidden_gambit_rate() - 0.50) * 55.0))

			if bf.is_unit_card(player_front_card):
				if ai_ap < player_ap:
					if bf.slot_has_protection_ability(ai_front_slot, &"plated") != null:
						raw_score += 34

					if bf.slot_has_protection_ability(ai_front_slot, &"spiked") != null:
						raw_score += 28

					if bf.slot_has_protection_ability(ai_front_slot, &"equalizer") != null and player_ap == ai_ap + 1:
						raw_score += 40

				elif ai_ap > player_ap:
					raw_score += 10

			if bf.slot_has_mobility_ability(ai_front_slot, &"volley") != null:
				raw_score += 10

		"check":
			if not player_back_is_face_down:
				return -999999

			if bf.ai_slot_has_any_ability(ai_front_slot, &"true_sight") != null:
				raw_score += 28

			if bf.ai_slot_has_any_ability(ai_front_slot, &"vantage") != null:
				raw_score += 24

			if bf.ai_slot_has_any_ability(ai_front_slot, &"intuition") != null:
				raw_score += 18

			if bf.get_gambit_attack_protection(ai_front_slot) != null:
				raw_score -= 20

			raw_score += int(round((bf.ai_memory_player_hidden_gambit_rate() - 0.50) * 65.0))

		"pass":
			if bf.player_passed_current_lane:
				raw_score += 10

			if bf.is_unit_card(player_front_card):
				if ai_ap < player_ap:
					raw_score += 16

					if bf.slot_has_protection_ability(ai_front_slot, &"shielded") != null:
						raw_score += 18

					if bf.slot_has_protection_ability(ai_front_slot, &"deflect") != null:
						raw_score += 14

				elif ai_ap > player_ap:
					raw_score -= 20

	return bf.ai_apply_ability_awareness_bonus(raw_score)



func ai_take_combat_initiative() -> void:
	var start_lane: String = bf.ai_choose_combat_start_lane()

	if start_lane == "right":
		bf.set_combat_lane_order_from_right()
	else:
		bf.set_combat_lane_order_from_left()

	bf.original_combat_priority_owner = "ai"
	bf.reset_priority_for_current_lane()
	bf.set_active_combat_lane_highlight(bf.current_combat_lane())

	bf.log_msg("AI chooses combat direction from the " + start_lane + " lane.")
	await bf.ai_resolve_combat_sequence()

func ai_choose_combat_start_lane() -> String:
	var left_score: int = bf.ai_score_combat_direction(["left", "middle", "right"])
	var right_score: int = bf.ai_score_combat_direction(["right", "middle", "left"])

	if left_score > right_score:
		return "left"

	if right_score > left_score:
		return "right"

	if (randi() % 2) == 0:
		return "left"

	return "right"


func ai_score_combat_direction(lanes: Array[String]) -> int:
	var score: int = 0
	var weight: int = 3

	for lane in lanes:
		var ai_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "front", lane)
		var player_slot: Node = bf.find_slot_by_owner_row_lane("player", "front", lane)

		var ai_card: CardData = bf.get_slot_card_data(ai_slot)
		var player_card: CardData = bf.get_slot_card_data(player_slot)
		var player_pressure := bf.ai_memory_player_lane_pressure_score(lane)

		if bf.is_unit_card(ai_card):
			score += ai_card.ap * weight

			if bf.is_unit_card(player_card):
				if ai_card.ap >= player_card.ap:
					score += 20 * weight
					score += bf.ai_apply_memory_bonus(player_pressure * weight)
				else:
					score -= 10 * weight
					score -= bf.ai_apply_memory_bonus(player_pressure * weight)
			else:
				score += 12 * weight
				score += bf.ai_apply_memory_bonus(player_pressure)

		else:
			score -= bf.ai_apply_memory_bonus(player_pressure)

		weight -= 1

	score += bf.ai_tactical_noise(10)
	return score


func ai_resolve_combat_sequence() -> void:
	if bf.combat_resolution_running:
		return

	bf.combat_resolution_running = true

	while bf.current_phase == bf.BattlePhase.COMBAT and not bf.parry_system.active and bf.combat_next_lane_index < bf.combat_lane_order.size():
		var next_lane: String = bf.combat_lane_order[bf.combat_next_lane_index]

		if bf.combat_priority_owner != "ai":
			break

		await bf.resolve_ai_current_priority_lane(next_lane)

		if bf.parry_system.active:
			break

		if bf.combat_priority_owner != "ai":
			break

		await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout

	bf.combat_resolution_running = false

func ai_count_front_units(owner_name: String) -> int:
	var count: int = 0
	var lanes: Array[String] = ["left", "middle", "right"]

	for lane in lanes:
		var slot: Node = bf.find_slot_by_owner_row_lane(owner_name, "front", lane)
		var card_data: CardData = bf.get_slot_card_data(slot)

		if bf.is_unit_card(card_data):
			count += 1

	return count


func ai_get_total_front_ap(owner_name: String) -> int:
	var total_ap: int = 0
	var lanes: Array[String] = ["left", "middle", "right"]

	for lane in lanes:
		var slot: Node = bf.find_slot_by_owner_row_lane(owner_name, "front", lane)
		var card_data: CardData = bf.get_slot_card_data(slot)

		if bf.is_unit_card(card_data):
			total_ap += card_data.ap

	return total_ap


func ai_take_deployment_turn() -> void:
	if bf.ai_hand.is_empty():
		bf.log_msg("AI has no hand cards to deploy.")
		return

	var plays_made: int = 0
	var max_plays: int = max(1, bf.ai_max_deployments_per_phase)

	for i in range(max_plays):
		var played: bool = await bf.ai_try_deploy_one_card()

		if not played:
			break

		plays_made += 1

		await bf.get_tree().create_timer(0.25).timeout

		if bf.ai_current_tp <= 0:
			break

	if plays_made == 0:
		bf.log_msg("AI passes deployment. No legal affordable play.")
	else:
		bf.log_msg("AI completed deployment with " + str(plays_made) + " play(s).")


func ai_try_deploy_one_card() -> bool:
	var action: Dictionary = bf.ai_choose_deployment_action()

	if action.is_empty():
		return false

	var card_index: int = int(action.get("card_index", -1))
	var target_slot: Node = action.get("slot", null) as Node
	var action_type: String = String(action.get("action_type", ""))
	var face_down: bool = bool(action.get("face_down", false))

	if card_index < 0 or card_index >= bf.ai_hand.size():
		return false

	if target_slot == null:
		return false

	var card_data: CardData = bf.ai_hand[card_index]

	if card_data == null:
		return false

	if not face_down and not bf.ai_card_passes_faction_gate(card_data, true):
		bf.log_msg("AI cannot play " + card_data.card_name + ": faction gate locked.")
		return false

	var deployment_cost: int = bf.get_ai_face_down_card_deployment_cost(card_data, face_down)

	if deployment_cost > bf.ai_current_tp:
		return false

	var success: bool = false

	if action_type == "equipment":
		await bf.play_enemy_hand_to_node_animation(card_data, target_slot, false)

		if target_slot.has_method("attach_equipment"):
			success = target_slot.attach_equipment(bf.TEST_CARD_SCENE, card_data)

		if success:
			bf.ai_hand.pop_at(card_index)
			bf.ai_spend_tp(card_data.tribute_cost)
			await ai_resolve_deployment_abilities(card_data, target_slot)

			var equipped_unit: CardData = bf.get_slot_card_data(target_slot)
			var equipped_unit_name: String = "unit"

			if equipped_unit != null:
				equipped_unit_name = equipped_unit.card_name

			bf.log_msg("AI attached " + card_data.card_name + " to " + equipped_unit_name + ".")
			bf.log_msg("AI TP after equipment: " + str(bf.ai_current_tp) + "/" + str(bf.ai_perm_tp) + " Temp +" + str(bf.ai_temp_tp))
			bf.update_ai_visuals()
			return true

		return false

	if action_type == "promotion":
		var old_unit: CardData = bf.get_slot_card_data(target_slot)

		if not bf.ai_can_promote_card_to_slot(card_data, target_slot):
			return false

		await bf.play_enemy_hand_to_node_animation(card_data, target_slot, false)
		success = bf.promote_slot_unit_preserving_equipment(target_slot, card_data, "enemy")

		if success:
			bf.ai_hand.pop_at(card_index)
			bf.ai_spend_tp(card_data.tribute_cost)
			await ai_resolve_deployment_abilities(card_data, target_slot)
			bf.log_msg("AI promoted " + old_unit.card_name + " into " + card_data.card_name + " for full cost: " + str(card_data.tribute_cost) + " TP.")
			bf.log_msg("AI TP after promotion: " + str(bf.ai_current_tp) + "/" + str(bf.ai_perm_tp) + " Temp +" + str(bf.ai_temp_tp))
			bf.update_ai_visuals()
			return true

		return false

	if action_type == "unit" or action_type == "gambit" or action_type == "equipment_setup":
		await bf.play_enemy_hand_to_node_animation(card_data, target_slot, face_down)

		if target_slot.has_method("place_card"):
			success = target_slot.place_card(bf.TEST_CARD_SCENE, card_data, face_down)

		if success:
			bf.ai_hand.pop_at(card_index)
			bf.ai_spend_tp(deployment_cost)

			if face_down:
				bf.ai_face_down_gambits_this_round += 1

			var visibility_text: String = "face down" if face_down else "face up"
			var row_text: String = String(target_slot.get_meta("row", "unknown row"))
			var cost_text: String = "Shadowtax setup cost" if face_down else "printed cost"

			bf.log_msg("AI placed " + card_data.card_name + " " + visibility_text + " in enemy " + row_text + " row.")
			bf.log_msg("AI spent " + str(deployment_cost) + " TP " + cost_text + ". AI TP after deployment: " + str(bf.ai_current_tp) + "/" + str(bf.ai_perm_tp) + " Temp +" + str(bf.ai_temp_tp))
			await ai_resolve_deployment_abilities(card_data, target_slot)
			bf.update_ai_visuals()
			return true

	return false


func ai_resolve_deployment_abilities(card_data: CardData, slot: Node) -> void:
	if card_data == null or slot == null or bool(slot.get_meta("face_down", false)):
		return
	if bf.is_equipment_card(card_data) and bf.is_equipment_suppressed(slot):
		var dampen := bf.control_controller.face_up_control_source("player", &"dampen", bf.get_slot_lane(slot))
		await bf.show_control_trigger(dampen.get("ability") as AbilityData, card_data.card_name + " suppressed")
		return
	if bf.is_ability_suppressed_by_lockdown(slot, "on_deploy"):
		var lockdown := bf.control_controller.get_lockdown_source_against(slot)
		await bf.show_control_trigger(lockdown.get("ability") as AbilityData, card_data.card_name + " On-Deploy abilities suppressed")
		return
	await bf.resolve_control_deployment(card_data, slot, "enemy")
	await bf.resolve_mobility_deployment(card_data, slot, "enemy")


func ai_choose_deployment_action() -> Dictionary:
	var actions: Array[Dictionary] = bf.ai_build_deployment_actions()

	if actions.is_empty():
		bf.ai_last_deployment_decision = "No legal deployment actions"
		return {}

	var best_action: Dictionary = {}
	var best_score: int = -999999

	for action_variant in actions:
		var action: Dictionary = action_variant
		var score: int = bf.ai_score_deployment_action(action)

		if score > best_score:
			best_score = score
			best_action = action

	var minimum_score := bf.ai_min_deployment_score()

	if best_score < minimum_score:
		bf.ai_last_deployment_decision = (
			"Skipped weak deployment | best "
			+ bf.ai_describe_deployment_action(best_action, best_score)
			+ " | minimum "
			+ str(minimum_score)
		)
		return {}

	bf.ai_last_deployment_decision = bf.ai_describe_deployment_action(best_action, best_score)
	return best_action


func ai_describe_deployment_action(action: Dictionary, score: int) -> String:
	if action.is_empty():
		return "None"

	var card_index := int(action.get("card_index", -1))

	if card_index < 0 or card_index >= bf.ai_hand.size():
		return "Invalid action"

	var card_data: CardData = bf.ai_hand[card_index]
	var slot := action.get("slot", null) as Node
	var action_type := String(action.get("action_type", ""))
	var face_down := bool(action.get("face_down", false))

	if card_data == null or slot == null:
		return "Invalid action"

	var lane := bf.get_slot_lane(slot)
	var row := String(slot.get_meta("row", "unknown"))
	var visibility := "face-down" if face_down else "face-up"

	return (
		card_data.card_name
		+ " | "
		+ action_type
		+ " | "
		+ row
		+ " "
		+ lane
		+ " | "
		+ visibility
		+ " | score "
		+ str(score)
	)



func ai_make_deployment_action(card_index: int, slot: Node, action_type: String, face_down: bool) -> Dictionary:
	return {
		"card_index": card_index,
		"slot": slot,
		"action_type": action_type,
		"face_down": face_down
	}


func ai_build_deployment_actions() -> Array[Dictionary]:
	var actions: Array[Dictionary] = []

	for card_index in range(bf.ai_hand.size()):
		var card_data: CardData = bf.ai_hand[card_index]

		if card_data == null:
			continue

		if bf.is_unit_card(card_data):
			bf.ai_add_unit_deployment_actions(actions, card_index, card_data)
			continue

		if bf.is_equipment_card(card_data):
			bf.ai_add_equipment_deployment_actions(actions, card_index, card_data)
			continue

		if bf.is_gambit_card(card_data):
			bf.ai_add_gambit_deployment_actions(actions, card_index, card_data)
			continue

	return actions


func ai_add_unit_deployment_actions(actions: Array[Dictionary], card_index: int, card_data: CardData) -> void:
	if card_data == null:
		return

	var printed_cost: int = bf.get_ai_face_down_card_deployment_cost(card_data, false)

	# Promotion candidates.
	if printed_cost <= bf.ai_current_tp and bf.ai_card_passes_faction_gate(card_data, false):
		for lane in ["left", "middle", "right"]:
			var promote_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "front", lane)

			if bf.ai_can_promote_card_to_slot(card_data, promote_slot):
				actions.append(bf.ai_make_deployment_action(card_index, promote_slot, "promotion", false))

	# Normal front-row unit candidates.
	if printed_cost <= bf.ai_current_tp and bf.ai_card_passes_faction_gate(card_data, false):
		for front_slot in bf.ai_get_empty_enemy_slots("front"):
			actions.append(bf.ai_make_deployment_action(card_index, front_slot, "unit", false))

	# Face-down setup option in back row.
	var setup_cost: int = bf.get_ai_face_down_card_deployment_cost(card_data, true)

	if setup_cost <= bf.ai_current_tp:
		for back_slot in bf.ai_get_empty_legal_enemy_back_slots():
			actions.append(bf.ai_make_deployment_action(card_index, back_slot, "unit", true))


func ai_add_equipment_deployment_actions(actions: Array[Dictionary], card_index: int, card_data: CardData) -> void:
	if card_data == null:
		return

	var printed_cost: int = bf.get_ai_face_down_card_deployment_cost(card_data, false)

	# Attach equipment to an existing enemy unit.
	if printed_cost <= bf.ai_current_tp and bf.ai_card_passes_faction_gate(card_data, false):
		for target_slot in bf.ai_get_enemy_equipment_target_slots():
			actions.append(bf.ai_make_deployment_action(card_index, target_slot, "equipment", false))

	# Face-down equipment setup in back row.
	var setup_cost: int = bf.get_ai_face_down_card_deployment_cost(card_data, true)

	if setup_cost <= bf.ai_current_tp:
		for back_slot in bf.ai_get_empty_legal_enemy_back_slots():
			actions.append(bf.ai_make_deployment_action(card_index, back_slot, "equipment_setup", true))


func ai_add_gambit_deployment_actions(actions: Array[Dictionary], card_index: int, card_data: CardData) -> void:
	if card_data == null:
		return

	var printed_cost: int = bf.get_ai_face_down_card_deployment_cost(card_data, false)

	# Face-up gambit placement.
	if printed_cost <= bf.ai_current_tp and bf.ai_card_passes_faction_gate(card_data, false):
		for front_slot in bf.ai_get_empty_enemy_slots("front"):
			actions.append(bf.ai_make_deployment_action(card_index, front_slot, "gambit", false))

		for back_slot in bf.ai_get_empty_legal_enemy_back_slots():
			actions.append(bf.ai_make_deployment_action(card_index, back_slot, "gambit", false))

	# Face-down hidden gambit setup.
	var setup_cost: int = bf.get_ai_face_down_card_deployment_cost(card_data, true)

	if setup_cost <= bf.ai_current_tp:
		for back_slot in bf.ai_get_empty_enemy_slots("back"):
			actions.append(bf.ai_make_deployment_action(card_index, back_slot, "gambit", true))


func ai_get_empty_enemy_slots(row: String) -> Array[Node]:
	var result: Array[Node] = []

	if bf.board_slots == null:
		return result

	for lane in ["left", "middle", "right"]:
		var slot: Node = bf.find_slot_by_owner_row_lane("enemy", row, lane)

		if slot == null:
			continue

		if bf.get_slot_card_data(slot) != null:
			continue

		result.append(slot)

	return result


func ai_get_enemy_equipment_target_slots() -> Array[Node]:
	var result: Array[Node] = []

	if bf.board_slots == null:
		return result

	for lane in ["left", "middle", "right"]:
		var slot: Node = bf.find_slot_by_owner_row_lane("enemy", "front", lane)

		if slot == null:
			continue

		if bool(slot.get_meta("face_down", false)):
			continue

		var unit_card: CardData = bf.get_slot_card_data(slot)

		if not bf.is_unit_card(unit_card):
			continue

		if not slot.has_method("can_attach_equipment"):
			continue

		if not slot.can_attach_equipment():
			continue

		result.append(slot)

	return result



func ai_score_deployment_action(action: Dictionary) -> int:
	var card_index: int = int(action.get("card_index", -1))

	if card_index < 0 or card_index >= bf.ai_hand.size():
		return -999999

	var card_data: CardData = bf.ai_hand[card_index]

	if card_data == null:
		return -999999

	var slot: Node = action.get("slot", null) as Node

	if slot == null:
		return -999999

	var action_type: String = String(action.get("action_type", ""))
	var face_down: bool = bool(action.get("face_down", false))
	var score: int = 0
	var deployment_cost: int = bf.get_ai_face_down_card_deployment_cost(card_data, face_down)

	if deployment_cost > bf.ai_current_tp:
		return -999999

	score -= deployment_cost * 6

	if bf.ai_current_tp > 1 and deployment_cost == bf.ai_current_tp:
		score -= 8

	match action_type:
		"promotion":
			score += bf.ai_score_promotion_deployment(card_data, slot)

		"unit":
			score += bf.ai_score_unit_deployment(card_data, slot, face_down)

		"equipment":
			score += bf.ai_score_equipment_deployment(card_data, slot)

		"equipment_setup":
			score += bf.ai_score_equipment_setup(card_data, slot)

		"gambit":
			score += bf.ai_score_gambit_deployment(card_data, slot, face_down)

		_:
			score -= 100

	score += bf.ai_score_card_abilities_for_deployment(card_data, slot, action_type, face_down)
	score += bf.ai_score_deployment_lookahead(card_data, slot, action_type, face_down)

	score += bf.ai_tactical_noise(8)

	return score


func ai_score_promotion_deployment(card_data: CardData, slot: Node) -> int:
	if card_data == null or slot == null:
		return -999999

	var old_unit: CardData = bf.get_slot_card_data(slot)

	if not bf.is_unit_card(old_unit):
		return -999999

	var score: int = 115
	score += maxi(0, card_data.ap - old_unit.ap) * 12
	score += maxi(0, card_data.dp - old_unit.dp) * 6
	score += card_data.tribute_cost * 2

	var lane: String = bf.get_slot_lane(slot)
	var player_front: CardData = bf.get_slot_card_data(bf.find_slot_by_owner_row_lane("player", "front", lane))

	if bf.is_unit_card(player_front):
		if card_data.ap >= player_front.ap:
			score += 45
		else:
			score += 15
	else:
		score += 20

	return score


func ai_score_unit_deployment(card_data: CardData, slot: Node, face_down: bool) -> int:
	if card_data == null or slot == null:
		return -999999

	var lane: String = bf.get_slot_lane(slot)
	var score: int = 0

	if face_down:
		score += 28
		score += card_data.dp * 3

		var enemy_front: CardData = bf.get_slot_card_data(bf.find_slot_by_owner_row_lane("enemy", "front", lane))

		if bf.is_unit_card(enemy_front):
			score += 24

		if bf.ai_get_empty_enemy_slots("front").is_empty():
			score += 28
		else:
			score -= 20

		return score

	score += 80
	score += card_data.ap * 8
	score += card_data.dp * 4
	score += bf.ai_score_front_slot_for_card(card_data, lane)

	var player_front: CardData = bf.get_slot_card_data(bf.find_slot_by_owner_row_lane("player", "front", lane))
	var player_back: CardData = bf.get_slot_card_data(bf.find_slot_by_owner_row_lane("player", "back", lane))

	if bf.is_unit_card(player_front):
		score += 28

		if card_data.ap >= player_front.ap:
			score += 35
		else:
			score -= 10
	else:
		# Empty player front row means possible Monarch pressure later.
		score += 24

	if player_back != null:
		score += 12

	return score


func ai_score_equipment_deployment(card_data: CardData, slot: Node) -> int:
	if card_data == null or slot == null:
		return -999999

	var equipped_unit: CardData = bf.get_slot_card_data(slot)

	if not bf.is_unit_card(equipped_unit):
		return -999999

	var lane: String = bf.get_slot_lane(slot)
	var player_front: CardData = bf.get_slot_card_data(bf.find_slot_by_owner_row_lane("player", "front", lane))
	var score: int = 85

	score += card_data.ap * 9
	score += card_data.dp * 6
	score += equipped_unit.ap * 2
	score += equipped_unit.dp

	if bf.is_unit_card(player_front):
		var before_ap: int = equipped_unit.ap
		var after_ap: int = equipped_unit.ap + card_data.ap

		if before_ap < player_front.ap and after_ap >= player_front.ap:
			score += 55
		elif after_ap >= player_front.ap:
			score += 25

	return score


func ai_score_equipment_setup(card_data: CardData, slot: Node) -> int:
	if card_data == null or slot == null:
		return -999999

	var lane: String = bf.get_slot_lane(slot)
	var score: int = 22
	var enemy_front: CardData = bf.get_slot_card_data(bf.find_slot_by_owner_row_lane("enemy", "front", lane))

	score += card_data.dp * 2

	if bf.is_unit_card(enemy_front):
		score += 20
	else:
		score -= 12

	return score


func ai_score_gambit_deployment(card_data: CardData, slot: Node, face_down: bool) -> int:
	if card_data == null or slot == null:
		return -999999

	var lane: String = bf.get_slot_lane(slot)
	var row: String = String(slot.get_meta("row", ""))
	var score: int = 0

	var enemy_front: CardData = bf.get_slot_card_data(bf.find_slot_by_owner_row_lane("enemy", "front", lane))
	var player_front: CardData = bf.get_slot_card_data(bf.find_slot_by_owner_row_lane("player", "front", lane))
	var player_back: CardData = bf.get_slot_card_data(bf.find_slot_by_owner_row_lane("player", "back", lane))

	if face_down:
		score += 62

		if row == "back":
			score += 20

		if bf.is_unit_card(enemy_front):
			score += 24

		if bf.is_unit_card(player_front):
			score += 18

		if player_back != null:
			score += 8
	else:
		score += 36

		if row == "front":
			score += 8

		if bf.is_unit_card(player_front):
			score += 12

	score += card_data.ap * 3
	score += card_data.dp * 2

	return score



func ai_can_promote_card_to_slot(new_unit: CardData, slot: Node) -> bool:
	if new_unit == null:
		return false

	if not bf.is_unit_card(new_unit):
		return false

	if slot == null:
		return false

	if String(slot.get_meta("owner", "")) != "enemy":
		return false

	if String(slot.get_meta("row", "")) != "front":
		return false

	if not bool(slot.get_meta("occupied", false)):
		return false

	if bool(slot.get_meta("face_down", false)):
		return false

	var old_unit: CardData = bf.get_slot_card_data(slot)

	if not bf.is_unit_card(old_unit):
		return false

	var new_race: String = bf.get_clean_card_race(new_unit)
	var old_race: String = bf.get_clean_card_race(old_unit)

	if new_race == "" or old_race == "":
		return false

	if new_race != old_race:
		return false

	if new_unit.tribute_cost <= old_unit.tribute_cost:
		return false

	return true


func ai_find_best_affordable_unit_index() -> int:
	var best_index: int = -1
	var best_ap: int = -999

	for i in range(bf.ai_hand.size()):
		var card_data: CardData = bf.ai_hand[i]

		if card_data == null:
			continue

		if not bf.is_unit_card(card_data):
			continue

		if not bf.ai_card_passes_faction_gate(card_data, false):
			continue

		if card_data.tribute_cost > bf.ai_current_tp:
			continue

		if card_data.ap > best_ap:
			best_ap = card_data.ap
			best_index = i

	return best_index


func ai_find_affordable_gambit_index_for_visibility(face_down: bool) -> int:
	for i in range(bf.ai_hand.size()):
		var card_data: CardData = bf.ai_hand[i]

		if card_data == null:
			continue

		if not bf.is_gambit_card(card_data):
			continue

		if not bf.ai_card_passes_faction_gate(card_data, false):
			continue

		var deployment_cost: int = bf.get_ai_face_down_card_deployment_cost(card_data, face_down)

		if deployment_cost > bf.ai_current_tp:
			continue

		return i

	return -1


func ai_find_enemy_unit_slot_that_can_take_equipment() -> Node:
	if bf.board_slots == null:
		return null

	for slot in bf.board_slots.get_children():
		if String(slot.get_meta("owner", "")) != "enemy":
			continue

		if not bool(slot.get_meta("occupied", false)):
			continue

		if bool(slot.get_meta("face_down", false)):
			continue

		var existing_card: CardData = bf.get_slot_card_data(slot)

		if not bf.is_unit_card(existing_card):
			continue

		if not slot.has_method("can_attach_equipment"):
			continue

		if not slot.can_attach_equipment():
			continue

		return slot

	return null


func ai_find_empty_enemy_slot(row: String) -> Node:
	if bf.board_slots == null:
		return null

	var empty_slots: Array[Node] = []

	for slot in bf.board_slots.get_children():
		if String(slot.get_meta("owner", "")) != "enemy":
			continue

		if String(slot.get_meta("row", "")) != row:
			continue

		if bool(slot.get_meta("occupied", false)):
			continue

		empty_slots.append(slot)

	if empty_slots.is_empty():
		return null

	empty_slots.shuffle()
	return empty_slots[0]


func ai_choose_slot_for_card(card_data: CardData) -> Node:
	if card_data == null:
		return null

	if bf.is_unit_card(card_data):
		return bf.ai_choose_front_slot_for_card(card_data)

	if bf.is_equipment_card(card_data):
		return bf.ai_choose_equipment_target_slot(card_data)

	if bf.is_gambit_card(card_data):
		return bf.ai_choose_spell_like_slot(card_data)

	return null


func ai_choose_spell_like_slot(card_data: CardData) -> Node:
	var front_slots: Array[Node] = []
	var back_slots: Array[Node] = []
	var lanes: Array[String] = ["left", "middle", "right"]

	for lane in lanes:
		var front_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "front", lane)

		if front_slot != null and bf.get_slot_card_data(front_slot) == null:
			front_slots.append(front_slot)

		var back_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "back", lane)

		if back_slot != null and bf.get_slot_card_data(back_slot) == null:
			back_slots.append(back_slot)

	if front_slots.is_empty() and back_slots.is_empty():
		return null

	# Traps and ruses prefer the back row.
	if CardRules.is_trap_card(card_data) or CardRules.is_ruse_card(card_data):
		if not back_slots.is_empty():
			return back_slots.pick_random()

		return front_slots.pick_random()

	# Spells and events can go front or back.
	if bf.is_spell_card(card_data) or CardRules.is_event_card(card_data):
		if not front_slots.is_empty() and not back_slots.is_empty():
			if (randi() % 100) < 60:
				return front_slots.pick_random()

			return back_slots.pick_random()

		if not front_slots.is_empty():
			return front_slots.pick_random()

		return back_slots.pick_random()

	var all_slots: Array[Node] = []
	all_slots.append_array(front_slots)
	all_slots.append_array(back_slots)
	return all_slots.pick_random()


func ai_choose_equipment_target_slot(_card_data: CardData) -> Node:
	var candidate_slots: Array[Node] = []
	var lanes: Array[String] = ["left", "middle", "right"]

	for lane in lanes:
		var slot: Node = bf.find_slot_by_owner_row_lane("enemy", "front", lane)

		if slot == null:
			continue

		var slot_card: CardData = bf.get_slot_card_data(slot)

		if not bf.is_unit_card(slot_card):
			continue

		if slot.has_method("can_attach_equipment") and not slot.can_attach_equipment():
			continue

		candidate_slots.append(slot)

	if candidate_slots.is_empty():
		return null

	var best_score: int = -999999
	var best_slots: Array[Node] = []

	for slot in candidate_slots:
		var unit_card: CardData = bf.get_slot_card_data(slot)
		var score: int = 0

		if unit_card != null:
			score += unit_card.ap
			score += unit_card.dp

		score += randi() % 10

		if score > best_score:
			best_score = score
			best_slots.clear()
			best_slots.append(slot)
		elif score == best_score:
			best_slots.append(slot)

	return best_slots.pick_random()


func ai_choose_front_slot_for_card(card_data: CardData) -> Node:
	var candidate_slots: Array[Node] = bf.ai_get_empty_front_slots()

	if candidate_slots.is_empty():
		return null

	var best_score: int = -999999
	var best_slots: Array[Node] = []

	for slot in candidate_slots:
		var lane: String = bf.get_slot_lane(slot)
		var score: int = bf.ai_score_front_slot_for_card(card_data, lane)

		if score > best_score:
			best_score = score
			best_slots.clear()
			best_slots.append(slot)
		elif score == best_score:
			best_slots.append(slot)

	if best_slots.is_empty():
		return candidate_slots.pick_random()

	return best_slots.pick_random()


func ai_get_empty_front_slots() -> Array[Node]:
	var empty_slots: Array[Node] = []
	var lanes: Array[String] = ["left", "middle", "right"]

	for lane in lanes:
		var slot: Node = bf.find_slot_by_owner_row_lane("enemy", "front", lane)

		if slot == null:
			continue

		if bf.get_slot_card_data(slot) == null:
			empty_slots.append(slot)

	return empty_slots


func ai_score_front_slot_for_card(card_data: CardData, lane: String) -> int:
	var score: int = 0

	if card_data == null:
		return score

	var player_front_slot: Node = bf.find_slot_by_owner_row_lane("player", "front", lane)
	var player_back_slot: Node = bf.find_slot_by_owner_row_lane("player", "back", lane)

	var player_front_card: CardData = bf.get_slot_card_data(player_front_slot)
	var player_back_card: CardData = bf.get_slot_card_data(player_back_slot)
	var lane_pressure := bf.ai_memory_player_lane_pressure_score(lane)

	if bf.is_unit_card(player_front_card):
		score += 35

		if card_data.ap >= player_front_card.ap:
			score += 35
			score += bf.ai_apply_memory_bonus(lane_pressure * 2)
		else:
			score += 15
			score += bf.ai_apply_memory_bonus(lane_pressure)

		score += min(player_front_card.ap, 10)

	else:
		score += 18
		score += bf.ai_apply_memory_bonus(lane_pressure)

	if player_back_card != null:
		score += 8
		score += bf.ai_apply_memory_bonus(int(bf.ai_memory_player_backrow_pressure.get(lane, 0)))

	score += bf.ai_tactical_noise(25)
	return score


func ai_score_deploy_card(card_data: CardData) -> int:
	if card_data == null:
		return -999999

	var score: int = 0
	var card_type: String = bf.get_clean_card_type(card_data)

	match card_type:
		"unit":
			score += 70
			score += card_data.ap * 4
			score += card_data.dp * 2

		"equipment":
			score += 60
			score += card_data.ap * 3
			score += card_data.dp * 3

		"gambit":
			score += 35
		_:
			score -= 100

	# Prefer cheaper cards slightly so AI does not waste its full turn too easily.
	score -= card_data.tribute_cost * 2

	# Randomness so AI is not scripted.
	score += randi() % 20

	return score


func ai_spend_tp(cost: int) -> bool:
	if cost <= 0:
		return true

	if bf.ai_current_tp < cost:
		return false

	var remaining_cost: int = cost

	if bf.ai_temp_tp > 0:
		var temp_spent: int = mini(bf.ai_temp_tp, remaining_cost)
		bf.ai_temp_tp -= temp_spent
		bf.ai_current_tp -= temp_spent
		remaining_cost -= temp_spent

	if remaining_cost > 0:
		bf.ai_current_perm_tp -= remaining_cost
		bf.ai_current_tp -= remaining_cost

	return true


func ai_active_ability_weight() -> float:
	return float(bf.ai_get_difficulty_profile().get("active_ability_weight", 0.60))


func ai_apply_active_ability_bonus(base_score: int) -> int:
	return int(round(float(base_score) * bf.ai_active_ability_weight()))


func ai_try_use_active_ability_before_combat(lane: String) -> Dictionary:
	if bf.ai_active_ability_weight() <= 0.0:
		bf.ai_last_active_ability_decision = "Ignored by difficulty"
		return {"used": false, "result": "none"}

	if bf.current_phase != bf.BattlePhase.COMBAT:
		bf.ai_last_active_ability_decision = "Not combat phase"
		return {"used": false, "result": "none"}

	if bf.parry_system.active:
		bf.ai_last_active_ability_decision = "Parry active"
		return {"used": false, "result": "none"}

	if bf.combat_priority_owner != "ai":
		bf.ai_last_active_ability_decision = "No AI priority"
		return {"used": false, "result": "none"}

	if not bf.ai_can_try_active_ability_in_lane(lane):
		bf.ai_last_active_ability_decision = "Skipped active ability: already tried lane or turn limit reached"
		return {"used": false, "result": "none"}

	var actions: Array[Dictionary] = bf.ai_build_active_ability_actions(lane)

	if actions.is_empty():
		bf.ai_last_active_ability_decision = "No active ability actions in " + lane
		return {"used": false, "result": "none"}

	bf.ai_mark_active_ability_lane_attempted(lane)

	var best_action: Dictionary = {}
	var best_score: int = -999999

	for action in actions:
		var score := bf.ai_score_active_ability_action(action, lane)

		if score > best_score:
			best_score = score
			best_action = action

	var threshold := bf.ai_active_ability_use_threshold()
	bf.ai_last_active_ability_decision = bf.ai_describe_active_ability_action(best_action, best_score, threshold)

	if best_score < threshold:
		return {"used": false, "result": "none"}

	bf.log_msg("AI active ability score in " + lane + ": " + str(best_score) + " / threshold " + str(threshold) + ".")

	var result: Dictionary = await bf.ai_execute_active_ability_action(best_action, lane)

	if bool(result.get("used", false)):
		bf.ai_mark_active_ability_turn_used()

	return result
	
	
func ai_describe_active_ability_action(action: Dictionary, score: int, threshold: int) -> String:
	if action.is_empty():
		return "None"

	var ability := action.get("ability", null) as AbilityData
	var source_slot := action.get("source_slot", null) as Node
	var target_slot := action.get("target_slot", null) as Node
	var action_type := String(action.get("type", ""))

	if ability == null or source_slot == null:
		return "Invalid active ability"

	var source_lane := bf.get_slot_lane(source_slot)
	var target_text := ""

	if target_slot != null:
		target_text = " -> " + bf.get_slot_lane(target_slot)

	return (
		ability.ability_name
		+ " | "
		+ action_type
		+ " | "
		+ source_lane
		+ target_text
		+ " | score "
		+ str(score)
		+ " / threshold "
		+ str(threshold)
	)


func ai_active_ability_use_threshold() -> int:
	return int(bf.ai_get_difficulty_profile().get("active_ability_threshold", 78))


func ai_build_active_ability_actions(current_lane_name: String) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []

	for slot in bf.ai_get_enemy_face_up_front_slots():
		var source_slot := slot as Node

		if source_slot == null:
			continue

		for entry in bf.ai_get_active_ability_entries_for_slot(source_slot):
			var ability := entry.get("ability") as AbilityData

			if ability == null:
				continue

			if not bf.ai_can_consider_active_ability(source_slot, ability):
				continue

			var category := String(ability.category).to_lower()

			if category == "mobility":
				bf.ai_add_active_mobility_actions(actions, current_lane_name, source_slot, ability)

			elif category == "insight":
				bf.ai_add_active_insight_actions(actions, current_lane_name, source_slot, ability)

	return actions


func ai_get_enemy_face_up_front_slots() -> Array[Node]:
	var result: Array[Node] = []

	for lane in ["left", "middle", "right"]:
		var slot := bf.find_slot_by_owner_row_lane("enemy", "front", lane)
		var card := bf.get_slot_card_data(slot)

		if not bf.is_unit_card(card):
			continue

		if bool(slot.get_meta("face_down", false)):
			continue

		result.append(slot)

	return result


func ai_get_active_ability_entries_for_slot(slot: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if slot == null:
		return result

	var entries: Array = []

	if slot.has_method("get_ability_visual_entries"):
		entries = slot.call("get_ability_visual_entries")

	if entries.is_empty():
		var main_card := bf.get_slot_card_data(slot)

		if main_card != null:
			entries.append({"card": main_card})

	for entry in entries:
		var card_data := entry.get("card") as CardData

		if card_data == null:
			continue

		for ability in card_data.get_abilities():
			if ability == null:
				continue

			var category := String(ability.category).to_lower()
			var handler_id := ability.get_handler_id()

			if category == "insight" and ability.trigger == "active":
				result.append({"card": card_data, "ability": ability})
				continue

			if category == "mobility" and bf.ai_is_supported_ai_active_mobility(handler_id):
				result.append({"card": card_data, "ability": ability})

	return result


func ai_can_consider_active_ability(slot: Node, ability: AbilityData) -> bool:
	if slot == null or ability == null:
		return false
	if bf.is_ability_suppressed_by_lockdown(slot, "active") or bf.is_unit_chained_down(slot):
		return false
	if ability.get_handler_id() == &"volley" and not bf.get_control_halt_source_against("enemy").is_empty():
		return false

	if String(slot.get_meta("owner", "")) != "enemy":
		return false

	if bool(slot.get_meta("face_down", false)):
		return false

	var category := String(ability.category).to_lower()

	if category == "mobility":
		if bf.used_mobility_ability_keys.has(bf.get_mobility_usage_key(slot, ability)):
			return false

		var used_turns: Dictionary = slot.get_meta("used_mobility_turns", {}).duplicate()

		if int(used_turns.get(String(ability.ability_id), -1)) == bf.turn_number:
			return false

		return true

	if category == "insight":
		if bf.used_active_insight_ability_keys.has(bf.get_active_insight_usage_key(slot, ability)):
			return false

		return true

	return false


func ai_add_active_mobility_actions(actions: Array[Dictionary], current_lane_name: String, source_slot: Node, ability: AbilityData) -> void:
	if source_slot == null or ability == null:
		return

	var handler_id := ability.get_handler_id()
	var source_lane := bf.get_slot_lane(source_slot)

	match handler_id:
		&"lane_shift", &"mobilize":
			for lane in bf.get_adjacent_lanes(source_lane):
				var target_slot := bf.find_slot_by_owner_row_lane("enemy", "front", lane)

				if target_slot != null and bf.get_slot_card_data(target_slot) == null:
					actions.append({
						"type": "move",
						"source_slot": source_slot,
						"target_slot": target_slot,
						"ability": ability
					})

		&"tactic_flow":
			for lane in ["left", "right"]:
				var target_slot := bf.find_slot_by_owner_row_lane("enemy", "front", lane)

				if target_slot != null and target_slot != source_slot and bf.get_slot_card_data(target_slot) == null:
					actions.append({
						"type": "move",
						"source_slot": source_slot,
						"target_slot": target_slot,
						"ability": ability
					})

		&"flank_swap":
			for other_slot in bf.ai_get_enemy_face_up_front_slots():
				if other_slot == source_slot:
					continue

				actions.append({
					"type": "swap",
					"source_slot": source_slot,
					"target_slot": other_slot,
					"ability": ability
				})

		&"imperial_decree":
			for lane in ["left", "middle", "right"]:
				var target_slot := bf.find_slot_by_owner_row_lane("player", "front", lane)
				var target_card := bf.get_slot_card_data(target_slot)

				if bf.is_unit_card(target_card) and bf.get_slot_combat_ap(target_slot) <= 6:
					actions.append({
						"type": "destroy_low_ap",
						"source_slot": source_slot,
						"target_slot": target_slot,
						"ability": ability
					})

		&"vortex":
			if bf.ai_count_front_units("enemy") >= 2:
				actions.append({
					"type": "vortex",
					"source_slot": source_slot,
					"ability": ability
				})

		_:
			pass


func ai_add_active_insight_actions(actions: Array[Dictionary], current_lane_name: String, source_slot: Node, ability: AbilityData) -> void:
	if source_slot == null or ability == null:
		return

	var handler_id := ability.get_handler_id()

	if handler_id != &"true_sight" and handler_id != &"vantage" and handler_id != &"intuition":
		return

	var source_lane := bf.get_slot_lane(source_slot)

	if source_lane != current_lane_name:
		return

	var player_back_slot := bf.find_slot_by_owner_row_lane("player", "back", current_lane_name)
	var player_back_card := bf.get_slot_card_data(player_back_slot)
	var player_back_is_face_down := player_back_card != null and player_back_slot != null and bool(player_back_slot.get_meta("face_down", false))

	if not player_back_is_face_down:
		return

	actions.append({
		"type": "insight_peek",
		"source_slot": source_slot,
		"target_slot": player_back_slot,
		"ability": ability
	})



func ai_score_active_ability_action(action: Dictionary, current_lane_name: String) -> int:
	var action_type := String(action.get("type", ""))
	var source_slot := action.get("source_slot", null) as Node
	var target_slot := action.get("target_slot", null) as Node
	var ability := action.get("ability", null) as AbilityData

	if source_slot == null or ability == null:
		return -999999

	var raw_score := 0

	match action_type:
		"move":
			raw_score += bf.ai_score_active_move_action(source_slot, target_slot, current_lane_name)

		"swap":
			raw_score += bf.ai_score_active_swap_action(source_slot, target_slot)

		"destroy_low_ap":
			raw_score += bf.ai_score_active_destroy_action(target_slot)

		"vortex":
			raw_score += bf.ai_score_active_vortex_action(source_slot)

		"insight_peek":
			raw_score += bf.ai_score_active_insight_peek_action(target_slot, current_lane_name)

		_:
			return -999999

	var category := String(ability.category).to_lower()

	if category == "mobility":
		raw_score += 12
	elif category == "insight":
		raw_score += 10

	raw_score += bf.ai_tactical_noise(10)

	return bf.ai_apply_active_ability_bonus(raw_score)


func ai_score_active_move_action(source_slot: Node, target_slot: Node, current_lane_name: String) -> int:
	if source_slot == null or target_slot == null:
		return -999999

	var source_card := bf.get_slot_card_data(source_slot)

	if not bf.is_unit_card(source_card):
		return -999999

	if bf.get_slot_card_data(target_slot) != null:
		return -999999

	var source_lane := bf.get_slot_lane(source_slot)
	var target_lane := bf.get_slot_lane(target_slot)
	var current_score := bf.ai_score_projected_lane_control(source_lane, bf.get_slot_combat_ap(source_slot), source_card.dp, true)
	var target_score := bf.ai_score_projected_lane_control(target_lane, bf.get_slot_combat_ap(source_slot), source_card.dp, true)
	var score := target_score - current_score

	if target_lane == current_lane_name:
		score += 34

	if source_lane == current_lane_name and target_lane != current_lane_name:
		score -= 95

	if target_lane == "left" or target_lane == "right":
		score += 10

	score += bf.ai_memory_player_lane_pressure_score(target_lane)
	score -= bf.ai_memory_player_lane_pressure_score(source_lane) / 2

	return score


func ai_score_active_swap_action(source_slot: Node, target_slot: Node) -> int:
	if source_slot == null or target_slot == null:
		return -999999

	var source_card := bf.get_slot_card_data(source_slot)
	var target_card := bf.get_slot_card_data(target_slot)

	if not bf.is_unit_card(source_card) or not bf.is_unit_card(target_card):
		return -999999

	var source_lane := bf.get_slot_lane(source_slot)
	var target_lane := bf.get_slot_lane(target_slot)

	var before_score := 0
	before_score += bf.ai_score_projected_lane_control(source_lane, bf.get_slot_combat_ap(source_slot), source_card.dp, true)
	before_score += bf.ai_score_projected_lane_control(target_lane, bf.get_slot_combat_ap(target_slot), target_card.dp, true)

	var after_score := 0
	after_score += bf.ai_score_projected_lane_control(source_lane, bf.get_slot_combat_ap(target_slot), target_card.dp, true)
	after_score += bf.ai_score_projected_lane_control(target_lane, bf.get_slot_combat_ap(source_slot), source_card.dp, true)

	return after_score - before_score


func ai_score_active_destroy_action(target_slot: Node) -> int:
	if target_slot == null:
		return -999999

	var target_card := bf.get_slot_card_data(target_slot)

	if not bf.is_unit_card(target_card):
		return -999999

	var score := 70
	score += bf.ai_estimate_card_value(target_card) / 3
	score += bf.get_unit_defeat_aurion_reward(target_card) * 12
	score += bf.ai_memory_player_lane_pressure_score(bf.get_slot_lane(target_slot))

	return score


func ai_score_active_vortex_action(source_slot: Node) -> int:
	if source_slot == null:
		return -999999

	if bf.ai_count_front_units("enemy") < 2:
		return -999999

	var source_card := bf.get_slot_card_data(source_slot)

	if not bf.is_unit_card(source_card):
		return -999999

	var score := 42
	score += bf.ai_count_front_units("enemy") * 16
	score += bf.ai_memory_player_lane_pressure_score(bf.get_slot_lane(source_slot))

	return score


func ai_score_active_insight_peek_action(target_slot: Node, current_lane_name: String) -> int:
	if target_slot == null:
		return -999999

	var target_card := bf.get_slot_card_data(target_slot)

	if target_card == null:
		return -999999

	if not bool(target_slot.get_meta("face_down", false)):
		return -999999

	var score := 38
	score += int(round((bf.ai_memory_player_hidden_gambit_rate() - 0.50) * 90.0))
	score += bf.ai_memory_player_lane_pressure_score(current_lane_name)

	if bf.is_gambit_card(target_card):
		score += 18

	return score


func ai_execute_active_ability_action(action: Dictionary, current_lane_name: String) -> Dictionary:
	var action_type := String(action.get("type", ""))
	var source_slot := action.get("source_slot", null) as Node
	var target_slot := action.get("target_slot", null) as Node
	var ability := action.get("ability", null) as AbilityData

	if source_slot == null or ability == null:
		return {"used": false, "result": "none"}

	match action_type:
		"move":
			return await bf.ai_execute_active_move_action(source_slot, target_slot, ability)

		"swap":
			return await bf.ai_execute_active_swap_action(source_slot, target_slot, ability)

		"destroy_low_ap":
			return await bf.ai_execute_active_destroy_action(source_slot, target_slot, ability)

		"vortex":
			return await bf.ai_execute_active_vortex_action(source_slot, ability)

		"insight_peek":
			return await bf.ai_execute_active_insight_peek_action(source_slot, target_slot, ability, current_lane_name)

	return {"used": false, "result": "none"}


func ai_mark_active_mobility_used(slot: Node, ability: AbilityData) -> void:
	if slot == null or ability == null:
		return

	var used_turns: Dictionary = slot.get_meta("used_mobility_turns", {}).duplicate()
	used_turns[String(ability.ability_id)] = bf.turn_number
	slot.set_meta("used_mobility_turns", used_turns)
	bf.used_mobility_ability_keys[bf.get_mobility_usage_key(slot, ability)] = true


func ai_mark_active_insight_used(slot: Node, ability: AbilityData) -> void:
	if slot == null or ability == null:
		return

	bf.used_active_insight_ability_keys[bf.get_active_insight_usage_key(slot, ability)] = true



func ai_execute_active_move_action(source_slot: Node, target_slot: Node, ability: AbilityData) -> Dictionary:
	if source_slot == null or target_slot == null or ability == null:
		return {"used": false, "result": "none"}

	if bf.get_slot_card_data(target_slot) != null:
		return {"used": false, "result": "none"}

	await bf.show_timed_mobility_message(ability.ability_name.to_upper() + "  -  AI repositions")
	await bf.move_slot_contents(source_slot, target_slot)
	bf.ai_mark_active_mobility_used(target_slot, ability)
	bf.update_ai_visuals()

	bf.log_msg("AI used " + ability.ability_name + " to move into the " + bf.get_slot_lane(target_slot) + " lane.")
	return {"used": true, "result": "used"}


func ai_execute_active_swap_action(source_slot: Node, target_slot: Node, ability: AbilityData) -> Dictionary:
	if source_slot == null or target_slot == null or ability == null:
		return {"used": false, "result": "none"}

	var source_lane := bf.get_slot_lane(source_slot)
	var target_lane := bf.get_slot_lane(target_slot)

	await bf.show_timed_mobility_message(ability.ability_name.to_upper() + "  -  AI swaps lanes")
	await bf.swap_owner_lanes("enemy", source_lane, target_lane)
	bf.ai_mark_active_mobility_used(bf.find_slot_by_owner_row_lane("enemy", "front", target_lane), ability)
	bf.update_ai_visuals()

	bf.log_msg("AI used " + ability.ability_name + " to swap " + source_lane + " and " + target_lane + ".")
	return {"used": true, "result": "used"}


func ai_execute_active_destroy_action(source_slot: Node, target_slot: Node, ability: AbilityData) -> Dictionary:
	if source_slot == null or target_slot == null or ability == null:
		return {"used": false, "result": "none"}

	var target_card := bf.get_slot_card_data(target_slot)

	if not bf.is_unit_card(target_card):
		return {"used": false, "result": "none"}

	await bf.show_timed_mobility_message(ability.ability_name.to_upper() + "  -  AI destroys a weak unit")
	bf.send_slot_card_to_discard(target_slot)
	bf.ai_mark_active_mobility_used(source_slot, ability)
	bf.update_ai_visuals()

	bf.log_msg("AI used " + ability.ability_name + " to destroy " + target_card.card_name + ".")
	return {"used": true, "result": "used"}


func ai_execute_active_vortex_action(source_slot: Node, ability: AbilityData) -> Dictionary:
	if source_slot == null or ability == null:
		return {"used": false, "result": "none"}

	if bf.ai_count_front_units("enemy") < 2:
		return {"used": false, "result": "none"}

	await bf.show_timed_mobility_message(ability.ability_name.to_upper() + "  -  AI merges pressure")
	var success := await bf.resolve_vortex(ability, "enemy")

	if not success:
		return {"used": false, "result": "none"}

	bf.ai_mark_active_mobility_used(source_slot, ability)
	bf.update_ai_visuals()

	bf.log_msg("AI used " + ability.ability_name + ".")
	return {"used": true, "result": "used"}


func ai_execute_active_insight_peek_action(source_slot: Node, target_slot: Node, ability: AbilityData, current_lane_name: String) -> Dictionary:
	if source_slot == null or target_slot == null or ability == null:
		return {"used": false, "result": "none"}

	var target_card := bf.get_slot_card_data(target_slot)

	if target_card == null or not bool(target_slot.get_meta("face_down", false)):
		return {"used": false, "result": "none"}

	await bf.show_timed_mobility_message(ability.ability_name.to_upper() + "  -  AI reads hidden card")

	if target_slot.has_method("reveal_card"):
		target_slot.reveal_card()

	bf.ai_memory_note_player_hidden_reveal(target_card, current_lane_name, "ai_active_insight")
	bf.ai_mark_active_insight_used(source_slot, ability)

	bf.log_msg("AI used " + ability.ability_name + " and revealed your hidden back-row card in the " + current_lane_name + " lane.")

	# Active Insight is used instead of attacking, mirroring the player's True Sight / Vantage behavior.
	bf.ai_passed_current_lane = true
	await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
	bf.set_lane_priority_to_player(current_lane_name, ability.ability_name + " used by AI instead of attacking.")

	return {"used": true, "result": "consumed"}



func ai_choose_combat_action(lane: String) -> String:
	var ai_front_slot := bf.find_slot_by_owner_row_lane("enemy", "front", lane)
	if bf.control_unit_must_attack(ai_front_slot) and not bf.is_unit_chained_down(ai_front_slot) and not bf.control_lane_attack_is_disabled("enemy", lane):
		return "attack"
	var attack_base: int = bf.ai_score_combat_attack_action(lane)
	var check_base: int = bf.ai_score_combat_check_action(lane)
	var pass_base: int = bf.ai_score_combat_pass_action(lane)

	var attack_lookahead: int = bf.ai_score_combat_action_lookahead(lane, "attack")
	var check_lookahead: int = bf.ai_score_combat_action_lookahead(lane, "check")
	var pass_lookahead: int = bf.ai_score_combat_action_lookahead(lane, "pass")

	var attack_ability: int = bf.ai_score_combat_ability_awareness(lane, "attack")
	var check_ability: int = bf.ai_score_combat_ability_awareness(lane, "check")
	var pass_ability: int = bf.ai_score_combat_ability_awareness(lane, "pass")

	var attack_score: int = attack_base + attack_lookahead + attack_ability
	if bf.is_unit_chained_down(ai_front_slot) or bf.control_lane_attack_is_disabled("enemy", lane):
		attack_score = -999999
	var check_score: int = check_base + check_lookahead + check_ability
	var pass_score: int = pass_base + pass_lookahead + pass_ability

	var best_action: String = "pass"
	var best_score: int = pass_score

	if attack_score > best_score:
		best_action = "attack"
		best_score = attack_score

	if check_score > best_score:
		best_action = "check"
		best_score = check_score

	bf.ai_last_combat_decision = (
		lane
		+ " | Attack "
		+ str(attack_score)
		+ " = "
		+ str(attack_base)
		+ "+"
		+ str(attack_lookahead)
		+ "+"
		+ str(attack_ability)
		+ " | Check "
		+ str(check_score)
		+ " = "
		+ str(check_base)
		+ "+"
		+ str(check_lookahead)
		+ "+"
		+ str(check_ability)
		+ " | Pass "
		+ str(pass_score)
		+ " = "
		+ str(pass_base)
		+ "+"
		+ str(pass_lookahead)
		+ "+"
		+ str(pass_ability)
		+ " -> "
		+ best_action.capitalize()
	)

	bf.log_msg(
		"AI combat scores in "
		+ lane
		+ ": Attack "
		+ str(attack_score)
		+ " (base "
		+ str(attack_base)
		+ ", lookahead "
		+ str(attack_lookahead)
		+ ", ability "
		+ str(attack_ability)
		+ "), Check "
		+ str(check_score)
		+ " (base "
		+ str(check_base)
		+ ", lookahead "
		+ str(check_lookahead)
		+ ", ability "
		+ str(check_ability)
		+ "), Pass "
		+ str(pass_score)
		+ " (base "
		+ str(pass_base)
		+ ", lookahead "
		+ str(pass_lookahead)
		+ ", ability "
		+ str(pass_ability)
		+ ") | Memory: hidden Gambit rate "
		+ str(int(round(bf.ai_memory_player_hidden_gambit_rate() * 100.0)))
		+ "%, lane pressure "
		+ str(bf.ai_memory_player_lane_pressure_score(lane))
		+ " -> "
		+ best_action.capitalize()
		+ "."
	)

	return best_action


func ai_score_combat_attack_action(lane: String) -> int:
	var ai_front_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "front", lane)
	var player_front_slot: Node = bf.find_slot_by_owner_row_lane("player", "front", lane)
	var player_back_slot: Node = bf.find_slot_by_owner_row_lane("player", "back", lane)

	var ai_card: CardData = bf.get_slot_card_data(ai_front_slot)
	var player_front_card: CardData = bf.get_slot_card_data(player_front_slot)
	var player_back_card: CardData = bf.get_slot_card_data(player_back_slot)
	var player_back_is_face_down: bool = player_back_card != null and player_back_slot != null and bool(player_back_slot.get_meta("face_down", false))

	if not bf.is_unit_card(ai_card):
		return -999999

	var score: int = 0
	var hidden_gambit_memory_bias := bf.ai_apply_memory_bonus(
		int(round((bf.ai_memory_player_hidden_gambit_rate() - 0.50) * 100.0))
	)
	var lane_pressure := bf.ai_memory_player_lane_pressure_score(lane)

	if player_back_is_face_down:
		score += 30

		var gambit_protection := bf.get_gambit_attack_protection(ai_front_slot)

		if gambit_protection != null:
			score += 65
		else:
			score -= 28
			score -= hidden_gambit_memory_bias

		if player_front_card == null:
			score += 35

	if player_front_card == null:
		score += 150
		score += bf.get_unit_defeat_aurion_reward(ai_card) * 4

		if player_back_is_face_down:
			score -= 25
			score -= hidden_gambit_memory_bias

		score += bf.ai_apply_memory_bonus(lane_pressure)
		return score + bf.ai_tactical_noise(6)

	var ai_ap: int = bf.get_slot_combat_ap(ai_front_slot)
	var player_ap: int = bf.get_slot_combat_ap(player_front_slot)
	var ap_gap: int = ai_ap - player_ap

	var ai_reward_value: int = bf.get_unit_defeat_aurion_reward(ai_card)
	var player_reward_value: int = bf.get_unit_defeat_aurion_reward(player_front_card)

	if ap_gap > 0:
		score += 82
		score += ap_gap * 14
		score += player_reward_value * 10
		score += bf.ai_apply_memory_bonus(lane_pressure)

		if ap_gap == 1:
			score -= 10

	elif ap_gap == 0:
		score += 28
		score += player_reward_value * 8
		score -= ai_reward_value * 6

		if player_reward_value > ai_reward_value:
			score += 18
		elif ai_reward_value > player_reward_value:
			score -= 16

	else:
		score -= 88
		score += ap_gap * 16
		score -= ai_reward_value * 14

		if bf.slot_has_protection_ability(ai_front_slot, &"plated") != null:
			score += 68

		if bf.slot_has_protection_ability(ai_front_slot, &"spiked") != null:
			score += 54

		score -= bf.ai_apply_memory_bonus(lane_pressure)

	if lane == "left" or lane == "right":
		score += 12

		if ai_ap > player_ap:
			score += 18
		elif ai_ap < player_ap:
			score -= 10

	if player_back_is_face_down and bf.get_gambit_attack_protection(ai_front_slot) == null:
		score -= 12
		score -= hidden_gambit_memory_bias

	score += bf.ai_tactical_noise(8)
	return score


func ai_score_combat_check_action(lane: String) -> int:
	var ai_front_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "front", lane)
	var player_front_slot: Node = bf.find_slot_by_owner_row_lane("player", "front", lane)
	var player_back_slot: Node = bf.find_slot_by_owner_row_lane("player", "back", lane)

	var ai_card: CardData = bf.get_slot_card_data(ai_front_slot)
	var player_front_card: CardData = bf.get_slot_card_data(player_front_slot)
	var player_back_card: CardData = bf.get_slot_card_data(player_back_slot)
	var player_back_is_face_down: bool = player_back_card != null and player_back_slot != null and bool(player_back_slot.get_meta("face_down", false))

	if not bf.is_unit_card(ai_card):
		return -999999

	if not player_back_is_face_down:
		return -999999

	var score: int = 46
	var hidden_gambit_memory_bias := bf.ai_apply_memory_bonus(
		int(round((bf.ai_memory_player_hidden_gambit_rate() - 0.50) * 100.0))
	)
	var lane_pressure := bf.ai_memory_player_lane_pressure_score(lane)

	var ai_ap: int = bf.get_slot_combat_ap(ai_front_slot)
	var player_ap: int = bf.get_slot_combat_ap(player_front_slot)

	score += hidden_gambit_memory_bias
	score += bf.ai_apply_memory_bonus(lane_pressure)

	if bf.get_gambit_attack_protection(ai_front_slot) != null:
		score -= 45

	if player_front_card == null:
		score += 38

	if bf.is_unit_card(player_front_card):
		if ai_ap < player_ap:
			score += 32
		elif ai_ap == player_ap:
			score += 14
		else:
			score -= 8

	if bf.player_passed_current_lane:
		score -= 12

	if bf.ai_passed_current_lane:
		score -= 35

	score += bf.ai_tactical_noise(10)
	return score


func ai_score_combat_pass_action(lane: String) -> int:
	var ai_front_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "front", lane)
	var player_front_slot: Node = bf.find_slot_by_owner_row_lane("player", "front", lane)
	var player_back_slot: Node = bf.find_slot_by_owner_row_lane("player", "back", lane)

	var ai_card: CardData = bf.get_slot_card_data(ai_front_slot)
	var player_front_card: CardData = bf.get_slot_card_data(player_front_slot)
	var player_back_card: CardData = bf.get_slot_card_data(player_back_slot)
	var player_back_is_face_down: bool = player_back_card != null and player_back_slot != null and bool(player_back_slot.get_meta("face_down", false))

	if not bf.is_unit_card(ai_card):
		return 80

	var score: int = 8
	var lane_pressure := bf.ai_memory_player_lane_pressure_score(lane)

	var attack_score: int = bf.ai_score_combat_attack_action(lane)
	var check_score: int = bf.ai_score_combat_check_action(lane)

	if bf.player_passed_current_lane:
		score += 42

		if attack_score < 25:
			score += 35

		if check_score < 25:
			score += 14

	if player_front_card == null and not player_back_is_face_down:
		score -= 120

	if attack_score < -20 and check_score < 0:
		score += 45

	if bf.is_unit_card(player_front_card):
		var ai_ap: int = bf.get_slot_combat_ap(ai_front_slot)
		var player_ap: int = bf.get_slot_combat_ap(player_front_slot)

		if ai_ap > player_ap:
			score -= 25
			score -= bf.ai_apply_memory_bonus(lane_pressure)
		elif ai_ap < player_ap:
			score += 18
			score += bf.ai_apply_memory_bonus(lane_pressure)

	score += bf.ai_tactical_noise(6)
	return score
