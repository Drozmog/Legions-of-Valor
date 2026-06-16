class_name BattlefieldManagerPhase2BoardMenu
extends "res://battlefield/BattlefieldManagerPhase1Rules.gd"

const BOARD_ACTION_INSPECT: int = 1
const BOARD_ACTION_CANCEL: int = 99

var board_action_menu: PopupMenu = null
var board_action_target_slot: Node = null


func _ready() -> void:
	super._ready()
	create_board_slot_action_menu()


func create_board_slot_action_menu() -> void:
	if board_action_menu != null:
		return

	board_action_menu = PopupMenu.new()
	board_action_menu.name = "BoardSlotActionMenu"
	board_action_menu.visible = false
	board_action_menu.exclusive = false
	board_action_menu.id_pressed.connect(_on_board_slot_action_selected)

	$UI.add_child(board_action_menu)


func _on_slot_right_clicked(slot: Node) -> void:
	show_board_slot_action_menu(slot)


func show_board_slot_action_menu(slot: Node) -> void:
	if slot == null:
		return

	if board_action_menu == null:
		create_board_slot_action_menu()

	board_action_target_slot = slot
	board_action_menu.clear()

	var card_data: CardData = get_slot_card_data(slot)

	if card_data != null:
		board_action_menu.add_item("Inspect", BOARD_ACTION_INSPECT)
	else:
		board_action_menu.add_disabled_item("Empty Slot")

	board_action_menu.add_separator()
	board_action_menu.add_item("Cancel", BOARD_ACTION_CANCEL)

	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	board_action_menu.position = Vector2i(int(mouse_position.x), int(mouse_position.y))
	board_action_menu.popup()


func _on_board_slot_action_selected(action_id: int) -> void:
	match action_id:
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
