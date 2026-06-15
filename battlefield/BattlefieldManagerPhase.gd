class_name BattlefieldManagerPhase
extends Node3D

const TEST_CARD_SCENE: PackedScene = preload("res://cards/Card3D_Test.tscn")
const ARCH_WIZARD_MAELCOR: CardData = preload("res://cards/definitions/arch_wizard_maelcor.tres")
const IMPERIAL_ARCHIVE_MASTER: CardData = preload("res://cards/definitions/imperial_archive_master.tres")
const JENA_OF_YEL: CardData = preload("res://cards/definitions/jena_of_yel.tres")
const IVAAN_BONE_CRUSHER: CardData = preload("res://cards/definitions/ivaan_bone_crusher.tres")
const UPPER_HALL_PROSPECTOR: CardData = preload("res://cards/definitions/upper_hall_prospector.tres")
const TEST_EQUIPMENT: CardData = preload("res://cards/definitions/Test_Equipment.tres")
const TEST_SPELL: CardData = preload("res://cards/definitions/Test_Spell.tres")

const OPPONENT_TEST_CARDS: Array[CardData] = [ARCH_WIZARD_MAELCOR, IMPERIAL_ARCHIVE_MASTER, JENA_OF_YEL, IVAAN_BONE_CRUSHER, UPPER_HALL_PROSPECTOR]

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

func _ready() -> void:
	randomize()
	connect_all_slots()
	connect_main_signals()
	create_phase_ui()
	create_ability_prompt_panel()
	create_debug_tp_button()
	set_phase(BattlePhase.BATTLEPLAN)
	setup_battle_plan_flow()

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
	var choices: Array[Dictionary] = battle_plan_manager.get_random_battle_plan_choices(3)
	battle_plan_selection_screen.show_selection(choices)

func _on_battle_plan_selected(plan: Dictionary) -> void:
	waiting_for_battle_plan = false
	if battle_plan_manager != null:
		battle_plan_manager.select_battle_plan(plan)
	if battle_plan_panel != null:
		battle_plan_panel.set_battle_plan(plan)
	choose_opponent_battle_plan()
	apply_battle_plan_rules(plan)
	apply_initiative_rules(plan)
	log_msg("Selected Battle Plan: " + str(plan.get("name", "Unknown Battle Plan")))
	log_msg("Opponent Battle Plan: " + str(opponent_battle_plan.get("name", "Unknown Battle Plan")))
	if not game_has_started:
		begin_game_after_battle_plan_selection()
	draw_battleplan_cards(plan)
	set_phase(BattlePhase.TRIBUTE)

func choose_opponent_battle_plan() -> void:
	opponent_battle_plan = {}
	if battle_plan_manager == null:
		return
	var choices: Array[Dictionary] = battle_plan_manager.get_random_battle_plan_choices(1)
	if not choices.is_empty():
		opponent_battle_plan = choices[0]

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
	if draw_amount <= 0 or player_deck == null or hand == null:
		return
	var drawn_count: int = 0
	for i in range(draw_amount):
		if not hand.can_accept_card():
			break
		var drawn_card: CardData = player_deck.draw_top_card()
		if drawn_card == null:
			break
		hand.add_card_to_hand(drawn_card)
		drawn_count += 1
		if draw_pile != null:
			draw_pile.consume_top_card()
	log_msg("Battleplan draw: player drew " + str(drawn_count) + "/" + str(draw_amount) + " cards.")
	log_msg("Opponent draws " + str(draw_amount) + " cards. Opponent hand is simulated for now.")

func begin_game_after_battle_plan_selection() -> void:
	if game_has_started:
		return
	game_has_started = true
	update_tribute_counter()
	deal_starting_hand()
	if tribute_manager != null:
		log_msg("Starting Tribute: " + tribute_manager.get_status_text())

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
	next_phase_button.pressed.connect(_on_next_phase_pressed)
	vbox.add_child(next_phase_button)
	spawn_opponent_button = Button.new()
	spawn_opponent_button.text = "Spawn Opponent Test Cards"
	spawn_opponent_button.pressed.connect(spawn_random_opponent_cards)
	vbox.add_child(spawn_opponent_button)
	$UI.add_child(phase_panel)
	update_phase_ui()

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
			log_msg("Phase: Tribute")
		BattlePhase.DEPLOYMENT:
			begin_deployment_phase()
		BattlePhase.COMBAT:
			begin_combat_phase()

func begin_deployment_phase() -> void:
	log_msg("Phase: Deployment")
	if player_has_initiative:
		log_msg("Player has initiative and deploys first.")
	else:
		log_msg("Opponent has initiative and deploys first. Spawning opponent test cards.")
		spawn_random_opponent_cards()

func begin_combat_phase() -> void:
	reset_combat_state()
	if player_has_initiative:
		log_msg("Phase: Combat. Player has first action.")
	else:
		log_msg("Phase: Combat. Opponent has first action.")

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
			set_phase(BattlePhase.COMBAT)
		BattlePhase.COMBAT:
			start_next_round()

func start_next_round() -> void:
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
	var target_node := get_3d_node_under_screen_position(screen_position)
	var target_slot := find_board_slot_from_node(target_node)
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
	if waiting_for_battle_plan or current_phase == BattlePhase.COMBAT:
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
			select_card(IVAAN_BONE_CRUSHER)
		if event.keycode == KEY_5:
			select_card(UPPER_HALL_PROSPECTOR)
		if event.keycode == KEY_6:
			select_card(TEST_EQUIPMENT)
		if event.keycode == KEY_7:
			select_card(TEST_SPELL)
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
	if current_phase == BattlePhase.COMBAT:
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
	var place_face_down: bool = slot_row == "back"
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
	var sacrificed_card_type := selected_card_data.card_type.to_lower()
	var tribute_success: bool = tribute_manager.offer_card_to_tribute(selected_card_data)
	if not tribute_success:
		return false
	if tribute_pile != null:
		tribute_pile.add_card()
	if sacrificed_card_type == "spell":
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
	combat_next_lane_index += 1
	if combat_next_lane_index >= combat_lane_order.size():
		log_msg("All combat lanes resolved. Press End Combat / Next Round when ready.")

func resolve_lane_combat(lane: String, player_slot: Node, opponent_slot: Node) -> void:
	var player_card: CardData = get_slot_card_data(player_slot)
	var opponent_card: CardData = get_slot_card_data(opponent_slot)
	if player_card == null and opponent_card == null:
		log_msg(lane.capitalize() + " lane: no combat.")
		return
	if player_card != null and opponent_card == null:
		log_msg(lane.capitalize() + " lane: " + player_card.card_name + " has no opposing target.")
		return
	if player_card == null and opponent_card != null:
		log_msg(lane.capitalize() + " lane: opponent " + opponent_card.card_name + " has no player target.")
		return
	if player_has_initiative:
		resolve_directed_clash(lane, player_slot, player_card, opponent_slot, opponent_card, true)
	else:
		resolve_directed_clash(lane, opponent_slot, opponent_card, player_slot, player_card, false)

func resolve_directed_clash(lane: String, first_slot: Node, first_card: CardData, second_slot: Node, second_card: CardData, player_is_first: bool) -> void:
	var first_label := "Player"
	var second_label := "Opponent"
	if not player_is_first:
		first_label = "Opponent"
		second_label = "Player"
	log_msg(lane.capitalize() + " lane clash: " + first_label + " " + first_card.card_name + " AP " + str(first_card.ap) + " vs " + second_label + " " + second_card.card_name + " DP " + str(second_card.dp))
	if first_card.ap >= second_card.dp:
		send_slot_card_to_discard(second_slot)
		log_msg(second_label + " " + second_card.card_name + " removed from board.")
		return
	log_msg(second_label + " " + second_card.card_name + " survives and answers.")
	if second_card.ap >= first_card.dp:
		send_slot_card_to_discard(first_slot)
		log_msg(first_label + " " + first_card.card_name + " removed from board.")
	else:
		log_msg("Both units remain on board.")

func get_slot_card_data(slot: Node) -> CardData:
	if slot == null:
		return null
	if slot.has_method("get_placed_card_data"):
		return slot.get_placed_card_data()
	return null

func find_slot_by_owner_row_lane(owner: String, row: String, lane: String) -> Node:
	for slot in board_slots.get_children():
		if slot.get_meta("owner", "") == owner and slot.get_meta("row", "") == row and get_slot_lane(slot) == lane:
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
	if discard_pile != null and card_data != null:
		discard_pile.add_card(card_data)
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

func create_debug_tp_button() -> void:
	if get_node_or_null("UI/DebugAddTPButton") != null:
		return
	var button := Button.new()
	button.name = "DebugAddTPButton"
	button.text = "+1 TP"
	button.custom_minimum_size = Vector2(120, 44)
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 0.0
	button.anchor_bottom = 0.0
	button.offset_left = -150.0
	button.offset_right = -20.0
	button.offset_top = 180.0
	button.offset_bottom = 224.0
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
