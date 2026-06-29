class_name BattlefieldInteractionController
extends RefCounted

## Domain controller extracted from BattlefieldManager. The manager facade preserves
## scene callbacks and dynamic-call compatibility.

var bf: BattlefieldManager


func _init(owner_battlefield: BattlefieldManager) -> void:
	bf = owner_battlefield


func _on_hand_card_drag_started(card: CardUI) -> void:
	if bf.waiting_for_battle_plan or card == null:
		return
	bf.select_card(card.card_data)
	bf.start_hand_drag_preview(card)


func _on_hand_card_drag_released(card: CardUI, screen_position: Vector2) -> void:
	bf.finish_hand_drag_preview()
	if card == null:
		bf.cancel_selected_card()
		return

	if not is_instance_valid(card):
		bf.cancel_selected_card()
		return
	card.visible = bf.player_hand_3d == null

	if bf.selected_card_data == null and card.card_data != null:
		bf.select_card(card.card_data)

	var dragged_card_data: CardData = bf.selected_card_data

	var target_node: Node = bf.get_3d_node_under_screen_position(screen_position)
	var target_slot: Node = bf.find_board_slot_from_node(target_node)

	if bf.parry_system.active:
		if bf.parry_system.is_node_in_pit(target_node):
			await bf.parry_system.sacrifice_card(card)
			return

		bf.log_msg("Drop cards into the glowing pit to parry, or press Let Unit Die.")
		bf.return_card_to_hand_safely(card)
		bf.cancel_selected_card()
		return

	if bf.battleplan_hand_cleanup_active:
		if bf.is_node_inside_target(target_node, bf.discard_pile):
			if dragged_card_data != null and bf.discard_pile != null:
				card.visible = false
				await bf.play_player_hand_to_node_animation(dragged_card_data, bf.discard_pile, false)
				bf.discard_pile.add_card(dragged_card_data)
				bf.hand.consume_dragged_card(card)
				bf.log_msg("Card discarded to meet the Battle Plan hand limit.")
			bf.cancel_selected_card()
			if bf.hand.cards.size() <= bf.hand.max_hand_size:
				bf.finish_battleplan_prephase()
			else:
				bf.update_phase_ui()
			return
		bf.log_msg("During hand cleanup, drop excess cards into the Discard Pile.")
		bf.return_card_to_hand_safely(card)
		bf.cancel_selected_card()
		return

	if bf.is_node_inside_target(target_node, bf.tribute_pile):
		if bf.current_phase != bf.BattlePhase.TRIBUTE:
			bf.log_msg("Cards can only be sent to Tribute during the Tribute Phase.")
			bf.return_card_to_hand_safely(card)
			bf.cancel_selected_card()
			return

		if card != null and is_instance_valid(card):
			card.visible = false

		await bf.play_player_hand_to_node_animation(dragged_card_data, bf.tribute_pile, false)

		var sacrificed: bool = bf.try_sacrifice_selected_card_to_tribute()

		if sacrificed:
			if bf.hand != null:
				bf.hand.consume_dragged_card(card)
		else:
			if card != null and is_instance_valid(card):
				card.visible = bf.player_hand_3d == null

			bf.return_card_to_hand_safely(card)

		bf.cancel_selected_card()
		return

	if target_slot != null:
		if bf.current_phase != bf.BattlePhase.DEPLOYMENT:
			bf.log_msg("Cards can only be deployed during the Deployment Phase.")
			bf.return_card_to_hand_safely(card)
			bf.cancel_selected_card()
			return
		if bf.player_passed_deployment:
			bf.log_msg("Deployment has already been passed. Proceed to Combat Phase.")
			bf.return_card_to_hand_safely(card)
			bf.cancel_selected_card()
			return

		var card_type: String = bf.get_clean_card_type(bf.selected_card_data)

		if bf.can_promote_selected_card_on_slot(target_slot):
			if card != null and is_instance_valid(card):
				card.visible = false

			await bf.play_player_hand_to_node_animation(dragged_card_data, target_slot, false)

			var promoted: bool = bf.try_promote_selected_card_on_slot(target_slot)

			if promoted:
				if bf.hand != null:
					bf.hand.consume_dragged_card(card)
			else:
				if card != null and is_instance_valid(card):
					card.visible = bf.player_hand_3d == null

				bf.return_card_to_hand_safely(card)

			bf.cancel_selected_card()
			return

		if card_type == "equipment" and not bf.can_place_selected_equipment_face_down(target_slot):
			if card != null and is_instance_valid(card):
				card.visible = false

			await bf.play_player_hand_to_node_animation(dragged_card_data, target_slot, false)

			var attached: bool = bf.try_attach_selected_equipment_to_slot(target_slot)

			if attached:
				if bf.hand != null:
					bf.hand.consume_dragged_card(card)
			else:
				if card != null and is_instance_valid(card):
					card.visible = bf.player_hand_3d == null

				bf.return_card_to_hand_safely(card)

			bf.cancel_selected_card()
			return

		if bf.is_gambit_card(bf.selected_card_data):
			if String(target_slot.get_meta("owner", "")) != "player":
				bf.log_msg("Spells can only be placed on your side of the board.")
				bf.return_card_to_hand_safely(card)
				bf.cancel_selected_card()
				return

			if bool(target_slot.get_meta("occupied", false)):
				bf.log_msg("That slot is already occupied.")
				bf.return_card_to_hand_safely(card)
				bf.cancel_selected_card()
				return

			var target_row: String = String(target_slot.get_meta("row", ""))

			if target_row == "front":
				if card != null and is_instance_valid(card):
					card.visible = false

				await bf.play_player_hand_to_node_animation(dragged_card_data, target_slot, false)

				var front_spell_placed: bool = bf.try_place_selected_card_on_slot(target_slot)

				if front_spell_placed:
					if bf.hand != null:
						bf.hand.consume_dragged_card(card)
				else:
					if card != null and is_instance_valid(card):
						card.visible = bf.player_hand_3d == null

					bf.return_card_to_hand_safely(card)

				bf.cancel_selected_card()
				return

			if target_row == "back":
				bf.return_card_to_hand_safely(card)
				bf.show_spell_choice_panel(card, target_slot)
				return

			bf.log_msg("Invalid spell placement row.")
			bf.return_card_to_hand_safely(card)
			bf.cancel_selected_card()
			return

		var place_face_down: bool = false
		var slot_row: String = String(target_slot.get_meta("row", ""))

		if (bf.is_unit_card(bf.selected_card_data) or bf.is_equipment_card(bf.selected_card_data)) and slot_row == "back":
			place_face_down = true

		if card != null and is_instance_valid(card):
			card.visible = false

		await bf.play_player_hand_to_node_animation(dragged_card_data, target_slot, place_face_down)

		var placed: bool = bf.try_place_selected_card_on_slot(target_slot)

		if placed:
			if bf.hand != null:
				bf.hand.consume_dragged_card(card)
		else:
			if card != null and is_instance_valid(card):
				card.visible = bf.player_hand_3d == null

			bf.return_card_to_hand_safely(card)

		bf.cancel_selected_card()
		return

	if bf.hand != null and bf.hand.has_method("is_screen_position_in_hand_reorder_zone"):
		if bf.hand.hand_is_raised and bf.hand.is_screen_position_in_hand_reorder_zone(screen_position):
			if bf.hand.has_method("reorder_card_in_hand"):
				bf.hand.reorder_card_in_hand(card, screen_position.x)

			bf.return_card_to_hand_safely(card)
			bf.cancel_selected_card()
			return

	bf.log_msg("Card dropped nowhere valid.")
	bf.return_card_to_hand_safely(card)
	bf.cancel_selected_card()


func start_hand_drag_preview(card: CardUI) -> void:
	bf.finish_hand_drag_preview()
	if card == null or card.card_data == null:
		return
	bf.hand_drag_preview = bf.TEST_CARD_SCENE.instantiate() as Node3D
	bf.hand_was_auto_lowered_for_drag = false
	if bf.bottom_hud_3d != null:
		bf.bottom_hud_3d.set_card_drag_active(true)
	bf.add_child(bf.hand_drag_preview)
	bf.hand_drag_preview.top_level = true
	if bf.hand_drag_preview.has_method("assign_card_data"):
		bf.hand_drag_preview.assign_card_data(card.card_data, false)
	bf.disable_preview_collision(bf.hand_drag_preview)
	bf.hand_drag_preview_target_scale = Vector3(1.12, 1.12, 1.12)
	if bf.player_hand_3d != null:
		bf.hand_drag_preview.global_position = bf.player_hand_3d.get_card_global_position(card)
		bf.hand_drag_preview.global_rotation = bf.player_hand_3d.get_card_global_rotation(card)
		bf.hand_drag_preview.scale = bf.player_hand_3d.get_card_global_scale(card)
		bf.player_hand_3d.hide_card_for_action(card)
	else:
		bf.hand_drag_preview.scale = Vector3(0.92, 0.92, 0.92)
		bf.hand_drag_preview.rotation = Vector3.ZERO
		bf.hand_drag_preview.global_position = bf.screen_to_battle_plane(
			bf.get_viewport().get_mouse_position(),
			0.62
		)
	bf.hand_drag_preview_target_position = bf.hand_drag_preview.global_position
	card.visible = false
	Cursors.use_grab()


func update_hand_drag_preview(delta: float) -> void:
	if bf.hand_drag_preview == null or not is_instance_valid(bf.hand_drag_preview):
		return
	var screen_position := bf.get_viewport().get_mouse_position()
	# Pull the rest of the hand out of the battlefield view once a held card
	# leaves the hand region. It stays sheathed until Space is pressed again.
	if bf.hand != null and bf.hand.hand_is_raised and not bf.hand_was_auto_lowered_for_drag:
		if not bf.hand.is_screen_position_in_hand_reorder_zone(screen_position):
			bf.hand.lower_hand()
			bf.hand_was_auto_lowered_for_drag = true
	var target_node := bf.get_3d_node_under_screen_position(screen_position)
	var target_slot := bf.find_board_slot_from_node(target_node)
	bf.hand_drag_preview_target_scale = Vector3(1.12, 1.12, 1.12)
	if target_slot != null and bf.current_phase == bf.BattlePhase.DEPLOYMENT:
		var card_point := target_slot.get_node_or_null("CardPoint") as Node3D
		bf.hand_drag_preview_target_position = (
			card_point.global_position if card_point != null else (target_slot as Node3D).global_position
		) + Vector3(0.0, 0.48, 0.0)
		bf.hand_drag_preview_target_scale = Vector3(1.18, 1.18, 1.18)
	elif bf.battleplan_hand_cleanup_active and bf.is_node_inside_target(target_node, bf.discard_pile):
		bf.hand_drag_preview_target_position = bf.discard_pile.global_position + Vector3(0.0, 0.52, 0.0)
		bf.hand_drag_preview_target_scale = Vector3(1.18, 1.18, 1.18)
	elif bf.is_node_inside_target(target_node, bf.tribute_pile) and bf.current_phase == bf.BattlePhase.TRIBUTE:
		bf.hand_drag_preview_target_position = bf.tribute_pile.global_position + Vector3(0.0, 0.52, 0.0)
		bf.hand_drag_preview_target_scale = Vector3(1.18, 1.18, 1.18)
	else:
		var table_position := bf.screen_to_battle_plane(screen_position, 0.62)
		var camera := bf.get_viewport().get_camera_3d()
		if camera != null:
			var toward_camera := (camera.global_position - table_position).normalized()
			bf.hand_drag_preview_target_position = table_position + toward_camera * 0.42
		else:
			bf.hand_drag_preview_target_position = table_position
	bf.hand_drag_preview.global_position = bf.hand_drag_preview.global_position.lerp(
		bf.hand_drag_preview_target_position,
		clampf(delta * 16.0, 0.0, 1.0)
	)
	bf.hand_drag_preview.scale = bf.hand_drag_preview.scale.lerp(
		bf.hand_drag_preview_target_scale,
		clampf(delta * 11.0, 0.0, 1.0)
	)
	bf.hand_drag_preview.rotation = bf.hand_drag_preview.rotation.lerp(
		Vector3.ZERO,
		clampf(delta * 12.0, 0.0, 1.0)
	)


func finish_hand_drag_preview() -> void:
	if bf.hand_drag_preview != null and is_instance_valid(bf.hand_drag_preview):
		bf.last_player_hand_animation_start = bf.hand_drag_preview.global_position
		bf.has_player_hand_animation_start = true
		bf.hand_drag_preview.queue_free()
	bf.hand_drag_preview = null
	bf.hand_was_auto_lowered_for_drag = false
	if bf.bottom_hud_3d != null:
		bf.bottom_hud_3d.set_card_drag_active(false)
	Cursors.use_normal()


func disable_preview_collision(node: Node) -> void:
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	for child in node.get_children():
		bf.disable_preview_collision(child)


func screen_to_battle_plane(screen_position: Vector2, plane_y: float) -> Vector3:
	var camera := bf.get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return origin
	var distance := (plane_y - origin.y) / direction.y
	return origin + direction * distance


func deal_starting_hand() -> void:
	if bf.hand == null or bf.player_deck == null:
		bf.log_msg("Hand or PlayerDeck is missing.")
		return
	bf.opening_hand_deal_active = true
	# Keep the destination visible while the cards travel into the fan.
	# Starting with a lowered hand made the real card vanish below the viewport
	# immediately after the old temporary animation reached its anchor.
	bf.hand.raise_hand()
	var deal_origin := bf.draw_pile.global_position + Vector3(0.0, 0.10, 0.0) if bf.draw_pile != null else Vector3.ZERO
	for i in range(3):
		var drawn_card: CardData = bf.player_deck.draw_top_card()
		if drawn_card == null:
			break
		# Spawn the persistent hand visual at the deck. BattlefieldHand3D then
		# carries that same object into the fan, avoiding the old temporary-card
		# handoff and its visible one-frame snap at the hand anchor.
		if bf.player_hand_3d != null and bf.draw_pile != null:
			bf.player_hand_3d.queue_next_card_spawn(deal_origin + Vector3(0.0, float(i) * 0.012, 0.0))
		bf.hand.add_card_to_hand(drawn_card, false)
		if bf.draw_pile != null:
			bf.draw_pile.set_card_count(bf.player_deck.cards_remaining())
		await bf.get_tree().create_timer(0.34).timeout
	# Let the last card complete its glide before restoring interaction.
	await bf.get_tree().create_timer(0.78).timeout
	bf.opening_hand_deal_active = false
	if bf.draw_pile != null:
		bf.draw_pile.set_card_count(bf.player_deck.cards_remaining())
	bf.log_msg("Starting hand of 3 cards dealt. Deck remaining: " + str(bf.player_deck.cards_remaining()))


func _on_draw_pile_drag_started(screen_position: Vector2) -> void:
	if bf.is_prebattle_modal_open():
		return
	var is_awarded_draw := bf.current_phase == bf.BattlePhase.BATTLEPLAN and bf.pending_battleplan_draws > 0
	if bf.current_phase == bf.BattlePhase.BATTLEPLAN and not is_awarded_draw:
		return
	if bf.current_phase == bf.BattlePhase.DEPLOYMENT or bf.current_phase == bf.BattlePhase.COMBAT:
		bf.log_msg("You cannot draw cards after Deployment has begun.")
		return
	if bf.hand == null or bf.player_deck == null:
		return
	if not is_awarded_draw and not bf.hand.can_accept_card():
		bf.log_msg("Hand is full. Max hand size: " + str(bf.hand.max_hand_size))
		return
	var preview_card: CardData = bf.player_deck.peek_top_card()
	var started: bool = bf.hand.start_draw_pile_drag(screen_position, preview_card, is_awarded_draw)
	if started:
		if bf.bottom_hud_3d != null:
			bf.bottom_hud_3d.set_card_drag_active(true)
		if bf.player_hand_3d != null and bf.draw_pile != null:
			if bf.hand.draw_drag_card != null:
				bf.hand.draw_drag_card.visible = false
			bf.player_hand_3d.start_draw_preview(preview_card, bf.draw_pile)
			bf.player_hand_3d.update_draw_preview_target(screen_position)
		bf.log_msg("Dragging card from Draw Pile.")
	else:
		bf.log_msg("Draw Pile is empty.")


func _on_draw_pile_drag_moved(screen_position: Vector2) -> void:
	if bf.hand != null:
		bf.hand.update_draw_pile_drag(screen_position)
	if bf.player_hand_3d != null:
		bf.player_hand_3d.update_draw_preview_target(screen_position)


func _on_draw_pile_drag_released(screen_position: Vector2) -> void:
	if bf.bottom_hud_3d != null:
		bf.bottom_hud_3d.set_card_drag_active(false)
	if bf.hand == null or bf.player_deck == null:
		return
	if not bf.hand.is_screen_position_in_hand_drop_zone(screen_position):
		bf.hand.finish_draw_pile_drag(screen_position, null)
		if bf.player_hand_3d != null:
			bf.player_hand_3d.cancel_draw_preview(true)
		return
	var is_awarded_draw := bf.current_phase == bf.BattlePhase.BATTLEPLAN and bf.pending_battleplan_draws > 0
	if not is_awarded_draw and not bf.hand.can_accept_card():
		bf.hand.finish_draw_pile_drag(screen_position, null)
		if bf.player_hand_3d != null:
			bf.player_hand_3d.cancel_draw_preview(true)
		bf.log_msg("Draw cancelled. Hand is full. Max hand size: " + str(bf.hand.max_hand_size))
		return
	var drawn_card: CardData = bf.player_deck.draw_top_card()
	var accepted: bool = bf.hand.finish_draw_pile_drag(screen_position, drawn_card, is_awarded_draw)
	if accepted:
		if bf.player_hand_3d != null:
			bf.player_hand_3d.finish_draw_preview_into_hand(bf.hand.last_drawn_card)
		bf.draw_pile.consume_top_card()
		bf.log_msg("Card drawn into hand. Deck remaining: " + str(bf.player_deck.cards_remaining()))
		if is_awarded_draw:
			bf.pending_battleplan_draws = maxi(bf.pending_battleplan_draws - 1, 0)
			bf.update_phase_ui()
			if bf.pending_battleplan_draws <= 0:
				bf.begin_battleplan_hand_cleanup_or_tribute()
	else:
		if bf.player_hand_3d != null:
			bf.player_hand_3d.cancel_draw_preview(true)


func _on_equipment_inspect_requested(slot: Node, equipment_card: CardData) -> void:
	if bf.is_prebattle_modal_open() or bf.game_over:
		return

	if equipment_card == null:
		return

	var slot_owner := String(slot.get_meta("owner", ""))
	var slot_face_down := bool(slot.get_meta("face_down", false))

	if slot_owner == "enemy" and slot_face_down:
		bf.log_msg("Enemy face-down equipment remains hidden.")
		return

	var inspect_panel: CardInspectPanel = bf.get_card_inspect_panel()

	if inspect_panel == null:
		bf.log_msg("CardInspectPanel is missing.")
		return

	var source_position := bf.get_viewport().get_mouse_position()
	inspect_panel.last_source_rect = Rect2(source_position, Vector2(90.0, 120.0))
	inspect_panel.show_card(null, equipment_card)

	bf.log_msg("Inspecting equipment: " + equipment_card.card_name)


func _on_slot_clicked(slot: Node) -> void:
	if bf.mobility_selection_active:
		if bf.mobility_candidate_slots.has(slot):
			bf.mobility_slot_chosen.emit(slot)
		return
	if bf.stealth_deployment_selection_slot != null:
		if slot == bf.stealth_deployment_selection_slot:
			bf.stealth_deployment_slot_chosen.emit(slot)
		return
	if bf.insight_gambit_selection_active:
		if bf.insight_gambit_candidate_slots.has(slot):
			bf.insight_gambit_slot_chosen.emit(slot)
		return
	if bf.is_prebattle_modal_open():
		return
	if bf.current_phase == bf.BattlePhase.COMBAT:
		# Combat must never auto-resolve from a normal slot click.
		# Right-click menu actions are the only valid player combat actions.
		# This prevents empty lanes from being skipped by accidental click events
		# after resolving Attack / Check from the board action menu.
		var lane: String = bf.get_slot_lane(slot)
		if lane != "":
			bf.log_msg("Combat action ready in the " + lane + " lane. Right-click and choose Attack, Check, or Pass.")
		else:
			bf.log_msg("Combat actions use the right-click menu.")
		return
	if bf.current_phase != bf.BattlePhase.DEPLOYMENT:
		bf.log_msg("Cards can only be deployed during the Deployment Phase.")
		return
	if bf.player_passed_deployment:
		bf.log_msg("Deployment has already been passed. Proceed to Combat Phase.")
		return
	var placed := bf.try_place_selected_card_on_slot(slot)
	if placed:
		if bf.hand != null:
			bf.hand.remove_selected_card()
		bf.cancel_selected_card()


func _on_slot_right_clicked(slot: Node) -> void:
	if bf.is_prebattle_modal_open():
		return
	bf.show_board_slot_action_menu(slot)


func _on_tribute_pile_clicked() -> void:
	if bf.is_prebattle_modal_open():
		return
	if bf.current_phase != bf.BattlePhase.TRIBUTE:
		bf.log_msg("Tribute pile is only active during the Tribute Phase.")
		return
	if not bf.has_selected_card:
		bf.log_msg("Drag a card from your hand to the Tribute Pile.")
		return
	var sacrificed := bf.try_sacrifice_selected_card_to_tribute()
	if sacrificed:
		if bf.hand != null:
			bf.hand.remove_selected_card()
		bf.cancel_selected_card()


func debug_draw_card() -> void:
	if bf.current_phase == bf.BattlePhase.DEPLOYMENT or bf.current_phase == bf.BattlePhase.COMBAT:
		bf.log_msg("You cannot draw cards after Deployment has begun.")
		return
	if bf.player_deck == null or not bf.hand.can_accept_card():
		return
	var drawn_card: CardData = bf.player_deck.draw_top_card()
	if drawn_card == null:
		return
	bf.hand.add_card_to_hand(drawn_card)
	if bf.draw_pile != null:
		bf.draw_pile.consume_top_card()


func debug_tribute_selected_card() -> void:
	if bf.selected_card_data == null:
		return

	if bf.try_sacrifice_selected_card_to_tribute():
		bf.log_msg("Debug tribute: " + bf.selected_card_data.card_name + ". " + bf.tribute_manager.get_status_text())


func get_3d_node_under_screen_position(screen_position: Vector2) -> Node:
	var camera := bf.get_viewport().get_camera_3d()
	if camera == null:
		return null
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result := bf.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	return result.get("collider", null)


func find_board_slot_from_node(node: Node) -> Node:
	var current := node
	while current != null:
		if current.has_method("place_card") and current.has_meta("slot_id"):
			return current
		current = current.get_parent()
	return null


func is_node_inside_target(node: Node, target: Node) -> bool:
	if node == null or target == null:
		return false
	var current := node
	while current != null:
		if current == target:
			return true
		current = current.get_parent()
	return false
