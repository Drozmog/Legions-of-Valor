class_name HandUI
extends Control

const CARD_UI_SCENE: PackedScene = preload("res://cards/CardUI.tscn")

signal card_drag_started(card: CardUI)
signal card_drag_released(card: CardUI, screen_position: Vector2)

signal card_inspect_requested(card: CardUI, card_data: CardData)

@warning_ignore("unused_signal")
signal card_selected(card: Control)
@warning_ignore("unused_signal")
signal card_cleared()

@export var card_scale: float = 0.80
@export var max_hand_size: int = 7

@export var raised_anchor_from_bottom: float = 120.0
@export var lowered_anchor_below_screen: float = 140.0

@export var min_spacing: float = 95.0
@export var max_spacing: float = 165.0
@export var max_fan_width: float = 1250.0

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
var showing_ability_icons: bool = false

func _ready() -> void:
	hand_is_raised = false
	arrange_fan(false)
	set_process(true)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			toggle_hand()


func _process(_delta: float) -> void:
	var shift_is_down := Input.is_key_pressed(KEY_SHIFT) and hand_is_raised

	if shift_is_down == showing_ability_icons:
		return

	showing_ability_icons = shift_is_down

	for card in cards:
		if card == null:
			continue

		if card.has_method("set_ability_icons_visible"):
			card.set_ability_icons_visible(showing_ability_icons)


func connect_hand_card_signals(card: CardUI) -> void:
	card.mouse_entered.connect(_on_card_hovered.bind(card))
	card.mouse_exited.connect(_on_card_unhovered.bind(card))

	card.drag_started.connect(_on_card_drag_started)
	card.drag_released.connect(_on_card_drag_released)
	card.clicked.connect(_on_card_clicked)


func toggle_hand() -> void:
	hand_is_raised = !hand_is_raised
	arrange_fan()


func raise_hand() -> void:
	hand_is_raised = true
	arrange_fan()


func lower_hand() -> void:
	hand_is_raised = false
	arrange_fan()

func set_max_hand_size(new_limit: int) -> void:
	max_hand_size = max(new_limit, 0)


func can_accept_card() -> bool:
	return cards.size() < max_hand_size


func add_card_to_hand(card_data: CardData, animated: bool = true) -> bool:
	if card_data == null:
		return false

	if not can_accept_card():
		return false

	var card := CARD_UI_SCENE.instantiate() as CardUI

	add_child(card)
	cards.append(card)

	card.setup(card_data)
	card.scale = Vector2(card_scale, card_scale)

	connect_hand_card_signals(card)

	arrange_fan(animated)

	return true


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

	card.move_to_front()
	_move_card_to(card, home_position + Vector2(0, -hover_lift))


func _on_card_unhovered(card: CardUI) -> void:
	
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

	for hand_card in cards:
		if hand_card != null and hand_card.has_method("set_ability_icons_visible"):
			hand_card.set_ability_icons_visible(false)

	card.move_to_front()
	card_drag_started.emit(card)


func _on_card_drag_released(card: CardUI, screen_position: Vector2) -> void:
	if card == null:
		return

	if not is_instance_valid(card):
		return

	card_drag_released.emit(card, screen_position)

	# Safety fallback:
	# Wait one frame. If the battlefield manager did not consume/place/tribute/reorder it,
	# smoothly return it to the hand.
	call_deferred("_deferred_return_if_card_still_in_hand", card)
	


func _on_card_clicked(card: CardUI, _screen_position: Vector2) -> void:
	if card == null:
		return

	if card.card_data == null:
		return

	card_inspect_requested.emit(card, card.card_data)


func return_dragged_card_to_hand(card: CardUI) -> void:
	force_return_card_to_hand(card)


func _deferred_return_if_card_still_in_hand(card: CardUI) -> void:
	if card == null:
		return

	if not is_instance_valid(card):
		return

	if not cards.has(card):
		return

	force_return_card_to_hand(card)
	

func is_screen_position_in_hand_reorder_zone(screen_position: Vector2) -> bool:
	var viewport_size: Vector2 = get_viewport_rect().size

	# Whole bottom hand area.
	# Do NOT cut off the right half anymore.
	return screen_position.y >= viewport_size.y - 300.0
	

func reorder_card_in_hand(card: CardUI, screen_x: float) -> void:
	if card == null:
		return

	if not cards.has(card):
		cards.append(card)

	cards.erase(card)

	var insert_index: int = cards.size()

	for i in range(cards.size()):
		var other_card: CardUI = cards[i]

		if other_card == null:
			continue

		var other_center_x: float = other_card.global_position.x + (other_card.size.x * other_card.scale.x * 0.5)

		if screen_x < other_center_x:
			insert_index = i
			break

	cards.insert(insert_index, card)
	


func force_return_card_to_hand(card: CardUI) -> void:
	if card == null:
		dragged_card = null
		selected_card = null
		arrange_fan()
		return

	var old_global_position: Vector2 = card.global_position

	card.mouse_is_pressed = false
	card.is_dragging = false
	card.set_process(false)

	if card.get_parent() != self:
		if card.get_parent() != null:
			card.get_parent().remove_child(card)

		add_child(card)
		card.global_position = old_global_position

	if not cards.has(card):
		cards.append(card)

	dragged_card = null
	selected_card = null

	card.rotation_degrees = 0
	card.scale = Vector2(card_scale, card_scale)
	card.move_to_front()

	# Smooth glide back instead of teleport.
	arrange_fan(true)



func consume_dragged_card(card: CardUI) -> void:
	if card != null:
		cards.erase(card)
		card.queue_free()

	dragged_card = null
	selected_card = null

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
	if not can_accept_card():
		return false
	
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

	if not can_accept_card():
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
