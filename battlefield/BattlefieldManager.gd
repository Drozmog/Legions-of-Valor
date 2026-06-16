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
var used_battle_plan_keys: Dictionary = {}

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

@onready var opponent_visuals: OpponentVisuals = get_node_or_null("OpponentVisuals") as OpponentVisuals
@onready var card_animation_manager: CardAnimationManager = get_node_or_null("CardAnimationManager") as CardAnimationManager

func _ready() -> void:
	super._ready()
	create_spell_choice_panel()
	create_parry_prompt_ui()
	create_parry_pit()
	create_aurion_counter_ui()
	disable_keyboard_focus_for_all_buttons($UI)
	

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
	var key: String = get_battle_plan_key(plan)

	if key == "":
		return false

	return used_battle_plan_keys.has(key)


func mark_battle_plan_used(plan: Dictionary) -> void:
	var key: String = get_battle_plan_key(plan)

	if key == "":
		return

	used_battle_plan_keys[key] = true


func get_unused_battle_plan_choices(amount: int) -> Array[Dictionary]:
	var final_choices: Array[Dictionary] = []

	if battle_plan_manager == null:
		return final_choices

	if amount <= 0:
		return final_choices

	var local_seen_keys: Dictionary = {}
	var attempts: int = 0
	var max_attempts: int = 60

	while final_choices.size() < amount and attempts < max_attempts:
		attempts += 1

		var raw_choices: Array = battle_plan_manager.get_random_battle_plan_choices(max(amount, 3))

		if raw_choices.is_empty():
			break

		for raw_plan in raw_choices:
			if not raw_plan is Dictionary:
				continue

			var plan: Dictionary = raw_plan
			var key: String = get_battle_plan_key(plan)

			if key == "":
				continue

			if used_battle_plan_keys.has(key):
				continue

			if local_seen_keys.has(key):
				continue

			local_seen_keys[key] = true
			final_choices.append(plan)

			if final_choices.size() >= amount:
				break

	return final_choices

func open_battle_plan_selection() -> void:
	waiting_for_battle_plan = true
	set_phase(BattlePhase.BATTLEPLAN)

	if battle_plan_manager == null:
		log_msg("BattlePlanManager is missing.")
		begin_game_after_battle_plan_selection()
		set_phase(BattlePhase.TRIBUTE)
		return

	if battle_plan_selection_screen == null:
		log_msg("BattlePlanSelectionScreen is missing.")
		begin_game_after_battle_plan_selection()
		set_phase(BattlePhase.TRIBUTE)
		return

	var choices: Array[Dictionary] = get_unused_battle_plan_choices(3)

	if choices.is_empty():
		log_msg("No unused Battle Plans remain. Battleplan deck is exhausted.")

		if battle_plan_selection_screen != null:
			battle_plan_selection_screen.visible = false

		return

	if choices.size() < 3:
		log_msg("Battleplan deck is running low. Remaining choices: " + str(choices.size()))

	battle_plan_selection_screen.show_selection(choices)
	
	
func _on_battle_plan_selected(plan: Dictionary) -> void:
	if plan.is_empty():
		log_msg("No Battle Plan selected.")
		return

	if is_battle_plan_used(plan):
		log_msg("That Battle Plan has already been used. Drawing new options.")
		open_battle_plan_selection()
		return

	waiting_for_battle_plan = false

	mark_battle_plan_used(plan)

	if battle_plan_manager != null:
		battle_plan_manager.select_battle_plan(plan)

	choose_opponent_battle_plan()

	if battle_plan_panel != null:
		battle_plan_panel.set_battle_plan(plan)

		if battle_plan_panel.has_method("set_opponent_battle_plan"):
			battle_plan_panel.set_opponent_battle_plan(opponent_battle_plan)

	apply_battle_plan_rules(plan)
	apply_initiative_rules(plan)

	log_msg("Selected Battle Plan: " + str(plan.get("name", "Unknown Battle Plan")))

	if opponent_battle_plan.is_empty():
		log_msg("Opponent has no unused Battle Plan.")
	else:
		log_msg("Opponent Battle Plan: " + str(opponent_battle_plan.get("name", "Unknown Battle Plan")))

	if not game_has_started:
		begin_game_after_battle_plan_selection()

	draw_battleplan_cards(plan)
	set_phase(BattlePhase.TRIBUTE)
	
	
func choose_opponent_battle_plan() -> void:
	opponent_battle_plan = {}

	if battle_plan_manager == null:
		return

	var choices: Array[Dictionary] = get_unused_battle_plan_choices(1)

	if choices.is_empty():
		log_msg("Opponent Battleplan deck is exhausted.")
		return

	opponent_battle_plan = choices[0]
	mark_battle_plan_used(opponent_battle_plan)
	



func update_ai_visuals() -> void:
	if opponent_visuals == null:
		return

	if opponent_visuals.has_method("set_all_card_data"):
		opponent_visuals.set_all_card_data(
			ai_deck.size(),
			ai_hand.size(),
			ai_tribute,
			ai_discard
		)


func play_player_hand_to_node_animation(card_data: CardData, target_node: Node, face_down: bool = false) -> void:
	if card_animation_manager == null:
		return

	await card_animation_manager.animate_card_from_anchor_to_node(
		card_data,
		"PlayerHandOrigin",
		target_node,
		face_down
	)


func play_enemy_hand_to_node_animation(card_data: CardData, target_node: Node, face_down: bool = false) -> void:
	if card_animation_manager == null:
		return

	await card_animation_manager.animate_card_from_anchor_to_node(
		card_data,
		"EnemyHandOrigin",
		target_node,
		face_down
	)


func play_card_to_discard_animation(card_data: CardData, source_node: Node, slot_owner: String) -> void:
	if card_animation_manager == null:
		return

	var target_node: Node = discard_pile

	if slot_owner == "enemy":
		target_node = get_enemy_visual_target("EnemyDiscardPileVisual")

	card_animation_manager.animate_card_between_nodes(
		card_data,
		source_node,
		target_node,
		false
	)


func get_enemy_visual_target(node_name: String) -> Node:
	if opponent_visuals == null:
		return null

	return opponent_visuals.get_node_or_null(node_name)
	



func create_aurion_counter_ui() -> void:
	# Aurion is now displayed inside the combined PhasePanel.
	# Keep this function so _ready() can still call it safely.
	if aurion_label != null:
		update_aurion_counter_ui()
	
	
func update_aurion_counter_ui() -> void:
	if aurion_label == null:
		return

	aurion_label.text = (
		"Aurion  |  Player "
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
	parry_pit_root = get_node_or_null("ParryPit") as Node3D

	if parry_pit_root == null:
		log_msg("ParryPit node is missing. Add a Node3D named ParryPit under Battlefield3D.")
		return

	parry_pit_glow = parry_pit_root.get_node_or_null("ParryPitGlow") as Node3D
	parry_dp_counter = parry_pit_root.get_node_or_null("ParryDPCounter")
	parry_pit_drop_area = parry_pit_root.get_node_or_null("ParryPitDropArea") as Area3D
	parry_sacrifice_stack_root = parry_pit_root.get_node_or_null("ParrySacrificeStack") as Node3D

	if parry_pit_glow == null:
		log_msg("ParryPitGlow is missing under ParryPit.")

	if parry_dp_counter == null:
		log_msg("ParryDPCounter is missing under ParryPit.")

	if parry_pit_drop_area == null:
		log_msg("ParryPitDropArea is missing under ParryPit.")

	if parry_sacrifice_stack_root == null:
		parry_sacrifice_stack_root = Node3D.new()
		parry_sacrifice_stack_root.name = "ParrySacrificeStack"
		parry_sacrifice_stack_root.position = Vector3(0, 0.08, 0)
		parry_pit_root.add_child(parry_sacrifice_stack_root)

	set_parry_pit_visible(false)
	clear_visible_parry_sacrifice_cards()
	update_parry_counter_label()
	
func set_parry_pit_visible(is_visible: bool) -> void:
	if parry_pit_root != null:
		parry_pit_root.visible = is_visible

	if parry_pit_drop_area != null:
		parry_pit_drop_area.input_ray_pickable = is_visible
	
	
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

	set_parry_pit_visible(true)

	if parry_prompt_panel != null:
		parry_prompt_panel.visible = true

	if parry_prompt_label != null:
		parry_prompt_label.text = (
			"Your "
			+ defender_card.card_name
			+ " is being attacked by "
			+ attacker_card.card_name
			+ ".\nDrop hand cards into the glowing pit to gather DP."
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
	if parry_dp_counter == null:
		return

	var counter_text := str(parry_gathered_dp) + "/" + str(parry_required_dp) + " DP"

	if parry_dp_counter is Label3D:
		var label_3d := parry_dp_counter as Label3D
		label_3d.text = counter_text

		if parry_active and parry_gathered_dp >= parry_required_dp:
			label_3d.modulate = Color(0.45, 1.0, 0.45, 1.0)
		elif parry_active:
			label_3d.modulate = Color(1.0, 0.88, 0.45, 1.0)
		else:
			label_3d.modulate = Color(1.0, 1.0, 1.0, 1.0)

		return

	if parry_dp_counter is Label:
		var label := parry_dp_counter as Label
		label.text = counter_text
		return
		
		
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
	
func _on_parry_let_die_pressed() -> void:
	if not parry_active:
		return

	if parry_defender_slot != null:
		send_slot_card_to_discard(parry_defender_slot)

	if parry_defender_card != null:
		log_msg("You let " + parry_defender_card.card_name + " die.")

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
	set_parry_pit_visible(false)

	if parry_prompt_panel != null:
		parry_prompt_panel.visible = false

	update_parry_counter_label()
		
		
	
	
	
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
	style.bg_color = Color(0.02, 0.02, 0.025, 0.92)
	style.border_color = Color(0.75, 0.55, 1.0, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	spell_choice_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	spell_choice_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	spell_choice_label = Label.new()
	spell_choice_label.text = "Place gambit as:"
	spell_choice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spell_choice_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(spell_choice_label)

	var face_up_button := Button.new()
	face_up_button.text = "Front Row: immediate"
	face_up_button.focus_mode = Control.FOCUS_NONE
	face_up_button.pressed.connect(_on_spell_face_up_pressed)
	vbox.add_child(face_up_button)

	var face_down_button := Button.new()
	face_down_button.text = "Back Row: hidden setup"
	face_down_button.focus_mode = Control.FOCUS_NONE
	face_down_button.pressed.connect(_on_spell_face_down_pressed)
	vbox.add_child(face_down_button)

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(_on_spell_choice_cancel_pressed)
	vbox.add_child(cancel_button)

	$UI.add_child(spell_choice_panel)
	
func create_phase_ui() -> void:
	phase_panel = PanelContainer.new()
	phase_panel.name = "PhasePanel"
	phase_panel.anchor_left = 0.5
	phase_panel.anchor_right = 0.5
	phase_panel.anchor_top = 0.0
	phase_panel.anchor_bottom = 0.0
	phase_panel.offset_left = -210.0
	phase_panel.offset_right = 210.0
	phase_panel.offset_top = 20.0
	phase_panel.offset_bottom = 178.0

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
	vbox.add_theme_constant_override("separation", 7)
	margin.add_child(vbox)

	phase_label = Label.new()
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(phase_label)

	aurion_label = Label.new()
	aurion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aurion_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(aurion_label)

	next_phase_button = Button.new()
	next_phase_button.focus_mode = Control.FOCUS_NONE
	next_phase_button.pressed.connect(_on_next_phase_pressed)
	vbox.add_child(next_phase_button)

	$UI.add_child(phase_panel)
	update_phase_ui()
	update_aurion_counter_ui()

func create_ability_prompt_panel() -> void:
	ability_prompt_panel = AbilityPromptPanel.new()
	ability_prompt_panel.ability_choice_made.connect(_on_ability_choice_made)
	$UI.add_child(ability_prompt_panel)

func _on_ability_choice_made(use_ability: bool, card_data: CardData, ability_text: String) -> void:
	if card_data == null:
		return
	if use_ability:
		log_msg("Used chosen ability: " + card_data.card_name)
		log_msg(ability_text)
	else:
		log_msg("Skipped chosen ability: " + card_data.card_name)

func set_phase(new_phase: int) -> void:
	current_phase = new_phase
	update_phase_ui()
	update_slot_highlights()
	match current_phase:
		BattlePhase.BATTLEPLAN:
			log_msg("Phase: Battleplan")
		BattlePhase.TRIBUTE:
			begin_tribute_phase()
		BattlePhase.DEPLOYMENT:
			begin_deployment_phase()
		BattlePhase.COMBAT:
			begin_combat_phase()
			
func begin_tribute_phase() -> void:
	log_msg("Phase: Tribute")

	if tribute_manager != null:
		tribute_manager.start_new_turn_refresh()
		update_tribute_counter()

	if not ai_has_starting_hand:
		ensure_ai_game_started()
	
func begin_deployment_phase() -> void:
	log_msg("Phase: Deployment")

	ensure_ai_game_started()

	if player_has_initiative:
		log_msg("Player has initiative and deploys first.")
		return

	log_msg("Opponent has initiative and deploys first.")
	ai_take_deployment_turn()
	
	
func begin_combat_phase() -> void:
	reset_combat_state()

	if player_has_initiative:
		log_msg("Phase: Combat. Player has first action.")
	else:
		log_msg("Phase: Combat. Opponent has first action.")
		ai_take_combat_turn()
		
func update_phase_ui() -> void:
	if phase_label == null or next_phase_button == null:
		return
	match current_phase:
		BattlePhase.BATTLEPLAN:
			phase_label.text = "BATTLEPLAN PHASE"
			next_phase_button.text = "Choose Battleplan"
		BattlePhase.TRIBUTE:
			phase_label.text = "TRIBUTE PHASE"
			next_phase_button.text = "Go to Deployment"
		BattlePhase.DEPLOYMENT:
			phase_label.text = "DEPLOYMENT PHASE"
			next_phase_button.text = "Go to Combat"
		BattlePhase.COMBAT:
			phase_label.text = "COMBAT PHASE"
			next_phase_button.text = "End Combat / Next Round"
			
			
func _on_next_phase_pressed() -> void:
	match current_phase:
		BattlePhase.BATTLEPLAN:
			open_battle_plan_selection()
		BattlePhase.TRIBUTE:
			set_phase(BattlePhase.DEPLOYMENT)
		BattlePhase.DEPLOYMENT:
			if not player_has_initiative:
				set_phase(BattlePhase.COMBAT)
				return

			ai_take_deployment_turn()
			set_phase(BattlePhase.COMBAT)
		BattlePhase.COMBAT:
			if player_has_initiative:
				ai_take_combat_turn()

			start_next_round()
			
func start_next_round() -> void:
	if battle_plan_manager != null:
		battle_plan_manager.advance_round()

	cancel_selected_card()
	clear_pending_spell_placement()
	end_parry_prompt()
	cleanup_battlefield_spells()
	open_battle_plan_selection()

func reset_combat_state() -> void:
	combat_direction_selected = false
	combat_lane_order.clear()
	combat_next_lane_index = 0

func connect_all_slots() -> void:
	if board_slots == null:
		return
	for slot in board_slots.get_children():
		if slot.has_signal("slot_clicked"):
			slot.slot_clicked.connect(_on_slot_clicked)
		if slot.has_signal("slot_right_clicked"):
			slot.slot_right_clicked.connect(_on_slot_right_clicked)

func _on_hand_card_drag_started(card: CardUI) -> void:
	if waiting_for_battle_plan or card == null:
		return
	select_card(card.card_data)

func _on_hand_card_drag_released(card: CardUI, screen_position: Vector2) -> void:
	if card == null:
		return

	var target_node := get_3d_node_under_screen_position(screen_position)
	var target_slot := find_board_slot_from_node(target_node)

	if parry_active and is_node_inside_target(target_node, parry_pit_drop_area):
		sacrifice_card_to_parry(card)
		return

	if target_slot != null:
		if current_phase != BattlePhase.DEPLOYMENT:
			log_msg("Cards can only be deployed during the Deployment Phase.")
			return_card_to_hand_safely(card)
			cancel_selected_card()
			return

		if not has_selected_card or selected_card_data == null:
			return_card_to_hand_safely(card)
			cancel_selected_card()
			return

		if is_spell_like_card(selected_card_data):
			var slot_row: String = target_slot.get_meta("row", "")

			if slot_row == "front":
				var front_spell_placed: bool = try_place_selected_card_on_slot(target_slot)

				if front_spell_placed:
					play_player_hand_to_node_animation(selected_card_data, target_slot, false)
					hand.consume_dragged_card(card)
				else:
					return_card_to_hand_safely(card)

				cancel_selected_card()
				return

			if slot_row == "back":
				show_spell_choice_panel(card, target_slot)
				return

			log_msg("Invalid gambit placement row.")
			return_card_to_hand_safely(card)
			cancel_selected_card()
			return

		var placed := try_place_selected_card_on_slot(target_slot)

		if placed:
			play_player_hand_to_node_animation(selected_card_data, target_slot, false)
			hand.consume_dragged_card(card)
		else:
			return_card_to_hand_safely(card)

		cancel_selected_card()
		return

	if is_node_inside_target(target_node, tribute_pile):
		if current_phase != BattlePhase.TRIBUTE:
			log_msg("Cards can only be sent to Tribute during the Tribute Phase.")
			return_card_to_hand_safely(card)
			cancel_selected_card()
			return
		var sacrificed := try_sacrifice_selected_card_to_tribute()
		if sacrificed:
			hand.consume_dragged_card(card)
		else:
			return_card_to_hand_safely(card)
		cancel_selected_card()
		return

	log_msg("Card dropped nowhere valid.")
	return_card_to_hand_safely(card)
	cancel_selected_card()
	
	
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


func return_card_to_hand_safely(card: CardUI) -> void:
	if hand == null:
		return

	if card == null:
		return

	if not is_instance_valid(card):
		return

	hand.return_dragged_card_to_hand(card)
	
	
func clear_pending_spell_placement() -> void:
	if pending_spell_card_ui != null:
		return_card_to_hand_safely(pending_spell_card_ui)

	hide_spell_choice_panel()

func deal_starting_hand() -> void:
	if hand == null or player_deck == null:
		log_msg("Hand or PlayerDeck is missing.")
		return
	for i in range(5):
		var drawn_card: CardData = player_deck.draw_top_card()
		if drawn_card == null:
			return
		hand.add_card_to_hand(drawn_card, false)
	if draw_pile != null:
		draw_pile.set_card_count(player_deck.cards_remaining())
	log_msg("Starting hand dealt. Deck remaining: " + str(player_deck.cards_remaining()))

func _on_draw_pile_drag_started(screen_position: Vector2) -> void:
	if waiting_for_battle_plan:
		return
	if current_phase == BattlePhase.DEPLOYMENT or current_phase == BattlePhase.COMBAT:
		log_msg("You cannot draw cards after Deployment has begun.")
		return
	if hand == null or player_deck == null:
		return
	if not hand.can_accept_card():
		log_msg("Hand is full. Max hand size: " + str(hand.max_hand_size))
		return
	var preview_card: CardData = player_deck.peek_top_card()
	var started: bool = hand.start_draw_pile_drag(screen_position, preview_card)
	if started:
		log_msg("Dragging card from Draw Pile.")
	else:
		log_msg("Draw Pile is empty.")

func _on_draw_pile_drag_moved(screen_position: Vector2) -> void:
	if hand != null:
		hand.update_draw_pile_drag(screen_position)

func _on_draw_pile_drag_released(screen_position: Vector2) -> void:
	if hand == null or player_deck == null:
		return
	if not hand.is_screen_position_in_hand_drop_zone(screen_position):
		hand.finish_draw_pile_drag(screen_position, null)
		return
	if not hand.can_accept_card():
		hand.finish_draw_pile_drag(screen_position, null)
		log_msg("Draw cancelled. Hand is full. Max hand size: " + str(hand.max_hand_size))
		return
	var drawn_card: CardData = player_deck.draw_top_card()
	var accepted: bool = hand.finish_draw_pile_drag(screen_position, drawn_card)
	if accepted:
		draw_pile.consume_top_card()
		log_msg("Card drawn into hand. Deck remaining: " + str(player_deck.cards_remaining()))

func _on_slot_clicked(slot: Node) -> void:
	if current_phase == BattlePhase.COMBAT:
		handle_combat_lane_click(slot)
		return
	if current_phase != BattlePhase.DEPLOYMENT:
		log_msg("Cards can only be deployed during the Deployment Phase.")
		return
	var placed := try_place_selected_card_on_slot(slot)
	if placed:
		if hand != null:
			hand.remove_selected_card()
		cancel_selected_card()

func _on_slot_right_clicked(_slot: Node) -> void:
	log_msg("Manual battlefield clearing is disabled. Cards leave the board only through combat, cleanup, or abilities.")

func _on_tribute_pile_clicked() -> void:
	if waiting_for_battle_plan:
		return
	if current_phase != BattlePhase.TRIBUTE:
		log_msg("Tribute pile is only active during the Tribute Phase.")
		return
	if not has_selected_card:
		log_msg("Drag a card from your hand to the Tribute Pile.")
		return
	var sacrificed := try_sacrifice_selected_card_to_tribute()
	if sacrificed:
		if hand != null:
			hand.remove_selected_card()
		cancel_selected_card()

func _input(event: InputEvent) -> void:
	if waiting_for_battle_plan:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			select_card(ARCH_WIZARD_MAELCOR)
		if event.keycode == KEY_2:
			select_card(IMPERIAL_ARCHIVE_MASTER)
		if event.keycode == KEY_3:
			select_card(JENA_OF_YEL)
		if event.keycode == KEY_4:
			select_card(IVAAN_THE_BONE_CRUSHER)
		if event.keycode == KEY_5:
			select_card(UPPER_HALL_PROSPECTOR)
		if event.keycode == KEY_6:
			select_card(VAELORI_LONGBOW_M)
		if event.keycode == KEY_7:
			select_card(BLACKMAIL)
		if event.keycode == KEY_ESCAPE:
			cancel_selected_card()
		if event.keycode == KEY_E:
			_on_next_phase_pressed()
		if event.keycode == KEY_T:
			debug_tribute_selected_card()
		if event.keycode == KEY_Y:
			tribute_manager.refresh_tribute_points()
		if event.keycode == KEY_D and hand != null:
			debug_draw_card()

func debug_draw_card() -> void:
	if current_phase == BattlePhase.DEPLOYMENT or current_phase == BattlePhase.COMBAT:
		log_msg("You cannot draw cards after Deployment has begun.")
		return
	if player_deck == null or not hand.can_accept_card():
		return
	var drawn_card: CardData = player_deck.draw_top_card()
	if drawn_card == null:
		return
	hand.add_card_to_hand(drawn_card)
	if draw_pile != null:
		draw_pile.consume_top_card()

func debug_tribute_selected_card() -> void:
	if selected_card_data == null:
		return
	if tribute_manager != null and not tribute_manager.can_offer_card_this_turn():
		log_msg("Tribute already used this turn. Only 1 card can be used as Tribute per turn.")
		return
	tribute_manager.offer_card_to_tribute(selected_card_data)
	log_msg("Debug tributed: " + selected_card_data.card_name + ". " + tribute_manager.get_status_text())

func select_card(card_data: CardData) -> void:
	if card_data == null:
		return
	selected_card_scene = TEST_CARD_SCENE
	selected_card_data = card_data
	has_selected_card = true
	log_msg("Selected: " + card_data.card_name + " | TP " + str(card_data.tribute_cost) + " | " + card_data.card_type)
	update_slot_highlights()

func cancel_selected_card() -> void:
	selected_card_scene = null
	selected_card_data = null
	has_selected_card = false
	update_slot_highlights()
	
func get_clean_card_type(card_data: CardData) -> String:
	if card_data == null:
		return ""

	return card_data.card_type.to_lower().strip_edges()
	
func is_gambit_card(card_data: CardData) -> bool:
	var card_type: String = get_clean_card_type(card_data)

	return card_type == "gambit"
	

# Legacy wrapper so older call sites do not break during the rename.
func is_spell_like_card(card_data: CardData) -> bool:
	return is_gambit_card(card_data)
	

func is_equipment_card(card_data: CardData) -> bool:
	return get_clean_card_type(card_data) == "equipment"

func is_trap_card(_card_data: CardData) -> bool:
	return false


func is_ruse_card(_card_data: CardData) -> bool:
	return false


func is_event_card(_card_data: CardData) -> bool:
	return false


func is_spell_card(_card_data: CardData) -> bool:
	return false
	

func get_slot_card_data(slot: Node) -> CardData:
	if slot == null:
		return null
	if slot.has_method("get_placed_card_data"):
		return slot.get_placed_card_data()
	return null

func try_place_selected_card_on_slot(slot: Node) -> bool:
	if slot == null:
		return false
	var slot_id: String = slot.get_meta("slot_id", "")
	if not has_selected_card or selected_card_data == null:
		return false
	if not is_valid_slot_for_selected_card(slot):
		log_msg("Invalid placement for " + selected_card_data.card_name + " on " + str(slot_id))
		return false
	if not tribute_manager.can_afford(selected_card_data.tribute_cost):
		log_msg("Not enough Tribute Points. Need " + str(selected_card_data.tribute_cost) + ", have " + str(tribute_manager.current_tribute_points) + ".")
		return false
	var slot_row: String = slot.get_meta("row", "")
	var place_face_down: bool = false
	if is_spell_like_card(selected_card_data):
		# Front row gambits are always face up.
		# Back row gambits should normally come through confirm_pending_spell_placement().
		place_face_down = slot_row == "back"
	elif slot_row == "back":
		place_face_down = true
	var placed_successfully: bool = slot.place_card(selected_card_scene, selected_card_data, place_face_down)
	if placed_successfully:
		tribute_manager.spend_tribute(selected_card_data.tribute_cost)
		log_msg("Spent " + str(selected_card_data.tribute_cost) + " TP. " + tribute_manager.get_status_text())
		handle_card_deployed(selected_card_data)
		return true
	return false

func try_sacrifice_selected_card_to_tribute() -> bool:
	if not has_selected_card or selected_card_data == null:
		return false
	if tribute_manager != null and not tribute_manager.can_offer_card_this_turn():
		log_msg("Tribute already used this turn. Only 1 card can be used as Tribute per turn.")
		return false
	var sacrificed_card_name := selected_card_data.card_name
	var sacrificed_card_type := get_clean_card_type(selected_card_data)
	var tribute_success: bool = tribute_manager.offer_card_to_tribute(selected_card_data)
	if not tribute_success:
		return false
	if tribute_pile != null:
		tribute_pile.add_card(selected_card_data)
	if sacrificed_card_type == "gambit":
		log_msg("Sacrificed " + sacrificed_card_name + " for temporary Tribute. +2 TP this turn.")
	else:
		log_msg("Sacrificed " + sacrificed_card_name + " for permanent Tribute. +1 permanent TP.")
	return true

func is_valid_slot_for_selected_card(slot: Node) -> bool:
	if current_phase != BattlePhase.DEPLOYMENT:
		return false
	if not has_selected_card or selected_card_data == null:
		return false
	if slot.get_meta("owner", "") != "player":
		return false
	if slot.occupied:
		return false
	var slot_row: String = slot.get_meta("row", "")
	if is_equipment_card(selected_card_data):
		if slot_row != "front":
			return false
		if not slot.has_method("has_unit_card") or not slot.has_unit_card():
			return false
		return true
	if is_spell_like_card(selected_card_data):
		return slot_row == "front" or slot_row == "back"
	if slot_row != "front":
		return false
	return true

func update_slot_highlights() -> void:
	if board_slots == null:
		return
	for slot in board_slots.get_children():
		if not slot.has_method("set_highlight") or not slot.has_method("set_invalid_highlight"):
			continue
		if not has_selected_card or current_phase != BattlePhase.DEPLOYMENT:
			slot.set_highlight(false)
			slot.set_invalid_highlight(false)
			continue
		if is_valid_slot_for_selected_card(slot):
			slot.set_highlight(true)
		else:
			slot.set_invalid_highlight(true)

func handle_card_deployed(card_data: CardData) -> void:
	if card_data == null:
		return

	var ability_text_lower: String = card_data.ability_text.to_lower()

	if ability_text_lower == "":
		return

	if is_spell_like_card(card_data):
		resolve_gambit_on_play(card_data)
		return

	if is_equipment_card(card_data):
		log_msg("Equipment attached: " + card_data.card_name)
		return

	if ability_text_lower.contains("on deploy") or ability_text_lower.contains("when deployed"):
		if ability_requires_choice(card_data):
			if ability_prompt_panel != null:
				ability_prompt_panel.show_for_card(card_data)
		else:
			log_msg("On-deploy ability triggered: " + card_data.card_name)
			log_msg(card_data.ability_text)
		return

	log_msg("Passive ability active: " + card_data.card_name)

func ability_requires_choice(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var ability_text_lower: String = card_data.ability_text.to_lower()
	return ability_text_lower.contains("volley") or ability_text_lower.contains("may ") or ability_text_lower.contains("choose")
	
func resolve_gambit_on_play(card_data: CardData) -> void:
	if card_data == null:
		return

	log_msg("Gambit played: " + card_data.card_name)

	var ability_text_lower: String = card_data.ability_text.to_lower()

	if ability_text_lower.contains("opponent discards"):
		ai_discard_random_hand_card()

	if ability_text_lower.contains("loses 1 aurion") or ability_text_lower.contains("lose 1 aurion"):
		ai_aurion_points = max(0, ai_aurion_points - 1)
		update_aurion_counter_ui()
		log_msg("AI loses 1 Aurion.")

	if ability_text_lower.contains("cannot attack"):
		log_msg(card_data.card_name + " effect noted: target cannot attack this turn. Targeting will be added later.")

func cleanup_battlefield_spells() -> void:
	if board_slots == null:
		return

	for slot in board_slots.get_children():
		var card_data: CardData = get_slot_card_data(slot)

		if card_data == null:
			continue

		if not is_spell_like_card(card_data):
			continue

		send_slot_card_to_discard(slot)
		log_msg("Gambit resolved and moved to discard: " + card_data.card_name)


func ai_discard_random_hand_card() -> void:
	if ai_hand.is_empty():
		log_msg("AI has no cards to discard.")
		return

	var index: int = randi() % ai_hand.size()
	var discarded_card: CardData = ai_hand[index]
	ai_hand.remove_at(index)
	ai_discard.append(discarded_card)
	update_ai_visuals()
	log_msg("AI discarded: " + discarded_card.card_name)
	

func spawn_random_opponent_cards() -> void:
	if board_slots == null:
		return
	var opponent_front_slots: Array[Node] = []
	for slot in board_slots.get_children():
		if slot.get_meta("owner", "") == "enemy" and slot.get_meta("row", "") == "front" and not slot.occupied:
			opponent_front_slots.append(slot)
	opponent_front_slots.shuffle()
	for slot in opponent_front_slots:
		var card_data: CardData = get_random_opponent_test_card()
		if card_data != null:
			slot.place_card(TEST_CARD_SCENE, card_data, false)
			log_msg("Spawned opponent test card: " + card_data.card_name)

func get_random_opponent_test_card() -> CardData:
	if OPPONENT_TEST_CARDS.is_empty():
		return null
	var index: int = randi() % OPPONENT_TEST_CARDS.size()
	return OPPONENT_TEST_CARDS[index]

func handle_combat_lane_click(slot: Node) -> void:
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
	if combat_next_lane_index >= combat_lane_order.size():
		return

	var expected_lane: String = combat_lane_order[combat_next_lane_index]

	if clicked_lane != expected_lane:
		log_msg("Next combat must resolve in the " + expected_lane + " lane.")
		return

	var player_slot := find_slot_by_owner_row_lane("player", "front", expected_lane)
	var opponent_slot := find_slot_by_owner_row_lane("enemy", "front", expected_lane)

	resolve_lane_combat(expected_lane, player_slot, opponent_slot)

	# If no Parry prompt is active, the lane fully resolved immediately.
	if not parry_active:
		advance_combat_lane_after_resolution()
		
func advance_combat_lane_after_resolution() -> void:
	combat_next_lane_index += 1

	if combat_next_lane_index >= combat_lane_order.size():
		log_msg("All combat lanes resolved. Press End Combat / Next Round when ready.")
		return

	log_msg("Next combat lane: " + combat_lane_order[combat_next_lane_index])


func resolve_lane_combat(lane: String, player_slot: Node, opponent_slot: Node) -> void:
	var player_card: CardData = get_slot_card_data(player_slot)
	var opponent_card: CardData = get_slot_card_data(opponent_slot)

	if player_card == null and opponent_card == null:
		log_msg(lane.capitalize() + " lane: no combat.")
		award_empty_lane_aurion(lane)
		return

	if player_card != null and opponent_card == null:
		log_msg(lane.capitalize() + " lane: " + player_card.card_name + " has no opposing target.")
		award_empty_lane_aurion(lane)
		return

	if player_card == null and opponent_card != null:
		log_msg(lane.capitalize() + " lane: opponent " + opponent_card.card_name + " has no player target.")
		award_empty_lane_aurion(lane)
		return

	if player_has_initiative:
		resolve_directed_clash(lane, player_slot, player_card, opponent_slot, opponent_card, true)
	else:
		resolve_directed_clash(lane, opponent_slot, opponent_card, player_slot, player_card, false)


func award_empty_lane_aurion(lane: String) -> void:
	var player_back_slot: Node = find_slot_by_owner_row_lane("player", "back", lane)
	var enemy_back_slot: Node = find_slot_by_owner_row_lane("enemy", "back", lane)

	var player_back_card: CardData = get_slot_card_data(player_back_slot)
	var enemy_back_card: CardData = get_slot_card_data(enemy_back_slot)

	if player_back_card != null:
		add_aurion("player", 1, "Back-row hold in " + lane + " lane.")

	if enemy_back_card != null:
		add_aurion("enemy", 1, "Enemy back-row hold in " + lane + " lane.")
		
		
func resolve_directed_clash(
	lane: String,
	first_slot: Node,
	first_card: CardData,
	second_slot: Node,
	second_card: CardData,
	player_is_first: bool
) -> void:
	if first_card == null or second_card == null:
		return

	var first_label := "Player"
	var second_label := "Opponent"

	if not player_is_first:
		first_label = "Opponent"
		second_label = "Player"

	log_msg(
		lane.capitalize()
		+ " lane clash: "
		+ first_label
		+ " "
		+ first_card.card_name
		+ " AP "
		+ str(first_card.ap)
		+ " vs "
		+ second_label
		+ " "
		+ second_card.card_name
		+ " DP "
		+ str(second_card.dp)
	)

	if first_card.ap >= second_card.dp:
		send_slot_card_to_discard(second_slot)
		log_msg(second_label + " " + second_card.card_name + " removed from board.")
		return

	log_msg(second_label + " " + second_card.card_name + " survives. Parry window opens.")
	begin_parry_prompt(lane, first_slot, first_card, second_slot, second_card)
	
func get_slot_card_data(slot: Node) -> CardData:
	if slot == null:
		return null
	if slot.has_method("get_placed_card_data"):
		return slot.get_placed_card_data()
	return null

func find_slot_by_owner_row_lane(owner_name: String, row: String, lane: String) -> Node:
	for slot in board_slots.get_children():
		if slot.get_meta("owner", "") == owner_name and slot.get_meta("row", "") == row and get_slot_lane(slot) == lane:
			return slot
	return null

func get_slot_lane(slot: Node) -> String:
	var slot_id := str(slot.get_meta("slot_id", "")).to_lower()
	if slot_id.contains("left"):
		return "left"
	if slot_id.contains("middle"):
		return "middle"
	if slot_id.contains("right"):
		return "right"
	var column: String = slot.get_meta("column", "")
	if column == "left" or column == "middle" or column == "right":
		return column
	return ""

func send_slot_card_to_discard(slot: Node) -> void:
	if slot == null:
		return
	var card_data: CardData = get_slot_card_data(slot)
	var slot_owner: String = str(slot.get_meta("owner", ""))

	if card_data != null:
		play_card_to_discard_animation(card_data, slot, slot_owner)

		if discard_pile != null and slot_owner != "enemy":
			discard_pile.add_card(card_data)

		if slot_owner == "enemy":
			ai_discard.append(card_data)
			update_ai_visuals()

	if slot.has_method("clear_slot"):
		slot.clear_slot()
		
func get_3d_node_under_screen_position(screen_position: Vector2) -> Node:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
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

func _on_tribute_changed(_status_text: String) -> void:
	update_tribute_counter()

func update_tribute_counter() -> void:
	if tribute_pile == null or tribute_manager == null:
		return
	if tribute_pile.has_method("set_status_text"):
		tribute_pile.set_status_text(tribute_manager.get_counter_text())
		
func update_draw_pile_counter() -> void:
	if draw_pile == null or player_deck == null:
		return

	if draw_pile.has_method("set_card_count"):
		draw_pile.set_card_count(player_deck.cards_remaining())


func ensure_ai_game_started() -> void:
	if ai_has_starting_hand:
		return
	setup_ai_deck()
	ai_draw_cards(5)
	ai_has_starting_hand = true
	log_msg("Opponent starting hand prepared: " + str(ai_hand.size()) + " cards.")
	

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

	var pool: Array[CardData] = CardDatabase.get_ai_test_deck()

	for i in range(40):
		ai_deck.append(pool[i % pool.size()])

	ai_deck.shuffle()
	update_ai_visuals()
	
	
func ai_draw_cards(amount: int) -> void:
	for i in range(amount):
		if ai_deck.is_empty():
			break
		var card: CardData = ai_deck.pop_back()
		ai_hand.append(card)
		log_msg("Opponent drew a card. Opponent hand: " + str(ai_hand.size()))

	update_ai_visuals()
	
func ai_draw_battleplan_cards(plan: Dictionary) -> void:
	var draw_amount: int = int(plan.get("draw_amount", 0))

	if draw_amount <= 0:
		return

	ai_draw_cards(draw_amount)
	log_msg("Opponent battleplan draw: " + str(draw_amount) + " cards.")

func ai_start_tribute_phase() -> void:
	ai_current_perm_tp = ai_perm_tp
	ai_temp_tp = 0
	ai_current_tp = ai_current_perm_tp
	ai_tribute_used_this_turn = false

func ai_offer_card_to_tribute(card_index: int) -> bool:
	if ai_tribute_used_this_turn:
		return false

	if card_index < 0 or card_index >= ai_hand.size():
		return false

	var card_data: CardData = ai_hand[card_index]
	ai_hand.remove_at(card_index)
	ai_tribute.append(card_data)
	ai_tribute_used_this_turn = true

	if is_spell_like_card(card_data):
		ai_temp_tp += 2
		ai_current_tp += 2
		log_msg("Opponent tributed a gambit for +2 temporary TP.")
	else:
		ai_perm_tp += 1
		ai_current_perm_tp += 1
		ai_current_tp += 1
		log_msg("Opponent tributed a card for +1 permanent TP.")

	update_ai_visuals()
	return true
	
	
func ai_get_affordable_card_indexes() -> Array[int]:
	var indexes: Array[int] = []

	for i in range(ai_hand.size()):
		var card: CardData = ai_hand[i]

		if card == null:
			continue

		if card.tribute_cost <= ai_current_tp:
			indexes.append(i)

	return indexes

func ai_choose_tribute_card_index() -> int:
	if ai_hand.is_empty():
		return -1

	var best_index: int = 0
	var best_score: int = 999999

	for i in range(ai_hand.size()):
		var card: CardData = ai_hand[i]

		if card == null:
			continue

		var score: int = 0

		if is_spell_like_card(card):
			score += 1
		else:
			score += 5

		score += card.ap
		score += card.dp
		score += card.tribute_cost

		if score < best_score:
			best_score = score
			best_index = i

	return best_index

func ai_take_tribute_turn() -> void:
	ai_start_tribute_phase()

	var tribute_index: int = ai_choose_tribute_card_index()

	if tribute_index != -1:
		ai_offer_card_to_tribute(tribute_index)

	update_ai_visuals()
	
func ai_choose_empty_front_slot() -> Node:
	var available_slots: Array[Node] = []

	for slot in board_slots.get_children():
		if slot.get_meta("owner", "") != "enemy":
			continue

		if slot.get_meta("row", "") != "front":
			continue

		if slot.occupied:
			continue

		available_slots.append(slot)

	if available_slots.is_empty():
		return null

	available_slots.shuffle()
	return available_slots[0]
	
func ai_choose_empty_back_slot_for_tactic(_card_data: CardData) -> Node:
	var available_slots: Array[Node] = []

	for slot in board_slots.get_children():
		if slot.get_meta("owner", "") != "enemy":
			continue

		if slot.get_meta("row", "") != "back":
			continue

		if slot.occupied:
			continue

		available_slots.append(slot)

	if available_slots.is_empty():
		return null

	available_slots.shuffle()
	return available_slots[0]
	
func ai_choose_spell_like_slot(card_data: CardData) -> Node:
	if card_data == null:
		return null

	var front_units: int = ai_count_front_units("enemy")
	var player_units: int = ai_count_front_units("player")

	if player_units > front_units:
		var back_slot: Node = ai_choose_empty_back_slot_for_tactic(card_data)

		if back_slot != null:
			return back_slot

	var front_slot: Node = ai_choose_empty_front_slot()

	if front_slot != null:
		return front_slot

	return ai_choose_empty_back_slot_for_tactic(card_data)


func ai_choose_equipment_target_slot(_card_data: CardData) -> Node:
	var possible_slots: Array[Node] = []

	for slot in board_slots.get_children():
		if slot.get_meta("owner", "") != "enemy":
			continue

		if slot.get_meta("row", "") != "front":
			continue

		if not slot.occupied:
			continue

		if not slot.has_method("has_unit_card") or not slot.has_unit_card():
			continue

		possible_slots.append(slot)

	if possible_slots.is_empty():
		return null

	possible_slots.shuffle()
	return possible_slots[0]
	
func ai_choose_slot_for_card(card_data: CardData) -> Node:
	if card_data == null:
		return null

	if is_equipment_card(card_data):
		return ai_choose_equipment_target_slot(card_data)

	if is_gambit_card(card_data):
		return ai_choose_spell_like_slot(card_data)

	return ai_choose_empty_front_slot()
	
	
func ai_make_deployment_action(card_index: int, target_slot: Node, action_type: String, face_down: bool = false) -> Dictionary:
	var card_data: CardData = null

	if card_index >= 0 and card_index < ai_hand.size():
		card_data = ai_hand[card_index]

	return {
		"card_index": card_index,
		"target_slot": target_slot,
		"action_type": action_type,
		"face_down": face_down,
		"card_data": card_data
	}
	
func ai_score_deploy_card(card_data: CardData, target_slot: Node) -> int:
	if card_data == null:
		return -999999

	if target_slot == null:
		return -999999

	var score: int = 0
	var card_type: String = get_clean_card_type(card_data)

	match card_type:
		"unit":
			score += 40
			score += card_data.ap * 3
			score += card_data.dp * 2

		"equipment":
			score += 30
			score += card_data.ap * 2
			score += card_data.dp * 2

		"gambit":
			score += 35

		_:
			score += 5

	score -= card_data.tribute_cost * 2

	var slot_row: String = target_slot.get_meta("row", "")

	if card_type == "unit" and slot_row == "front":
		score += 10

	if card_type == "equipment" and slot_row == "front":
		score += 10

	if card_type == "gambit" and slot_row == "back":
		score += 10

	return score
	
	
func ai_find_best_deployment_action() -> Dictionary:
	var affordable_indexes: Array[int] = ai_get_affordable_card_indexes()

	if affordable_indexes.is_empty():
		return ai_make_deployment_action(-1, null, "none")

	var best_action: Dictionary = ai_make_deployment_action(-1, null, "none")
	var best_score: int = -999999

	for card_index in affordable_indexes:
		var card_data: CardData = ai_hand[card_index]
		var target_slot: Node = ai_choose_slot_for_card(card_data)

		if target_slot == null:
			continue

		var score: int = ai_score_deploy_card(card_data, target_slot)

		if score > best_score:
			best_score = score
			best_action = ai_make_deployment_action(
				card_index,
				target_slot,
				get_clean_card_type(card_data),
				target_slot.get_meta("row", "") == "back"
			)

	return best_action

func ai_deploy_card_from_action(action: Dictionary) -> bool:
	var card_index: int = int(action.get("card_index", -1))
	var target_slot: Node = action.get("target_slot", null)
	var action_type: String = str(action.get("action_type", "none"))
	var face_down: bool = bool(action.get("face_down", false))

	if action_type == "none":
		return false

	if target_slot == null:
		return false

	if card_index < 0 or card_index >= ai_hand.size():
		return false

	var card_data: CardData = ai_hand[card_index]

	if card_data == null:
		return false

	if card_data.tribute_cost > ai_current_tp:
		return false

	if action_type == "equipment":
		if not target_slot.has_method("attach_equipment"):
			return false

		if not target_slot.attach_equipment(TEST_CARD_SCENE, card_data):
			return false

		ai_current_tp -= card_data.tribute_cost
		ai_hand.remove_at(card_index)
		update_ai_visuals()

		log_msg("Opponent attached equipment: " + card_data.card_name)
		return true

	if action_type == "unit" or action_type == "gambit":
		var placed: bool = target_slot.place_card(TEST_CARD_SCENE, card_data, face_down)

		if not placed:
			return false

		ai_current_tp -= card_data.tribute_cost
		ai_hand.remove_at(card_index)
		update_ai_visuals()

		if action_type == "gambit":
			log_msg("Opponent set a gambit.")
		else:
			log_msg("Opponent deployed: " + card_data.card_name)

		return true

	return false

func ai_take_deployment_turn() -> void:
	var deployments_made: int = 0

	while deployments_made < ai_max_deployments_per_phase:
		var action: Dictionary = ai_find_best_deployment_action()

		if str(action.get("action_type", "none")) == "none":
			break

		if not ai_deploy_card_from_action(action):
			break

		deployments_made += 1

	if deployments_made == 0:
		log_msg("Opponent has no valid deployment.")
	else:
		log_msg("Opponent deployment complete: " + str(deployments_made) + " card(s).")
		
func ai_count_front_units(owner_name: String) -> int:
	var count: int = 0
	var lanes: Array[String] = ["left", "middle", "right"]

	for lane in lanes:
		var slot: Node = find_slot_by_owner_row_lane(owner_name, "front", lane)
		var card_data: CardData = get_slot_card_data(slot)

		if is_unit_card(card_data):
			count += 1

	return count
	
func ai_get_total_front_ap(owner_name: String) -> int:
	var total_ap: int = 0
	var lanes: Array[String] = ["left", "middle", "right"]

	for lane in lanes:
		var slot: Node = find_slot_by_owner_row_lane(owner_name, "front", lane)
		var card_data: CardData = get_slot_card_data(slot)

		if is_unit_card(card_data):
			total_ap += card_data.ap

	return total_ap

func ai_take_combat_turn() -> void:
	if current_phase != BattlePhase.COMBAT:
		return

	if combat_direction_selected:
		return

	var player_left_ap: int = 0
	var player_right_ap: int = 0

	var player_left_slot: Node = find_slot_by_owner_row_lane("player", "front", "left")
	var player_right_slot: Node = find_slot_by_owner_row_lane("player", "front", "right")

	var player_left_card: CardData = get_slot_card_data(player_left_slot)
	var player_right_card: CardData = get_slot_card_data(player_right_slot)

	if player_left_card != null:
		player_left_ap = player_left_card.ap

	if player_right_card != null:
		player_right_ap = player_right_card.ap

	if player_left_ap >= player_right_ap:
		set_combat_lane_order_from_left()
		resolve_next_combat_lane("left")
	else:
		set_combat_lane_order_from_right()
		resolve_next_combat_lane("right")

func is_unit_card(card_data: CardData) -> bool:
	return get_clean_card_type(card_data) == "unit"

func create_debug_tp_button() -> void:
	if get_node_or_null("UI/DebugAddTPButton") != null:
		return

	var button := Button.new()
	button.name = "DebugAddTPButton"
	button.text = "+1 TP"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(120, 44)

	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 0.0
	button.anchor_bottom = 0.0

	button.offset_left = -150.0
	button.offset_right = -20.0

	# Moved lower so it does not overlap the Player Status panel.
	button.offset_top = 265.0
	button.offset_bottom = 309.0

	button.pressed.connect(_on_debug_add_tp_pressed)
	$UI.add_child(button)


func _on_debug_add_tp_pressed() -> void:
	if tribute_manager == null:
		return
	tribute_manager.add_debug_tribute_points(1)
	update_tribute_counter()
	log_msg("Debug added +1 TP. " + tribute_manager.get_status_text())


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

	if not is_valid_slot_for_selected_card(pending_spell_slot):
		log_msg("Invalid placement for " + selected_card_data.card_name)
		hide_spell_choice_panel()
		cancel_selected_card()
		return

	if not tribute_manager.can_afford(selected_card_data.tribute_cost):
		log_msg("Not enough Tribute Points. Need " + str(selected_card_data.tribute_cost) + ", have " + str(tribute_manager.current_tribute_points) + ".")

		if pending_spell_card_ui != null:
			return_card_to_hand_safely(pending_spell_card_ui)

		hide_spell_choice_panel()
		cancel_selected_card()
		return

	var placed_successfully: bool = pending_spell_slot.place_card(TEST_CARD_SCENE, selected_card_data, place_face_down)

	if placed_successfully:
		tribute_manager.spend_tribute(selected_card_data.tribute_cost)
		log_msg("Spent " + str(selected_card_data.tribute_cost) + " TP. " + tribute_manager.get_status_text())

		if pending_spell_card_ui != null:
			play_player_hand_to_node_animation(selected_card_data, pending_spell_slot, place_face_down)
			hand.consume_dragged_card(pending_spell_card_ui)

		handle_card_deployed(selected_card_data)
	else:
		if pending_spell_card_ui != null:
			return_card_to_hand_safely(pending_spell_card_ui)

	hide_spell_choice_panel()
	cancel_selected_card()


func log_msg(message: String) -> void:
	if game_log != null and game_log.has_method("add_log"):
		game_log.add_log(message)
	else:
		print("LOG FALLBACK: " + message)
