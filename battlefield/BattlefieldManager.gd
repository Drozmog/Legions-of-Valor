extends Node3D

const TEST_CARD_SCENE: PackedScene = preload("res://cards/Card3D_Test.tscn")

const ARCH_WIZARD_MAELCOR: CardData = preload("res://cards/definitions/arch_wizard_maelcor.tres")
const IMPERIAL_ARCHIVE_MASTER: CardData = preload("res://cards/definitions/imperial_archive_master.tres")
const JENA_OF_YEL: CardData = preload("res://cards/definitions/jena_of_yel.tres")
const IVAAN_BONE_CRUSHER: CardData = preload("res://cards/definitions/ivaan_bone_crusher.tres")
const UPPER_HALL_PROSPECTOR: CardData = preload("res://cards/definitions/upper_hall_prospector.tres")
const TEST_EQUIPMENT: CardData = preload("res://cards/definitions/Test_Equipment.tres")
const TEST_SPELL: CardData = preload("res://cards/definitions/Test_Spell.tres")

@onready var board_slots: Node3D = $BoardSlots
@onready var game_log = $GameLog
@onready var tribute_manager = $TributeManager

@onready var battle_plan_manager: BattlePlanManager = $BattlePlanManager
@onready var battle_plan_panel: BattlePlanPanel = $UI/BattlePlanPanel
@onready var battle_plan_selection_screen: BattlePlanSelectionScreen = $UI/BattlePlanSelectionScreen
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


func _ready() -> void:
	connect_all_slots()

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

	setup_battle_plan_flow()
	create_debug_tp_button()


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

	if battle_plan_manager == null:
		log_msg("BattlePlanManager is missing.")
		begin_game_after_battle_plan_selection()
		return

	if battle_plan_selection_screen == null:
		log_msg("BattlePlanSelectionScreen is missing.")
		begin_game_after_battle_plan_selection()
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


func connect_all_slots() -> void:
	for slot in board_slots.get_children():
		if slot.has_signal("slot_clicked"):
			slot.slot_clicked.connect(_on_slot_clicked)

		if slot.has_signal("slot_right_clicked"):
			slot.slot_right_clicked.connect(_on_slot_right_clicked)


# ------------------------------------------------------------
# HAND CARD DRAG TO BOARD / TRIBUTE
# ------------------------------------------------------------

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
		var placed := try_place_selected_card_on_slot(target_slot)

		if placed:
			hand.consume_dragged_card(card)
			cancel_selected_card()
		else:
			hand.return_dragged_card_to_hand(card)
			cancel_selected_card()

		return

	if is_node_inside_target(target_node, tribute_pile):
		var sacrificed := try_sacrifice_selected_card_to_tribute()

		if sacrificed:
			hand.consume_dragged_card(card)
			cancel_selected_card()
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


# ------------------------------------------------------------
# DRAW PILE DRAG TO HAND
# ------------------------------------------------------------

func _on_draw_pile_drag_started(screen_position: Vector2) -> void:
	if waiting_for_battle_plan:
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


# ------------------------------------------------------------
# OLD CLICK SUPPORT / DEBUG
# ------------------------------------------------------------

func _on_slot_clicked(slot: Node) -> void:
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
			tribute_manager.cleanup_temporary_tribute()
			log_msg("End Turn cleanup: temporary TP removed. " + tribute_manager.get_status_text())
			update_tribute_counter()
			if battle_plan_manager != null:
				battle_plan_manager.advance_round()

				open_battle_plan_selection()

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


# ------------------------------------------------------------
# CARD SELECTION
# ------------------------------------------------------------

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


# ------------------------------------------------------------
# PLACEMENT
# ------------------------------------------------------------

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

	log_msg("Trying to place: " + selected_card_data.card_name)

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
	var slot_owner: String = slot.get_meta("owner", "")

	if not has_selected_card:
		return false

	if selected_card_data == null:
		return false

	if slot_owner != "player":
		return false

	if slot.occupied:
		return false

	return true


func update_slot_highlights() -> void:
	for slot in board_slots.get_children():
		if not slot.has_method("set_highlight"):
			continue

		if not slot.has_method("set_invalid_highlight"):
			continue

		if not has_selected_card:
			slot.set_highlight(false)
			slot.set_invalid_highlight(false)
			continue

		if is_valid_slot_for_selected_card(slot):
			slot.set_highlight(true)
		else:
			slot.set_invalid_highlight(true)


# ------------------------------------------------------------
# RAYCAST / TARGET DETECTION
# ------------------------------------------------------------

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
	if node == null:
		return false

	if target == null:
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
	if tribute_pile == null:
		return

	if tribute_manager == null:
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



# ------------------------------------------------------------
# LOG
# ------------------------------------------------------------

func log_msg(message: String) -> void:
	if game_log != null and game_log.has_method("add_log"):
		game_log.add_log(message)
	else:
		print("LOG FALLBACK: " + message)
