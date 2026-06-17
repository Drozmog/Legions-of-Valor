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

@export var counter_side_offset: float = 0.3
@export var counter_height: float = 0.55
@export var counter_forward_offset: float = -0.85
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
		card.rotation_degrees = Vector3(0, float(i % 4) * 1.5, 0)
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
			if card_count <= 0:
				return

			is_dragging_from_pile = true
			set_process(true)

			draw_drag_started.emit(get_viewport().get_mouse_position())


func _process(_delta: float) -> void:
	if not is_dragging_from_pile:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	draw_drag_moved.emit(mouse_pos)

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_dragging_from_pile = false
		set_process(false)

		draw_drag_released.emit(mouse_pos)


func consume_top_card() -> void:
	if card_count <= 0:
		return

	card_count -= 1
	build_stack()
