class_name BattlefieldManagerPhase3CombatMenu
extends "res://battlefield/BattlefieldManagerPhase2BoardMenu.gd"

const BOARD_ACTION_ATTACK: int = 2


func show_board_slot_action_menu(slot: Node) -> void:
	if slot == null:
		return

	if board_action_menu == null:
		create_board_slot_action_menu()

	board_action_target_slot = slot
	board_action_menu.clear()

	var lane: String = get_slot_lane(slot)
	var card_data: CardData = get_slot_card_data(slot)
	var attack_added: bool = false

	if current_phase == BattlePhase.COMBAT:
		if can_player_attack_lane_from_menu(lane):
			board_action_menu.add_item("Attack", BOARD_ACTION_ATTACK)
			attack_added = true
		else:
			board_action_menu.add_item("Attack", BOARD_ACTION_CANCEL)
			var attack_item_index: int = board_action_menu.get_item_count() - 1
			board_action_menu.set_item_disabled(attack_item_index, true)

	if card_data != null:
		board_action_menu.add_item("Inspect", BOARD_ACTION_INSPECT)
	else:
		if not attack_added:
			board_action_menu.add_item("Empty Slot", BOARD_ACTION_CANCEL)
			var empty_item_index: int = board_action_menu.get_item_count() - 1
			board_action_menu.set_item_disabled(empty_item_index, true)

	board_action_menu.add_separator()
	board_action_menu.add_item("Cancel", BOARD_ACTION_CANCEL)

	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	board_action_menu.position = Vector2i(int(mouse_position.x), int(mouse_position.y))
	board_action_menu.popup()


func _on_board_slot_action_selected(action_id: int) -> void:
	match action_id:
		BOARD_ACTION_ATTACK:
			attack_from_board_action_menu(board_action_target_slot)
		BOARD_ACTION_INSPECT:
			inspect_board_slot(board_action_target_slot)
		BOARD_ACTION_CANCEL:
			pass

	board_action_target_slot = null

	if board_action_menu != null:
		board_action_menu.hide()


func can_player_attack_lane_from_menu(lane: String) -> bool:
	if current_phase != BattlePhase.COMBAT:
		return false

	if parry_active:
		return false

	if not player_has_initiative:
		return false

	if lane == "":
		return false

	if not combat_direction_selected:
		if lane != "left" and lane != "right":
			return false
	else:
		if combat_next_lane_index >= combat_lane_order.size():
			return false

		var expected_lane: String = combat_lane_order[combat_next_lane_index]

		if lane != expected_lane:
			return false

	var player_front_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)
	var player_card: CardData = get_slot_card_data(player_front_slot)

	return is_unit_card(player_card)


func attack_from_board_action_menu(slot: Node) -> void:
	if slot == null:
		return

	if current_phase != BattlePhase.COMBAT:
		log_msg("Attack is only available during Combat.")
		return

	if parry_active:
		log_msg("Resolve the current parry prompt first.")
		return

	if not player_has_initiative:
		log_msg("AI has initiative this combat. You cannot attack from the menu yet.")
		return

	var lane: String = get_slot_lane(slot)

	if lane == "":
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
		log_msg("All combat lanes are already resolved.")
		return

	var expected_lane: String = combat_lane_order[combat_next_lane_index]

	if lane != expected_lane:
		log_msg("Next combat must resolve in the " + expected_lane + " lane.")
		return

	var player_front_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)
	var enemy_front_slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)
	var enemy_back_slot: Node = find_slot_by_owner_row_lane("enemy", "back", lane)

	var player_card: CardData = get_slot_card_data(player_front_slot)

	if not is_unit_card(player_card):
		log_msg(lane.capitalize() + " lane: you have no front-row unit to attack with.")
		return

	var enemy_front_card: CardData = get_slot_card_data(enemy_front_slot)
	var enemy_back_card: CardData = get_slot_card_data(enemy_back_slot)
	var enemy_front_has_card: bool = enemy_front_card != null
	var enemy_back_has_card: bool = enemy_back_card != null

	if not enemy_front_has_card and not enemy_back_has_card:
		resolve_monarch_strike(lane, player_card)
		advance_combat_lane_after_resolution()
		return

	if enemy_front_has_card:
		resolve_next_combat_lane(lane)
		return

	log_msg(lane.capitalize() + " lane: enemy back row is occupied. Check system comes in the next phase.")


func resolve_monarch_strike(lane: String, attacker_card: CardData) -> void:
	if attacker_card == null:
		return

	add_aurion("player", 1, "Monarch Strike through the " + lane + " lane by " + attacker_card.card_name + ".")
	log_msg(lane.capitalize() + " lane: Monarch Strike successful.")
