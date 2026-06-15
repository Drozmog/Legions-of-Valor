extends "res://battlefield/BattlefieldManagerPhase.gd"

var combat_command_panel: CombatCommandPanel = null
var parry_prompt_panel: ParryPromptPanel = null
var pending_defeated_slot: Node = null


func _ready() -> void:
	super._ready()
	create_combat_command_panel()
	create_parry_prompt_panel()


func create_combat_command_panel() -> void:
	combat_command_panel = CombatCommandPanel.new()
	combat_command_panel.combat_command_selected.connect(_on_combat_command_selected)
	$UI.add_child(combat_command_panel)


func create_parry_prompt_panel() -> void:
	parry_prompt_panel = ParryPromptPanel.new()
	parry_prompt_panel.parry_resolved.connect(_on_parry_resolved)
	$UI.add_child(parry_prompt_panel)


func begin_combat_phase() -> void:
	reset_combat_state()
	resolve_start_of_combat_spells()

	if player_has_initiative:
		log_msg("Phase: Combat. Player has first action.")
	else:
		log_msg("Phase: Combat. Opponent has first action. Prototype opponent will commit when you choose a lane.")


func start_next_round() -> void:
	cleanup_remaining_back_row_spells()
	super.start_next_round()


func is_valid_slot_for_selected_card(slot: Node) -> bool:
	if current_phase != BattlePhase.DEPLOYMENT:
		return false

	if not has_selected_card or selected_card_data == null:
		return false

	if slot.get_meta("owner", "") != "player":
		return false

	var card_type := get_clean_card_type(selected_card_data)
	var slot_row: String = slot.get_meta("row", "")
	var lane := get_slot_lane(slot)

	if card_type == "unit":
		return slot_row == "front" and not slot.occupied

	if card_type == "equipment":
		if slot_row != "front":
			return false
		if not slot.occupied:
			return false
		if not is_unit_card(slot.get_placed_card_data()):
			return false
		if slot.has_method("can_attach_equipment"):
			return slot.can_attach_equipment()
		return false

	if is_spell_like_type(card_type):
		if slot_row != "back":
			return false
		if slot.occupied:
			return false
		return lane_has_front_unit("player", lane)

	return false


func try_place_selected_card_on_slot(slot: Node) -> bool:
	if slot == null:
		return false

	if not has_selected_card or selected_card_data == null:
		log_msg("No card selected.")
		return false

	if not is_valid_slot_for_selected_card(slot):
		log_msg("Invalid placement for " + selected_card_data.card_name + " on " + str(slot.get_meta("slot_id", "")))
		return false

	if not tribute_manager.can_afford(selected_card_data.tribute_cost):
		log_msg("Not enough Tribute Points. Need " + str(selected_card_data.tribute_cost) + ", have " + str(tribute_manager.current_tribute_points) + ".")
		return false

	var card_type := get_clean_card_type(selected_card_data)
	var placed_successfully := false

	if card_type == "equipment":
		placed_successfully = slot.attach_equipment(selected_card_scene, selected_card_data)
	else:
		var place_face_down := slot.get_meta("row", "") == "back"
		placed_successfully = slot.place_card(selected_card_scene, selected_card_data, place_face_down)

	if placed_successfully:
		tribute_manager.spend_tribute(selected_card_data.tribute_cost)
		log_msg("Spent " + str(selected_card_data.tribute_cost) + " TP. " + tribute_manager.get_status_text())
		handle_card_deployed(selected_card_data)
		return true

	return false


func handle_combat_lane_click(slot: Node) -> void:
	var lane: String = get_slot_lane(slot)

	if lane == "":
		log_msg("Could not detect combat lane.")
		return

	if not combat_direction_selected:
		if lane == "left":
			set_combat_lane_order_from_left()
		elif lane == "right":
			set_combat_lane_order_from_right()
		else:
			log_msg("Choose the leftmost or rightmost lane first to set combat direction.")
			return

	if combat_next_lane_index >= combat_lane_order.size():
		log_msg("All combat lanes have already been resolved.")
		return

	var expected_lane: String = combat_lane_order[combat_next_lane_index]

	if lane != expected_lane:
		log_msg("Next combat must resolve in the " + expected_lane + " lane.")
		return

	if player_has_initiative:
		open_player_combat_command(lane)
	else:
		log_msg("Prototype opponent commits in the " + lane.capitalize() + " lane.")
		resolve_combat_command("commit", lane, false)


func open_player_combat_command(lane: String) -> void:
	if combat_command_panel == null:
		resolve_combat_command("commit", lane, true)
		return

	combat_command_panel.show_for_lane(lane, "Player")


func _on_combat_command_selected(command: String, lane: String) -> void:
	resolve_combat_command(command, lane, true)


func resolve_combat_command(command: String, lane: String, player_is_active: bool) -> void:
	match command:
		"pass":
			log_msg(lane.capitalize() + " lane: " + get_side_label(player_is_active) + " passes.")
			advance_combat_lane()
		"commit":
			resolve_commit_strike(lane, player_is_active)
		"cautious":
			resolve_cautious_strike(lane, player_is_active)


func resolve_commit_strike(lane: String, player_is_attacker: bool) -> void:
	var attacker_owner := "player" if player_is_attacker else "enemy"
	var defender_owner := "enemy" if player_is_attacker else "player"
	var attacker_slot := find_slot_by_owner_row_lane(attacker_owner, "front", lane)
	var defender_slot := find_slot_by_owner_row_lane(defender_owner, "front", lane)
	var defender_back_slot := find_slot_by_owner_row_lane(defender_owner, "back", lane)
	var attacker_card := get_slot_card_data(attacker_slot)

	if attacker_card == null:
		log_msg(lane.capitalize() + " lane: no attacking unit. Lane ends.")
		advance_combat_lane()
		return

	if defender_back_slot != null and defender_back_slot.occupied:
		var hidden_card := get_slot_card_data(defender_back_slot)

		if is_trap_card(hidden_card):
			log_msg("Commit Strike hits a Trap in the " + lane.capitalize() + " lane. Trap effect placeholder resolves, then the Trap is discarded.")
			send_back_row_card_to_discard(defender_back_slot)
			advance_combat_lane()
			return

		if is_ruse_card(hidden_card):
			log_msg("Commit Strike called the bluff in the " + lane.capitalize() + " lane. Ruse is discarded. Attacker gains +1 Aurion placeholder.")
			send_back_row_card_to_discard(defender_back_slot)

	var defender_card := get_slot_card_data(defender_slot)

	if defender_card == null:
		log_msg(attacker_card.card_name + " lands a Monarch Strike in the " + lane.capitalize() + " lane. Aurion scoring placeholder.")
		advance_combat_lane()
		return

	resolve_unit_attack(lane, attacker_slot, attacker_card, defender_slot, defender_card, player_is_attacker)


func resolve_cautious_strike(lane: String, player_is_attacker: bool) -> void:
	var defender_owner := "enemy" if player_is_attacker else "player"
	var defender_back_slot := find_slot_by_owner_row_lane(defender_owner, "back", lane)

	if defender_back_slot == null or not defender_back_slot.occupied:
		log_msg("Cautious Strike finds no hidden card in the " + lane.capitalize() + " lane. Choose another command.")
		if player_is_attacker:
			open_player_combat_command(lane)
		else:
			resolve_commit_strike(lane, false)
		return

	var hidden_card := get_slot_card_data(defender_back_slot)

	if is_trap_card(hidden_card):
		log_msg("Cautious Strike catches a Trap in the " + lane.capitalize() + " lane. Trap is discarded. Attacker gains +1 Aurion placeholder.")
		send_back_row_card_to_discard(defender_back_slot)
		if player_is_attacker:
			open_player_combat_command(lane)
		else:
			resolve_commit_strike(lane, false)
		return

	log_msg("Cautious Strike was baited by a Ruse in the " + lane.capitalize() + " lane. Defender gains +1 Aurion placeholder. Lane ends.")
	if defender_owner == "player" and hand != null and hand.can_accept_card():
		hand.add_card_to_hand(hidden_card)
		defender_back_slot.clear_slot()
	else:
		send_back_row_card_to_discard(defender_back_slot)
	advance_combat_lane()


func resolve_unit_attack(lane: String, attacker_slot: Node, attacker_card: CardData, defender_slot: Node, defender_card: CardData, player_is_attacker: bool) -> void:
	var attacker_label := get_side_label(player_is_attacker)
	var defender_label := get_side_label(not player_is_attacker)
	log_msg(lane.capitalize() + " lane: " + attacker_label + " " + attacker_card.card_name + " AP " + str(attacker_card.ap) + " attacks " + defender_label + " " + defender_card.card_name + " AP " + str(defender_card.ap) + ".")

	if attacker_card.ap <= defender_card.ap:
		log_msg(defender_card.card_name + " holds the line. No unit is destroyed.")
		advance_combat_lane()
		return

	if not player_is_attacker:
		prompt_player_parry(attacker_card, defender_card, defender_slot)
		return

	log_msg(defender_card.card_name + " is overpowered and removed from the board.")
	send_slot_card_to_discard(defender_slot)
	advance_combat_lane()


func prompt_player_parry(attacker_card: CardData, defender_card: CardData, defender_slot: Node) -> void:
	pending_defeated_slot = defender_slot

	if parry_prompt_panel == null or hand == null:
		send_slot_card_to_discard(defender_slot)
		advance_combat_lane()
		return

	parry_prompt_panel.show_prompt(attacker_card, defender_card, defender_slot, get_hand_card_data_list())


func _on_parry_resolved(saved: bool, discarded_cards: Array[CardData], defender_slot: Node) -> void:
	if saved:
		discard_hand_cards(discarded_cards)
		log_msg("Parry Chain succeeded. Unit survives.")
	else:
		log_msg("Parry declined. Unit falls.")
		send_slot_card_to_discard(defender_slot)

	pending_defeated_slot = null
	advance_combat_lane()


func advance_combat_lane() -> void:
	combat_next_lane_index += 1

	if combat_next_lane_index >= combat_lane_order.size():
		log_msg("All combat lanes resolved. Press End Combat / Next Round when ready.")
	else:
		log_msg("Next combat lane: " + combat_lane_order[combat_next_lane_index].capitalize())


func resolve_start_of_combat_spells() -> void:
	if board_slots == null:
		return

	for slot in board_slots.get_children():
		if slot.get_meta("row", "") != "back":
			continue
		if not slot.occupied:
			continue

		var card_data := get_slot_card_data(slot)
		if card_data == null:
			continue

		if is_spell_card(card_data) and not is_trap_card(card_data) and not is_ruse_card(card_data):
			log_msg("Spell resolves at start of Combat: " + card_data.card_name)
			if card_data.ability_text != "":
				log_msg(card_data.ability_text)
			send_back_row_card_to_discard(slot)


func cleanup_remaining_back_row_spells() -> void:
	if board_slots == null:
		return

	for slot in board_slots.get_children():
		if slot.get_meta("row", "") != "back":
			continue
		if not slot.occupied:
			continue

		var card_data := get_slot_card_data(slot)
		if is_spell_card(card_data):
			log_msg("Combat cleanup discards spell: " + card_data.card_name)
			send_back_row_card_to_discard(slot)


func send_slot_card_to_discard(slot: Node) -> void:
	if slot == null:
		return

	var card_data: CardData = get_slot_card_data(slot)
	if discard_pile != null and card_data != null:
		discard_pile.add_card(card_data)

	if slot.has_method("get_equipment_cards") and discard_pile != null:
		for equipment_card in slot.get_equipment_cards():
			discard_pile.add_card(equipment_card)

	if slot.has_method("clear_slot"):
		slot.clear_slot()


func send_back_row_card_to_discard(slot: Node) -> void:
	var card_data: CardData = get_slot_card_data(slot)
	if discard_pile != null and card_data != null:
		discard_pile.add_card(card_data)
	if slot.has_method("clear_slot"):
		slot.clear_slot()


func _on_slot_right_clicked(slot: Node) -> void:
	var slot_id: String = slot.get_meta("slot_id", "")
	send_slot_card_to_discard(slot)
	log_msg("Cleared slot: " + str(slot_id))
	update_slot_highlights()


func get_hand_card_data_list() -> Array[CardData]:
	var result: Array[CardData] = []
	if hand == null:
		return result
	for card_ui in hand.cards:
		if card_ui != null and card_ui.card_data != null:
			result.append(card_ui.card_data)
	return result


func discard_hand_cards(card_datas: Array[CardData]) -> void:
	if hand == null:
		return
	for card_data in card_datas:
		for card_ui in hand.cards:
			if card_ui != null and card_ui.card_data == card_data:
				hand.cards.erase(card_ui)
				card_ui.queue_free()
				if discard_pile != null:
					discard_pile.add_card(card_data)
				break
	hand.arrange_fan()


func lane_has_front_unit(owner: String, lane: String) -> bool:
	var front_slot := find_slot_by_owner_row_lane(owner, "front", lane)
	return front_slot != null and front_slot.occupied and is_unit_card(get_slot_card_data(front_slot))


func is_unit_card(card_data: CardData) -> bool:
	return card_data != null and get_clean_card_type(card_data) == "unit"


func is_spell_card(card_data: CardData) -> bool:
	return card_data != null and is_spell_like_type(get_clean_card_type(card_data))


func is_spell_like_type(card_type: String) -> bool:
	return card_type == "spell" or card_type == "event" or card_type == "trap" or card_type == "ruse"


func is_trap_card(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var text := get_card_search_text(card_data)
	return text.contains("trap")


func is_ruse_card(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var text := get_card_search_text(card_data)
	return text.contains("ruse") or text.contains("bluff") or text.contains("fake")


func get_card_search_text(card_data: CardData) -> String:
	return (card_data.card_id + " " + card_data.card_name + " " + card_data.card_type + " " + card_data.ability_text + " " + card_data.lore_text).to_lower()


func get_clean_card_type(card_data: CardData) -> String:
	if card_data == null:
		return ""
	return card_data.card_type.to_lower().strip_edges()


func get_side_label(is_player_side: bool) -> String:
	return "Player" if is_player_side else "Opponent"
