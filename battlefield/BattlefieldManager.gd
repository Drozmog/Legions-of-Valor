class_name BattlefieldManager
extends Node3D

# Consolidated from BattlefieldManagerPhase.gd, BattlefieldManager.gd, and Phase 1-4 wrapper managers.
# After this file works, the wrapper manager scripts can be removed.

const TEST_CARD_SCENE: PackedScene = preload("res://cards/Card3D_Test.tscn")

const ARCH_WIZARD_MAELCOR: CardData = CardDatabase.ARCH_WIZARD_MAELCOR

const IMPERIAL_ARCHIVE_MASTER: CardData = CardDatabase.IMPERIAL_ARCHIVE_MASTER

const JENA_OF_YEL: CardData = CardDatabase.JENA_OF_YEL

const IVAAN_THE_BONE_CRUSHER: CardData = CardDatabase.IVAAN_THE_BONE_CRUSHER

const UPPER_HALL_PROSPECTOR: CardData = CardDatabase.UPPER_HALL_PROSPECTOR

const BLACKMAIL: CardData = CardDatabase.BLACKMAIL

const VAELORI_LONGBOW_M: CardData = CardDatabase.VAELORI_LONGBOW_M

const OPPONENT_TEST_CARDS: Array[CardData] = [
	ARCH_WIZARD_MAELCOR,
	IMPERIAL_ARCHIVE_MASTER,
	JENA_OF_YEL,
	IVAAN_THE_BONE_CRUSHER,
	UPPER_HALL_PROSPECTOR
]

enum BattlePhase { BATTLEPLAN, TRIBUTE, DEPLOYMENT, COMBAT }

@onready var board_slots: Node3D = $BoardSlots

@onready var game_log = $GameLog

@onready var tribute_manager: TributeManager = $TributeManager

@onready var battle_plan_manager: BattlePlanManager = get_node_or_null("BattlePlanManager") as BattlePlanManager

@onready var battle_plan_panel: BattlePlanPanel = get_node_or_null("UI/BattlePlanPanel") as BattlePlanPanel

@onready var battle_plan_selection_screen: BattlePlanSelectionScreen = get_node_or_null("UI/BattlePlanSelectionScreen") as BattlePlanSelectionScreen

@onready var discard_pile: DiscardPile = get_node_or_null("DiscardPile") as DiscardPile

@export var hand: HandUI

@export var draw_pile: DrawPile

@export var tribute_pile: TributePile

@export var player_deck: PlayerDeck

var selected_card_scene: PackedScene = null

var selected_card_data: CardData = null

var has_selected_card: bool = false

var game_has_started: bool = false

var waiting_for_battle_plan: bool = true

var current_phase: int = BattlePhase.BATTLEPLAN

var opponent_battle_plan: Dictionary = {}

var player_has_initiative: bool = true

var combat_direction_selected: bool = false

var combat_lane_order: Array[String] = []

var combat_next_lane_index: int = 0

var phase_panel: PanelContainer = null

var phase_label: Label = null

var next_phase_button: Button = null

var spawn_opponent_button: Button = null

var ability_prompt_panel: AbilityPromptPanel = null

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

const BOARD_ACTION_INSPECT: int = 1

const BOARD_ACTION_CANCEL: int = 99

var board_action_menu: PopupMenu = null

var board_action_target_slot: Node = null

const BOARD_ACTION_ATTACK: int = 2

const COMBAT_LANE_GLOW: Color = Color(1.0, 1.0, 1.0, 0.82)

const COMBAT_LANE_START_DELAY: float = 0.35

const COMBAT_LANE_END_DELAY: float = 0.45

var active_combat_lane: String = ""

var combat_resolution_running: bool = false

const BOARD_ACTION_CHECK: int = 3

const BLUFF_REVEAL_DELAY: float = 0.30

var enemy_fortified_lanes: Dictionary = {}


# === Functions ===

func _ready() -> void:
	randomize()
	connect_all_slots()
	connect_main_signals()
	create_phase_ui()
	create_ability_prompt_panel()
	create_debug_tp_button()
	set_phase(BattlePhase.BATTLEPLAN)
	setup_battle_plan_flow()
	create_spell_choice_panel()
	create_parry_prompt_ui()
	create_parry_pit()
	create_aurion_counter_ui()
	disable_keyboard_focus_for_all_buttons($UI)
	create_board_slot_action_menu()
	patch_game_log_for_scrolling()


func connect_main_signals() -> void:
	if hand != null:
		hand.card_drag_started.connect(_on_hand_card_drag_started)
		hand.card_drag_released.connect(_on_hand_card_drag_released)
	if draw_pile != null:
		draw_pile.draw_drag_started.connect(_on_draw_pile_drag_started)
		draw_pile.draw_drag_moved.connect(_on_draw_pile_drag_moved)
		draw_pile.draw_drag_released.connect(_on_draw_pile_drag_released)
	if tribute_pile != null:
		tribute_pile.tribute_pile_clicked.connect(_on_tribute_pile_clicked)
	if tribute_manager != null:
		tribute_manager.tribute_changed.connect(_on_tribute_changed)


func setup_battle_plan_flow() -> void:
	waiting_for_battle_plan = true
	if battle_plan_panel != null:
		battle_plan_panel.clear_battle_plan()
	if battle_plan_selection_screen != null:
		if not battle_plan_selection_screen.battle_plan_selected.is_connected(_on_battle_plan_selected):
			battle_plan_selection_screen.battle_plan_selected.connect(_on_battle_plan_selected)
	open_battle_plan_selection()


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


func apply_battle_plan_rules(plan: Dictionary) -> void:
	if hand == null:
		return
	var max_hand_size: int = int(plan.get("max_hand_size", 7))
	hand.set_max_hand_size(max_hand_size)
	log_msg("Max hand size set to " + str(max_hand_size) + " by " + str(plan.get("name", "Battle Plan")))


func apply_initiative_rules(plan: Dictionary) -> void:
	var player_initiative: int = int(plan.get("initiative_mark", 0))
	var opponent_initiative: int = int(opponent_battle_plan.get("initiative_mark", 0))
	player_has_initiative = player_initiative >= opponent_initiative
	if player_has_initiative:
		log_msg("Initiative: Player acts first. " + str(player_initiative) + " vs " + str(opponent_initiative))
	else:
		log_msg("Initiative: Opponent acts first. " + str(opponent_initiative) + " vs " + str(player_initiative))


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

	if opponent_battle_plan.is_empty():
		log_msg("AI battleplan draw skipped. No unused AI battleplan remains.")
		return

	var ai_draw_amount: int = int(opponent_battle_plan.get("draw_amount", 0))
	ai_draw_cards(ai_draw_amount)

	log_msg("AI battleplan draw: AI drew " + str(ai_draw_amount) + " cards. AI hand: " + str(ai_hand.size()))


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
	update_ai_visuals()


func create_phase_ui() -> void:
	phase_panel = PanelContainer.new()
	phase_panel.name = "PhasePanel"

	# One combined right-side command panel.
	# Sits below enemy discard/deck visuals and above the player tribute pile.
	phase_panel.anchor_left = 1.0
	phase_panel.anchor_right = 1.0
	phase_panel.anchor_top = 0.0
	phase_panel.anchor_bottom = 0.0

	phase_panel.offset_left = -250.0
	phase_panel.offset_right = -20.0
	phase_panel.offset_top = 320.0
	phase_panel.offset_bottom = 300.0
	phase_panel.z_index = 75

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.015, 0.005, 0.74)
	style.border_color = Color(1.0, 0.78, 0.22, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	phase_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	phase_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	phase_label = Label.new()
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 17)
	vbox.add_child(phase_label)

	aurion_label = Label.new()
	aurion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aurion_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	aurion_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(aurion_label)

	next_phase_button = Button.new()
	next_phase_button.focus_mode = Control.FOCUS_NONE
	next_phase_button.custom_minimum_size = Vector2(0, 32)
	next_phase_button.pressed.connect(_on_next_phase_pressed)
	vbox.add_child(next_phase_button)

	# No more separate opponent test button.
	spawn_opponent_button = null

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
	if current_phase == BattlePhase.COMBAT and new_phase != BattlePhase.COMBAT:
		clear_active_combat_lane_highlight()

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

		if next_phase_button != null:
			next_phase_button.disabled = true

		await ai_take_deployment_turn()

		if next_phase_button != null:
			next_phase_button.disabled = false


func begin_combat_phase() -> void:
	reset_combat_state()
	clear_active_combat_lane_highlight()

	if player_has_initiative:
		log_msg("Phase: Combat. Player has initiative. Right-click the leftmost or rightmost lane, then choose Attack.")
	else:
		log_msg("Phase: Combat. AI has initiative. Combat will resolve lane by lane visually.")
		await get_tree().create_timer(COMBAT_LANE_START_DELAY).timeout
		ai_take_combat_initiative()


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
	if next_phase_button != null and next_phase_button.disabled:
		return

	match current_phase:
		BattlePhase.BATTLEPLAN:
			open_battle_plan_selection()

		BattlePhase.TRIBUTE:
			set_phase(BattlePhase.DEPLOYMENT)

		BattlePhase.DEPLOYMENT:
			if player_has_initiative:
				if next_phase_button != null:
					next_phase_button.disabled = true

				await ai_take_deployment_turn()

				if next_phase_button != null:
					next_phase_button.disabled = false

			set_phase(BattlePhase.COMBAT)

		BattlePhase.COMBAT:
			start_next_round()


func start_next_round() -> void:
	clear_active_combat_lane_highlight()
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


func reset_combat_state() -> void:
	combat_direction_selected = false
	combat_lane_order.clear()
	combat_next_lane_index = 0
	enemy_fortified_lanes.clear()
	combat_resolution_running = false
	active_combat_lane = ""


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
		cancel_selected_card()
		return

	if not is_instance_valid(card):
		cancel_selected_card()
		return

	if selected_card_data == null and card.card_data != null:
		select_card(card.card_data)

	var dragged_card_data: CardData = selected_card_data

	var target_node: Node = get_3d_node_under_screen_position(screen_position)
	var target_slot: Node = find_board_slot_from_node(target_node)

	if parry_active:
		var dropped_on_parry_pit := false

		if parry_pit_drop_area != null and is_node_inside_target(target_node, parry_pit_drop_area):
			dropped_on_parry_pit = true
		elif parry_pit_root != null and is_node_inside_target(target_node, parry_pit_root):
			dropped_on_parry_pit = true

		if dropped_on_parry_pit:
			await sacrifice_card_to_parry(card)
			return

		log_msg("Drop cards into the glowing pit to parry, or press Let Unit Die.")
		return_card_to_hand_safely(card)
		cancel_selected_card()
		return

	if is_node_inside_target(target_node, tribute_pile):
		if current_phase != BattlePhase.TRIBUTE:
			log_msg("Cards can only be sent to Tribute during the Tribute Phase.")
			return_card_to_hand_safely(card)
			cancel_selected_card()
			return

		if card != null and is_instance_valid(card):
			card.visible = false

		await play_player_hand_to_node_animation(dragged_card_data, tribute_pile, false)

		var sacrificed: bool = try_sacrifice_selected_card_to_tribute()

		if sacrificed:
			if hand != null:
				hand.consume_dragged_card(card)
		else:
			if card != null and is_instance_valid(card):
				card.visible = true

			return_card_to_hand_safely(card)

		cancel_selected_card()
		return

	if target_slot != null:
		if current_phase != BattlePhase.DEPLOYMENT:
			log_msg("Cards can only be deployed during the Deployment Phase.")
			return_card_to_hand_safely(card)
			cancel_selected_card()
			return

		var card_type: String = get_clean_card_type(selected_card_data)

		if card_type == "equipment":
			if card != null and is_instance_valid(card):
				card.visible = false

			await play_player_hand_to_node_animation(dragged_card_data, target_slot, false)

			var attached: bool = try_attach_selected_equipment_to_slot(target_slot)

			if attached:
				if hand != null:
					hand.consume_dragged_card(card)
			else:
				if card != null and is_instance_valid(card):
					card.visible = true

				return_card_to_hand_safely(card)

			cancel_selected_card()
			return

		if is_gambit_card(selected_card_data):
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
				if card != null and is_instance_valid(card):
					card.visible = false

				await play_player_hand_to_node_animation(dragged_card_data, target_slot, false)

				var front_spell_placed: bool = try_place_selected_card_on_slot(target_slot)

				if front_spell_placed:
					if hand != null:
						hand.consume_dragged_card(card)
				else:
					if card != null and is_instance_valid(card):
						card.visible = true

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

		var place_face_down: bool = false
		var slot_row: String = String(target_slot.get_meta("row", ""))

		if is_unit_card(selected_card_data) and slot_row == "back":
			place_face_down = true

		if card != null and is_instance_valid(card):
			card.visible = false

		await play_player_hand_to_node_animation(dragged_card_data, target_slot, place_face_down)

		var placed: bool = try_place_selected_card_on_slot(target_slot)

		if placed:
			if hand != null:
				hand.consume_dragged_card(card)
		else:
			if card != null and is_instance_valid(card):
				card.visible = true

			return_card_to_hand_safely(card)

		cancel_selected_card()
		return

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


func _on_slot_right_clicked(slot: Node) -> void:
	show_board_slot_action_menu(slot)


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

	if try_sacrifice_selected_card_to_tribute():
		log_msg("Debug tribute: " + selected_card_data.card_name + ". " + tribute_manager.get_status_text())


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

	if is_gambit_card(selected_card_data):
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


func try_sacrifice_selected_card_to_tribute() -> bool:
	if not has_selected_card or selected_card_data == null:
		return false

	if tribute_manager == null:
		return false

	if not tribute_manager.can_offer_card_this_turn():
		log_msg("Tribute already used this turn. Only 1 card can be used as Tribute per turn.")
		return false

	var offered_card_name: String = selected_card_data.card_name
	var offered_card_type: String = get_clean_card_type(selected_card_data)

	if offered_card_type == "gambit":
		tribute_manager.add_temporary_tribute(selected_card_data)
		tribute_manager.tribute_card_used_this_turn = true
		log_msg("Offered " + offered_card_name + " for temporary Tribute. +2 TP this turn.")
	else:
		tribute_manager.add_permanent_tribute(selected_card_data)
		tribute_manager.tribute_card_used_this_turn = true
		log_msg("Offered " + offered_card_name + " for permanent Tribute. +1 permanent TP.")

	if tribute_pile != null:
		tribute_pile.add_card(selected_card_data)

	update_tribute_counter()
	return true


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

	if is_gambit_card(selected_card_data):
		# Spells can go front or back, any lane.
		# Front = face up automatically.
		# Back = prompt for face up / face down.
		return (slot_row == "front" or slot_row == "back") and not slot_occupied

	if card_type == "unit":
		# Units can go front face-up or back face-down.
		return (slot_row == "front" or slot_row == "back") and not slot_occupied

	return false


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


func spawn_random_opponent_cards() -> void:
	# Old test-spawn disabled.
	# AI must deploy through hand + TP + phase rules.
	log_msg("Old opponent test spawn is disabled. AI uses legal deployment now.")


func get_random_opponent_test_card() -> CardData:
	if OPPONENT_TEST_CARDS.is_empty():
		return null
	var index: int = randi() % OPPONENT_TEST_CARDS.size()
	return OPPONENT_TEST_CARDS[index]


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


func get_slot_card_data(slot: Node) -> CardData:
	if slot == null:
		return null

	if slot.has_method("get_placed_card_data"):
		return slot.get_placed_card_data()

	return null


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


func send_slot_card_to_discard(slot: Node) -> void:
	if slot == null:
		return

	var slot_owner: String = String(slot.get_meta("owner", ""))
	var card_data: CardData = get_slot_card_data(slot)

	if card_data != null:
		play_card_to_discard_animation(card_data, slot, slot_owner)

		if slot_owner == "enemy":
			ai_discard.append(card_data)
		elif discard_pile != null:
			discard_pile.add_card(card_data)

	if slot.has_method("get_equipment_cards"):
		var equipment_cards: Array = slot.get_equipment_cards()

		for equipment_card in equipment_cards:
			if equipment_card == null:
				continue

			play_card_to_discard_animation(equipment_card, slot, slot_owner)

			if slot_owner == "enemy":
				ai_discard.append(equipment_card)
			elif discard_pile != null:
				discard_pile.add_card(equipment_card)

	if slot.has_method("clear_slot"):
		slot.clear_slot()

	update_ai_visuals()


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


func log_msg(message: String) -> void:
	if game_log != null and game_log.has_method("add_log"):
		game_log.add_log(message)
	else:
		print("LOG FALLBACK: " + message)


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
	set_active_combat_lane_highlight(lane)
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

	if card_ui != null and is_instance_valid(card_ui):
		card_ui.visible = false

	await play_player_hand_to_node_animation(sacrificed_card, parry_pit_root, false)

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
	clear_active_combat_lane_highlight()

	if current_phase == BattlePhase.COMBAT and combat_next_lane_index < combat_lane_order.size():
		set_active_combat_lane_highlight(combat_lane_order[combat_next_lane_index])


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


func advance_combat_lane_after_resolution() -> void:
	clear_active_combat_lane_highlight()
	combat_next_lane_index += 1

	if combat_next_lane_index >= combat_lane_order.size():
		log_msg("All combat lanes resolved. Press End Combat / Next Round when ready.")
	else:
		log_msg("Next lane to resolve: " + combat_lane_order[combat_next_lane_index])

	if current_phase != BattlePhase.COMBAT:
		return

	if parry_active:
		return

	if combat_next_lane_index < combat_lane_order.size():
		set_active_combat_lane_highlight(combat_lane_order[combat_next_lane_index])


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


func get_clean_card_type(card_data: CardData) -> String:
	if card_data == null:
		return ""

	return card_data.card_type.to_lower().strip_edges()


func is_gambit_card(card_data: CardData) -> bool:
	return get_clean_card_type(card_data) == "gambit"


# Legacy wrapper: older code still calls this for the old spell-like bucket.


func is_equipment_card(card_data: CardData) -> bool:
	return get_clean_card_type(card_data) == "equipment"


func is_trap_card(_card_data: CardData) -> bool:
	return false


func is_ruse_card(_card_data: CardData) -> bool:
	return false


func is_event_card(_card_data: CardData) -> bool:
	return false


func is_spell_card(card_data: CardData) -> bool:
	return is_gambit_card(card_data)


func return_card_to_hand_safely(card: CardUI) -> void:
	if hand == null:
		return

	if card != null and is_instance_valid(card):
		card.mouse_is_pressed = false
		card.is_dragging = false
		card.set_process(false)

	if hand.has_method("return_dragged_card_to_hand"):
		hand.return_dragged_card_to_hand(card)


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

	if not is_gambit_card(selected_card_data):
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

	var spell_card_data: CardData = selected_card_data
	var spell_slot: Node = pending_spell_slot
	var spell_card_ui: CardUI = pending_spell_card_ui

	if spell_card_ui != null and is_instance_valid(spell_card_ui):
		spell_card_ui.visible = false

	hide_spell_choice_panel()

	await play_player_hand_to_node_animation(spell_card_data, spell_slot, place_face_down)

	var placed: bool = spell_slot.place_card(TEST_CARD_SCENE, spell_card_data, place_face_down)

	if placed:
		tribute_manager.spend_tribute(spell_card_data.tribute_cost)

		var visibility_text: String = "face down" if place_face_down else "face up"
		log_msg("Placed spell " + spell_card_data.card_name + " " + visibility_text + ".")
		log_msg("Spent " + str(spell_card_data.tribute_cost) + " TP. " + tribute_manager.get_status_text())

		if spell_card_ui != null and hand != null:
			hand.consume_dragged_card(spell_card_ui)
		elif hand != null:
			hand.remove_selected_card()

		handle_card_deployed(spell_card_data)
	else:
		if spell_card_ui != null and is_instance_valid(spell_card_ui):
			spell_card_ui.visible = true

		if spell_card_ui != null:
			return_card_to_hand_safely(spell_card_ui)

	cancel_selected_card()


func cleanup_battlefield_spells() -> void:
	cleanup_phase_one_board_cards()


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
			return

		var drawn_card: CardData = ai_deck.pop_back()

		if drawn_card != null:
			ai_hand.append(drawn_card)
		update_ai_visuals()


func ai_start_tribute_phase() -> void:
	ai_current_perm_tp = ai_perm_tp
	ai_temp_tp = 0
	ai_current_tp = ai_current_perm_tp
	ai_tribute_used_this_turn = false

	if next_phase_button != null:
		next_phase_button.disabled = true

	await ai_offer_one_card_to_tribute()

	if next_phase_button != null:
		next_phase_button.disabled = false


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

	var tribute_card: CardData = ai_hand[tribute_index]

	if tribute_card == null:
		return

	await play_enemy_hand_to_node_animation(
		tribute_card,
		get_enemy_visual_target("EnemyTributePileVisual"),
		false
	)

	ai_hand.pop_at(tribute_index)
	ai_tribute.append(tribute_card)
	ai_tribute_used_this_turn = true

	var card_type: String = get_clean_card_type(tribute_card)

	if card_type == "gambit":
		ai_temp_tp += 2
		ai_current_tp += 2
		log_msg("AI offered " + tribute_card.card_name + " for +2 temporary TP.")
	else:
		ai_perm_tp += 1
		ai_current_perm_tp += 1
		ai_current_tp += 1
		log_msg("AI offered " + tribute_card.card_name + " for +1 permanent TP.")

	log_msg("AI TP: " + str(ai_current_tp) + "/" + str(ai_perm_tp) + " Temp +" + str(ai_temp_tp))
	update_ai_visuals()


func ai_choose_tribute_card_index() -> int:
	# Prefer unit/equipment for permanent TP.
	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if card_data == null:
			continue

		var card_type: String = get_clean_card_type(card_data)

		if card_type == "unit" or card_type == "equipment":
			return i

	# If no permanent option exists, use a gambit for temporary TP.
	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if is_gambit_card(card_data):
			return i

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
	if combat_resolution_running:
		return

	combat_resolution_running = true

	while current_phase == BattlePhase.COMBAT and not parry_active and combat_next_lane_index < combat_lane_order.size():
		var next_lane: String = combat_lane_order[combat_next_lane_index]
		await resolve_ai_combat_lane_with_visuals(next_lane)
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout

	combat_resolution_running = false


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
		var played: bool = await ai_try_deploy_one_card()

		if not played:
			break

		plays_made += 1

		await get_tree().create_timer(0.25).timeout

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
		await play_enemy_hand_to_node_animation(card_data, target_slot, false)

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
			update_ai_visuals()
			return true

		return false

	if action_type == "unit" or action_type == "gambit":
		await play_enemy_hand_to_node_animation(card_data, target_slot, face_down)

		if target_slot.has_method("place_card"):
			success = target_slot.place_card(TEST_CARD_SCENE, card_data, face_down)

		if success:
			ai_hand.pop_at(card_index)
			ai_spend_tp(card_data.tribute_cost)

			var visibility_text: String = "face down" if face_down else "face up"
			var row_text: String = String(target_slot.get_meta("row", "unknown row"))

			log_msg("AI placed " + card_data.card_name + " " + visibility_text + " in enemy " + row_text + " row.")
			log_msg("AI TP after deployment: " + str(ai_current_tp) + "/" + str(ai_perm_tp) + " Temp +" + str(ai_temp_tp))
			update_ai_visuals()
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

	return ai_make_deployment_action(spell_index, chosen_slot, "gambit", face_down)


func ai_find_affordable_spell_index() -> int:
	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if card_data == null:
			continue

		if not is_gambit_card(card_data):
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

	if is_gambit_card(card_data):
		return ai_choose_spell_like_slot(card_data)

	return null


func ai_should_place_card_face_down(card_data: CardData, target_slot: Node) -> bool:
	if card_data == null or target_slot == null:
		return false

	var row: String = String(target_slot.get_meta("row", ""))

	if row == "front":
		return false

	if row == "back":
		return is_unit_card(card_data) or is_gambit_card(card_data)

	return false


func ai_choose_empty_back_slot_for_tactic(_card_data: CardData) -> Node:
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


func ai_choose_equipment_target_slot(_card_data: CardData) -> Node:
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


func is_spell_like_card(card_data: CardData) -> bool:
	return is_gambit_card(card_data)


func cleanup_phase_one_board_cards() -> void:
	if board_slots == null:
		return

	var returned_count: int = 0
	var discarded_count: int = 0

	for slot in board_slots.get_children():
		var card_data: CardData = get_slot_card_data(slot)

		if card_data == null:
			continue

		var slot_owner: String = String(slot.get_meta("owner", ""))
		var slot_row: String = String(slot.get_meta("row", ""))
		var is_face_down: bool = bool(slot.get_meta("face_down", false))
		var was_interacted: bool = bool(slot.get_meta("interacted_this_round", false))

		if is_face_down and slot_row == "back" and not was_interacted:
			return_face_down_setup_card_to_owner_hand(slot, card_data, slot_owner)
			returned_count += 1
			continue

		if is_gambit_card(card_data) and not is_face_down:
			discard_slot_card_for_cleanup(slot, card_data, slot_owner)
			discarded_count += 1
			continue

		slot.set_meta("interacted_this_round", false)

	if returned_count > 0:
		log_msg("Returned " + str(returned_count) + " untouched face-down back-row card(s) to hand.")

	if discarded_count > 0:
		log_msg("Cleaned up " + str(discarded_count) + " face-up Gambit card(s).")

	update_ai_visuals()


func return_face_down_setup_card_to_owner_hand(slot: Node, card_data: CardData, slot_owner: String) -> void:
	if card_data == null or slot == null:
		return

	if slot_owner == "enemy":
		ai_hand.append(card_data)
	else:
		if hand != null:
			hand.add_card_to_hand(card_data)

	if slot.has_method("clear_slot"):
		slot.clear_slot()

	slot.set_meta("interacted_this_round", false)


func discard_slot_card_for_cleanup(slot: Node, card_data: CardData, slot_owner: String) -> void:
	if card_data == null or slot == null:
		return

	play_card_to_discard_animation(card_data, slot, slot_owner)

	if slot_owner == "enemy":
		ai_discard.append(card_data)
	elif discard_pile != null:
		discard_pile.add_card(card_data)

	if slot.has_method("clear_slot"):
		slot.clear_slot()

	slot.set_meta("interacted_this_round", false)


func create_board_slot_action_menu() -> void:
	if board_action_menu != null:
		return

	board_action_menu = PopupMenu.new()
	board_action_menu.name = "BoardSlotActionMenu"
	board_action_menu.visible = false
	board_action_menu.exclusive = false
	board_action_menu.id_pressed.connect(_on_board_slot_action_selected)

	$UI.add_child(board_action_menu)


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


func inspect_board_slot(slot: Node) -> void:
	if slot == null:
		return

	var card_data: CardData = get_slot_card_data(slot)

	if card_data == null:
		log_msg("No card in this slot.")
		return

	var slot_owner: String = String(slot.get_meta("owner", ""))
	var is_face_down: bool = bool(slot.get_meta("face_down", false))
	var slot_id: String = String(slot.get_meta("slot_id", "board slot"))

	if slot_owner == "enemy" and is_face_down:
		log_msg("Inspected " + slot_id + ": enemy face-down card remains hidden.")
		return

	var inspect_panel: CardInspectPanel = get_card_inspect_panel()

	if inspect_panel == null:
		log_msg("CardInspectPanel is missing.")
		return

	var source_position: Vector2 = get_viewport().get_mouse_position()
	inspect_panel.last_source_rect = Rect2(source_position, Vector2(130.0, 180.0))
	inspect_panel.show_card(null, card_data)

	log_msg("Inspecting board card: " + card_data.card_name)


func get_card_inspect_panel() -> CardInspectPanel:
	var inspect_panel: CardInspectPanel = get_node_or_null("UI/CardInspectPanel") as CardInspectPanel

	if inspect_panel != null:
		return inspect_panel

	return find_card_inspect_panel(self)


func find_card_inspect_panel(node: Node) -> CardInspectPanel:
	if node == null:
		return null

	if node is CardInspectPanel:
		return node as CardInspectPanel

	for child in node.get_children():
		var found: CardInspectPanel = find_card_inspect_panel(child)

		if found != null:
			return found

	return null


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
	if combat_resolution_running:
		log_msg("Combat is already resolving. Wait for the current lane.")
		return

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

	await resolve_player_attack_lane_with_visuals(lane)


func resolve_monarch_strike(lane: String, attacker_card: CardData) -> void:
	if attacker_card == null:
		return

	add_aurion("player", 1, "Monarch Strike through the " + lane + " lane by " + attacker_card.card_name + ".")
	log_msg(lane.capitalize() + " lane: Monarch Strike successful.")


func patch_game_log_for_scrolling() -> void:
	if game_log == null:
		return

	game_log.set("max_lines", 200)

	var panel: PanelContainer = game_log.get_node_or_null("PanelContainer") as PanelContainer
	var margin: MarginContainer = game_log.get_node_or_null("PanelContainer/MarginContainer") as MarginContainer
	var log_text: RichTextLabel = game_log.get_node_or_null("PanelContainer/MarginContainer/LogText") as RichTextLabel

	if panel != null:
		panel.offset_left = 20.0
		panel.offset_top = 20.0
		panel.offset_right = 520.0
		panel.offset_bottom = 235.0
		panel.custom_minimum_size = Vector2(500.0, 215.0)

	if margin != null:
		margin.custom_minimum_size = Vector2(480.0, 195.0)
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)

	if log_text != null:
		log_text.custom_minimum_size = Vector2(460.0, 180.0)
		log_text.scroll_active = true
		log_text.scroll_following = true
		log_text.fit_content = false
		log_text.clip_contents = true
		log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		log_text.mouse_filter = Control.MOUSE_FILTER_STOP


func resolve_player_attack_lane_with_visuals(lane: String) -> void:
	if combat_resolution_running:
		return

	combat_resolution_running = true

	if not prepare_player_lane_action(lane):
		combat_resolution_running = false
		return

	set_active_combat_lane_highlight(lane)
	log_msg("Resolving attack in the " + lane + " lane.")
	await get_tree().create_timer(COMBAT_LANE_START_DELAY).timeout

	var player_front_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)
	var enemy_front_slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)
	var enemy_back_slot: Node = find_slot_by_owner_row_lane("enemy", "back", lane)

	var player_card: CardData = get_slot_card_data(player_front_slot)
	var enemy_front_card: CardData = get_slot_card_data(enemy_front_slot)
	var enemy_back_card: CardData = get_slot_card_data(enemy_back_slot)
	var enemy_back_is_face_down: bool = enemy_back_card != null and enemy_back_slot != null and bool(enemy_back_slot.get_meta("face_down", false))

	if not is_unit_card(player_card):
		log_msg(lane.capitalize() + " lane: you have no front-row unit to attack with.")
		combat_resolution_running = false
		return

	if enemy_back_is_face_down:
		await resolve_attack_into_face_down_backrow(lane, player_card, enemy_front_slot, enemy_back_slot, enemy_back_card)
		combat_resolution_running = false
		return

	if enemy_front_card == null and enemy_back_card == null:
		resolve_monarch_strike(lane, player_card)
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		advance_combat_lane_after_resolution()
		combat_resolution_running = false
		return

	if enemy_front_card != null:
		resolve_lane_combat(lane, player_front_slot, enemy_front_slot)

		if parry_active:
			combat_resolution_running = false
			return

		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		advance_combat_lane_after_resolution()
		combat_resolution_running = false
		return

	log_msg(lane.capitalize() + " lane: enemy back row is occupied but not face down. Attack cannot resolve yet.")
	combat_resolution_running = false


func resolve_ai_combat_lane_with_visuals(lane: String) -> void:
	if current_phase != BattlePhase.COMBAT:
		return

	if combat_next_lane_index >= combat_lane_order.size():
		return

	var expected_lane: String = combat_lane_order[combat_next_lane_index]

	if lane != expected_lane:
		return

	set_active_combat_lane_highlight(lane)
	log_msg("AI resolving " + lane + " lane.")
	await get_tree().create_timer(COMBAT_LANE_START_DELAY).timeout

	var player_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)
	var opponent_slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)

	resolve_lane_combat(lane, player_slot, opponent_slot)

	if parry_active:
		return

	advance_combat_lane_after_resolution()


func set_active_combat_lane_highlight(lane: String) -> void:
	if lane == "":
		return

	clear_active_combat_lane_highlight()
	active_combat_lane = lane

	if board_slots == null:
		return

	for slot in board_slots.get_children():
		if slot == null:
			continue

		if get_slot_lane(slot) != lane:
			continue

		if slot.has_method("set_highlight"):
			slot.set_highlight(true)

		if slot.has_method("set_outline_color"):
			slot.set_outline_color(COMBAT_LANE_GLOW)


func clear_active_combat_lane_highlight() -> void:
	if board_slots == null:
		active_combat_lane = ""
		return

	for slot in board_slots.get_children():
		if slot == null:
			continue

		if active_combat_lane != "" and get_slot_lane(slot) != active_combat_lane:
			continue

		if slot.has_method("set_highlight"):
			slot.set_highlight(false)

	active_combat_lane = ""


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

	await resolve_player_check_lane_with_visuals(lane)


func resolve_player_check_lane_with_visuals(lane: String) -> void:
	if combat_resolution_running:
		return

	combat_resolution_running = true

	if not prepare_player_lane_action(lane):
		combat_resolution_running = false
		return

	set_active_combat_lane_highlight(lane)
	log_msg("Checking hidden back-row card in the " + lane + " lane.")
	await get_tree().create_timer(COMBAT_LANE_START_DELAY).timeout

	var back_slot: Node = find_slot_by_owner_row_lane("enemy", "back", lane)
	var back_card: CardData = get_slot_card_data(back_slot)

	if back_slot == null or back_card == null or not bool(back_slot.get_meta("face_down", false)):
		log_msg(lane.capitalize() + " lane: no face-down back-row card to check.")
		combat_resolution_running = false
		return

	back_slot.set_meta("interacted_this_round", true)

	if back_slot.has_method("reveal_card"):
		back_slot.reveal_card()

	await get_tree().create_timer(BLUFF_REVEAL_DELAY).timeout

	if is_gambit_card(back_card):
		add_aurion("player", 1, "Successful Check: " + back_card.card_name + " was a Gambit.")
		log_msg("Check successful. Gambit goes to discard. Lane action ends.")
		send_slot_card_to_discard(back_slot)
	else:
		add_aurion("ai", 1, "Failed Check: " + back_card.card_name + " was a decoy.")
		enemy_fortified_lanes[lane] = true
		log_msg("Check failed. Decoy returns to enemy hand. Enemy is fortified in this lane.")
		return_setup_card(back_slot, back_card, "enemy")

	await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
	advance_combat_lane_after_resolution()
	combat_resolution_running = false


func prepare_player_lane_action(lane: String) -> bool:
	if lane == "":
		return false

	if not combat_direction_selected:
		if lane == "left":
			set_combat_lane_order_from_left()
		elif lane == "right":
			set_combat_lane_order_from_right()
		else:
			log_msg("Choose the leftmost or rightmost lane first to set combat direction.")
			return false

	if combat_next_lane_index >= combat_lane_order.size():
		log_msg("All combat lanes are already resolved.")
		return false

	var expected_lane: String = combat_lane_order[combat_next_lane_index]

	if lane != expected_lane:
		log_msg("Next combat must resolve in the " + expected_lane + " lane.")
		return false

	var player_front_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)
	var player_card: CardData = get_slot_card_data(player_front_slot)

	if not is_unit_card(player_card):
		log_msg(lane.capitalize() + " lane: you have no front-row unit to act with.")
		return false

	return true


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


func resolve_attack_into_face_down_backrow(
	lane: String,
	attacker_card: CardData,
	enemy_front_slot: Node,
	enemy_back_slot: Node,
	enemy_back_card: CardData
) -> void:
	if enemy_back_slot == null or enemy_back_card == null:
		return

	enemy_back_slot.set_meta("interacted_this_round", true)

	if enemy_back_slot.has_method("reveal_card"):
		enemy_back_slot.reveal_card()

	await get_tree().create_timer(BLUFF_REVEAL_DELAY).timeout

	if is_gambit_card(enemy_back_card):
		log_msg("Attack failed: " + enemy_back_card.card_name + " was a hidden Gambit. Attack is stopped.")
		send_slot_card_to_discard(enemy_back_slot)
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		advance_combat_lane_after_resolution()
		return

	log_msg("Attack read correctly: " + enemy_back_card.card_name + " was not a Gambit. Decoy is discarded.")
	send_slot_card_to_discard(enemy_back_slot)
	await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout

	var enemy_front_card: CardData = get_slot_card_data(enemy_front_slot)

	if enemy_front_card == null:
		resolve_monarch_strike(lane, attacker_card)
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		advance_combat_lane_after_resolution()
		return

	var player_front_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)
	resolve_lane_combat(lane, player_front_slot, enemy_front_slot)

	if parry_active:
		return

	await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
	advance_combat_lane_after_resolution()
