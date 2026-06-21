class_name DrawPile
extends Node3D

signal draw_drag_started(screen_position: Vector2)
signal draw_drag_moved(screen_position: Vector2)
signal draw_drag_released(screen_position: Vector2)

@export var card_count: int = 40
@export var card_width: float = 1.02
@export var card_height: float = 1.34
@export var card_thickness: float = 0.006
@export var max_visible_cards: int = 14
@export var card_gap: float = 0.008

@export var counter_side_offset: float = 0.0
@export var counter_height: float = 0.16
@export var counter_forward_offset: float = 0.92
@export var counter_pixel_size: float = 0.006

@onready var click_area: Area3D = get_node_or_null("ClickArea") as Area3D

var is_dragging_from_pile: bool = false
var stacked_cards: Array[Node3D] = []
var base_node: MeshInstance3D = null
var counter_label: Label3D = null


func _ready() -> void:
	create_base()
	create_counter_label()
	build_stack()

	if click_area != null:
		click_area.input_ray_pickable = true
		click_area.input_event.connect(_on_click_area_input_event)
		click_area.mouse_entered.connect(_on_mouse_entered)
		click_area.mouse_exited.connect(_on_mouse_exited)

	set_process(false)


func create_base() -> void:
	if base_node != null:
		return

	base_node = CardPileVisual.create_pile_base("DrawPileBase")
	add_child(base_node)


func create_counter_label() -> void:
	if counter_label != null:
		return

	counter_label = CardPileVisual.create_counter_label(
		"DrawPileCounter",
		"Deck: " + str(card_count),
		Vector3(counter_side_offset, counter_height, counter_forward_offset),
		counter_pixel_size,
		20
	)

	add_child(counter_label)


func update_counter_label() -> void:
	if counter_label == null:
		return

	counter_label.position = Vector3(counter_side_offset, counter_height, counter_forward_offset)
	counter_label.text = "Deck: " + str(card_count)


func set_card_count(new_count: int) -> void:
	card_count = max(new_count, 0)
	build_stack()


func build_stack() -> void:
	clear_stack()

	var visible_count: int = mini(card_count, max_visible_cards)

	for i in range(visible_count):
		var card := CardPileVisual.create_card_back_visual(card_width, card_height)
		card.position = Vector3(0, 0.025 + float(i) * (card_thickness + card_gap), 0)
		card.rotation_degrees = Vector3.ZERO
		add_child(card)
		stacked_cards.append(card)

	update_counter_label()


func clear_stack() -> void:
	for card in stacked_cards:
		if card != null and is_instance_valid(card):
			card.queue_free()

	stacked_cards.clear()


func _on_click_area_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if card_count <= 0 or is_dragging_from_pile:
				return

			is_dragging_from_pile = true
			Cursors.use_grab()
			set_process(true)

			draw_drag_started.emit(get_viewport().get_mouse_position())


func _process(_delta: float) -> void:
	if not is_dragging_from_pile:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	draw_drag_moved.emit(mouse_pos)

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_dragging_from_pile = false
		Cursors.use_normal()
		set_process(false)

		draw_drag_released.emit(mouse_pos)


func _on_mouse_entered() -> void:
	if not is_dragging_from_pile and card_count > 0:
		Cursors.use_pointing()


func _on_mouse_exited() -> void:
	if not is_dragging_from_pile:
		Cursors.use_normal()


func consume_top_card() -> void:
	if card_count <= 0:
		return

	card_count -= 1
	build_stack()


func get_top_card_global_position() -> Vector3:
	if not stacked_cards.is_empty():
		var top_card := stacked_cards.back() as Node3D
		if top_card != null and is_instance_valid(top_card):
			return top_card.global_position
	return global_position
