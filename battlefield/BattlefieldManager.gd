class_name BattlefieldManager
extends BattlefieldManagerPhase

const AURION_WIN_TARGET: int = 25

var player_aurion_points: int = 0
var ai_aurion_points: int = 0

var aurion_panel: PanelContainer = null
var aurion_label: Label = null

var ai_deck: Array[CardData] = []
var ai_hand: Array[CardData] = []
var ai_discard: Array[CardData] = []
var ai_tribute: Array[CardData] = []
@export var ai_max_deployments_per_phase: int = 2

var ai_perm_tp: int = 0
var ai_current_perm_tp: int = 0
var ai_temp_tp: int = 0
var ai_current_tp: int = 0
var ai_tribute_used_this_turn: bool = false
var ai_has_starting_hand: bool = false

var pending_spell_card_ui: CardUI = null
var pending_spell_slot: Node = null
var spell_choice_panel: PanelContainer = null
var spell_choice_label: Label = null

var global_ability_icons_visible: bool = false

var parry_active: bool = false
var parry_lane: String = ""
var parry_attacker_slot: Node = null
var parry_attacker_card: CardData = null
var parry_defender_slot: Node = null
var parry_defender_card: CardData = null
var parry_required_dp: int = 0
var parry_gathered_dp: int = 0

var parry_pit_root: Node3D = null
var parry_pit_glow: Node3D = null
var parry_dp_counter: Node = null
var parry_pit_drop_area: Area3D = null
var parry_sacrifice_stack_root: Node3D = null
var parry_sacrifice_nodes: Array[Node3D] = []

var parry_prompt_panel: PanelContainer = null
var parry_prompt_label: Label = null
var parry_let_die_button: Button = null



func _ready() -> void:
	super._ready()
	create_spell_choice_panel()
	create_parry_prompt_ui()
	create_parry_pit()
	create_aurion_counter_ui()
	disable_keyboard_focus_for_all_buttons($UI)
	

func create_aurion_counter_ui() -> void:
	if aurion_panel != null:
		return

	aurion_panel = PanelContainer.new()
	aurion_panel.name = "AurionCounterPanel"

	# Top-right area, between the center phase panel and the player status panel.
	aurion_panel.anchor_left = 1.0
	aurion_panel.anchor_right = 1.0
	aurion_panel.anchor_top = 0.0
	aurion_panel.anchor_bottom = 0.0

	aurion_panel.offset_left = -690.0
	aurion_panel.offset_right = -350.0
	aurion_panel.offset_top = 34.0
	aurion_panel.offset_bottom = 92.0
	aurion_panel.z_index = 70

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.015, 0.005, 0.72)
	style.border_color = Color(1.0, 0.78, 0.22, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	aurion_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	aurion_panel.add_child(margin)

	aurion_label = Label.new()
	aurion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aurion_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	aurion_label.add_theme_font_size_override("font_size", 18)
	margin.add_child(aurion_label)

	$UI.add_child(aurion_panel)
	update_aurion_counter_ui()
	
	
func update_aurion_counter_ui() -> void:
	if aurion_label == null:
		return

	aurion_label.text = (
		"AURION POINTS\n"
		+ "Player "
		+ str(player_aurion_points)
		+ "/"
		+ str(AURION_WIN_TARGET)
		+ "    AI "
		+ str(ai_aurion_points)
		+ "/"
		+ str(AURION_WIN_TARGET)
	)



func add_aurion(scoring_owner: String, amount: int, reason: String = "") -> void:
	if amount <= 0:
		return

	var clean_owner: String = scoring_owner.to_lower().strip_edges()

	if clean_owner == "player":
		player_aurion_points += amount
		log_msg("Player gains +" + str(amount) + " Aurion. " + reason)

	elif clean_owner == "ai" or clean_owner == "enemy" or clean_owner == "opponent":
		ai_aurion_points += amount
		log_msg("AI gains +" + str(amount) + " Aurion. " + reason)

	else:
		log_msg("Unknown Aurion owner: " + scoring_owner)
		return

	update_aurion_counter_ui()
	check_aurion_victory()
	
	
func check_aurion_victory() -> void:
	if player_aurion_points >= AURION_WIN_TARGET:
		log_msg("Player has reached " + str(AURION_WIN_TARGET) + " Aurion.")

	if ai_aurion_points >= AURION_WIN_TARGET:
		log_msg("AI has reached " + str(AURION_WIN_TARGET) + " Aurion.")




	
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			if hand != null and hand.has_method("toggle_hand"):
				hand.toggle_hand()

			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_SHIFT:
			toggle_global_ability_icons()
			get_viewport().set_input_as_handled()
			return

	super._input(event)
	
	
func create_parry_prompt_ui() -> void:
	if parry_prompt_panel != null:
		return

	parry_prompt_panel = PanelContainer.new()
	parry_prompt_panel.name = "ParryPromptPanel"
	parry_prompt_panel.visible = false
	parry_prompt_panel.anchor_left = 0.5
	parry_prompt_panel.anchor_right = 0.5
	parry_prompt_panel.anchor_top = 0.5
	parry_prompt_panel.anchor_bottom = 0.5
	parry_prompt_panel.offset_left = -260.0
	parry_prompt_panel.offset_right = 260.0
	parry_prompt_panel.offset_top = -75.0
	parry_prompt_panel.offset_bottom = 75.0
	parry_prompt_panel.z_index = 90

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.01, 0.005, 0.92)
	style.border_color = Color(1.0, 0.35, 0.12, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	parry_prompt_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	parry_prompt_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	parry_prompt_label = Label.new()
	parry_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parry_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parry_prompt_label.text = "Parry"
	parry_prompt_label.add_theme_font_size_override("font_size", 17)
	vbox.add_child(parry_prompt_label)

	parry_let_die_button = Button.new()
	parry_let_die_button.text = "Let Unit Die"
	parry_let_die_button.focus_mode = Control.FOCUS_NONE
	parry_let_die_button.pressed.connect(_on_parry_let_die_pressed)
	vbox.add_child(parry_let_die_button)

	$UI.add_child(parry_prompt_panel)
	
	
func create_parry_pit() -> void:
	parry_pit_root = get_node_or_null("ParryPit")

	if parry_pit_root == null:
		parry_pit_root = get_node_or_null("Battlefield3D/ParryPit")

	if parry_pit_root == null and get_tree().current_scene != null:
		parry_pit_root = get_tree().current_scene.get_node_or_null("Battlefield3D/ParryPit")

	if parry_pit_root == null:
		push_error("ParryPit not found. Expected node path: Battlefield3D/ParryPit")
		return

	parry_pit_glow = parry_pit_root.get_node_or_null("ParryPitGlow")
	parry_dp_counter = parry_pit_root.get_node_or_null("ParryDPCounter")
	parry_pit_drop_area = parry_pit_root.get_node_or_null("ParryPitDropArea")
	parry_sacrifice_stack_root = parry_pit_root.get_node_or_null("ParrySacrificeStack")

	if parry_dp_counter == null:
		push_warning("ParryDPCounter not found under ParryPit. Creating fallback Label3D.")
		parry_dp_counter = Label3D.new()
		parry_dp_counter.name = "ParryDPCounter"
		parry_pit_root.add_child(parry_dp_counter)

	if parry_dp_counter is Label3D:
		parry_dp_counter.position = Vector3(-0.60, 0.85, -0.30)
		parry_dp_counter.text = "0/0 DP"
		parry_dp_counter.font_size = 48
		parry_dp_counter.modulate = Color(1.0, 0.92, 0.35, 1.0)
		parry_dp_counter.outline_size = 8
		parry_dp_counter.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
		parry_dp_counter.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		parry_dp_counter.no_depth_test = true
		parry_dp_counter.visible = false

	if parry_dp_counter == null:
		push_warning("ParryDPCounter not found under ParryPit.")

	if parry_pit_drop_area == null:
		push_warning("ParryPitDropArea not found under ParryPit.")

	if parry_sacrifice_stack_root == null:
		parry_sacrifice_stack_root = Node3D.new()
		parry_sacrifice_stack_root.name = "ParrySacrificeStack"
		parry_pit_root.add_child(parry_sacrifice_stack_root)
		parry_sacrifice_stack_root.position = Vector3.ZERO

	parry_pit_root.visible = false
	update_parry_counter_visual(0, 0)
	
	
func show_parry_pit(required_dp: int) -> void:
	parry_required_dp = required_dp

	if parry_pit_root == null:
		create_parry_pit()

	if parry_pit_root == null:
		return

	parry_pit_root.visible = true

	if parry_pit_glow != null:
		parry_pit_glow.visible = true

	if parry_dp_counter != null:
		parry_dp_counter.visible = true

	update_parry_counter_visual(parry_gathered_dp, parry_required_dp)


func hide_parry_pit() -> void:
	if parry_pit_root == null:
		return

	if parry_pit_glow != null:
		parry_pit_glow.visible = false

	if parry_dp_counter != null:
		parry_dp_counter.visible = false

	parry_pit_root.visible = false

	update_parry_counter_visual(0, 0)


func update_parry_counter_visual(current_dp: int, required_dp: int) -> void:
	if parry_dp_counter == null:
		return

	var counter_text := "%d/%d DP" % [current_dp, required_dp]

	if parry_dp_counter is Label3D:
		parry_dp_counter.text = counter_text
	elif parry_dp_counter is Label:
		parry_dp_counter.text = counter_text
	else:
		parry_dp_counter.set("text", counter_text)
	
	
func add_visible_parry_sacrifice_card(card_data: CardData) -> void:
	if card_data == null:
		return

	if parry_sacrifice_stack_root == null:
		return

	var visual_card := TEST_CARD_SCENE.instantiate() as Node3D
	parry_sacrifice_stack_root.add_child(visual_card)

	if visual_card.has_method("assign_card_data"):
		visual_card.assign_card_data(card_data, false)

	var index: int = parry_sacrifice_nodes.size()

	# Ordered overlap, not a perfect pile.
	var x_offset: float = -0.28 + float(index % 4) * 0.18
	var z_offset: float = -0.18 + float(index % 4) * 0.12
	var y_offset: float = 0.02 + float(index) * 0.012
	var rotation_offset: float = -10.0 + float(index % 5) * 5.0

	visual_card.position = Vector3(x_offset, y_offset, z_offset)
	visual_card.rotation_degrees = Vector3(0, rotation_offset, 0)
	visual_card.scale = Vector3(0.46, 0.46, 0.46)

	parry_sacrifice_nodes.append(visual_card)
	
	
func clear_visible_parry_sacrifice_cards() -> void:
	for visual_card in parry_sacrifice_nodes:
		if visual_card != null and is_instance_valid(visual_card):
			visual_card.queue_free()

	parry_sacrifice_nodes.clear()
	
	
func begin_parry_prompt(
	lane: String,
	attacker_slot: Node,
	attacker_card: CardData,
	defender_slot: Node,
	defender_card: CardData
) -> void:
	if attacker_card == null or defender_card == null:
		return

	parry_active = true
	parry_lane = lane
	parry_attacker_slot = attacker_slot
	parry_attacker_card = attacker_card
	parry_defender_slot = defender_slot
	parry_defender_card = defender_card
	parry_required_dp = max(1, attacker_card.ap)
	parry_gathered_dp = 0

	show_parry_pit(parry_required_dp)

	if parry_prompt_panel != null:
		parry_prompt_panel.visible = true

	if parry_prompt_label != null:
		parry_prompt_label.text = (
			"Your "
			+ defender_card.card_name
			+ " is being attacked by "
			+ attacker_card.card_name
			+ ".\nDrop hand cards into the glowing pit to gather DP."
			+ "\nRequired DP: "
			+ str(parry_required_dp)
		)

	update_parry_counter_label()

	log_msg("Parry prompt: sacrifice hand cards into the pit. Required DP: " + str(parry_required_dp))
	
	
	
func disable_keyboard_focus_for_all_buttons(root: Node) -> void:
	if root == null:
		return

	if root is Button:
		var button := root as Button
		button.focus_mode = Control.FOCUS_NONE

	for child in root.get_children():
		disable_keyboard_focus_for_all_buttons(child)

	
	
func update_parry_counter_label() -> void:
	update_parry_counter_visual(parry_gathered_dp, parry_required_dp)
		
		
func sacrifice_card_to_parry(card_ui: CardUI) -> void:
	if not parry_active:
		return

	if card_ui == null:
		return

	if not is_instance_valid(card_ui):
		return

	var sacrificed_card: CardData = card_ui.card_data

	if sacrificed_card == null:
		return_card_to_hand_safely(card_ui)
		cancel_selected_card()
		return

	var gained_dp: int = max(0, sacrificed_card.dp)
	parry_gathered_dp += gained_dp

	add_visible_parry_sacrifice_card(sacrificed_card)

	if discard_pile != null:
		discard_pile.add_card(sacrificed_card)

	if hand != null:
		hand.consume_dragged_card(card_ui)

	log_msg("Parry sacrifice: " + sacrificed_card.card_name + " added " + str(gained_dp) + " DP.")
	update_parry_counter_label()
	cancel_selected_card()

	if parry_gathered_dp >= parry_required_dp:
		complete_parry_success()
		
		
		
func complete_parry_success() -> void:
	if not parry_active:
		return

	log_msg(
		"Parry successful. "
		+ parry_defender_card.card_name
		+ " survives with "
		+ str(parry_gathered_dp)
		+ "/"
		+ str(parry_required_dp)
		+ " DP."
	)

	end_parry_prompt()
	advance_combat_lane_after_resolution()

	if not player_has_initiative:
		ai_resolve_combat_sequence()
		

	
func _on_parry_let_die_pressed() -> void:
	if not parry_active:
		return

	if parry_defender_slot != null:
		send_slot_card_to_discard(parry_defender_slot)

	if parry_defender_card != null:
		log_msg("You let " + parry_defender_card.card_name + " die.")
		add_aurion("ai", 1, "Destroyed " + parry_defender_card.card_name + " in combat.")

	end_parry_prompt()
	advance_combat_lane_after_resolution()
	
	
func end_parry_prompt() -> void:
	parry_active = false
	parry_lane = ""
	parry_attacker_slot = null
	parry_attacker_card = null
	parry_defender_slot = null
	parry_defender_card = null
	parry_required_dp = 0
	parry_gathered_dp = 0

	clear_visible_parry_sacrifice_cards()
	hide_parry_pit()

	if parry_prompt_panel != null:
		parry_prompt_panel.visible = false
		
		
	
	
	
func toggle_global_ability_icons() -> void:
	global_ability_icons_visible = !global_ability_icons_visible
	set_global_ability_icons_visible(global_ability_icons_visible)
	
func set_global_ability_icons_visible(show_icons: bool) -> void:
	if hand != null and hand.has_method("set_all_ability_icons_visible"):
		hand.set_all_ability_icons_visible(show_icons)

	set_battlefield_ability_icons_visible(show_icons)
	

func set_battlefield_ability_icons_visible(show_icons: bool) -> void:
	if board_slots == null:
		return

	for slot in board_slots.get_children():
		if slot == null:
			continue

		if slot.has_method("set_slot_ability_icons_visible"):
			slot.set_slot_ability_icons_visible(show_icons)


func create_spell_choice_panel() -> void:
	if spell_choice_panel != null:
		return

	spell_choice_panel = PanelContainer.new()
	spell_choice_panel.name = "SpellChoicePanel"
	spell_choice_panel.visible = false
	spell_choice_panel.anchor_left = 0.5
	spell_choice_panel.anchor_right = 0.5
	spell_choice_panel.anchor_top = 0.5
	spell_choice_panel.anchor_bottom = 0.5
	spell_choice_panel.offset_left = -180.0
	spell_choice_panel.offset_right = 180.0
	spell_choice_panel.offset_top = -90.0
	spell_choice_panel.offset_bottom = 90.0
	spell_choice_panel.z_index = 80

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.015, 0.94)
	style.border_color = Color(0.9, 0.72, 0.32, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	spell_choice_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	spell_choice_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	spell_choice_label = Label.new()
	spell_choice_label.text = "Place spell as:"
	spell_choice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spell_choice_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(spell_choice_label)

	var face_up_button := Button.new()
	face_up_button.text = "Face Up"
	face_up_button.focus_mode = Control.FOCUS_NONE
	face_up_button.pressed.connect(_on_spell_face_up_pressed)
	vbox.add_child(face_up_button)

	var face_down_button := Button.new()
	face_down_button.text = "Face Down"
	face_down_button.focus_mode = Control.FOCUS_NONE
	face_down_button.pressed.connect(_on_spell_face_down_pressed)
	vbox.add_child(face_down_button)

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(_on_spell_choice_cancel_pressed)
	vbox.add_child(cancel_button)

	$UI.add_child(spell_choice_panel)
	


	
func begin_combat_phase() -> void:
	reset_combat_state()

	if player_has_initiative:
		log_msg("Phase: Combat. Player has initiative. Click the leftmost or rightmost lane to choose combat direction.")
	else:
		log_msg("Phase: Combat. AI has initiative and will decide whether to attack.")
		ai_take_combat_initiative()
	
		
func reset_combat_state() -> void:
	combat_direction_selected = false
	combat_lane_order.clear()
	combat_next_lane_index = 0
	
func handle_combat_lane_click(slot: Node) -> void:
	if slot == null:
		return

	if not player_has_initiative:
		log_msg("AI has initiative this combat. You cannot choose the attack lane.")
		return
		
	var lane: String = get_slot_lane(slot)

	if lane == "":
		return

	if not combat_direction_selected:
		if lane == "left":
			set_combat_lane_order_from_left()
			resolve_next_combat_lane(lane)
			return

		if lane == "right":
			set_combat_lane_order_from_right()
			resolve_next_combat_lane(lane)
			return

		log_msg("Choose the leftmost or rightmost lane first to set combat direction.")
		return

	resolve_next_combat_lane(lane)
	
	
func set_combat_lane_order_from_left() -> void:
	combat_direction_selected = true
	combat_lane_order.clear()
	combat_lane_order.append("left")
	combat_lane_order.append("middle")
	combat_lane_order.append("right")
	combat_next_lane_index = 0

	log_msg("Combat direction selected: left to right.")
	
	
func set_combat_lane_order_from_right() -> void:
	combat_direction_selected = true
	combat_lane_order.clear()
	combat_lane_order.append("right")
	combat_lane_order.append("middle")
	combat_lane_order.append("left")
	combat_next_lane_index = 0

	log_msg("Combat direction selected: right to left.")
	
	
func resolve_next_combat_lane(clicked_lane: String) -> void:
	if parry_active:
		log_msg("Resolve the current parry prompt first.")
		return

	if combat_next_lane_index >= combat_lane_order.size():
		log_msg("All combat lanes are already resolved.")
		return

	var expected_lane: String = combat_lane_order[combat_next_lane_index]

	if clicked_lane != expected_lane:
		log_msg("Next combat must resolve in the " + expected_lane + " lane.")
		return

	var player_slot: Node = find_slot_by_owner_row_lane("player", "front", expected_lane)
	var opponent_slot: Node = find_slot_by_owner_row_lane("enemy", "front", expected_lane)

	resolve_lane_combat(expected_lane, player_slot, opponent_slot)

	# If parry started, do NOT advance lane yet.
	# Parry will advance the lane after success or Let Die.
	if parry_active:
		return

	advance_combat_lane_after_resolution()
	
	
		
func advance_combat_lane_after_resolution() -> void:
	combat_next_lane_index += 1

	if combat_next_lane_index >= combat_lane_order.size():
		log_msg("All combat lanes resolved. Press End Combat / Next Round when ready.")
	else:
		log_msg("Next lane to resolve: " + combat_lane_order[combat_next_lane_index])
		

func resolve_lane_combat(lane: String, player_slot: Node, opponent_slot: Node) -> void:
	var player_card: CardData = get_slot_card_data(player_slot)
	var opponent_card: CardData = get_slot_card_data(opponent_slot)

	var player_has_unit: bool = is_unit_card(player_card)
	var opponent_has_unit: bool = is_unit_card(opponent_card)

	if not player_has_unit and not opponent_has_unit:
		log_msg(lane.capitalize() + " lane: no unit combat.")
		return

	if player_has_unit and not opponent_has_unit:
		log_msg(lane.capitalize() + " lane: " + player_card.card_name + " has no opposing unit target.")
		return

	if not player_has_unit and opponent_has_unit:
		log_msg(lane.capitalize() + " lane: opponent " + opponent_card.card_name + " has no player unit target.")
		return

	if player_has_initiative:
		resolve_directed_clash(lane, player_slot, player_card, opponent_slot, opponent_card, true)
	else:
		resolve_directed_clash(lane, opponent_slot, opponent_card, player_slot, player_card, false)
	
	



func show_spell_choice_panel(card_ui: CardUI, slot: Node) -> void:
	pending_spell_card_ui = card_ui
	pending_spell_slot = slot

	if spell_choice_panel == null:
		create_spell_choice_panel()

	if spell_choice_label != null and selected_card_data != null:
		spell_choice_label.text = "Place " + selected_card_data.card_name + " as:"

	spell_choice_panel.visible = true
	
	
func hide_spell_choice_panel() -> void:
	if spell_choice_panel != null:
		spell_choice_panel.visible = false

	pending_spell_card_ui = null
	pending_spell_slot = null


func _on_spell_face_up_pressed() -> void:
	confirm_pending_spell_placement(false)
	
	
func _on_spell_face_down_pressed() -> void:
	confirm_pending_spell_placement(true)
	
	
func _on_spell_choice_cancel_pressed() -> void:
	if pending_spell_card_ui != null:
		return_card_to_hand_safely(pending_spell_card_ui)

	hide_spell_choice_panel()
	cancel_selected_card()


func create_phase_ui() -> void:
	phase_panel = PanelContainer.new()
	phase_panel.name = "PhasePanel"
	phase_panel.anchor_left = 0.5
	phase_panel.anchor_right = 0.5
	phase_panel.anchor_top = 0.0
	phase_panel.anchor_bottom = 0.0
	phase_panel.offset_left = -190.0
	phase_panel.offset_right = 190.0
	phase_panel.offset_top = 20.0
	phase_panel.offset_bottom = 145.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.58)
	style.border_color = Color(0.9, 0.75, 0.35, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	phase_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	phase_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	phase_label = Label.new()
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(phase_label)

	next_phase_button = Button.new()
	next_phase_button.focus_mode = Control.FOCUS_NONE
	next_phase_button.pressed.connect(_on_next_phase_pressed)
	vbox.add_child(next_phase_button)

	# No more "Spawn Opponent Test Cards" button.
	spawn_opponent_button = null

	$UI.add_child(phase_panel)
	update_phase_ui()


func begin_game_after_battle_plan_selection() -> void:
	if game_has_started:
		return

	game_has_started = true

	setup_ai_deck()
	ai_draw_cards(5)
	ai_has_starting_hand = true

	update_tribute_counter()
	deal_starting_hand()

	if tribute_manager != null:
		log_msg("Starting Tribute: " + tribute_manager.get_status_text())

	log_msg("AI starting hand dealt. AI hand: " + str(ai_hand.size()) + " | AI deck: " + str(ai_deck.size()))


func _on_hand_card_drag_released(card: CardUI, screen_position: Vector2) -> void:
	if card == null:
		cancel_selected_card()
		return

	if not is_instance_valid(card):
		cancel_selected_card()
		return

	if selected_card_data == null and card.card_data != null:
		select_card(card.card_data)

	var target_node: Node = get_3d_node_under_screen_position(screen_position)
	var target_slot: Node = find_board_slot_from_node(target_node)

	# 0. Parry pit has highest priority during parry prompt.
	# 0. Parry pit has highest priority during parry prompt.
	# 0. Parry pit has highest priority during parry prompt.
	if parry_active:
		var dropped_on_parry_pit := false

		if parry_pit_drop_area != null and is_node_inside_target(target_node, parry_pit_drop_area):
			dropped_on_parry_pit = true
		elif parry_pit_root != null and is_node_inside_target(target_node, parry_pit_root):
			dropped_on_parry_pit = true

		if dropped_on_parry_pit:
			sacrifice_card_to_parry(card)
			return

		log_msg("Drop cards into the glowing pit to parry, or press Let Unit Die.")
		return_card_to_hand_safely(card)
		cancel_selected_card()
		return

	# 1. Tribute pile has priority.
	if is_node_inside_target(target_node, tribute_pile):
		if current_phase != BattlePhase.TRIBUTE:
			log_msg("Cards can only be sent to Tribute during the Tribute Phase.")
			return_card_to_hand_safely(card)
			cancel_selected_card()
			return

		var sacrificed: bool = try_sacrifice_selected_card_to_tribute()

		if sacrificed:
			if hand != null:
				hand.consume_dragged_card(card)
		else:
			return_card_to_hand_safely(card)

		cancel_selected_card()
		return

	# 2. Board slot / equipment / spell placement.
	if target_slot != null:
		if current_phase != BattlePhase.DEPLOYMENT:
			log_msg("Cards can only be deployed during the Deployment Phase.")
			return_card_to_hand_safely(card)
			cancel_selected_card()
			return

		var card_type: String = get_clean_card_type(selected_card_data)

		if card_type == "equipment":
			var attached: bool = try_attach_selected_equipment_to_slot(target_slot)

			if attached:
				if hand != null:
					hand.consume_dragged_card(card)
			else:
				return_card_to_hand_safely(card)

			cancel_selected_card()
			return

		if is_spell_like_card(selected_card_data):
			if String(target_slot.get_meta("owner", "")) != "player":
				log_msg("Spells can only be placed on your side of the board.")
				return_card_to_hand_safely(card)
				cancel_selected_card()
				return

			if bool(target_slot.get_meta("occupied", false)):
				log_msg("That slot is already occupied.")
				return_card_to_hand_safely(card)
				cancel_selected_card()
				return

			var target_row: String = String(target_slot.get_meta("row", ""))

			if target_row == "front":
				var front_spell_placed: bool = try_place_selected_card_on_slot(target_slot)

				if front_spell_placed:
					if hand != null:
						hand.consume_dragged_card(card)
				else:
					return_card_to_hand_safely(card)

				cancel_selected_card()
				return

			if target_row == "back":
				return_card_to_hand_safely(card)
				show_spell_choice_panel(card, target_slot)
				return

			log_msg("Invalid spell placement row.")
			return_card_to_hand_safely(card)
			cancel_selected_card()
			return

		var placed: bool = try_place_selected_card_on_slot(target_slot)

		if placed:
			if hand != null:
				hand.consume_dragged_card(card)
		else:
			return_card_to_hand_safely(card)

		cancel_selected_card()
		return

	# 3. Hand reorder.
	if hand != null and hand.has_method("is_screen_position_in_hand_reorder_zone"):
		if hand.is_screen_position_in_hand_reorder_zone(screen_position):
			if hand.has_method("reorder_card_in_hand"):
				hand.reorder_card_in_hand(card, screen_position.x)

			return_card_to_hand_safely(card)
			cancel_selected_card()
			return

	log_msg("Card dropped nowhere valid.")
	return_card_to_hand_safely(card)
	cancel_selected_card()
	

	
func get_clean_card_type(card_data: CardData) -> String:
	if card_data == null:
		return ""

	return card_data.card_type.to_lower().strip_edges()
	

func is_spell_like_card(card_data: CardData) -> bool:
	var card_type: String = get_clean_card_type(card_data)

	return card_type == "spell" or card_type == "event" or card_type == "trap" or card_type == "ruse"
	

func is_equipment_card(card_data: CardData) -> bool:
	return get_clean_card_type(card_data) == "equipment"

func is_trap_card(card_data: CardData) -> bool:
	return get_clean_card_type(card_data) == "trap"


func is_ruse_card(card_data: CardData) -> bool:
	return get_clean_card_type(card_data) == "ruse"


func is_event_card(card_data: CardData) -> bool:
	return get_clean_card_type(card_data) == "event"


func is_spell_card(card_data: CardData) -> bool:
	return get_clean_card_type(card_data) == "spell"
	

func get_slot_card_data(slot: Node) -> CardData:
	if slot == null:
		return null

	if slot.has_method("get_placed_card_data"):
		return slot.get_placed_card_data()

	return null
	

func return_card_to_hand_safely(card: CardUI) -> void:
	if hand == null:
		return

	if card != null and is_instance_valid(card):
		card.mouse_is_pressed = false
		card.is_dragging = false
		card.set_process(false)

	if hand.has_method("return_dragged_card_to_hand"):
		hand.return_dragged_card_to_hand(card)


func draw_battleplan_cards(plan: Dictionary) -> void:
	var draw_amount: int = int(plan.get("draw_amount", 0))

	var player_drawn_count: int = 0

	if draw_amount > 0 and player_deck != null and hand != null:
		for i in range(draw_amount):
			if not hand.can_accept_card():
				break

			var drawn_card: CardData = player_deck.draw_top_card()

			if drawn_card == null:
				break

			hand.add_card_to_hand(drawn_card)
			player_drawn_count += 1

			if draw_pile != null:
				draw_pile.consume_top_card()

	log_msg("Battleplan draw: player drew " + str(player_drawn_count) + "/" + str(draw_amount) + " cards.")

	var ai_draw_amount: int = int(opponent_battle_plan.get("draw_amount", draw_amount))
	ai_draw_cards(ai_draw_amount)

	log_msg("AI battleplan draw: AI drew " + str(ai_draw_amount) + " cards. AI hand: " + str(ai_hand.size()))


func try_place_selected_card_on_slot(slot: Node) -> bool:
	if slot == null:
		return false

	if not has_selected_card or selected_card_data == null:
		return false

	var slot_id: String = String(slot.get_meta("slot_id", ""))
	var slot_row: String = String(slot.get_meta("row", ""))
	var card_type: String = get_clean_card_type(selected_card_data)

	if card_type == "equipment":
		return try_attach_selected_equipment_to_slot(slot)

	if not is_valid_slot_for_selected_card(slot):
		log_msg("Invalid placement for " + selected_card_data.card_name + " on " + slot_id)
		return false

	if not tribute_manager.can_afford(selected_card_data.tribute_cost):
		log_msg("Not enough Tribute Points. Need " + str(selected_card_data.tribute_cost) + ", have " + str(tribute_manager.current_tribute_points) + ".")
		return false

	var place_face_down: bool = false

	if card_type == "unit" and slot_row == "back":
		place_face_down = true

	if is_spell_like_card(selected_card_data):
		# Front row spells are always face up.
		# Back row spells should normally come through confirm_pending_spell_placement().
		place_face_down = false

	var placed_successfully: bool = slot.place_card(TEST_CARD_SCENE, selected_card_data, place_face_down)

	if placed_successfully:
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

	if slot == null:
		return false

	if String(slot.get_meta("owner", "")) != "player":
		return false

	var slot_row: String = String(slot.get_meta("row", ""))
	var slot_occupied: bool = bool(slot.get_meta("occupied", false))
	var card_type: String = get_clean_card_type(selected_card_data)

	if card_type == "equipment":
		if not slot_occupied:
			return false

		if not slot.has_method("can_attach_equipment"):
			return false

		if not slot.can_attach_equipment():
			return false

		var existing_card: CardData = get_slot_card_data(slot)
		return is_unit_card(existing_card)

	if is_spell_like_card(selected_card_data):
		# Spells can go front or back, any lane.
		# Front = face up automatically.
		# Back = prompt for face up / face down.
		return (slot_row == "front" or slot_row == "back") and not slot_occupied

	if card_type == "unit":
		# Units can go front face-up or back face-down.
		return (slot_row == "front" or slot_row == "back") and not slot_occupied

	return false
	
	
func is_unit_card(card_data: CardData) -> bool:
	return get_clean_card_type(card_data) == "unit"
	
	
	
func try_attach_selected_equipment_to_slot(slot: Node) -> bool:
	if slot == null:
		return false

	if selected_card_data == null:
		return false

	if not is_equipment_card(selected_card_data):
		return false

	if String(slot.get_meta("owner", "")) != "player":
		log_msg("Equipment can only be attached to your units.")
		return false

	if not bool(slot.get_meta("occupied", false)):
		log_msg("Equipment cannot be placed alone. Attach it to an existing unit.")
		return false

	if bool(slot.get_meta("face_down", false)):
		log_msg("Equipment cannot be attached to a face-down card.")
		return false
	
	var existing_card: CardData = get_slot_card_data(slot)

	if not is_unit_card(existing_card):
		log_msg("Equipment can only be attached to a unit.")
		return false

	if not slot.has_method("can_attach_equipment") or not slot.can_attach_equipment():
		log_msg("This unit already has the maximum 2 equipment cards.")
		return false

	if not tribute_manager.can_afford(selected_card_data.tribute_cost):
		log_msg("Not enough Tribute Points. Need " + str(selected_card_data.tribute_cost) + ", have " + str(tribute_manager.current_tribute_points) + ".")
		return false

	if not slot.has_method("attach_equipment"):
		log_msg("This slot does not support equipment attachment.")
		return false

	var attached: bool = slot.attach_equipment(TEST_CARD_SCENE, selected_card_data)

	if attached:
		tribute_manager.spend_tribute(selected_card_data.tribute_cost)
		log_msg("Attached " + selected_card_data.card_name + " to " + existing_card.card_name + ".")
		log_msg("Spent " + str(selected_card_data.tribute_cost) + " TP. " + tribute_manager.get_status_text())
		handle_card_deployed(selected_card_data)
		return true

	return false
	

func confirm_pending_spell_placement(place_face_down: bool) -> void:
	if pending_spell_slot == null:
		hide_spell_choice_panel()
		cancel_selected_card()
		return

	if selected_card_data == null:
		hide_spell_choice_panel()
		cancel_selected_card()
		return

	if not is_spell_like_card(selected_card_data):
		hide_spell_choice_panel()
		cancel_selected_card()
		return

	if current_phase != BattlePhase.DEPLOYMENT:
		log_msg("Spells can only be placed during the Deployment Phase.")
		hide_spell_choice_panel()
		cancel_selected_card()
		return

	if String(pending_spell_slot.get_meta("owner", "")) != "player":
		log_msg("Spells can only be placed on your side of the board.")
		hide_spell_choice_panel()
		cancel_selected_card()
		return

	if String(pending_spell_slot.get_meta("row", "")) != "back":
		log_msg("Only back-row spells can be placed face down.")
		hide_spell_choice_panel()
		cancel_selected_card()
		return

	if bool(pending_spell_slot.get_meta("occupied", false)):
		log_msg("That slot is already occupied.")
		hide_spell_choice_panel()
		cancel_selected_card()
		return

	if not tribute_manager.can_afford(selected_card_data.tribute_cost):
		log_msg("Not enough Tribute Points. Need " + str(selected_card_data.tribute_cost) + ", have " + str(tribute_manager.current_tribute_points) + ".")
		hide_spell_choice_panel()
		cancel_selected_card()
		return

	var placed: bool = pending_spell_slot.place_card(TEST_CARD_SCENE, selected_card_data, place_face_down)

	if placed:
		tribute_manager.spend_tribute(selected_card_data.tribute_cost)

		var visibility_text: String = "face down" if place_face_down else "face up"
		log_msg("Placed spell " + selected_card_data.card_name + " " + visibility_text + ".")
		log_msg("Spent " + str(selected_card_data.tribute_cost) + " TP. " + tribute_manager.get_status_text())

		if pending_spell_card_ui != null and hand != null:
			hand.consume_dragged_card(pending_spell_card_ui)
		elif hand != null:
			hand.remove_selected_card()

		handle_card_deployed(selected_card_data)

	hide_spell_choice_panel()
	cancel_selected_card()
	

func start_next_round() -> void:
	if parry_active:
		log_msg("Resolve the parry prompt before ending combat.")
		return

	cleanup_battlefield_spells()

	if tribute_manager != null:
		tribute_manager.start_new_turn_refresh()
		update_tribute_counter()

	if battle_plan_manager != null:
		battle_plan_manager.advance_round()

	cancel_selected_card()
	open_battle_plan_selection()
	


func find_slot_by_owner_row_lane(owner_name: String, row: String, lane: String) -> Node:
	if board_slots == null:
		return null

	for slot in board_slots.get_children():
		if String(slot.get_meta("owner", "")) == owner_name and String(slot.get_meta("row", "")) == row and get_slot_lane(slot) == lane:
			return slot

	return null
	

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



func cleanup_battlefield_spells() -> void:
	if board_slots == null:
		return

	var cleaned_count: int = 0

	for slot in board_slots.get_children():
		var card_data: CardData = get_slot_card_data(slot)

		if card_data == null:
			continue

		if not is_spell_like_card(card_data):
			continue

		if discard_pile != null:
			discard_pile.add_card(card_data)

		if slot.has_method("clear_slot"):
			slot.clear_slot()

		cleaned_count += 1

	if cleaned_count > 0:
		log_msg("Cleaned up " + str(cleaned_count) + " spell card(s) from the battlefield.")


func send_slot_card_to_discard(slot: Node) -> void:
	if slot == null:
		return

	var card_data: CardData = get_slot_card_data(slot)

	if card_data != null and discard_pile != null:
		discard_pile.add_card(card_data)

	if slot.has_method("get_equipment_cards") and discard_pile != null:
		var equipment_cards: Array = slot.get_equipment_cards()

		for equipment_card in equipment_cards:
			if equipment_card != null:
				discard_pile.add_card(equipment_card)

	if slot.has_method("clear_slot"):
		slot.clear_slot()



func set_phase(new_phase: int) -> void:
	current_phase = new_phase
	update_phase_ui()
	update_slot_highlights()

	match current_phase:
		BattlePhase.BATTLEPLAN:
			log_msg("Phase: Battleplan")

		BattlePhase.TRIBUTE:
			log_msg("Phase: Tribute")
			ai_start_tribute_phase()

		BattlePhase.DEPLOYMENT:
			begin_deployment_phase()

		BattlePhase.COMBAT:
			begin_combat_phase()


func begin_deployment_phase() -> void:
	log_msg("Phase: Deployment")

	if player_has_initiative:
		log_msg("Player has initiative and deploys first. AI will deploy after you press Go to Combat.")
	else:
		log_msg("AI has initiative and deploys first.")
		ai_take_deployment_turn()


func _on_next_phase_pressed() -> void:
	match current_phase:
		BattlePhase.BATTLEPLAN:
			open_battle_plan_selection()

		BattlePhase.TRIBUTE:
			set_phase(BattlePhase.DEPLOYMENT)

		BattlePhase.DEPLOYMENT:
			if player_has_initiative:
				ai_take_deployment_turn()
			set_phase(BattlePhase.COMBAT)

		BattlePhase.COMBAT:
			start_next_round()


func setup_ai_deck() -> void:
	ai_deck.clear()
	ai_hand.clear()
	ai_discard.clear()
	ai_tribute.clear()

	ai_perm_tp = 0
	ai_current_perm_tp = 0
	ai_temp_tp = 0
	ai_current_tp = 0
	ai_tribute_used_this_turn = false

	var pool: Array[CardData] = [
		ARCH_WIZARD_MAELCOR,
		IMPERIAL_ARCHIVE_MASTER,
		JENA_OF_YEL,
		IVAAN_BONE_CRUSHER,
		UPPER_HALL_PROSPECTOR,
		TEST_EQUIPMENT,
		TEST_SPELL
	]

	for i in range(40):
		ai_deck.append(pool[i % pool.size()])

	ai_deck.shuffle()


func ai_draw_cards(amount: int) -> void:
	for i in range(amount):
		if ai_deck.is_empty():
			return

		var drawn_card: CardData = ai_deck.pop_back()

		if drawn_card != null:
			ai_hand.append(drawn_card)


func ai_start_tribute_phase() -> void:
	ai_current_perm_tp = ai_perm_tp
	ai_temp_tp = 0
	ai_current_tp = ai_current_perm_tp
	ai_tribute_used_this_turn = false

	ai_offer_one_card_to_tribute()


func ai_offer_one_card_to_tribute() -> void:
	if ai_tribute_used_this_turn:
		return

	if ai_hand.is_empty():
		log_msg("AI has no cards to offer as Tribute.")
		return

	var tribute_index: int = ai_choose_tribute_card_index()

	if tribute_index < 0:
		log_msg("AI found no valid Tribute card.")
		return

	var tribute_card: CardData = ai_hand.pop_at(tribute_index)

	if tribute_card == null:
		return

	ai_tribute.append(tribute_card)
	ai_tribute_used_this_turn = true

	var card_type: String = tribute_card.card_type.to_lower().strip_edges()

	if card_type == "spell" or card_type == "event" or card_type == "trap" or card_type == "ruse":
		ai_temp_tp += 2
		ai_current_tp += 2
		log_msg("AI sacrificed " + tribute_card.card_name + " for +2 temporary TP.")
	else:
		ai_perm_tp += 1
		ai_current_perm_tp += 1
		ai_current_tp += 1
		log_msg("AI sacrificed " + tribute_card.card_name + " for +1 permanent TP.")

	log_msg("AI TP: " + str(ai_current_tp) + "/" + str(ai_perm_tp) + " Temp +" + str(ai_temp_tp))


func ai_choose_tribute_card_index() -> int:
	# Prefer a unit/equipment for permanent TP.
	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if card_data == null:
			continue

		var card_type: String = card_data.card_type.to_lower().strip_edges()

		if card_type == "unit" or card_type == "equipment":
			return i

	# If no permanent tribute option exists, use a spell/event/trap/ruse.
	if not ai_hand.is_empty():
		return 0

	return -1


func ai_take_combat_initiative() -> void:
	if not ai_should_attack_this_combat():
		log_msg("AI chooses not to attack this combat.")
		combat_direction_selected = true
		combat_lane_order.clear()
		combat_next_lane_index = 0
		return

	var start_lane: String = ai_choose_combat_start_lane()

	if start_lane == "right":
		set_combat_lane_order_from_right()
	else:
		set_combat_lane_order_from_left()

	log_msg("AI chooses to attack from the " + start_lane + " lane.")
	ai_resolve_combat_sequence()


func ai_should_attack_this_combat() -> bool:
	var ai_units: int = ai_count_front_units("enemy")
	var player_units: int = ai_count_front_units("player")

	if ai_units <= 0:
		return false

	if player_units <= 0:
		return true

	var ai_total_ap: int = ai_get_total_front_ap("enemy")
	var player_total_ap: int = ai_get_total_front_ap("player")

	# If AI is clearly stronger, attack.
	if ai_total_ap >= player_total_ap:
		return true

	# If AI is weaker, it can still attack sometimes.
	return (randi() % 100) < 35


func ai_choose_combat_start_lane() -> String:
	var left_score: int = ai_score_combat_direction(["left", "middle", "right"])
	var right_score: int = ai_score_combat_direction(["right", "middle", "left"])

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
		var ai_slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)
		var player_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)

		var ai_card: CardData = get_slot_card_data(ai_slot)
		var player_card: CardData = get_slot_card_data(player_slot)

		if is_unit_card(ai_card):
			score += ai_card.ap * weight

			if is_unit_card(player_card):
				if ai_card.ap >= player_card.ap:
					score += 20 * weight
				else:
					score -= 10 * weight
			else:
				score += 12 * weight

		weight -= 1

	score += randi() % 10
	return score


func ai_resolve_combat_sequence() -> void:
	while current_phase == BattlePhase.COMBAT and not parry_active and combat_next_lane_index < combat_lane_order.size():
		var next_lane: String = combat_lane_order[combat_next_lane_index]
		resolve_next_combat_lane(next_lane)


func ai_count_front_units(owner: String) -> int:
	var count: int = 0
	var lanes: Array[String] = ["left", "middle", "right"]

	for lane in lanes:
		var slot: Node = find_slot_by_owner_row_lane(owner, "front", lane)
		var card_data: CardData = get_slot_card_data(slot)

		if is_unit_card(card_data):
			count += 1

	return count


func ai_get_total_front_ap(owner: String) -> int:
	var total_ap: int = 0
	var lanes: Array[String] = ["left", "middle", "right"]

	for lane in lanes:
		var slot: Node = find_slot_by_owner_row_lane(owner, "front", lane)
		var card_data: CardData = get_slot_card_data(slot)

		if is_unit_card(card_data):
			total_ap += card_data.ap

	return total_ap



func ai_deploy_one_card() -> void:
	# Legacy wrapper. Other code can still call this safely.
	ai_take_deployment_turn()
	
func ai_take_deployment_turn() -> void:
	if ai_hand.is_empty():
		log_msg("AI has no hand cards to deploy.")
		return

	var plays_made: int = 0
	var max_plays: int = max(1, ai_max_deployments_per_phase)

	for i in range(max_plays):
		var played: bool = ai_try_deploy_one_card()

		if not played:
			break

		plays_made += 1

		if ai_current_tp <= 0:
			break

	if plays_made == 0:
		log_msg("AI passes deployment. No legal affordable play.")
	else:
		log_msg("AI completed deployment with " + str(plays_made) + " play(s).")
		
		
func ai_try_deploy_one_card() -> bool:
	var action: Dictionary = ai_choose_deployment_action()

	if action.is_empty():
		return false

	var card_index: int = int(action.get("card_index", -1))
	var target_slot: Node = action.get("slot", null) as Node
	var action_type: String = String(action.get("action_type", ""))
	var face_down: bool = bool(action.get("face_down", false))

	if card_index < 0 or card_index >= ai_hand.size():
		return false

	if target_slot == null:
		return false

	var card_data: CardData = ai_hand[card_index]

	if card_data == null:
		return false

	if card_data.tribute_cost > ai_current_tp:
		return false

	var success: bool = false

	if action_type == "equipment":
		if target_slot.has_method("attach_equipment"):
			success = target_slot.attach_equipment(TEST_CARD_SCENE, card_data)

		if success:
			ai_hand.pop_at(card_index)
			ai_spend_tp(card_data.tribute_cost)

			var equipped_unit: CardData = get_slot_card_data(target_slot)
			var equipped_unit_name: String = "unit"

			if equipped_unit != null:
				equipped_unit_name = equipped_unit.card_name

			log_msg("AI attached " + card_data.card_name + " to " + equipped_unit_name + ".")
			log_msg("AI TP after equipment: " + str(ai_current_tp) + "/" + str(ai_perm_tp) + " Temp +" + str(ai_temp_tp))
			return true

		return false

	if action_type == "unit" or action_type == "spell":
		if target_slot.has_method("place_card"):
			success = target_slot.place_card(TEST_CARD_SCENE, card_data, face_down)

		if success:
			ai_hand.pop_at(card_index)
			ai_spend_tp(card_data.tribute_cost)

			var visibility_text: String = "face down" if face_down else "face up"
			var row_text: String = String(target_slot.get_meta("row", "unknown row"))

			log_msg("AI placed " + card_data.card_name + " " + visibility_text + " in enemy " + row_text + " row.")
			log_msg("AI TP after deployment: " + str(ai_current_tp) + "/" + str(ai_perm_tp) + " Temp +" + str(ai_temp_tp))
			return true

	return false
	
	
func ai_choose_deployment_action() -> Dictionary:
	var equipment_action: Dictionary = ai_find_equipment_action()
	var spell_action: Dictionary = ai_find_spell_action()
	var unit_action: Dictionary = ai_find_unit_action()

	# Testing behavior:
	# Sometimes choose spell/equipment even before full effects exist,
	# so we can verify the board rules.
	var roll: int = randi() % 100

	if roll < 25 and not equipment_action.is_empty():
		return equipment_action

	if roll < 55 and not spell_action.is_empty():
		return spell_action

	if not unit_action.is_empty():
		return unit_action

	if not spell_action.is_empty():
		return spell_action

	if not equipment_action.is_empty():
		return equipment_action

	return {}
	
	
func ai_make_deployment_action(card_index: int, slot: Node, action_type: String, face_down: bool) -> Dictionary:
	return {
		"card_index": card_index,
		"slot": slot,
		"action_type": action_type,
		"face_down": face_down
	}
	
func ai_find_unit_action() -> Dictionary:
	var unit_index: int = ai_find_best_affordable_unit_index()

	if unit_index < 0:
		return {}

	var front_slot: Node = ai_find_empty_enemy_slot("front")
	var back_slot: Node = ai_find_empty_enemy_slot("back")

	if front_slot == null and back_slot == null:
		return {}

	var chosen_slot: Node = null
	var face_down: bool = false

	if front_slot != null and back_slot != null:
		# Mostly prefer front row, but sometimes use back row face-down.
		if randi() % 100 < 65:
			chosen_slot = front_slot
			face_down = false
		else:
			chosen_slot = back_slot
			face_down = true
	elif front_slot != null:
		chosen_slot = front_slot
		face_down = false
	else:
		chosen_slot = back_slot
		face_down = true

	return ai_make_deployment_action(unit_index, chosen_slot, "unit", face_down)
	
	
func ai_find_best_affordable_unit_index() -> int:
	var best_index: int = -1
	var best_ap: int = -999

	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if card_data == null:
			continue

		if not is_unit_card(card_data):
			continue

		if card_data.tribute_cost > ai_current_tp:
			continue

		if card_data.ap > best_ap:
			best_ap = card_data.ap
			best_index = i

	return best_index
	
	
func ai_find_spell_action() -> Dictionary:
	var spell_index: int = ai_find_affordable_spell_index()

	if spell_index < 0:
		return {}

	var front_slot: Node = ai_find_empty_enemy_slot("front")
	var back_slot: Node = ai_find_empty_enemy_slot("back")

	if front_slot == null and back_slot == null:
		return {}

	var chosen_slot: Node = null
	var face_down: bool = false

	if front_slot != null and back_slot != null:
		# Spells can go front or back.
		# Front is always face up.
		# Back can be face up or face down.
		if randi() % 100 < 45:
			chosen_slot = front_slot
			face_down = false
		else:
			chosen_slot = back_slot
			face_down = randi() % 100 < 50
	elif front_slot != null:
		chosen_slot = front_slot
		face_down = false
	else:
		chosen_slot = back_slot
		face_down = randi() % 100 < 50

	return ai_make_deployment_action(spell_index, chosen_slot, "spell", face_down)
	
	
func ai_find_affordable_spell_index() -> int:
	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if card_data == null:
			continue

		if not is_spell_like_card(card_data):
			continue

		if card_data.tribute_cost > ai_current_tp:
			continue

		return i

	return -1
	
	
func ai_find_equipment_action() -> Dictionary:
	var target_slot: Node = ai_find_enemy_unit_slot_that_can_take_equipment()

	if target_slot == null:
		return {}

	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if card_data == null:
			continue

		if not is_equipment_card(card_data):
			continue

		if card_data.tribute_cost > ai_current_tp:
			continue

		return ai_make_deployment_action(i, target_slot, "equipment", false)

	return {}
	
	
func ai_find_enemy_unit_slot_that_can_take_equipment() -> Node:
	if board_slots == null:
		return null

	for slot in board_slots.get_children():
		if String(slot.get_meta("owner", "")) != "enemy":
			continue

		if not bool(slot.get_meta("occupied", false)):
			continue

		if bool(slot.get_meta("face_down", false)):
			continue

		var existing_card: CardData = get_slot_card_data(slot)

		if not is_unit_card(existing_card):
			continue

		if not slot.has_method("can_attach_equipment"):
			continue

		if not slot.can_attach_equipment():
			continue

		return slot

	return null
	




	
func ai_find_empty_enemy_slot(row: String) -> Node:
	if board_slots == null:
		return null

	var empty_slots: Array[Node] = []

	for slot in board_slots.get_children():
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

	if is_unit_card(card_data):
		return ai_choose_front_slot_for_card(card_data)

	if is_equipment_card(card_data):
		return ai_choose_equipment_target_slot(card_data)

	if is_trap_card(card_data) or is_ruse_card(card_data):
		return ai_choose_empty_back_slot_for_tactic(card_data)

	if is_spell_card(card_data) or is_event_card(card_data):
		return ai_choose_spell_like_slot(card_data)

	return null


func ai_should_place_card_face_down(card_data: CardData, target_slot: Node) -> bool:
	if card_data == null or target_slot == null:
		return false

	var row: String = String(target_slot.get_meta("row", ""))

	# Front row is always face-up.
	if row == "front":
		return false

	# Back row cards should be hidden.
	if row == "back":
		if is_unit_card(card_data):
			return true

		if is_trap_card(card_data):
			return true

		if is_ruse_card(card_data):
			return true

		if is_spell_card(card_data):
			return true

		if is_event_card(card_data):
			return true

	return false


func ai_choose_empty_back_slot_for_tactic(card_data: CardData) -> Node:
	var candidate_slots: Array[Node] = []
	var lanes: Array[String] = ["left", "middle", "right"]

	for lane in lanes:
		var slot: Node = find_slot_by_owner_row_lane("enemy", "back", lane)

		if slot == null:
			continue

		if get_slot_card_data(slot) == null:
			candidate_slots.append(slot)

	if candidate_slots.is_empty():
		return null

	# Prefer back-row tactics behind an AI front unit.
	var protected_slots: Array[Node] = []

	for slot in candidate_slots:
		var lane: String = get_slot_lane(slot)
		var front_slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)
		var front_card: CardData = get_slot_card_data(front_slot)

		if is_unit_card(front_card):
			protected_slots.append(slot)

	if not protected_slots.is_empty():
		return protected_slots.pick_random()

	return candidate_slots.pick_random()


func ai_choose_spell_like_slot(card_data: CardData) -> Node:
	var front_slots: Array[Node] = []
	var back_slots: Array[Node] = []
	var lanes: Array[String] = ["left", "middle", "right"]

	for lane in lanes:
		var front_slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)

		if front_slot != null and get_slot_card_data(front_slot) == null:
			front_slots.append(front_slot)

		var back_slot: Node = find_slot_by_owner_row_lane("enemy", "back", lane)

		if back_slot != null and get_slot_card_data(back_slot) == null:
			back_slots.append(back_slot)

	if front_slots.is_empty() and back_slots.is_empty():
		return null

	# Traps and ruses prefer the back row.
	if is_trap_card(card_data) or is_ruse_card(card_data):
		if not back_slots.is_empty():
			return back_slots.pick_random()

		return front_slots.pick_random()

	# Spells and events can go front or back.
	if is_spell_card(card_data) or is_event_card(card_data):
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
	


func ai_choose_equipment_target_slot(card_data: CardData) -> Node:
	var candidate_slots: Array[Node] = []
	var lanes: Array[String] = ["left", "middle", "right"]

	for lane in lanes:
		var slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)

		if slot == null:
			continue

		var slot_card: CardData = get_slot_card_data(slot)

		if not is_unit_card(slot_card):
			continue

		if slot.has_method("can_attach_equipment") and not slot.can_attach_equipment():
			continue

		candidate_slots.append(slot)

	if candidate_slots.is_empty():
		return null

	var best_score: int = -999999
	var best_slots: Array[Node] = []

	for slot in candidate_slots:
		var unit_card: CardData = get_slot_card_data(slot)
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


func ai_attach_equipment_to_slot(equipment_card: CardData, target_slot: Node) -> bool:
	if equipment_card == null or target_slot == null:
		return false

	if not target_slot.has_method("attach_equipment"):
		log_msg("AI could not attach equipment because target slot has no attach_equipment method.")
		return false

	return target_slot.attach_equipment(TEST_CARD_SCENE, equipment_card)
	
	
		
		
func ai_choose_front_slot_for_card(card_data: CardData) -> Node:
	var candidate_slots: Array[Node] = ai_get_empty_front_slots()

	if candidate_slots.is_empty():
		return null

	var best_score: int = -999999
	var best_slots: Array[Node] = []

	for slot in candidate_slots:
		var lane: String = get_slot_lane(slot)
		var score: int = ai_score_front_slot_for_card(card_data, lane)

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
		var slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)

		if slot == null:
			continue

		if get_slot_card_data(slot) == null:
			empty_slots.append(slot)

	return empty_slots


func ai_score_front_slot_for_card(card_data: CardData, lane: String) -> int:
	var score: int = 0

	if card_data == null:
		return score

	var player_front_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)
	var player_back_slot: Node = find_slot_by_owner_row_lane("player", "back", lane)

	var player_front_card: CardData = get_slot_card_data(player_front_slot)
	var player_back_card: CardData = get_slot_card_data(player_back_slot)

	# If the player has a front unit in this lane, AI likes contesting/blocking it.
	if is_unit_card(player_front_card):
		score += 35

		# If AI can beat or match it by AP, this lane becomes very attractive.
		if card_data.ap >= player_front_card.ap:
			score += 35
		else:
			score += 15

		# Strong enemy targets attract AI attention.
		score += min(player_front_card.ap, 10)

	# If the player has no front unit, AI may still choose the open lane.
	else:
		score += 18

	# If the player has something hidden/backline in this lane, AI slightly cares.
	if player_back_card != null:
		score += 8

	# Add randomness so AI does not feel scripted.
	score += randi() % 25

	return score
	
	


func ai_find_empty_front_slot() -> Node:
	if board_slots == null:
		return null

	for slot in board_slots.get_children():
		if slot.get_meta("owner", "") == "enemy" and slot.get_meta("row", "") == "front" and not slot.occupied:
			return slot

	return null


func ai_choose_deploy_card_index() -> int:
	var best_index: int = -1
	var best_score: int = -999999

	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if card_data == null:
			continue

		if card_data.tribute_cost > ai_current_tp:
			continue

		# Do not choose cards that currently have nowhere legal/useful to go.
		var possible_slot: Node = ai_choose_slot_for_card(card_data)

		if possible_slot == null:
			continue

		var score: int = ai_score_deploy_card(card_data)

		if score > best_score:
			best_score = score
			best_index = i

	return best_index


func ai_score_deploy_card(card_data: CardData) -> int:
	if card_data == null:
		return -999999

	var score: int = 0
	var card_type: String = get_clean_card_type(card_data)

	match card_type:
		"unit":
			score += 70
			score += card_data.ap * 4
			score += card_data.dp * 2

		"equipment":
			score += 60
			score += card_data.ap * 3
			score += card_data.dp * 3

		"trap":
			score += 45

		"ruse":
			score += 45

		"spell":
			score += 25

		"event":
			score += 25

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

	if ai_current_tp < cost:
		return false

	var remaining_cost: int = cost

	if ai_temp_tp > 0:
		var temp_spent: int = mini(ai_temp_tp, remaining_cost)
		ai_temp_tp -= temp_spent
		ai_current_tp -= temp_spent
		remaining_cost -= temp_spent

	if remaining_cost > 0:
		ai_current_perm_tp -= remaining_cost
		ai_current_tp -= remaining_cost

	return true


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

	var attacker_label: String = "Player" if player_is_attacker else "Opponent"
	var defender_label: String = "Opponent" if player_is_attacker else "Player"

	log_msg(
		lane.capitalize()
		+ " lane attack: "
		+ attacker_label
		+ " "
		+ attacker_card.card_name
		+ " AP "
		+ str(attacker_card.ap)
		+ " vs "
		+ defender_label
		+ " "
		+ defender_card.card_name
		+ " AP "
		+ str(defender_card.ap)
	)

	if attacker_card.ap == defender_card.ap:
		send_slot_card_to_discard(defender_slot)
		send_slot_card_to_discard(_attacker_slot)

		log_msg(
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

	if attacker_card.ap >= defender_card.ap:
		if not player_is_attacker:
			begin_parry_prompt(lane, _attacker_slot, attacker_card, defender_slot, defender_card)
			return

		send_slot_card_to_discard(defender_slot)
		log_msg(defender_label + " " + defender_card.card_name + " was destroyed.")
		add_aurion("player", 1, "Destroyed " + defender_card.card_name + " in combat.")
		return

	log_msg(defender_label + " " + defender_card.card_name + " survived the attack.")
	


func spawn_random_opponent_cards() -> void:
	# Old test-spawn disabled.
	# AI must deploy through hand + TP + phase rules.
	log_msg("Old opponent test spawn is disabled. AI uses legal deployment now.")
