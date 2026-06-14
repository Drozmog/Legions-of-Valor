extends Node3D

const TEST_CARD_SCENE: PackedScene = preload("res://cards/Card3D_Test.tscn")

const ARCH_WIZARD_MAELCOR: CardData = preload("res://cards/definitions/arch_wizard_maelcor.tres")
const IMPERIAL_ARCHIVE_MASTER: CardData = preload("res://cards/definitions/imperial_archive_master.tres")
const JENA_OF_YEL: CardData = preload("res://cards/definitions/jena_of_yel.tres")
const IVAAN_BONE_CRUSHER: CardData = preload("res://cards/definitions/ivaan_bone_crusher.tres")
const UPPER_HALL_PROSPECTOR: CardData = preload("res://cards/definitions/upper_hall_prospector.tres")
const TEST_EQUIPMENT: CardData = preload("res://cards/definitions/Test_Equipment.tres")
const TEST_SPELL: CardData = preload("res://cards/definitions/Test_Spell.tres")

const OPPONENT_TEST_CARDS: Array[CardData] = [
	ARCH_WIZARD_MAELCOR,
	IMPERIAL_ARCHIVE_MASTER,
	JENA_OF_YEL,
	IVAAN_BONE_CRUSHER,
	UPPER_HALL_PROSPECTOR,
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

var phase_panel: PanelContainer = null
var phase_label: Label = null
var next_phase_button: Button = null
var spawn_opponent_button: Button = null


func _ready() -> void:
	randomize()
	connect_all_slots()
	connect_main_signals()
	create_phase_ui()
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

	var choices := battle_plan_manager.get_random_battle_plan_choices(3)
	battle_plan_selection_screen.show_selection(choices)


func _on_battle_plan_selected(plan: Dictionary) -> void:
	waiting_for_battle_plan = false

	if battle_plan_manager != null:
		battle_plan_manager.select_battle_plan(plan)

	if battle_plan_panel != null:
		battle_plan_panel.set_battle_plan(plan)

	apply_battle_plan_rules(plan)
	log_msg("Selected Battle Plan: " + str(plan.get("name", "Unknown Battle Plan")))

	if not game_has_started:
		begin_game_after_battle_plan_selection()

	set_phase(BattlePhase.TRIBUTE)


func apply_battle_plan_rules(plan: Dictionary) -> void:
	if hand == null:
		return

	var max_hand_size := int(plan.get("max_hand_size", 7))
	hand.set_max_hand_size(max_hand_size)
	log_msg("Max hand size set to " + str(max_hand_size) + " by " + str(plan.get("name", "Battle Plan")))


func begin_game_after_battle_plan_selection() -> void:
	if game_has_started:
		return

	game_has_started = true
	update_tribute_counter()
	deal_starting_hand()

	if tribute_manager != null:
		log_msg("Starting Tribute: " + tribute_manager.get_status_text())


func create_phase_ui() -> void:
	if get_node_or_null("UI/PhasePanel") != null:
		phase_panel = get_node_or_null("UI/PhasePanel") as PanelContainer
		return

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
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
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
	phase_label.text = "PHASE"
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(phase_label)

	next_phase_button = Button.new()
	next_phase_button.text = "Next Phase"
	next_phase_button.pressed.connect(_on_next_phase_pressed)
	vbox.add_child(next_phase_button)

	spawn_opponent_button = Button.new()
	spawn_opponent_button.text = "Spawn Opponent Test Cards"
	spawn_opponent_button.pressed.connect(spawn_random_opponent_cards)
	vbox.add_child(spawn_opponent_button)

	$UI.add_child(phase_panel)
	update_phase_ui()


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
			log_msg("Phase: Deployment")
		BattlePhase.COMBAT:
			log_msg("Phase: Combat")


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
			next_phase_button.text = "Resolve Combat"


func _on_next_phase_pressed() -> void:
	match current_phase:
		BattlePhase.BATTLEPLAN:
			open_battle_plan_selection()
		BattlePhase.TRIBUTE:
			set_phase(BattlePhase.DEPLOYMENT)
		BattlePhase.DEPLOYMENT:
			set_phase(BattlePhase.COMBAT)
		BattlePhase.COMBAT:
			resolve_combat_phase()
			start_next_round()


func start_next_round() -> void:
	if tribute_manager != null:
		tribute_manager.start_new_turn_refresh()
		update_tribute_counter()

	if battle_plan_manager != null:
		battle_plan_manager.advance_round()

	cancel_selected_card()
	open_battle_plan_selection()


func connect_all_slots() -> void:
	if board_slots == null:
		return

	for slot in board_slots.get_children():
		if slot.has_signal("slot_clicked"):
			slot.slot_clicked.connect(_on_slot_clicked)

		if slot.has_signal("slot_right_clicked"):
			slot.slot_right_clicked.connect(_on_slot_right_clicked)


func _on_hand_card_drag_started(card: CardUI) -> void:
	if waiting_for_battle_plan:
		return

	if card == null:
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
	if hand == null:
		return

	if player_deck == null:
		log_msg("PlayerDeck is missing.")
		return

	for i in range(5):
		var drawn_card: CardData = player_deck.draw_top_card()

		if drawn_card == null:
			log_msg("Deck ran out while dealing starting hand.")
			return

		hand.add_card_to_hand(drawn_card, false)

	if draw_pile != null:
		draw_pile.set_card_count(player_deck.cards_remaining())

	log_msg("Starting hand dealt. Deck remaining: " + str(player_deck.cards_remaining()))


func _on_draw_pile_drag_started(screen_position: Vector2) -> void:
	if waiting_for_battle_plan:
		return

	if current_phase == BattlePhase.COMBAT:
		log_msg("Cannot draw during Combat Phase.")
		return

	if hand == null:
		return

	if player_deck == null:
		log_msg("PlayerDeck is missing.")
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
	if hand == null:
		return

	hand.update_draw_pile_drag(screen_position)


func _on_draw_pile_drag_released(screen_position: Vector2) -> void:
	if hand == null:
		return

	if player_deck == null:
		log_msg("PlayerDeck is missing.")
		return

	if not hand.is_screen_position_in_hand_drop_zone(screen_position):
		var cancelled: bool = hand.finish_draw_pile_drag(screen_position, null)

		if not cancelled:
			log_msg("Draw cancelled.")

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
	else:
		log_msg("Draw cancelled.")


func _on_slot_clicked(slot: Node) -> void:
	if current_phase != BattlePhase.DEPLOYMENT:
		log_msg("Cards can only be deployed during the Deployment Phase.")
		return

	var placed := try_place_selected_card_on_slot(slot)

	if placed:
		if hand != null:
			hand.remove_selected_card()

		cancel_selected_card()


func _on_slot_right_clicked(slot: Node) -> void:
	var slot_id: String = slot.get_meta("slot_id", "")
	var discarded_card_data: CardData = null

	if slot.has_method("get_placed_card_data"):
		discarded_card_data = slot.get_placed_card_data()

	if discard_pile != null and discarded_card_data != null:
		discard_pile.add_card(discarded_card_data)
		log_msg("Sent " + discarded_card_data.card_name + " to discard pile.")

	slot.clear_slot()
	log_msg("Cleared slot: " + str(slot_id))
	update_slot_highlights()


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
			if selected_card_data == null:
				log_msg("Select a card first, then press T to tribute it.")
				return
			tribute_manager.offer_card_to_tribute(selected_card_data)
			log_msg("Debug tributed: " + selected_card_data.card_name + ". " + tribute_manager.get_status_text())
			log_msg("Unlocked factions: " + str(tribute_manager.get_unlocked_factions()))
		if event.keycode == KEY_Y:
			tribute_manager.refresh_tribute_points()
			log_msg("Tribute refreshed. " + tribute_manager.get_status_text())
		if event.keycode == KEY_D and hand != null:
			debug_draw_card()


func debug_draw_card() -> void:
	if current_phase == BattlePhase.COMBAT:
		log_msg("Cannot draw during Combat Phase.")
		return
	if player_deck == null:
		log_msg("PlayerDeck is missing.")
		return
	if not hand.can_accept_card():
		log_msg("Debug draw blocked. Hand is full. Max hand size: " + str(hand.max_hand_size))
		return

	var drawn_card: CardData = player_deck.draw_top_card()
	if drawn_card == null:
		log_msg("Deck is empty.")
		return

	hand.add_card_to_hand(drawn_card)
	if draw_pile != null:
		draw_pile.consume_top_card()
	log_msg("Debug drew card. Deck remaining: " + str(player_deck.cards_remaining()))


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
		log_msg("No slot found.")
		return false

	var slot_id: String = slot.get_meta("slot_id", "")

	if not has_selected_card:
		log_msg("No card selected.")
		return false
	if selected_card_data == null:
		log_msg("Selected card data is missing.")
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
		return true

	return false


func try_sacrifice_selected_card_to_tribute() -> bool:
	if not has_selected_card:
		log_msg("No card selected for tribute.")
		return false
	if selected_card_data == null:
		log_msg("Selected card data is missing.")
		return false

	var sacrificed_card_name := selected_card_data.card_name
	var sacrificed_card_type := selected_card_data.card_type.to_lower()
	var tribute_success: bool = tribute_manager.offer_card_to_tribute(selected_card_data)

	if not tribute_success:
		log_msg("Could not sacrifice " + sacrificed_card_name + ". Invalid card type.")
		return false

	if tribute_pile != null:
		tribute_pile.add_card()

	if sacrificed_card_type == "spell":
		log_msg("Sacrificed " + sacrificed_card_name + " for temporary Tribute. +2 TP this turn. " + tribute_manager.get_status_text())
	elif sacrificed_card_type == "equipment":
		log_msg("Sacrificed " + sacrificed_card_name + " for permanent Tribute. +1 permanent TP. " + tribute_manager.get_status_text())
	else:
		log_msg("Sacrificed " + sacrificed_card_name + " for Tribute. " + tribute_manager.get_status_text())

	log_msg("Unlocked factions: " + str(tribute_manager.get_unlocked_factions()))
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


func spawn_random_opponent_cards() -> void:
	if board_slots == null:
		return

	var opponent_front_slots: Array[Node] = []
	for slot in board_slots.get_children():
		if slot.get_meta("owner", "") != "enemy":
			continue
		if slot.get_meta("row", "") != "front":
			continue
		if slot.occupied:
			continue
		opponent_front_slots.append(slot)

	opponent_front_slots.shuffle()
	for slot in opponent_front_slots:
		var card_data: CardData = get_random_opponent_test_card()
		if card_data == null:
			continue
		if slot.has_method("place_card"):
			slot.place_card(TEST_CARD_SCENE, card_data, false)
			log_msg("Spawned opponent test card: " + card_data.card_name + " on " + str(slot.get_meta("slot_id", "")))

	log_msg("Opponent test board ready.")


func get_random_opponent_test_card() -> CardData:
	if OPPONENT_TEST_CARDS.is_empty():
		return null
	var index: int = randi() % OPPONENT_TEST_CARDS.size()
	return OPPONENT_TEST_CARDS[index]


func resolve_combat_phase() -> void:
	log_msg("Resolving prototype combat...")
	for lane in ["left", "middle", "right"]:
		var player_slot := find_slot_by_owner_row_lane("player", "front", lane)
		var opponent_slot := find_slot_by_owner_row_lane("enemy", "front", lane)
		resolve_lane_combat(lane, player_slot, opponent_slot)


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

	log_msg(lane.capitalize() + " lane clash: " + player_card.card_name + " AP " + str(player_card.ap) + " vs " + opponent_card.card_name + " DP " + str(opponent_card.dp))

	var opponent_defeated := player_card.ap >= opponent_card.dp
	var player_defeated := opponent_card.ap >= player_card.dp

	if opponent_defeated:
		send_slot_card_to_discard(opponent_slot)
		log_msg("Opponent " + opponent_card.card_name + " defeated.")
	if player_defeated:
		send_slot_card_to_discard(player_slot)
		log_msg("Player " + player_card.card_name + " defeated.")
	if not opponent_defeated and not player_defeated:
		log_msg("Both units survived the clash.")


func get_slot_card_data(slot: Node) -> CardData:
	if slot == null:
		return null
	if slot.has_method("get_placed_card_data"):
		return slot.get_placed_card_data()
	return null


func find_slot_by_owner_row_lane(owner: String, row: String, lane: String) -> Node:
	for slot in board_slots.get_children():
		if slot.get_meta("owner", "") != owner:
			continue
		if slot.get_meta("row", "") != row:
			continue
		if get_slot_lane(slot) != lane:
			continue
		return slot
	return null


func get_slot_lane(slot: Node) -> String:
	var column: String = slot.get_meta("column", "")
	if column == "left" or column == "middle" or column == "right":
		return column
	var slot_id := str(slot.get_meta("slot_id", "")).to_lower()
	if slot_id.contains("left"):
		return "left"
	if slot_id.contains("middle"):
		return "middle"
	if slot_id.contains("right"):
		return "right"
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
