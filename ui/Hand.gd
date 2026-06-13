class_name HandUI
extends Control

const CARD_UI_SCENE: PackedScene = preload("res://cards/CardUI.tscn")

signal card_drag_started(card: CardUI)
signal card_drag_released(card: CardUI, screen_position: Vector2)

var dragged_card: CardUI = null

@export var card_scale: float = 0.62

@export var raised_anchor_from_bottom: float = 85.0
@export var lowered_anchor_below_screen: float = 180.0

@export var min_spacing: float = 75.0
@export var max_spacing: float = 145.0
@export var max_fan_width: float = 1050.0

@export var max_rotation_degrees: float = 7.0
@export var fan_curve_drop: float = 35.0
@export var hover_lift: float = 55.0
@export var tween_time: float = 0.22

var cards: Array[Control] = []
var selected_card: Control = null
var deck: Array[CardData] = []
var hand_is_raised: bool = false

signal card_selected(card: Control)
signal card_cleared()

const SAMPLE_CARDS: Array[CardData] = [
	preload("res://cards/definitions/Dwarf_Axe_Guard.tres"),
	preload("res://cards/definitions/Elf_Canopy_Archer.tres"),
	preload("res://cards/definitions/Orc_Blood_Raider.tres"),
	preload("res://cards/definitions/Test_Ruse.tres"),
	preload("res://cards/definitions/Test_Trap.tres"),
]


func _ready() -> void:
	build_deck()

	for i in range(5):
		draw_card()

	arrange_fan(false)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			toggle_hand()


func build_deck() -> void:
	deck.clear()

	for n in range(4):
		deck.append_array(SAMPLE_CARDS)

	deck.shuffle()


func draw_card() -> void:
	if deck.is_empty():
		return

	var data: CardData = deck.pop_back()
	var card: CardUI = CARD_UI_SCENE.instantiate()

	add_child(card)
	cards.append(card)

	card.setup(data)
	card.drag_started.connect(_on_card_drag_started)
	card.drag_released.connect(_on_card_drag_released)
	card.mouse_entered.connect(_on_card_hovered.bind(card))
	card.mouse_exited.connect(_on_card_unhovered.bind(card))
	card.gui_input.connect(_on_card_gui_input.bind(card))

	arrange_fan()

func _on_card_drag_started(card: CardUI) -> void:
	dragged_card = card
	selected_card = card

	lower_hand()

	card_drag_started.emit(card)


func _on_card_drag_released(card: CardUI, screen_position: Vector2) -> void:
	card_drag_released.emit(card, screen_position)


func return_dragged_card_to_hand(card: CardUI) -> void:
	dragged_card = null
	selected_card = null

	if not cards.has(card):
		cards.append(card)

	raise_hand()
	arrange_fan()


func consume_dragged_card(card: CardUI) -> void:
	cards.erase(card)

	if card != null:
		card.queue_free()

	dragged_card = null
	selected_card = null

	lower_hand()
	arrange_fan()

func toggle_hand() -> void:
	hand_is_raised = !hand_is_raised
	arrange_fan()


func raise_hand() -> void:
	hand_is_raised = true
	arrange_fan()


func lower_hand() -> void:
	hand_is_raised = false
	arrange_fan()


func arrange_fan(animated: bool = true) -> void:
	var count := cards.size()

	if count == 0:
		return

	var area_size := get_hand_area_size()
	var center_x := area_size.x / 2.0

	var anchor_y: float

	if hand_is_raised:
		anchor_y = area_size.y - raised_anchor_from_bottom
	else:
		anchor_y = area_size.y + lowered_anchor_below_screen

	var spacing := 0.0

	if count > 1:
		spacing = max_fan_width / float(count - 1)
		spacing = clamp(spacing, min_spacing, max_spacing)

	var total_width := spacing * float(count - 1)
	var start_x := center_x - total_width / 2.0

	for i in range(count):
		var card := cards[i]
		if card == dragged_card:
			continue

		var normalized := 0.0

		if count > 1:
			normalized = (float(i) / float(count - 1)) * 2.0 - 1.0

		var target_x := start_x + spacing * float(i)
		var edge_drop := pow(absf(normalized), 1.2) * fan_curve_drop
		var target_y := anchor_y + edge_drop
		var target_rotation := normalized * max_rotation_degrees

		card.pivot_offset = Vector2(card.size.x / 2.0, card.size.y)

		var target_position := Vector2(target_x, target_y) - card.pivot_offset

		card.set_meta("home_position", target_position)
		card.set_meta("home_rotation", target_rotation)

		if animated:
			_move_card_to_layout(card, target_position, target_rotation)
		else:
			card.position = target_position
			card.rotation_degrees = target_rotation
			card.scale = Vector2(card_scale, card_scale)


func get_hand_area_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size

	return get_viewport_rect().size


func _on_card_hovered(card: Control) -> void:
	if not hand_is_raised:
		return

	if card == selected_card:
		return

	card.move_to_front()
	_move_card_to(card, card.get_meta("home_position") + Vector2(0, -hover_lift))


func _on_card_unhovered(card: Control) -> void:
	if card == selected_card:
		return

	_move_card_to(card, card.get_meta("home_position"))


func _on_card_gui_input(event: InputEvent, card: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not hand_is_raised:
			raise_hand()
			return

		select_card(card)


func select_card(card: Control) -> void:
	if selected_card == card:
		_move_card_to(card, card.get_meta("home_position"))
		selected_card = null
		card_cleared.emit()
		return

	if selected_card != null:
		_move_card_to(selected_card, selected_card.get_meta("home_position"))

	selected_card = card
	card.move_to_front()

	_move_card_to(card, card.get_meta("home_position") + Vector2(0, -hover_lift))

	card_selected.emit(card)


func _move_card_to(card: Control, target: Vector2) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", target, tween_time)


func _move_card_to_layout(card: Control, target_position: Vector2, target_rotation: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	tween.tween_property(card, "position", target_position, tween_time)
	tween.parallel().tween_property(card, "rotation_degrees", target_rotation, tween_time)
	tween.parallel().tween_property(card, "scale", Vector2(card_scale, card_scale), tween_time)


func remove_selected_card() -> void:
	if selected_card == null:
		return

	cards.erase(selected_card)
	selected_card.queue_free()
	selected_card = null

	arrange_fan()
