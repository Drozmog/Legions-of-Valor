extends "res://battlefield/BattlefieldManagerPhase.gd"

const AI_DECK_SIZE: int = 40
const FACE_AUTO: int = -1
const FACE_UP: int = 0
const FACE_DOWN: int = 1

var game_mode: String = "practice"
var mode_selected: bool = false

var mode_panel: PanelContainer = null
var spell_panel: PanelContainer = null
var spell_label: Label = null
var pending_spell_card_ui: CardUI = null
var pending_spell_slot: Node = null
var pending_spell_from_click: bool = false

var guide_root: Node3D = null

var parry_panel: PanelContainer = null
var parry_label: Label = null
var parry_cards_box: VBoxContainer = null
var parry_required_dp: int = 0
var parry_current_dp: int = 0
var parry_cards: Array[CardData] = []
var parry_defender_slot: Node = null

var ai_panel: PanelContainer = null
var ai_label: Label = null
var ai_deck: Array[CardData] = []
var ai_hand: Array[CardData] = []
var ai_discard: Array[CardData] = []
var ai_tribute: Array[CardData] = []
var ai_perm_tp: int = 0
var ai_current_perm_tp: int = 0
var ai_temp_tp: int = 0
var ai_current_tp: int = 0
var ai_tribute_used: bool = false
var ai_starting_hand_done: bool = false


func _ready() -> void:
	randomize()
	connect_all_slots()
	connect_main_signals()
	create_phase_ui()
	create_ability_prompt_panel()
	create_debug_tp_button()
	create_mode_panel()
	create_spell_panel()
	create_parry_panel()
	create_ai_panel()
	set_phase(BattlePhase.BATTLEPLAN)
	show_mode_panel()


func show_mode_panel() -> void:
	waiting_for_battle_plan = true
	mode_selected = false
	if battle_plan_selection_screen != null:
		battle_plan_selection_screen.hide()
	if mode_panel != null:
		mode_panel.show()
	log_msg("Choose Practice Mode or Battle Against AI.")


func create_mode_panel() -> void:
	mode_panel = PanelContainer.new()
	mode_panel.name = "ModeSelectionPanel"
	mode_panel.anchor_left = 0.5
	mode_panel.anchor_right = 0.5
	mode_panel.anchor_top = 0.5
	mode_panel.anchor_bottom = 0.5
	mode_panel.offset_left = -280.0
	mode_panel.offset_right = 280.0
	mode_panel.offset_top = -145.0
	mode_panel.offset_bottom = 145.0
	mode_panel.z_index = 300
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.86)
	style.border_color = Color(0.9, 0.75, 0.35, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	mode_panel.add_theme_stylebox_override("panel", style)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	mode_panel.add_child(margin)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	var title: Label = Label.new()
	title.text = "SELECT GAME MODE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	var practice_button: Button = Button.new()
	practice_button.text = "Practice Mode / Admin Playtest"
	practice_button.pressed.connect(_on_mode_chosen.bind("practice"))
	vbox.add_child(practice_button)
	var ai_button: Button = Button.new()
	ai_button.text = "Battle Against AI"
	ai_button.pressed.connect(_on_mode_chosen.bind("ai"))
	vbox.add_child(ai_button)
	$UI.add_child(mode_panel)


func _on_mode_chosen(selected_mode: String) -> void:
	game_mode = selected_mode
	mode_selected = true
	if mode_panel != null:
		mode_panel.hide()
	if game_mode == "ai":
		setup_ai_match()
		log_msg("Mode selected: Battle Against AI.")
	else:
		log_msg("Mode selected: Practice Mode.")
	setup_battle_plan_flow()


func setup_ai_match() -> void:
	ai_deck.clear()
	ai_hand.clear()
	ai_discard.clear()
	ai_tribute.clear()
	ai_perm_tp = 0
	ai_current_perm_tp = 0
	ai_temp_tp = 0
	ai_current_tp = 0
	ai_tribute_used = false
	ai_starting_hand_done = false
	var pool: Array[CardData] = [ARCH_WIZARD_MAELCOR, IMPERIAL_ARCHIVE_MASTER, JENA_OF_YEL, IVAAN_BONE_CRUSHER, UPPER_HALL_PROSPECTOR, TEST_EQUIPMENT, TEST_SPELL]
	for i in range(AI_DECK_SIZE):
		ai_deck.append(pool[i % pool.size()])
	ai_deck.shuffle()
	update_ai_panel()


func create_ai_panel() -> void:
	ai_panel = PanelContainer.new()
	ai_panel.name = "AIStatusPanel"
	ai_panel.visible = false
	ai_panel.anchor_left = 0.0
	ai_panel.anchor_right = 0.0
	ai_panel.anchor_top = 0.0
	ai_panel.anchor_bottom = 0.0
	ai_panel.offset_left = 405.0
	ai_panel.offset_right = 790.0
	ai_panel.offset_top = 32.0
	ai_panel.offset_bottom = 260.0
	ai_panel.z_index = 40
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.58)
	style.border_color = Color(0.75, 0.25, 0.25, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	ai_panel.add_theme_stylebox_override("panel", style)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	ai_panel.add_child(margin)
	ai_label = Label.new()
	ai_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ai_label.add_theme_font_size_override("font_size", 13)
	margin.add_child(ai_label)
	$UI.add_child(ai_panel)


func update_ai_panel() -> void:
	if ai_panel == null or ai_label == null:
		return

	ai_panel.visible = game_mode == "ai"

	var names: Array[String] = []

	for card_data in ai_hand:
		var typed_card: CardData = card_data as CardData
		if typed_card != null:
			names.append(typed_card.card_name)

	var hand_text: String = ", ".join(names)

	if hand_text == "":
		hand_text = "Empty"

	ai_label.text = "AI STATUS\nDeck: " + str(ai_deck.size()) + "\nHand: " + str(ai_hand.size()) + "\nTP: " + str(ai_current_tp) + "/" + str(ai_perm_tp) + "  Temp +" + str(ai_temp_tp) + "\nTribute: " + str(ai_tribute.size()) + "\nDiscard: " + str(ai_discard.size()) + "\nVisible Hand:\n" + hand_text


func begin_game_after_battle_plan_selection() -> void:
	super.begin_game_after_battle_plan_selection()
	if game_mode == "ai" and not ai_starting_hand_done:
		ai_draw_cards(5)
		ai_starting_hand_done = true
		log_msg("AI starting hand dealt. AI deck remaining: " + str(ai_deck.size()))
		update_ai_panel()


func draw_battleplan_cards(plan: Dictionary) -> void:
	super.draw_battleplan_cards(plan)
	if game_mode != "ai":
		return
	var amount: int = int(opponent_battle_plan.get("draw_amount", plan.get("draw_amount", 0)))
	ai_draw_cards(amount)
	log_msg("AI battleplan draw: AI drew " + str(amount) + " cards.")
	update_ai_panel()


func set_phase(new_phase: int) -> void:
	if new_phase != BattlePhase.COMBAT:
		clear_attack_guides()
	super.set_phase(new_phase)
	if game_mode == "ai" and new_phase == BattlePhase.TRIBUTE:
		ai_start_turn_refresh()
		ai_offer_tribute()


func begin_deployment_phase() -> void:
	if game_mode != "ai":
		super.begin_deployment_phase()
		return
	log_msg("Phase: Deployment")
	if player_has_initiative:
		log_msg("Player has initiative. AI will deploy after player before Combat.")
	else:
		log_msg("AI has initiative and deploys first.")
		ai_deploy_turn()
		log_msg("AI deployment complete.")


func begin_combat_phase() -> void:
	resolve_face_up_spells()
	reset_combat_state()
	if game_mode == "ai" and player_has_initiative:
		ai_deploy_turn()
	show_attack_guides()
	if game_mode == "ai" and not player_has_initiative:
		log_msg("Phase: Combat. AI attacks first left-to-right.")
		set_combat_lane_order_from_left()
		ai_resolve_combat()
	else:
		log_msg("Phase: Combat. Click the leftmost or rightmost lane to choose attack direction.")


func _on_next_phase_pressed() -> void:
	match current_phase:
		BattlePhase.BATTLEPLAN:
			open_battle_plan_selection()
		BattlePhase.TRIBUTE:
			set_phase(BattlePhase.DEPLOYMENT)
		BattlePhase.DEPLOYMENT:
			if game_mode == "ai" and player_has_initiative:
				ai_deploy_turn()
			set_phase(BattlePhase.COMBAT)
		BattlePhase.COMBAT:
			start_next_round()


func start_next_round() -> void:
	cleanup_back_row_spells()
	clear_attack_guides()
	super.start_next_round()


func ai_draw_cards(amount: int) -> void:
	for i in range(amount):
		if ai_deck.is_empty():
			break
		var drawn_card: CardData = ai_deck.pop_back()
		ai_hand.append(drawn_card)
	update_ai_panel()


func ai_start_turn_refresh() -> void:
	ai_current_perm_tp = ai_perm_tp
	ai_temp_tp = 0
	ai_current_tp = ai_current_perm_tp
	ai_tribute_used = false
	update_ai_panel()


func ai_offer_tribute() -> void:
	if ai_tribute_used or ai_hand.is_empty():
		return
	var index: int = ai_choose_tribute_index()
	if index < 0:
		return
	var card_data: CardData = ai_hand.pop_at(index)
	ai_tribute.append(card_data)
	ai_tribute_used = true
	if is_spell_like_type(get_clean_card_type(card_data)):
		ai_temp_tp += 2
		ai_current_tp += 2
		log_msg("AI used " + card_data.card_name + " as Tribute: +2 temporary TP.")
	else:
		ai_perm_tp += 1
		ai_current_perm_tp += 1
		ai_current_tp += 1
		log_msg("AI used " + card_data.card_name + " as Tribute: +1 permanent TP.")
	update_ai_panel()


func ai_choose_tribute_index() -> int:
	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]
		if get_clean_card_type(card_data) == "unit":
			return i
	return 0


func ai_can_afford(cost: int) -> bool:
	return ai_current_tp >= cost


func ai_spend_tp(cost: int) -> bool:
	if not ai_can_afford(cost):
		return false
	var remaining: int = cost
	if ai_temp_tp > 0:
		var temp_spent: int = mini(ai_temp_tp, remaining)
		ai_temp_tp -= temp_spent
		ai_current_tp -= temp_spent
		remaining -= temp_spent
	if remaining > 0:
		ai_current_perm_tp -= remaining
		ai_current_tp -= remaining
	update_ai_panel()
	return true


func ai_deploy_turn() -> void:
	if game_mode != "ai":
		return
	var deployed: bool = true
	var safety: int = 0
	while deployed and safety < 8:
		safety += 1
		deployed = false
		if ai_try_attach_equipment():
			deployed = true
			continue
		if ai_try_deploy_unit():
			deployed = true
			continue
		if ai_try_deploy_spell():
			deployed = true
			continue
	update_ai_panel()


func ai_try_deploy_unit() -> bool:
	var slot: Node = ai_find_empty_front_slot()
	if slot == null:
		return false
	var chosen_index: int = -1
	var best_ap: int = -999
	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]
		if get_clean_card_type(card_data) != "unit":
			continue
		if not ai_can_afford(card_data.tribute_cost):
			continue
		if card_data.ap > best_ap:
			best_ap = card_data.ap
			chosen_index = i
	if chosen_index < 0:
		return false
	var play_card: CardData = ai_hand.pop_at(chosen_index)
	if slot.place_card(TEST_CARD_SCENE, play_card, false):
		ai_spend_tp(play_card.tribute_cost)
		log_msg("AI deployed unit: " + play_card.card_name)
		return true
	ai_hand.append(play_card)
	return false


func ai_try_attach_equipment() -> bool:
	var slot: Node = ai_find_equipment_target_slot()
	if slot == null:
		return false
	var chosen_index: int = -1
	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]
		if get_clean_card_type(card_data) == "equipment" and ai_can_afford(card_data.tribute_cost):
			chosen_index = i
			break
	if chosen_index < 0:
		return false
	var equipment_card: CardData = ai_hand.pop_at(chosen_index)
	if slot.has_method("attach_equipment") and slot.attach_equipment(TEST_CARD_SCENE, equipment_card):
		ai_spend_tp(equipment_card.tribute_cost)
		log_msg("AI attached equipment: " + equipment_card.card_name)
		return true
	ai_hand.append(equipment_card)
	return false


func ai_try_deploy_spell() -> bool:
	var slot: Node = ai_find_empty_back_slot_with_front_unit()
	if slot == null:
		return false
	var chosen_index: int = -1
	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]
		if not is_spell_like_type(get_clean_card_type(card_data)):
			continue
		if not ai_can_afford(card_data.tribute_cost):
			continue
		chosen_index = i
		break
	if chosen_index < 0:
		return false
	var spell_card: CardData = ai_hand.pop_at(chosen_index)
	if slot.place_card(TEST_CARD_SCENE, spell_card, true):
		ai_spend_tp(spell_card.tribute_cost)
		log_msg("AI placed a back-row card face down.")
		return true
	ai_hand.append(spell_card)
	return false


func ai_find_empty_front_slot() -> Node:
	for slot in board_slots.get_children():
		if String(slot.get_meta("owner", "")) == "enemy" and String(slot.get_meta("row", "")) == "front" and not slot.occupied:
			return slot
	return null


func ai_find_equipment_target_slot() -> Node:
	for slot in board_slots.get_children():
		if String(slot.get_meta("owner", "")) != "enemy":
			continue
		if String(slot.get_meta("row", "")) != "front":
			continue
		if not slot.occupied:
			continue
		if not is_unit_card(get_slot_card_data(slot)):
			continue
		if slot.has_method("can_attach_equipment") and slot.can_attach_equipment():
			return slot
	return null


func ai_find_empty_back_slot_with_front_unit() -> Node:
	for slot in board_slots.get_children():
		if String(slot.get_meta("owner", "")) != "enemy":
			continue
		if String(slot.get_meta("row", "")) != "back":
			continue
		if slot.occupied:
			continue
		var lane: String = get_slot_lane(slot)
		if lane_has_front_unit("enemy", lane):
			return slot
	return null


func _on_hand_card_drag_released(card: CardUI, screen_position: Vector2) -> void:
	var target_node: Node = get_3d_node_under_screen_position(screen_position)
	var target_slot: Node = find_board_slot_from_node(target_node)
	if target_slot == null and selected_card_data != null and get_clean_card_type(selected_card_data) == "equipment":
		target_slot = find_equipment_target_slot_from_screen_position(screen_position)
	if target_slot != null:
		if current_phase != BattlePhase.DEPLOYMENT:
			log_msg("Cards can only be deployed during the Deployment Phase.")
			hand.return_dragged_card_to_hand(card)
			cancel_selected_card()
			return
		if should_prompt_spell_visibility(target_slot):
			show_spell_choice(card, target_slot, false)
			return
		var placed: bool = try_place_selected_card_on_slot(target_slot)
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
		var sacrificed: bool = try_sacrifice_selected_card_to_tribute()
		if sacrificed:
			hand.consume_dragged_card(card)
		else:
			hand.return_dragged_card_to_hand(card)
		cancel_selected_card()
		return
	log_msg("Card dropped nowhere valid.")
	hand.return_dragged_card_to_hand(card)
	cancel_selected_card()


func _on_slot_clicked(slot: Node) -> void:
	if current_phase == BattlePhase.COMBAT:
		handle_combat_lane_click(slot)
		return
	if current_phase != BattlePhase.DEPLOYMENT:
		log_msg("Cards can only be deployed during the Deployment Phase.")
		return
	if should_prompt_spell_visibility(slot):
		show_spell_choice(null, slot, true)
		return
	var placed: bool = try_place_selected_card_on_slot(slot)
	if placed:
		if hand != null:
			hand.remove_selected_card()
		cancel_selected_card()


func should_prompt_spell_visibility(slot: Node) -> bool:
	if selected_card_data == null or slot == null:
		return false
	if String(slot.get_meta("row", "")) != "back":
		return false
	return is_spell_like_type(get_clean_card_type(selected_card_data))


func create_spell_panel() -> void:
	spell_panel = PanelContainer.new()
	spell_panel.name = "SpellVisibilityPanel"
	spell_panel.visible = false
	spell_panel.anchor_left = 0.5
	spell_panel.anchor_right = 0.5
	spell_panel.anchor_top = 0.5
	spell_panel.anchor_bottom = 0.5
	spell_panel.offset_left = -230.0
	spell_panel.offset_right = 230.0
	spell_panel.offset_top = -115.0
	spell_panel.offset_bottom = 115.0
	spell_panel.z_index = 260
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.84)
	style.border_color = Color(0.55, 0.35, 1.0, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	spell_panel.add_theme_stylebox_override("panel", style)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	spell_panel.add_child(margin)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	spell_label = Label.new()
	spell_label.text = "Place spell face up or face down?"
	spell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spell_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(spell_label)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	vbox.add_child(buttons)
	var up_button: Button = Button.new()
	up_button.text = "Face Up"
	up_button.pressed.connect(_on_spell_face_chosen.bind(false))
	buttons.add_child(up_button)
	var down_button: Button = Button.new()
	down_button.text = "Face Down"
	down_button.pressed.connect(_on_spell_face_chosen.bind(true))
	buttons.add_child(down_button)
	$UI.add_child(spell_panel)


func show_spell_choice(card_ui: CardUI, slot: Node, from_click: bool) -> void:
	pending_spell_card_ui = card_ui
	pending_spell_slot = slot
	pending_spell_from_click = from_click
	if spell_label != null and selected_card_data != null:
		spell_label.text = "Place " + selected_card_data.card_name + " face up or face down?"
	if spell_panel != null:
		spell_panel.show()


func _on_spell_face_chosen(face_down: bool) -> void:
	if spell_panel != null:
		spell_panel.hide()
	var face_mode: int = FACE_DOWN if face_down else FACE_UP
	var placed: bool = false
	if pending_spell_slot != null:
		placed = place_selected_card_on_slot(pending_spell_slot, face_mode)
	if pending_spell_card_ui != null:
		if placed:
			hand.consume_dragged_card(pending_spell_card_ui)
		else:
			hand.return_dragged_card_to_hand(pending_spell_card_ui)
	elif pending_spell_from_click and placed and hand != null:
		hand.remove_selected_card()
	pending_spell_card_ui = null
	pending_spell_slot = null
	pending_spell_from_click = false
	cancel_selected_card()


func find_equipment_target_slot_from_screen_position(screen_position: Vector2) -> Node:
	if board_slots == null:
		return null
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return null
	var best_slot: Node = null
	var best_distance: float = 999999.0
	var max_distance: float = 260.0
	for slot in board_slots.get_children():
		if String(slot.get_meta("owner", "")) != "player":
			continue
		if String(slot.get_meta("row", "")) != "front":
			continue
		if not slot.occupied:
			continue
		if not is_unit_card(get_slot_card_data(slot)):
			continue
		if slot.has_method("can_attach_equipment") and not slot.can_attach_equipment():
			continue
		var slot_screen: Vector2 = camera.unproject_position(slot.global_position)
		var distance: float = slot_screen.distance_to(screen_position)
		if distance < best_distance:
			best_distance = distance
			best_slot = slot
	if best_distance <= max_distance:
		return best_slot
	return null


func try_place_selected_card_on_slot(slot: Node) -> bool:
	return place_selected_card_on_slot(slot, FACE_AUTO)


func place_selected_card_on_slot(slot: Node, face_mode: int) -> bool:
	if slot == null:
		return false
	var slot_id: String = String(slot.get_meta("slot_id", ""))
	if not has_selected_card or selected_card_data == null:
		log_msg("No card selected.")
		return false
	if not is_valid_slot_for_selected_card(slot):
		log_msg("Invalid placement for " + selected_card_data.card_name + " on " + slot_id)
		return false
	if not tribute_manager.can_afford(selected_card_data.tribute_cost):
		log_msg("Not enough Tribute Points. Need " + str(selected_card_data.tribute_cost) + ", have " + str(tribute_manager.current_tribute_points) + ".")
		return false
	var card_type: String = get_clean_card_type(selected_card_data)
	var placed: bool = false
	if card_type == "equipment":
		if slot.has_method("attach_equipment"):
			placed = slot.attach_equipment(selected_card_scene, selected_card_data)
	else:
		var face_down: bool = false
		if face_mode == FACE_AUTO:
			face_down = String(slot.get_meta("row", "")) == "back"
		else:
			face_down = face_mode == FACE_DOWN
		placed = slot.place_card(selected_card_scene, selected_card_data, face_down)
	if placed:
		tribute_manager.spend_tribute(selected_card_data.tribute_cost)
		log_msg("Spent " + str(selected_card_data.tribute_cost) + " TP. " + tribute_manager.get_status_text())
		handle_card_deployed(selected_card_data)
		return true
	return false


func is_valid_slot_for_selected_card(slot: Node) -> bool:
	if current_phase != BattlePhase.DEPLOYMENT:
		return false
	if not has_selected_card or selected_card_data == null:
		return false
	if String(slot.get_meta("owner", "")) != "player":
		return false
	var card_type: String = get_clean_card_type(selected_card_data)
	var row: String = String(slot.get_meta("row", ""))
	var lane: String = get_slot_lane(slot)
	if card_type == "unit":
		if row == "front":
			return not slot.occupied
		if row == "back":
			return not slot.occupied and lane_has_front_unit("player", lane)
		return false
	if card_type == "equipment":
		if row != "front" or not slot.occupied:
			return false
		if not is_unit_card(get_slot_card_data(slot)):
			return false
		if slot.has_method("can_attach_equipment"):
			return slot.can_attach_equipment()
		return false
	if is_spell_like_type(card_type):
		if row != "back" or slot.occupied:
			return false
		return lane_has_front_unit("player", lane)
	return false


func _on_slot_right_clicked(_slot: Node) -> void:
	log_msg("Manual battlefield clearing is disabled. Cards leave the board only through combat, cleanup, or abilities.")


func resolve_face_up_spells() -> void:
	for slot in board_slots.get_children():
		if String(slot.get_meta("row", "")) != "back" or not slot.occupied:
			continue
		var card_data: CardData = get_slot_card_data(slot)
		if card_data == null:
			continue
		if not is_spell_like_type(get_clean_card_type(card_data)):
			continue
		var is_face_down: bool = bool(slot.get_meta("face_down", false))
		if is_face_down:
			continue
		log_msg("Face-up spell resolves first in Combat: " + card_data.card_name)
		if card_data.ability_text != "":
			log_msg(card_data.ability_text)
		send_back_card_to_owner_discard(slot)


func cleanup_back_row_spells() -> void:
	for slot in board_slots.get_children():
		if String(slot.get_meta("row", "")) != "back" or not slot.occupied:
			continue
		var card_data: CardData = get_slot_card_data(slot)
		if card_data != null and is_spell_like_type(get_clean_card_type(card_data)):
			log_msg("Combat cleanup discards spell: " + card_data.card_name)
			send_back_card_to_owner_discard(slot)


func send_back_card_to_owner_discard(slot: Node) -> void:
	var card_data: CardData = get_slot_card_data(slot)
	if card_data != null:
		if String(slot.get_meta("owner", "")) == "enemy" and game_mode == "ai":
			ai_discard.append(card_data)
		elif discard_pile != null:
			discard_pile.add_card(card_data)
	if slot.has_method("clear_slot"):
		slot.clear_slot()
	update_ai_panel()


func show_attack_guides() -> void:
	clear_attack_guides()
	guide_root = Node3D.new()
	guide_root.name = "AttackGuides"
	add_child(guide_root)
	for slot in board_slots.get_children():
		if String(slot.get_meta("row", "")) != "front" or not slot.occupied:
			continue
		var card_data: CardData = get_slot_card_data(slot)
		if card_data == null:
			continue
		var owner: String = String(slot.get_meta("owner", ""))
		var lane: String = get_slot_lane(slot)
		draw_guides_for_unit(slot, owner, lane, card_data)


func clear_attack_guides() -> void:
	if guide_root != null and is_instance_valid(guide_root):
		guide_root.queue_free()
	guide_root = null


func draw_guides_for_unit(source_slot: Node, owner: String, lane: String, card_data: CardData) -> void:
	var target_owner: String = "enemy" if owner == "player" else "player"
	var lanes: Array[String] = [lane]

	if card_has_volley(card_data):
		if lane == "left":
			lanes.append("middle")
		elif lane == "middle":
			lanes.append("left")
			lanes.append("right")
		elif lane == "right":
			lanes.append("middle")

	for target_lane in lanes:
		var typed_target_lane: String = str(target_lane)
		var target_slot: Node = find_slot_by_owner_row_lane(target_owner, "front", typed_target_lane)

		if target_slot == null:
			continue

		var diagonal: bool = typed_target_lane != lane

		draw_attack_arrow(
			source_slot.global_position + Vector3(0, 0.20, 0),
			target_slot.global_position + Vector3(0, 0.20, 0),
			diagonal
		)


func draw_attack_arrow(from_pos: Vector3, to_pos: Vector3, diagonal: bool) -> void:
	if guide_root == null:
		return
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from_pos)
	mesh.surface_add_vertex(to_pos)
	mesh.surface_end()
	var line: MeshInstance3D = MeshInstance3D.new()
	line.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if diagonal:
		mat.albedo_color = Color(0.45, 0.85, 1.0, 1.0)
	else:
		mat.albedo_color = Color(1.0, 0.82, 0.25, 1.0)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 1.7
	line.material_override = mat
	guide_root.add_child(line)
	var head: MeshInstance3D = MeshInstance3D.new()
	head.mesh = SphereMesh.new()
	head.scale = Vector3(0.075, 0.075, 0.075)
	head.position = to_pos
	head.material_override = mat
	guide_root.add_child(head)


func card_has_volley(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var text: String = (card_data.card_name + " " + card_data.ability_text + " " + str(card_data.ability_types)).to_lower()
	return text.contains("volley")


func resolve_directed_clash(lane: String, attacker_slot: Node, attacker_card: CardData, defender_slot: Node, defender_card: CardData, player_is_attacker: bool) -> void:
	var attacker_label: String = "Player" if player_is_attacker else "AI"
	var defender_label: String = "AI" if player_is_attacker else "Player"
	log_msg(lane.capitalize() + " lane attack: " + attacker_label + " " + attacker_card.card_name + " AP " + str(attacker_card.ap) + " attacks " + defender_label + " " + defender_card.card_name + " AP " + str(defender_card.ap) + ".")
	if attacker_card.ap <= defender_card.ap:
		log_msg(defender_card.card_name + " holds the lane. No unit is destroyed.")
		return
	if player_is_attacker:
		if game_mode == "ai" and ai_try_parry(attacker_card.ap):
			log_msg("AI parried with hand DP. " + defender_card.card_name + " survives.")
		else:
			log_msg(defender_card.card_name + " is destroyed.")
			send_slot_card_to_discard(defender_slot)
	else:
		show_parry_panel(attacker_card, defender_card, defender_slot)


func ai_resolve_combat() -> void:
	for lane_value in combat_lane_order:
		var lane: String = str(lane_value)

		var ai_slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)
		var player_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)

		var ai_card: CardData = get_slot_card_data(ai_slot)
		var player_card: CardData = get_slot_card_data(player_slot)

		if ai_card == null:
			log_msg("AI has no attacker in the " + lane.capitalize() + " lane.")
			continue

		if player_card == null:
			log_msg("AI lands a Monarch Strike in the " + lane.capitalize() + " lane. Aurion scoring placeholder.")
			continue

		resolve_directed_clash(lane, ai_slot, ai_card, player_slot, player_card, false)

	log_msg("AI combat complete. End Combat / Next Round when ready.")
	


func ai_try_parry(required_dp: int) -> bool:
	var chosen_indices: Array[int] = []
	var total_dp: int = 0
	while total_dp < required_dp:
		var best_index: int = -1
		var best_dp: int = 999
		for i in range(ai_hand.size()):
			if chosen_indices.has(i):
				continue
			var card_data: CardData = ai_hand[i]
			var card_dp: int = maxi(card_data.dp, 0)
			if card_dp > 0 and card_dp < best_dp:
				best_dp = card_dp
				best_index = i
		if best_index < 0:
			break
		chosen_indices.append(best_index)
		var chosen_card: CardData = ai_hand[best_index]
		total_dp += maxi(chosen_card.dp, 0)
	if total_dp < required_dp:
		return false
	chosen_indices.sort()
	chosen_indices.reverse()
	for index: int in chosen_indices:
		var discarded_card: CardData = ai_hand.pop_at(index)
		ai_discard.append(discarded_card)
		log_msg("AI parry discarded: " + discarded_card.card_name + " DP " + str(discarded_card.dp))
	update_ai_panel()
	return true


func create_parry_panel() -> void:
	parry_panel = PanelContainer.new()
	parry_panel.name = "ParryPanel"
	parry_panel.visible = false
	parry_panel.anchor_left = 0.5
	parry_panel.anchor_right = 0.5
	parry_panel.anchor_top = 0.5
	parry_panel.anchor_bottom = 0.5
	parry_panel.offset_left = -310.0
	parry_panel.offset_right = 310.0
	parry_panel.offset_top = -220.0
	parry_panel.offset_bottom = 220.0
	parry_panel.z_index = 270
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.86)
	style.border_color = Color(0.35, 0.55, 1.0, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	parry_panel.add_theme_stylebox_override("panel", style)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	parry_panel.add_child(margin)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title: Label = Label.new()
	title.text = "PARRY CHAIN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)
	parry_label = Label.new()
	parry_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(parry_label)
	parry_cards_box = VBoxContainer.new()
	parry_cards_box.add_theme_constant_override("separation", 5)
	vbox.add_child(parry_cards_box)
	var let_die_button: Button = Button.new()
	let_die_button.text = "Let Unit Fall"
	let_die_button.pressed.connect(_on_parry_let_die_pressed)
	vbox.add_child(let_die_button)
	$UI.add_child(parry_panel)


func show_parry_panel(attacker_card: CardData, defender_card: CardData, defender_slot: Node) -> void:
	parry_defender_slot = defender_slot
	parry_required_dp = attacker_card.ap
	parry_current_dp = 0
	parry_cards.clear()
	rebuild_parry_buttons()
	update_parry_label(defender_card)
	if parry_panel != null:
		parry_panel.show()


func rebuild_parry_buttons() -> void:
	for child in parry_cards_box.get_children():
		child.queue_free()
	if hand == null or hand.cards.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No hand cards available to parry with."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		parry_cards_box.add_child(empty_label)
		return
	for card_ui in hand.cards:
		if card_ui == null or card_ui.card_data == null:
			continue
		var button: Button = Button.new()
		button.text = card_ui.card_data.card_name + " | DP " + str(card_ui.card_data.dp)
		button.pressed.connect(_on_parry_card_clicked.bind(card_ui.card_data, button))
		parry_cards_box.add_child(button)


func update_parry_label(defender_card: CardData) -> void:
	if parry_label == null:
		return
	var defender_name: String = "Unit"
	if defender_card != null:
		defender_name = defender_card.card_name
	parry_label.text = defender_name + " is being attacked for AP " + str(parry_required_dp) + ".\nDiscard hand cards until total DP reaches " + str(parry_required_dp) + ".\nCurrent Parry DP: " + str(parry_current_dp)


func _on_parry_card_clicked(card_data: CardData, button: Button) -> void:
	if card_data == null or parry_cards.has(card_data):
		return
	parry_cards.append(card_data)
	parry_current_dp += maxi(card_data.dp, 0)
	button.disabled = true
	button.text += " [chosen]"
	update_parry_label(get_slot_card_data(parry_defender_slot))
	if parry_current_dp >= parry_required_dp:
		discard_player_hand_cards(parry_cards)
		log_msg("Parry Chain succeeded. Unit survives.")
		if parry_panel != null:
			parry_panel.hide()
		clear_parry_state()


func _on_parry_let_die_pressed() -> void:
	log_msg("Parry declined. Unit falls.")
	if parry_defender_slot != null:
		send_slot_card_to_discard(parry_defender_slot)
	if parry_panel != null:
		parry_panel.hide()
	clear_parry_state()


func clear_parry_state() -> void:
	parry_required_dp = 0
	parry_current_dp = 0
	parry_cards.clear()
	parry_defender_slot = null


func discard_player_hand_cards(cards_to_discard: Array[CardData]) -> void:
	if hand == null:
		return

	for card_data in cards_to_discard:
		var typed_card_data: CardData = card_data as CardData

		if typed_card_data == null:
			continue

		for card_ui in hand.cards:
			if card_ui != null and card_ui.card_data == typed_card_data:
				hand.cards.erase(card_ui)
				card_ui.queue_free()

				if discard_pile != null:
					discard_pile.add_card(typed_card_data)

				break

	hand.arrange_fan()


func send_slot_card_to_discard(slot: Node) -> void:
	if slot == null:
		return

	var card_data: CardData = get_slot_card_data(slot)

	if card_data != null:
		if String(slot.get_meta("owner", "")) == "enemy" and game_mode == "ai":
			ai_discard.append(card_data)
		elif discard_pile != null:
			discard_pile.add_card(card_data)

	if slot.has_method("get_equipment_cards"):
		var equipment_cards: Array[CardData] = slot.get_equipment_cards()

		for equipment_card in equipment_cards:
			var typed_equipment_card: CardData = equipment_card as CardData

			if typed_equipment_card == null:
				continue

			if String(slot.get_meta("owner", "")) == "enemy" and game_mode == "ai":
				ai_discard.append(typed_equipment_card)
			elif discard_pile != null:
				discard_pile.add_card(typed_equipment_card)

	if slot.has_method("clear_slot"):
		slot.clear_slot()

	update_ai_panel()
	show_attack_guides()


func lane_has_front_unit(owner: String, lane: String) -> bool:
	var front_slot: Node = find_slot_by_owner_row_lane(owner, "front", lane)
	return front_slot != null and front_slot.occupied and is_unit_card(get_slot_card_data(front_slot))


func is_unit_card(card_data: CardData) -> bool:
	return card_data != null and get_clean_card_type(card_data) == "unit"


func is_spell_like_type(card_type: String) -> bool:
	return card_type == "spell" or card_type == "event" or card_type == "trap" or card_type == "ruse"


func get_clean_card_type(card_data: CardData) -> String:
	if card_data == null:
		return ""
	return card_data.card_type.to_lower().strip_edges()
