class_name HandUI
extends Control

const CARD_UI_SCENE: PackedScene = preload("res://cards/CardUI.tscn")

signal card_drag_started(card: CardUI)
signal card_drag_released(card: CardUI, screen_position: Vector2)

signal card_preview_requested(card_data: CardData)
signal card_preview_cleared()

@warning_ignore("unused_signal")
signal card_selected(card: Control)
@warning_ignore("unused_signal")
signal card_cleared()

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

@export var draw_drop_zone_from_bottom: float = 330.0

var cards: Array[CardUI] = []
var selected_card: CardUI = null
var dragged_card: CardUI = null

var hand_is_raised: bool = false

var draw_drag_card: CardUI = null
var pending_draw_data: CardData = null


func _ready() -> void:
	arrange_fan(false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			toggle_hand()


func connect_hand_card_signals(card: CardUI) -> void:
	card.mouse_entered.connect(_on_card_hovered.bind(card))
	card.mouse_exited.connect(_on_card_unhovered.bind(card))

	card.drag_started.connect(_on_card_drag_started)
	card.drag_released.connect(_on_card_drag_released)


func toggle_hand() -> void:
	hand_is_raised = !hand_is_raised
	arrange_fan()


func raise_hand() -> void:
	hand_is_raised = true
	arrange_fan()


func lower_hand() -> void:
	hand_is_raised = false
	arrange_fan()


func add_card_to_hand(card_data: CardData, animated: bool = true) -> void:
	if card_data == null:
		return

	var card := CARD_UI_SCENE.instantiate() as CardUI

	add_child(card)
	cards.append(card)

	card.setup(card_data)
	card.scale = Vector2(card_scale, card_scale)

	connect_hand_card_signals(card)

	arrange_fan(animated)


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


func _on_card_hovered(card: CardUI) -> void:
	if not hand_is_raised:
		return

	if card == selected_card:
		return

	if card == dragged_card:
		return

	if card == draw_drag_card:
		return

	if not card.has_meta("home_position"):
		return

	var home_position = card.get_meta("home_position")

	if home_position == null:
		return

	if card.card_data != null:
		card_preview_requested.emit(card.card_data)

	card.move_to_front()
	_move_card_to(card, home_position + Vector2(0, -hover_lift))


func _on_card_unhovered(card: CardUI) -> void:
	card_preview_cleared.emit()
	
	if card == selected_card:
		return

	if card == dragged_card:
		return

	if card == draw_drag_card:
		return

	if not card.has_meta("home_position"):
		return

	var home_position = card.get_meta("home_position")

	if home_position == null:
		return

	_move_card_to(card, home_position)


func _on_card_drag_started(card: CardUI) -> void:
	dragged_card = card
	selected_card = card

	lower_hand()

	card.move_to_front()
	card_drag_started.emit(card)


func _on_card_drag_released(card: CardUI, screen_position: Vector2) -> void:
	card_drag_released.emit(card, screen_position)


func return_dragged_card_to_hand(card: CardUI) -> void:
	dragged_card = null
	selected_card = null

	if card != null and not cards.has(card):
		cards.append(card)

	raise_hand()
	arrange_fan()


func consume_dragged_card(card: CardUI) -> void:
	if card != null:
		cards.erase(card)
		card.queue_free()

	dragged_card = null
	selected_card = null

	lower_hand()
	arrange_fan()


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
	dragged_card = null

	arrange_fan()


# ------------------------------------------------------------
# DRAW PILE DRAG INTO HAND
# ------------------------------------------------------------

func start_draw_pile_drag(screen_position: Vector2, preview_card_data: CardData) -> bool:
	if preview_card_data == null:
		return false

	pending_draw_data = preview_card_data

	draw_drag_card = CARD_UI_SCENE.instantiate() as CardUI
	add_child(draw_drag_card)

	draw_drag_card.setup(pending_draw_data)
	draw_drag_card.show_back()

	draw_drag_card.scale = Vector2(card_scale, card_scale)
	draw_drag_card.rotation_degrees = 0
	draw_drag_card.move_to_front()

	draw_drag_card.global_position = screen_position - draw_drag_card.size * card_scale / 2.0

	return true

func update_draw_pile_drag(screen_position: Vector2) -> void:
	if draw_drag_card == null:
		return

	draw_drag_card.global_position = screen_position - draw_drag_card.size * card_scale / 2.0


func finish_draw_pile_drag(screen_position: Vector2, drawn_card_data: CardData) -> bool:
	if draw_drag_card == null:
		return false

	if not is_screen_position_in_hand_drop_zone(screen_position):
		draw_drag_card.queue_free()
		draw_drag_card = null
		pending_draw_data = null
		return false

	if drawn_card_data == null:
		draw_drag_card.queue_free()
		draw_drag_card = null
		pending_draw_data = null
		return false

	draw_drag_card.card_data = drawn_card_data
	draw_drag_card.show_back()

	cards.append(draw_drag_card)
	connect_hand_card_signals(draw_drag_card)

	animate_draw_flip_into_hand(draw_drag_card)

	draw_drag_card = null
	pending_draw_data = null

	return true
	

func is_screen_position_in_hand_drop_zone(screen_position: Vector2) -> bool:
	var viewport_size := get_viewport_rect().size
	return screen_position.y >= viewport_size.y - draw_drop_zone_from_bottom


func animate_draw_flip_into_hand(card: CardUI) -> void:
	card.move_to_front()
	card.rotation_degrees = 0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(card, "scale", Vector2(0.0, card_scale), 0.12)
	tween.tween_callback(Callable(card, "show_front"))
	tween.tween_property(card, "scale", Vector2(card_scale, card_scale), 0.12)
	tween.tween_callback(Callable(self, "arrange_fan"))
