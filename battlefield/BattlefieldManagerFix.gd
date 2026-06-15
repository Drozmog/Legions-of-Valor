extends "res://battlefield/BattlefieldManagerPhase2.gd"


func _on_hand_card_drag_released(card: CardUI, screen_position: Vector2) -> void:
	var target_node := get_3d_node_under_screen_position(screen_position)
	var target_slot := find_board_slot_from_node(target_node)

	# Equipment often gets dropped on top of the visible card mesh instead of the slot collider.
	# This fallback finds the nearest valid occupied front-row unit and attaches the equipment there.
	if target_slot == null and selected_card_data != null and get_clean_card_type(selected_card_data) == "equipment":
		target_slot = find_equipment_target_slot_from_screen_position(screen_position)

	if target_slot != null:
		if current_phase != BattlePhase.DEPLOYMENT:
			log_msg("Cards can only be deployed during the Deployment Phase.")
			hand.return_dragged_card_to_hand(card)
			cancel_selected_card()
			return

		var placed := try_place_selected_card_on_slot(target_slot)

		if placed:
			hand.consume_dragged_card(card)
		else:
			hand.return_dragged_card_to_hand(card)

		cancel_selected_card()
		return

	if is_node_inside_target(target_node, tribute_pile):
		if current_phase != BattlePhase.TRIBUTE:
			log_msg("Cards can only be sent to Tribute during the Tribute Phase.")
			hand.return_dragged_card_to_hand(card)
			cancel_selected_card()
			return

		var sacrificed := try_sacrifice_selected_card_to_tribute()

		if sacrificed:
			hand.consume_dragged_card(card)
		else:
			hand.return_dragged_card_to_hand(card)

		cancel_selected_card()
		return

	log_msg("Card dropped nowhere valid.")
	hand.return_dragged_card_to_hand(card)
	cancel_selected_card()


func find_equipment_target_slot_from_screen_position(screen_position: Vector2) -> Node:
	if board_slots == null:
		return null

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null

	var best_slot: Node = null
	var best_distance := 999999.0
	var max_distance := 240.0

	for slot in board_slots.get_children():
		if slot.get_meta("owner", "") != "player":
			continue

		if slot.get_meta("row", "") != "front":
			continue

		if not slot.occupied:
			continue

		if not is_unit_card(get_slot_card_data(slot)):
			continue

		if slot.has_method("can_attach_equipment") and not slot.can_attach_equipment():
			continue

		var slot_screen_position := camera.unproject_position(slot.global_position)
		var distance := slot_screen_position.distance_to(screen_position)

		if distance < best_distance:
			best_distance = distance
			best_slot = slot

	if best_distance <= max_distance:
		return best_slot

	return null


func _on_slot_right_clicked(_slot: Node) -> void:
	log_msg("Manual battlefield clearing is disabled. Cards leave the board only through combat, cleanup, or abilities.")
