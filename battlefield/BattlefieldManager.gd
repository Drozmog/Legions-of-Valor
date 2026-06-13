extends Node3D

const TEST_CARD_SCENE: PackedScene = preload("res://cards/Card3D_Test.tscn")

const DWARF_AXE_GUARD: CardData = preload("res://cards/definitions/Dwarf_Axe_Guard.tres")
const ELF_CANOPY_ARCHER: CardData = preload("res://cards/definitions/Elf_Canopy_Archer.tres")
const ORC_BLOOD_RAIDER: CardData = preload("res://cards/definitions/Orc_Blood_Raider.tres")
const TEST_RUSE: CardData = preload("res://cards/definitions/Test_Ruse.tres")
const TEST_TRAP: CardData = preload("res://cards/definitions/Test_Trap.tres")

@onready var board_slots: Node3D = $BoardSlots
@onready var game_log = $GameLog
@onready var tribute_manager = $TributeManager

var selected_card_scene: PackedScene = null
var selected_card_data: CardData = null
var has_selected_card: bool = false

@export var hand: HandUI
@export var draw_pile: DrawPile
@export var tribute_pile: TributePile

func _ready() -> void:
	connect_all_slots()
	hand.card_drag_started.connect(_on_hand_card_drag_started)
	hand.card_drag_released.connect(_on_hand_card_drag_released)
	hand.card_selected.connect(_on_hand_card_selected)
	hand.card_cleared.connect(_on_hand_card_cleared)
	tribute_manager.add_tribute(3)
	draw_pile.pile_clicked.connect(_on_draw_pile_clicked)
	tribute_pile.tribute_pile_clicked.connect(_on_tribute_pile_clicked)
	log_msg("Starting Tribute: " + tribute_manager.get_status_text())
		

func _on_hand_card_drag_started(card: CardUI) -> void:
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

func try_place_selected_card_on_slot(slot: Node) -> bool:
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

	var placed_successfully: bool = slot.place_card(selected_card_scene, selected_card_data)

	if placed_successfully:
		tribute_manager.spend_tribute(selected_card_data.tribute_cost)
		log_msg("Spent " + str(selected_card_data.tribute_cost) + " TP. " + tribute_manager.get_status_text())
		return true

	return false

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
	var current := node

	while current != null:
		if current == target:
			return true

		current = current.get_parent()

	return false

func connect_all_slots() -> void:
	for slot in board_slots.get_children():
		if slot.has_signal("slot_clicked"):
			slot.slot_clicked.connect(_on_slot_clicked)

		if slot.has_signal("slot_right_clicked"):
			slot.slot_right_clicked.connect(_on_slot_right_clicked)


func _on_hand_card_selected(card) -> void:
	select_card(card.card_data)
	
func _on_hand_card_cleared() -> void:
	cancel_selected_card()
	
func _on_draw_pile_clicked() -> void:
	hand.draw_card()
	
func _on_tribute_pile_clicked() -> void:
	if not has_selected_card:
		log_msg("Select a card from your hand to sacrifice for tribute.")
		return
	tribute_manager.add_tribute(1)        # each sacrifice = +1 TP for now
	tribute_pile.add_card()               # grow the visual pile
	log_msg("Sacrificed " + selected_card_data.card_name + " for 1 TP. " + tribute_manager.get_status_text())
	hand.remove_selected_card()           # the card leaves your hand
	cancel_selected_card()
	
	
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			select_card(DWARF_AXE_GUARD)

		if event.keycode == KEY_2:
			select_card(TEST_RUSE)

		if event.keycode == KEY_3:
			select_card(TEST_TRAP)

		if event.keycode == KEY_4:
			select_card(ELF_CANOPY_ARCHER)

		if event.keycode == KEY_5:
			select_card(ORC_BLOOD_RAIDER)

		if event.keycode == KEY_ESCAPE:
			cancel_selected_card()

		if event.keycode == KEY_T:
			tribute_manager.add_tribute(1)
			log_msg("Added 1 card to Tribute Pile. " + tribute_manager.get_status_text())

		if event.keycode == KEY_Y:
			tribute_manager.refresh_tribute_points()
			log_msg("Tribute refreshed. " + tribute_manager.get_status_text())
			
		if event.keycode == KEY_D:
			hand.draw_card()


func select_card(card_data: CardData) -> void:
	selected_card_scene = TEST_CARD_SCENE
	selected_card_data = card_data
	has_selected_card = true

	log_msg("Selected: " + card_data.card_name + " | TP " + str(card_data.tribute_cost) + " | " + card_data.card_type)
	update_slot_highlights()


func cancel_selected_card() -> void:
	selected_card_scene = null
	selected_card_data = null
	has_selected_card = false

	log_msg("Selected card cancelled.")
	update_slot_highlights()


func _on_slot_clicked(slot: Node) -> void:
	var placed := try_place_selected_card_on_slot(slot)

	if placed:
		hand.remove_selected_card()
		cancel_selected_card()

func _on_slot_right_clicked(slot: Node) -> void:
	var slot_id: String = slot.get_meta("slot_id", "")
	slot.clear_slot()
	log_msg("Cleared slot: " + str(slot_id))
	update_slot_highlights()

func try_sacrifice_selected_card_to_tribute() -> bool:
	if not has_selected_card:
		log_msg("No card selected for tribute.")
		return false

	if selected_card_data == null:
		log_msg("Selected card data is missing.")
		return false

	tribute_manager.add_tribute(1)
	tribute_pile.add_card()

	log_msg("Sacrificed " + selected_card_data.card_name + " for Tribute. " + tribute_manager.get_status_text())

	return true

func is_valid_slot_for_selected_card(slot: Node) -> bool:
	var slot_owner: String = slot.get_meta("owner", "")
	var slot_row: String = slot.get_meta("row", "")

	if not has_selected_card:
		return false

	if selected_card_data == null:
		return false

	if slot_owner != "player":
		return false

	if slot.occupied:
		return false

	if selected_card_data.card_type == "unit":
		return slot_row == "front"

	if selected_card_data.card_type == "ruse" or selected_card_data.card_type == "trap":
		return slot_row == "back"

	return false


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


func log_msg(message: String) -> void:
	if game_log != null and game_log.has_method("add_log"):
		game_log.add_log(message)
	else:
		print("LOG FALLBACK: " + message)
