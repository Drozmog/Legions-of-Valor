class_name PhaseShared
extends "res://battlefield/BattlefieldManagerPhase35CombatReadability.gd"

const BOARD_ACTION_CHECK: int = 3
const BLUFF_REVEAL_DELAY: float = 0.30

var enemy_fortified_lanes: Dictionary = {}


func reset_combat_state() -> void:
	super.reset_combat_state()
	enemy_fortified_lanes.clear()


func show_board_slot_action_menu(slot: Node) -> void:
	if slot == null:
		return

	if board_action_menu == null:
		create_board_slot_action_menu()

	board_action_target_slot = slot
	board_action_menu.clear()

	var lane: String = get_slot_lane(slot)
	var card_data: CardData = get_slot_card_data(slot)
	var can_act: bool = can_player_attack_lane_from_menu(lane)
	var enemy_back_slot: Node = find_slot_by_owner_row_lane("enemy", "back", lane)
	var enemy_back_card: CardData = get_slot_card_data(enemy_back_slot)
	var has_hidden_back: bool = enemy_back_card != null and bool(enemy_back_slot.get_meta("face_down", false))
	var added_action: bool = false

	if current_phase == BattlePhase.COMBAT:
		board_action_menu.add_item("Attack", BOARD_ACTION_ATTACK)
		var attack_index: int = board_action_menu.get_item_count() - 1
		if can_act:
			added_action = true
		else:
			board_action_menu.set_item_disabled(attack_index, true)

		if has_hidden_back:
			board_action_menu.add_item("Check", BOARD_ACTION_CHECK)
			var check_index: int = board_action_menu.get_item_count() - 1
			if can_act:
				added_action = true
			else:
				board_action_menu.set_item_disabled(check_index, true)

	if card_data != null:
		board_action_menu.add_item("Inspect", BOARD_ACTION_INSPECT)
	elif not added_action:
		board_action_menu.add_item("Empty Slot", BOARD_ACTION_CANCEL)
		var empty_index: int = board_action_menu.get_item_count() - 1
		board_action_menu.set_item_disabled(empty_index, true)

	board_action_menu.add_separator()
	board_action_menu.add_item("Cancel", BOARD_ACTION_CANCEL)

	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	board_action_menu.position = Vector2i(int(mouse_position.x), int(mouse_position.y))
	board_action_menu.popup()


func _on_board_slot_action_selected(action_id: int) -> void:
	match action_id:
		BOARD_ACTION_ATTACK:
			await attack_from_board_action_menu(board_action_target_slot)
		BOARD_ACTION_CHECK:
			await check_from_board_action_menu(board_action_target_slot)
		BOARD_ACTION_INSPECT:
			inspect_board_slot(board_action_target_slot)
		BOARD_ACTION_CANCEL:
			pass

	board_action_target_slot = null

	if board_action_menu != null:
		board_action_menu.hide()


func check_from_board_action_menu(slot: Node) -> void:
	if combat_resolution_running:
		log_msg("Combat is already resolving. Wait for the current lane.")
		return

	if slot == null:
		return

	if current_phase != BattlePhase.COMBAT:
		log_msg("Check is only available during Combat.")
		return

	if parry_active:
		log_msg("Resolve the current parry prompt first.")
		return

	if not player_has_initiative:
		log_msg("AI has initiative this combat. You cannot check from the menu yet.")
		return

	var lane: String = get_slot_lane(slot)
	if lane == "":
		return

	await call("resolve_player_check_lane_with_visuals", lane)


func return_setup_card(slot: Node, card_data: CardData, owner_name: String) -> void:
	if slot == null or card_data == null:
		return

	if slot.has_method("clear_slot"):
		slot.clear_slot()

	if owner_name == "enemy":
		ai_hand.append(card_data)
		update_ai_visuals()
		return

	if hand != null:
		hand.add_card_to_hand(card_data)
