extends Node3D

const TEST_CARD_SCENE: PackedScene = preload("res://Scenes/Cards/Card3D_Test.tscn")

const DWARF_AXE_GUARD: CardData = preload("res://Data/Cards/Dwarf_Axe_Guard.tres")
const ELF_CANOPY_ARCHER: CardData = preload("res://Data/Cards/Elf_Canopy_Archer.tres")
const ORC_BLOOD_RAIDER: CardData = preload("res://Data/Cards/Orc_Blood_Raider.tres")
const TEST_RUSE: CardData = preload("res://Data/Cards/Test_Ruse.tres")
const TEST_TRAP: CardData = preload("res://Data/Cards/Test_Trap.tres")

@onready var board_slots: Node3D = $BoardSlots
@onready var game_log = $GameLog
@onready var tribute_manager = $TributeManager

var selected_card_scene: PackedScene = null
var selected_card_data: CardData = null
var has_selected_card: bool = false


func _ready() -> void:
	connect_all_slots()
	tribute_manager.add_tribute(3)
	log_msg("Starting Tribute: " + tribute_manager.get_status_text())
		


func connect_all_slots() -> void:
	for slot in board_slots.get_children():
		if slot.has_signal("slot_clicked"):
			slot.slot_clicked.connect(_on_slot_clicked)

		if slot.has_signal("slot_right_clicked"):
			slot.slot_right_clicked.connect(_on_slot_right_clicked)


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
	var slot_id: String = slot.get_meta("slot_id", "")

	log_msg("Clicked slot: " + str(slot_id))

	if not has_selected_card:
		log_msg("No card selected.")
		return

	if selected_card_data == null:
		log_msg("Selected card data is missing.")
		return

	if not is_valid_slot_for_selected_card(slot):
		log_msg("Invalid placement for " + selected_card_data.card_name + " on " + str(slot_id))
		return

	log_msg("Trying to place: " + selected_card_data.card_name)
	
	if not tribute_manager.can_afford(selected_card_data.tribute_cost):
		log_msg("Not enough Tribute Points. Need " + str(selected_card_data.tribute_cost) + ", have " + str(tribute_manager.current_tribute_points) + ".")
		return
	
	var placed_successfully: bool = slot.place_card(selected_card_scene, selected_card_data)

	if placed_successfully:
		tribute_manager.spend_tribute(selected_card_data.tribute_cost)
		log_msg("Spent " + str(selected_card_data.tribute_cost) + " TP. " + tribute_manager.get_status_text())
		cancel_selected_card()


func _on_slot_right_clicked(slot: Node) -> void:
	var slot_id: String = slot.get_meta("slot_id", "")
	slot.clear_slot()
	log_msg("Cleared slot: " + str(slot_id))
	update_slot_highlights()


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
