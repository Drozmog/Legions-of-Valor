extends Node3D

const TEST_CARD_SCENE: PackedScene = preload("res://Scenes/Cards/Card3D_Test.tscn")

@onready var board_slots: Node3D = $BoardSlots
@onready var game_log = $GameLog

var selected_card_scene: PackedScene = null
var has_selected_card: bool = false


func _ready() -> void:
	connect_all_slots()


func connect_all_slots() -> void:
	for slot in board_slots.get_children():
		if slot.has_signal("slot_clicked"):
			slot.slot_clicked.connect(_on_slot_clicked)

		if slot.has_signal("slot_right_clicked"):
			slot.slot_right_clicked.connect(_on_slot_right_clicked)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			select_test_card()

		if event.keycode == KEY_ESCAPE:
			cancel_selected_card()


func select_test_card() -> void:
	selected_card_scene = TEST_CARD_SCENE
	has_selected_card = true
	log_msg("Test card selected. Click a valid player slot.")
	update_slot_highlights()


func cancel_selected_card() -> void:
	selected_card_scene = null
	has_selected_card = false
	log_msg("Selected card cancelled.")
	update_slot_highlights()


func _on_slot_clicked(slot: Node) -> void:
	var slot_owner: String = slot.get_meta("owner", "")
	var slot_id: String = slot.get_meta("slot_id", "")

	log_msg("Clicked slot: " + str(slot_id))

	if not has_selected_card:
		log_msg("No card selected.")
		return

	if slot_owner != "player":
		log_msg("Cannot place card on enemy slot: " + slot_id)
		return

	if slot.occupied:
		log_msg("Slot already occupied: " + str(slot_id))
		return

	var placed_successfully: bool = slot.place_card(selected_card_scene)

	if placed_successfully:
		cancel_selected_card()


func _on_slot_right_clicked(slot: Node) -> void:
	slot.clear_slot()
	
	
func log_msg(message: String) -> void:
	if game_log and game_log.has_method("add_log"):
		game_log.add_log(message)
	else:
		print(message)


func update_slot_highlights() -> void:
	log_msg("Updating slot highlights.")

	for slot in board_slots.get_children():
		var slot_owner: String = slot.get_meta("owner", "")

		if not slot.has_method("set_highlight"):
			continue

		if not has_selected_card:
			slot.set_highlight(false)
			slot.set_invalid_highlight(false)
			continue

		if slot_owner == "player" and not slot.occupied:
			slot.set_highlight(true)
		else:
			slot.set_invalid_highlight(true)
