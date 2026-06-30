class_name BattlefieldPhaseController
extends RefCounted

## Domain controller extracted from BattlefieldManager. The manager facade preserves
## scene callbacks and dynamic-call compatibility.

var bf: BattlefieldManager


func _init(owner_battlefield: BattlefieldManager) -> void:
	bf = owner_battlefield


func _on_deck_selection_screen_selected(slot_index: int) -> void:
	if bf.deck_selection_context == bf.DECK_SELECTION_CONTEXT_AI:
		await bf._on_ai_deck_selected(slot_index)
	else:
		await bf._on_prebattle_deck_selected(slot_index)


func setup_deck_selection_flow() -> void:
	bf.waiting_for_battle_plan = true
	bf.deck_selection_context = bf.DECK_SELECTION_CONTEXT_PLAYER
	bf.deck_selection_complete = false

	if bf.battle_plan_selection_screen != null:
		bf.battle_plan_selection_screen.hide_selection()

	if bf.deck_selection_screen == null or bf.player_deck == null:
		bf.deck_selection_complete = true
		bf.setup_battle_plan_flow()
		return

	bf.deck_selection_screen.show_selection(
		bf.player_deck.get_saved_deck_summaries(),
		"CHOOSE YOUR WAR DECK",
		"Select the saved deck you will bring into this battle.",
		false
	)

	bf.update_phase_progress_state()


func _on_prebattle_deck_selected(slot_index: int) -> void:
	if bf.player_deck == null:
		return

	if slot_index < 0:
		bf.player_deck.use_fallback_deck()
	else:
		var loaded := bf.player_deck.load_saved_deck_slot(slot_index, true)

		if not loaded:
			bf.log_msg("That saved deck is unavailable or has fewer than 10 valid cards.")
			bf.deck_selection_screen.show_selection(
				bf.player_deck.get_saved_deck_summaries(),
				"CHOOSE YOUR WAR DECK",
				"Select the saved deck you will bring into this battle.",
				false
			)
			return

	bf.log_msg("Battle deck selected: " + str(bf.player_deck.cards_remaining()) + " cards.")

	await bf.get_tree().process_frame
	bf.show_ai_deck_selection()


func show_ai_deck_selection() -> void:
	if bf.deck_selection_screen == null or bf.player_deck == null:
		bf.ai_deck_source_mode = bf.AI_DECK_SOURCE_RANDOM_SYNERGY
		bf.ai_selected_saved_deck_slot = -1
		bf.deck_selection_complete = true
		bf.setup_battle_plan_flow()
		return

	bf.deck_selection_context = bf.DECK_SELECTION_CONTEXT_AI

	bf.deck_selection_screen.show_selection(
		bf.player_deck.get_saved_deck_summaries(),
		"CHOOSE OPPONENT DECK",
		"Let the AI build a synergistic deck, or choose one of your saved decks for it.",
		true
	)

	bf.update_phase_progress_state()


func _on_ai_deck_selected(slot_index: int) -> void:
	if slot_index == bf.AI_DECK_OPTION_RANDOM_SYNERGY:
		bf.ai_deck_source_mode = bf.AI_DECK_SOURCE_RANDOM_SYNERGY
		bf.ai_selected_saved_deck_slot = -1
		bf.log_msg("AI deck selected: Random Synergy Deck.")
	else:
		var saved_cards := bf.player_deck.get_saved_deck_slot_cards(slot_index) if bf.player_deck != null else []

		if saved_cards.is_empty():
			bf.log_msg("That opponent deck is unavailable or has fewer than 10 valid cards.")
			bf.show_ai_deck_selection()
			return

		bf.ai_deck_source_mode = bf.AI_DECK_SOURCE_SAVED
		bf.ai_selected_saved_deck_slot = slot_index
		bf.log_msg("AI deck selected: Saved Deck Slot " + str(slot_index + 1) + ".")

	bf.deck_selection_complete = true

	await bf.get_tree().process_frame
	bf.setup_battle_plan_flow()


func setup_battle_plan_flow() -> void:
	bf.waiting_for_battle_plan = true
	if bf.battle_plan_panel != null:
		bf.battle_plan_panel.clear_battle_plan()
	if bf.battle_plan_selection_screen != null:
		if not bf.battle_plan_selection_screen.battle_plan_selected.is_connected(_on_battle_plan_selected):
			bf.battle_plan_selection_screen.battle_plan_selected.connect(_on_battle_plan_selected)
	bf.open_battle_plan_selection()


func open_battle_plan_selection() -> void:
	bf.waiting_for_battle_plan = true
	bf.set_phase(bf.BattlePhase.BATTLEPLAN)

	await bf.get_tree().create_timer(bf.PHASE_TITLE_TOTAL_TIME).timeout

	if bf.current_phase != bf.BattlePhase.BATTLEPLAN:
		return

	if bf.battle_plan_manager == null:
		bf.log_msg("BattlePlanManager is missing.")
		await bf.begin_game_after_battle_plan_selection()
		bf.set_phase(bf.BattlePhase.TRIBUTE)
		return

	if bf.battle_plan_selection_screen == null:
		bf.log_msg("BattlePlanSelectionScreen is missing.")
		await bf.begin_game_after_battle_plan_selection()
		bf.set_phase(bf.BattlePhase.TRIBUTE)
		return

	var choices: Array[Dictionary] = bf.get_unused_battle_plan_choices(5)

	if choices.is_empty():
		bf.log_msg("All Battle Plans have been used. Reshuffling the Battleplan deck.")

		await bf.show_timed_mobility_message(
			"BATTLEPLANS FINISHED  -  Reshuffling the Battleplan deck"
		)

		bf.used_battle_plan_keys.clear()
		bf.opponent_battle_plan = {}

		if bf.battle_plan_manager != null:
			bf.battle_plan_manager.clear_current_battle_plan()

		choices = bf.get_unused_battle_plan_choices(5)

		if choices.is_empty():
			bf.log_msg("Battleplan reshuffle failed: no Battle Plans are available.")
			return

	if choices.size() < 5:
		bf.log_msg("Battleplan deck is running low. Remaining choices: " + str(choices.size()))

	bf.battle_plan_selection_screen.show_selection(choices)
	bf.update_phase_progress_state()


func _on_battle_plan_selected(plan: Dictionary) -> void:
	if plan.is_empty():
		bf.log_msg("No Battle Plan selected.")
		return

	if bf.is_battle_plan_used(plan):
		bf.log_msg("That Battle Plan has already been used. Drawing new options.")
		bf.open_battle_plan_selection()
		return

	bf.waiting_for_battle_plan = false

	bf.mark_battle_plan_used(plan)

	if bf.battle_plan_manager != null:
		bf.battle_plan_manager.select_battle_plan(plan)

	bf.choose_opponent_battle_plan()
	bf.battleplan_objective_controller.reset_round(plan, bf.opponent_battle_plan)

	if bf.battle_plan_panel != null:
		bf.battle_plan_panel.set_battle_plan(plan)

		if bf.battle_plan_panel.has_method("set_opponent_battle_plan"):
			bf.battle_plan_panel.set_opponent_battle_plan(bf.opponent_battle_plan)

	bf.apply_battle_plan_rules(plan)
	bf.apply_initiative_rules(plan)

	bf.log_msg("Selected Battle Plan: " + str(plan.get("name", "Unknown Battle Plan")))

	if bf.opponent_battle_plan.is_empty():
		bf.log_msg("Opponent has no unused Battle Plan.")
	else:
		bf.log_msg("Opponent Battle Plan: " + str(bf.opponent_battle_plan.get("name", "Unknown Battle Plan")))

	if not bf.game_has_started:
		await bf.begin_game_after_battle_plan_selection()

	bf.draw_battleplan_cards(plan)


func choose_opponent_battle_plan() -> void:
	bf.opponent_battle_plan = {}

	if bf.battle_plan_manager == null:
		return

	var choices: Array[Dictionary] = bf.get_unused_battle_plan_choices(1)

	if choices.is_empty():
		bf.log_msg("Opponent Battleplan deck is exhausted.")
		return

	bf.opponent_battle_plan = choices[0]
	bf.mark_battle_plan_used(bf.opponent_battle_plan)


func apply_battle_plan_rules(plan: Dictionary) -> void:
	if bf.hand == null:
		return
	var max_hand_size: int = int(plan.get("max_hand_size", 7))
	bf.hand.set_max_hand_size(max_hand_size)
	bf.log_msg("Max hand size set to " + str(max_hand_size) + " by " + str(plan.get("name", "Battle Plan")))


func apply_initiative_rules(plan: Dictionary) -> void:
	var player_initiative: int = int(plan.get("initiative_mark", 0))
	var opponent_initiative: int = int(bf.opponent_battle_plan.get("initiative_mark", 0))
	bf.player_has_initiative = player_initiative >= opponent_initiative
	if bf.player_has_initiative:
		bf.log_msg("Initiative: Player acts first. " + str(player_initiative) + " vs " + str(opponent_initiative))
	else:
		bf.log_msg("Initiative: Opponent acts first. " + str(opponent_initiative) + " vs " + str(player_initiative))


func draw_battleplan_cards(plan: Dictionary) -> void:
	var draw_amount: int = int(plan.get("draw_amount", 0))
	bf.pending_battleplan_draws = 0
	bf.battleplan_hand_cleanup_active = false

	if draw_amount > 0 and bf.player_deck != null and bf.hand != null:
		bf.pending_battleplan_draws = mini(draw_amount, bf.player_deck.cards_remaining())

	if bf.pending_battleplan_draws > 0:
		bf.log_msg(
			"Battleplan draw: drag "
			+ str(bf.pending_battleplan_draws)
			+ " card(s) from the Draw Pile into your hand."
		)
	else:
		bf.log_msg("Battleplan draw: no player cards to draw.")

	if bf.opponent_battle_plan.is_empty():
		bf.log_msg("AI battleplan draw skipped. No unused AI battleplan remains.")
	else:
		var ai_draw_amount: int = int(bf.opponent_battle_plan.get("draw_amount", 0))
		bf.ai_draw_cards(ai_draw_amount)
		bf.log_msg("AI battleplan draw: AI drew " + str(ai_draw_amount) + " cards. AI hand: " + str(bf.ai_hand.size()))

	bf.update_phase_ui()
	if bf.pending_battleplan_draws <= 0:
		bf.begin_battleplan_hand_cleanup_or_tribute()


func begin_battleplan_hand_cleanup_or_tribute() -> void:
	if bf.hand != null and bf.hand.cards.size() > bf.hand.max_hand_size:
		bf.battleplan_hand_cleanup_active = true
		bf.battleplan_discard_time_left = bf.BATTLEPLAN_HAND_CLEANUP_TIME
		bf.log_msg(
			"Hand limit exceeded. Discard "
			+ str(bf.hand.cards.size() - bf.hand.max_hand_size)
			+ " card(s) of your choice within "
			+ str(int(bf.BATTLEPLAN_HAND_CLEANUP_TIME))
			+ " seconds."
		)
		bf.update_phase_ui()
		return
	bf.finish_battleplan_prephase()


func update_battleplan_hand_cleanup(delta: float) -> void:
	if not bf.battleplan_hand_cleanup_active or bf.hand == null:
		return
	if bf.hand.cards.size() <= bf.hand.max_hand_size:
		bf.finish_battleplan_prephase()
		return
	# Do not let the deadline consume a card while the player is physically holding it.
	if bf.hand_drag_preview != null or bf.selected_card_data != null:
		return
	bf.battleplan_discard_time_left = maxf(bf.battleplan_discard_time_left - delta, 0.0)
	bf.update_phase_instruction_ui()
	if bf.battleplan_discard_time_left > 0.0:
		return
	while bf.hand.cards.size() > bf.hand.max_hand_size:
		var card_ui: CardUI = bf.hand.cards.back() as CardUI
		if card_ui == null or card_ui.card_data == null:
			break
		if bf.discard_pile != null:
			bf.discard_pile.add_card(card_ui.card_data)
		bf.hand.consume_dragged_card(card_ui)
	bf.log_msg("Discard timer expired. Excess cards were discarded automatically.")
	bf.finish_battleplan_prephase()


func finish_battleplan_prephase() -> void:
	bf.pending_battleplan_draws = 0
	bf.battleplan_hand_cleanup_active = false
	bf.battleplan_discard_time_left = 0.0
	bf.set_phase(bf.BattlePhase.TRIBUTE)


func begin_game_after_battle_plan_selection() -> void:
	if bf.game_has_started:
		return

	bf.game_has_started = true

	bf.setup_ai_deck()
	bf.ai_draw_cards(3)
	bf.ai_has_starting_hand = true

	bf.update_tribute_counter()
	await bf.deal_starting_hand()

	if bf.tribute_manager != null:
		bf.log_msg("Starting Tribute: " + bf.tribute_manager.get_status_text())

	bf.log_msg("AI starting hand dealt. AI hand: " + str(bf.ai_hand.size()) + " | AI deck: " + str(bf.ai_deck.size()))
	bf.update_ai_visuals()


func set_phase(new_phase: int) -> void:
	if bf.current_phase == bf.BattlePhase.COMBAT and new_phase != bf.BattlePhase.COMBAT:
		bf.clear_active_combat_lane_highlight()

	bf.current_phase = new_phase
	if bf.phase_tip_panel != null:
		bf.phase_tip_panel.reset_timer()
	bf.update_phase_ui()
	bf.update_slot_highlights()
	if bf.current_phase != bf.BattlePhase.BATTLEPLAN or bf.deck_selection_complete:
		bf.show_phase_title(bf.get_phase_name(bf.current_phase))

	match bf.current_phase:
		bf.BattlePhase.BATTLEPLAN:
			bf.log_msg("Phase: Battleplan")

		bf.BattlePhase.TRIBUTE:
			bf.log_msg("Phase: Tribute")
			bf.ai_start_tribute_phase()

		bf.BattlePhase.DEPLOYMENT:
			bf.begin_deployment_phase()

		bf.BattlePhase.COMBAT:
			bf.begin_combat_phase()


func get_phase_name(phase: int) -> String:
	match phase:
		bf.BattlePhase.BATTLEPLAN:
			return "BATTLEPLAN"
		bf.BattlePhase.TRIBUTE:
			return "TRIBUTE"
		bf.BattlePhase.DEPLOYMENT:
			return "DEPLOYMENT"
		bf.BattlePhase.COMBAT:
			return "COMBAT"
	return ""


func begin_deployment_phase() -> void:
	bf.ai_deployed_this_deployment_phase = false
	bf.player_passed_deployment = false
	bf.log_msg("Phase: Deployment")

	if bf.player_has_initiative:
		bf.log_msg("Player has initiative and deploys first. AI will deploy after you press Go to Combat.")
	else:
		bf.log_msg("AI has initiative and deploys first.")
		await bf.run_ai_deployment_turn_if_needed()


func run_ai_deployment_turn_if_needed() -> void:
	if bf.ai_deployed_this_deployment_phase or bf.phase_transition_busy:
		return
	bf.phase_transition_busy = true

	if bf.next_phase_button != null:
		bf.next_phase_button.disabled = true

	await bf.ai_take_deployment_turn()
	bf.ai_deployed_this_deployment_phase = true
	bf.phase_transition_busy = false

	if bf.next_phase_button != null:
		bf.next_phase_button.disabled = false


func begin_combat_phase() -> void:
	bf.phase_transition_busy = true
	bf.cleanup_face_up_gambits_before_combat()
	bf.reset_combat_state()
	bf.clear_active_combat_lane_highlight()
	await bf.get_tree().create_timer(bf.PHASE_TITLE_TOTAL_TIME).timeout
	if bf.current_phase != bf.BattlePhase.COMBAT:
		bf.phase_transition_busy = false
		return
	bf.phase_transition_busy = false

	if bf.player_has_initiative:
		bf.log_msg("Phase: Combat. Player has initiative. Right-click the leftmost or rightmost lane, then choose Attack, Check, or Pass.")
	else:
		bf.log_msg("Phase: Combat. AI has initiative. AI chooses combat direction and gets first priority in each lane.")
		await bf.get_tree().create_timer(bf.COMBAT_LANE_START_DELAY).timeout
		await bf.ai_take_combat_initiative()

func update_phase_ui() -> void:
	if bf.phase_label == null or bf.next_phase_button == null:
		return

	match bf.current_phase:
		bf.BattlePhase.BATTLEPLAN:
			if bf.pending_battleplan_draws > 0:
				bf.phase_label.text = "BATTLEPLAN DRAW"
				bf.next_phase_button.text = "Draw " + str(bf.pending_battleplan_draws) + " Card(s)"
			elif bf.battleplan_hand_cleanup_active:
				bf.phase_label.text = "HAND LIMIT"
				bf.next_phase_button.text = "Discard Excess Cards"
			else:
				bf.phase_label.text = "BATTLEPLAN PHASE"
				bf.next_phase_button.text = "Choose Battleplan"
		bf.BattlePhase.TRIBUTE:
			bf.phase_label.text = "TRIBUTE PHASE"
			bf.next_phase_button.text = "Tribute in Progress"
		bf.BattlePhase.DEPLOYMENT:
			bf.phase_label.text = "DEPLOYMENT PHASE"
			bf.next_phase_button.text = (
				"Proceed to Combat Phase" if bf.player_passed_deployment else "Pass Deployment"
			)
		bf.BattlePhase.COMBAT:
			bf.phase_label.text = "COMBAT PHASE"
			bf.next_phase_button.text = ""

	bf.update_phase_instruction_ui()
	bf.update_turn_counter_ui()
	bf.update_phase_progress_state()
	bf.refresh_bottom_hud()


func update_phase_progress_state() -> void:
	if bf.next_phase_button == null:
		return
	var ready := bf.is_current_phase_complete()
	bf.next_phase_button.disabled = not ready
	bf.set_phase_button_ready_visual(ready)
	bf.refresh_bottom_hud()


func is_current_phase_complete() -> bool:
	if bf.phase_transition_busy or bf.is_prebattle_modal_open() or bf.hand_drag_preview != null:
		return false
	match bf.current_phase:
		bf.BattlePhase.BATTLEPLAN:
			return false
		bf.BattlePhase.TRIBUTE:
			return false
		bf.BattlePhase.DEPLOYMENT:
			return true
		bf.BattlePhase.COMBAT:
			return (
				bf.combat_direction_selected
				and bf.combat_next_lane_index >= bf.combat_lane_order.size()
				and not bf.combat_resolution_running
				and not bf.parry_system.active
			)
	return false


func try_auto_advance_combat_phase() -> void:
	if bf.game_over or bf.current_phase != bf.BattlePhase.COMBAT:
		return
	if bf.is_current_phase_complete():
		bf.start_next_round()


func is_prebattle_modal_open() -> bool:
	return (
		(bf.deck_selection_screen != null and bf.deck_selection_screen.visible)
		or (bf.battle_plan_selection_screen != null and bf.battle_plan_selection_screen.visible)
		or bf.waiting_for_battle_plan
		or bf.insight_presentation_active
		or bf.opening_hand_deal_active
		or bf.phase_title_interaction_locked
	)


func player_has_remaining_deployment_move() -> bool:
	if bf.hand == null or bf.tribute_manager == null or bf.board_slots == null:
		return false
	var available_tp := bf.tribute_manager.current_tribute_points
	for card_ui in bf.hand.cards:
		if card_ui == null or card_ui.card_data == null:
			continue
		var card_data: CardData = card_ui.card_data
		var card_type := bf.get_clean_card_type(card_data)
		for slot in bf.board_slots.get_children():
			if String(slot.get_meta("owner", "")) != "player":
				continue
			var occupied := bool(slot.get_meta("occupied", false))
			var row := String(slot.get_meta("row", ""))
			if card_type == "equipment":
				if (
					occupied
					and slot.has_method("can_attach_equipment")
					and slot.can_attach_equipment()
					and card_data.tribute_cost <= available_tp
					and bf.player_card_passes_faction_gate(card_data, false)
				):
					return true
				if not occupied and row == "back":
					var equipment_shadowtax := bf.get_player_face_down_card_deployment_cost(card_data, true)
					if equipment_shadowtax <= available_tp:
						return true
				continue
			if occupied or (row != "front" and row != "back"):
				continue
			var can_skip_gate := bf.should_skip_player_faction_gate_for_slot(card_data, slot)
			if not can_skip_gate and not bf.player_card_passes_faction_gate(card_data, false):
				continue
			var face_down := row == "back" and (bf.is_unit_card(card_data) or bf.is_gambit_card(card_data))
			var cost := bf.get_player_face_down_card_deployment_cost(card_data, face_down)
			if cost <= available_tp:
				return true
	return false


func set_phase_button_ready_visual(ready: bool) -> void:
	if bf.phase_button_ready_visual == ready:
		return
	bf.phase_button_ready_visual = ready
	if not ready:
		bf.next_phase_button.remove_theme_stylebox_override("normal")
		bf.next_phase_button.remove_theme_color_override("font_color")
		return
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(0.48, 0.29, 0.045, 0.98)
	glow.border_color = Color(1.0, 0.82, 0.24, 1.0)
	glow.set_border_width_all(3)
	glow.set_corner_radius_all(7)
	glow.shadow_color = Color(1.0, 0.62, 0.08, 0.72)
	glow.shadow_size = 12
	bf.next_phase_button.add_theme_stylebox_override("normal", glow)
	bf.next_phase_button.add_theme_color_override("font_color", Color(1.0, 0.96, 0.72, 1.0))


func update_phase_instruction_ui() -> void:
	if bf.phase_instruction_label == null:
		return

	bf.phase_instruction_label.text = bf.get_phase_instruction_text()


func get_phase_instruction_text() -> String:
	if bf.parry_system.active:
		return (
			"PARRY ACTIVE
"
			+ "Drop hand cards into the glowing Parry Pit.
"
			+ "Add enough DP to reach the target.
"
			+ "Or press Let Unit Die."
		)

	match bf.current_phase:
		bf.BattlePhase.BATTLEPLAN:
			if bf.pending_battleplan_draws > 0:
				return (
					"Physically drag "
					+ str(bf.pending_battleplan_draws)
					+ " awarded card(s) from Draw Pile into your hand."
				)
			if bf.battleplan_hand_cleanup_active and bf.hand != null:
				return (
					"Discard "
					+ str(maxi(bf.hand.cards.size() - bf.hand.max_hand_size, 0))
					+ " card(s) into the Discard Pile.  Time: "
					+ str(int(ceil(bf.battleplan_discard_time_left)))
					+ "s"
				)
			return (
				"Choose 1 Battle Plan.
"
				+ "Initiative decides who acts first.
"
				+ "Plans can affect draw, hand size, and rewards."
			)

		bf.BattlePhase.TRIBUTE:
			if bf.tribute_manager != null and bf.tribute_manager.tribute_card_used_this_turn:
				return "Tribute offered. Deployment will begin automatically."

			return (
				"Drag exactly 1 card from hand to Tribute.
"
				+ "Units/Equipment: +1 permanent TP.
"
				+ "Gambits: +2 temporary TP this turn."
			)

		bf.BattlePhase.DEPLOYMENT:
			if bf.player_passed_deployment:
				return (
					"Your Deployment has been passed.\n"
					+ "Press Proceed to Combat Phase when ready."
				)
			return (
				"Drag cards to glowing valid slots.
"
				+ "Face-down cards use Shadowtax.
"
				+ "Face-up race cards require Faction Gate.
"
				+ "Equipment attaches to face-up units.
"
				+ "Deploy while useful, or pass Deployment at any time."
			)

		bf.BattlePhase.COMBAT:
			if bf.combat_direction_selected and bf.combat_next_lane_index >= bf.combat_lane_order.size():
				return "All combat lanes are resolved."

			if not bf.combat_direction_selected:
				if bf.player_has_initiative:
					return (
						"Right-click the leftmost or rightmost lane.
"
						+ "Choose Attack, Check, or Pass.
"
						+ "This sets combat direction."
					)

				return (
					"AI has initiative.
"
					+ "AI chooses direction and acts first.
"
					+ "Wait for the active lane."
				)

			var lane: String = bf.current_combat_lane()

			if lane == "":
				lane = bf.active_combat_lane

			if bf.combat_priority_owner == "player":
				return (
					"Right-click the glowing "
					+ lane.capitalize()
					+ " lane.
"
					+ "Choose Attack, Check, or Pass.
"
					+ "Resolve hidden back row before Monarch Strike."
				)

			if bf.combat_priority_owner == "ai":
				return (
					"AI has priority in the "
					+ lane.capitalize()
					+ " lane.
"
					+ "Wait for AI to attack, check, or pass."
				)

			return (
				"Combat is ready.
"
				+ "Right-click the glowing lane.
"
				+ "Choose Attack, Check, or Pass."
			)

	return ""


func _on_next_phase_pressed() -> void:
	if bf.is_prebattle_modal_open() or not bf.is_current_phase_complete():
		return
	if bf.next_phase_button != null and bf.next_phase_button.disabled:
		return

	match bf.current_phase:
		bf.BattlePhase.BATTLEPLAN:
			bf.open_battle_plan_selection()

		bf.BattlePhase.TRIBUTE:
			bf.set_phase(bf.BattlePhase.DEPLOYMENT)

		bf.BattlePhase.DEPLOYMENT:
			if not bf.player_passed_deployment:
				bf.player_passed_deployment = true
				bf.log_msg("Player passed Deployment.")
				bf.cancel_selected_card()
				bf.update_slot_highlights()
				if not bf.ai_deployed_this_deployment_phase:
					if bf.player_has_initiative:
						bf.log_msg("AI now takes its Deployment turn.")
					else:
						bf.log_msg("Resolving the AI Deployment turn.")
					await bf.run_ai_deployment_turn_if_needed()
			bf.battleplan_objective_controller.capture_deployment_end()
			bf.set_phase(bf.BattlePhase.COMBAT)

func start_next_round() -> void:
	bf.phase_transition_busy = true
	bf.clear_active_combat_lane_highlight()
	if bf.parry_system.active:
		bf.log_msg("Resolve the parry prompt before ending combat.")
		bf.phase_transition_busy = false
		return
	bf.battleplan_objective_controller.resolve_end_of_round()
	bf.reset_face_down_gambit_setup_counters()
	bf.queue_surviving_stealth_deployments()
	await bf.resolve_pending_stealth_deployments()

	bf.resolve_dominance_before_cleanup()
	bf.cleanup_battlefield_spells()

	if bf.tribute_manager != null:
		bf.tribute_manager.start_new_turn_refresh()
		bf.update_tribute_counter()

	if bf.battle_plan_manager != null:
		bf.battle_plan_manager.advance_round()

	bf.turn_number += 1
	bf.used_active_insight_ability_keys.clear()
	bf.used_active_control_ability_keys.clear()
	bf.used_mobility_ability_keys.clear()
	bf.control_disabled_lane_turns.clear()
	bf.control_no_parry_turns.clear()
	bf.control_handicap_turns.clear()
	bf.update_turn_counter_ui()
	bf.cancel_selected_card()
	bf.phase_transition_busy = false
	bf.open_battle_plan_selection()


func resolve_pending_stealth_deployments() -> void:
	for pending in bf.pending_stealth_deployments.duplicate():
		var back_slot := pending.get("slot") as Node
		var card_data := pending.get("card") as CardData
		var lane := String(pending.get("lane", ""))
		if back_slot == null or card_data == null or bf.get_slot_card_data(back_slot) != card_data:
			continue
		back_slot.reveal_card()
		back_slot.set_meta("stealth_pending", false)
		var front_slot := bf.find_slot_by_owner_row_lane("player", "front", lane)
		if front_slot == null or bf.get_slot_card_data(front_slot) != null:
			continue
		bf.stealth_deployment_selection_slot = back_slot
		bf.insight_presentation_active = true
		back_slot.call("set_insight_highlight", true, Color(0.72, 0.24, 1.0, 1.0))
		bf.show_phase_title("DEPLOY " + card_data.card_name.to_upper() + " FOR FREE")
		await bf.stealth_deployment_slot_chosen
		back_slot.call("set_insight_highlight", false, Color.WHITE)
		bf.stealth_deployment_selection_slot = null
		bf.insight_presentation_active = false
		if bf.get_slot_card_data(back_slot) == card_data and bf.get_slot_card_data(front_slot) == null:
			back_slot.clear_slot()
			front_slot.call("place_card", bf.TEST_CARD_SCENE, card_data, false)
	bf.pending_stealth_deployments.clear()


func queue_surviving_stealth_deployments() -> void:
	if bf.board_slots == null:
		return
	for slot in bf.board_slots.get_children():
		if String(slot.get_meta("owner", "")) != "player" or String(slot.get_meta("row", "")) != "back":
			continue
		if not bool(slot.get_meta("face_down", false)):
			continue
		var card_data := bf.get_slot_card_data(slot)
		if card_data == null or bf.get_card_insight_ability(card_data, &"stealth") == null:
			continue
		var already_pending := false
		for pending in bf.pending_stealth_deployments:
			if pending.get("slot") == slot:
				already_pending = true
				break
		if not already_pending:
			bf.pending_stealth_deployments.append({
				"slot": slot,
				"card": card_data,
				"lane": bf.get_slot_lane(slot),
			})


func try_auto_advance_tribute_phase() -> void:
	if bf.current_phase != bf.BattlePhase.TRIBUTE:
		return
	if bf.tribute_manager == null or not bf.tribute_manager.tribute_card_used_this_turn:
		return
	if not bf.ai_tribute_finished_this_turn:
		return
	bf.set_phase(bf.BattlePhase.DEPLOYMENT)


func get_battle_plan_key(plan: Dictionary) -> String:
	if plan.is_empty():
		return ""

	if plan.has("id"):
		return str(plan.get("id", "")).strip_edges()

	if plan.has("battle_plan_id"):
		return str(plan.get("battle_plan_id", "")).strip_edges()

	if plan.has("plan_id"):
		return str(plan.get("plan_id", "")).strip_edges()

	return str(plan.get("name", "Unknown Battle Plan")).strip_edges()


func is_battle_plan_used(plan: Dictionary) -> bool:
	var key: String = bf.get_battle_plan_key(plan)

	if key == "":
		return false

	return bf.used_battle_plan_keys.has(key)


func mark_battle_plan_used(plan: Dictionary) -> void:
	var key: String = bf.get_battle_plan_key(plan)

	if key == "":
		return

	bf.used_battle_plan_keys[key] = true


func get_unused_battle_plan_choices(amount: int) -> Array[Dictionary]:
	var final_choices: Array[Dictionary] = []

	if bf.battle_plan_manager == null:
		return final_choices

	if amount <= 0:
		return final_choices

	var resource_choices: Array[Dictionary] = []
	var fallback_choices: Array[Dictionary] = []
	for plan in bf.battle_plan_manager.get_all_battle_plans():
		var key := bf.get_battle_plan_key(plan)
		if key.is_empty() or bf.used_battle_plan_keys.has(key):
			continue
		if plan.get("card_art", null) is Texture2D:
			resource_choices.append(plan)
		else:
			fallback_choices.append(plan)

	resource_choices.shuffle()
	fallback_choices.shuffle()
	resource_choices.append_array(fallback_choices)
	for plan in resource_choices:
		final_choices.append(plan)
		if final_choices.size() >= amount:
			break

	return final_choices


func resolve_dominance_before_cleanup() -> void:
	if bf.current_phase != bf.BattlePhase.COMBAT:
		return

	var checked_lanes: Array[String] = ["left", "right"]
	var player_has_dominance: bool = false
	var ai_has_dominance: bool = false

	for lane in checked_lanes:
		var player_ap: int = bf.get_front_lane_ap_total("player", lane)
		var ai_ap: int = bf.get_front_lane_ap_total("enemy", lane)

		if player_ap > ai_ap:
			player_has_dominance = true
			bf.log_msg(lane.capitalize() + " lane Dominance: Player AP " + str(player_ap) + " vs AI AP " + str(ai_ap) + ".")
		elif ai_ap > player_ap:
			ai_has_dominance = true
			bf.log_msg(lane.capitalize() + " lane Dominance: AI AP " + str(ai_ap) + " vs Player AP " + str(player_ap) + ".")
		else:
			bf.log_msg(lane.capitalize() + " lane Dominance: tied at " + str(player_ap) + " AP. No Aurion gained.")

	if player_has_dominance:
		bf.add_aurion("player", 1, "Dominance: controlled at least one side lane this turn.")

	if ai_has_dominance:
		bf.add_aurion("ai", 1, "Dominance: controlled at least one side lane this turn.")

	if player_has_dominance or ai_has_dominance:
		bf.log_msg("Dominance resolved. Each side can gain at most +1 Aurion from Dominance this turn.")
	else:
		bf.log_msg("Dominance resolved. No side-lane advantage gained.")


func get_front_lane_ap_total(owner_name: String, lane: String) -> int:
	var slot: Node = bf.find_slot_by_owner_row_lane(owner_name, "front", lane)
	return bf.get_slot_combat_ap(slot)
