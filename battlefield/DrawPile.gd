@tool
class_name DrawPile
extends Node3D

signal draw_drag_started(screen_position: Vector2)
signal draw_drag_moved(screen_position: Vector2)
signal draw_drag_released(screen_position: Vector2)

@export_group("Card Stack")
@export var card_count: int = 40:
	set(value):
		card_count = max(value, 0)
		_refresh_visuals()
@export var card_width: float = 1.02:
	set(value):
		card_width = value
		_refresh_visuals()
@export var card_height: float = 1.34:
	set(value):
		card_height = value
		_refresh_visuals()
@export var card_thickness: float = 0.006:
	set(value):
		card_thickness = value
		_refresh_visuals()
@export var max_visible_cards: int = 14:
	set(value):
		max_visible_cards = max(value, 0)
		_refresh_visuals()
@export var card_gap: float = 0.008:
	set(value):
		card_gap = value
		_refresh_visuals()
@export var stack_base_offset: Vector3 = Vector3(0.0, 0.025, 0.0):
	set(value):
		stack_base_offset = value
		_refresh_visuals()

@export_group("Pile Base")
@export var base_local_offset: Vector3 = Vector3.ZERO:
	set(value):
		base_local_offset = value
		_apply_base_layout()

@export_group("Counter Label")
@export var counter_side_offset: float = 0.0:
	set(value):
		counter_side_offset = value
		update_counter_label()
@export var counter_height: float = 0.16:
	set(value):
		counter_height = value
		update_counter_label()
@export var counter_forward_offset: float = -0.92:
	set(value):
		counter_forward_offset = value
		update_counter_label()
@export var counter_pixel_size: float = 0.006:
	set(value):
		counter_pixel_size = value
		update_counter_label()

@export_group("Interaction Area")
@export var click_area_local_offset: Vector3 = Vector3(0.0, 0.0, -0.29577875):
	set(value):
		click_area_local_offset = value
		_apply_click_area_layout()

@onready var click_area: Area3D = get_node_or_null("ClickArea") as Area3D

var is_dragging_from_pile: bool = false
var stacked_cards: Array[Node3D] = []
var base_node: MeshInstance3D = null
var counter_label: Label3D = null


func _ready() -> void:
	create_base()
	create_counter_label()
	_sync_layout_exports_from_existing_children()
	_apply_all_layout()

	if not Engine.is_editor_hint():
		build_stack()
		connect_click_area_signals()

	set_process(false)


func apply_editor_owner(node: Node) -> void:
	if not Engine.is_editor_hint():
		return
	if node == null or get_tree() == null:
		return
	var edited_root := get_tree().edited_scene_root
	if edited_root != null and node.owner == null:
		node.owner = edited_root


func _refresh_visuals() -> void:
	if not is_inside_tree():
		return
	create_base()
	create_counter_label()
	_apply_all_layout()
	if not Engine.is_editor_hint():
		build_stack()


func _apply_all_layout() -> void:
	_apply_base_layout()
	_apply_click_area_layout()
	update_counter_label()


func _sync_layout_exports_from_existing_children() -> void:
	if base_node != null:
		base_local_offset = base_node.position

	if counter_label != null:
		counter_side_offset = counter_label.position.x
		counter_height = counter_label.position.y
		counter_forward_offset = counter_label.position.z
		counter_pixel_size = counter_label.pixel_size

	if click_area != null:
		click_area_local_offset = click_area.position


func _get_counter_offset() -> Vector3:
	return Vector3(counter_side_offset, counter_height, counter_forward_offset)


func _apply_base_layout() -> void:
	if base_node != null:
		base_node.position = base_local_offset


func _apply_click_area_layout() -> void:
	if click_area == null:
		click_area = get_node_or_null("ClickArea") as Area3D
	if click_area != null:
		click_area.position = click_area_local_offset


func create_base() -> void:
	base_node = get_node_or_null("DrawPileBase") as MeshInstance3D
	if base_node != null:
		return

	base_node = CardPileVisual.create_pile_base("DrawPileBase")
	add_child(base_node)
	apply_editor_owner(base_node)


func create_counter_label() -> void:
	counter_label = get_node_or_null("DrawPileCounter") as Label3D
	if counter_label == null:
		counter_label = CardPileVisual.create_counter_label(
			"DrawPileCounter",
			"Deck: " + str(card_count),
			_get_counter_offset(),
			counter_pixel_size,
			20
		)

		add_child(counter_label)
		apply_editor_owner(counter_label)

	update_counter_label()


func update_counter_label() -> void:
	if counter_label == null:
		return

	counter_label.position = _get_counter_offset()
	counter_label.pixel_size = counter_pixel_size
	counter_label.text = "Deck: " + str(card_count)


func connect_click_area_signals() -> void:
	if click_area == null:
		return

	click_area.input_ray_pickable = true
	if not click_area.input_event.is_connected(_on_click_area_input_event):
		click_area.input_event.connect(_on_click_area_input_event)
	if not click_area.mouse_entered.is_connected(_on_mouse_entered):
		click_area.mouse_entered.connect(_on_mouse_entered)
	if not click_area.mouse_exited.is_connected(_on_mouse_exited):
		click_area.mouse_exited.connect(_on_mouse_exited)


func set_card_count(new_count: int) -> void:
	card_count = max(new_count, 0)


func build_stack() -> void:
	clear_stack()

	var visible_count: int = mini(card_count, max_visible_cards)

	for i in range(visible_count):
		var card := CardPileVisual.create_card_back_visual(card_width, card_height)
		card.position = stack_base_offset + Vector3(0.0, float(i) * (card_thickness + card_gap), 0.0)
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
	if Engine.is_editor_hint():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if card_count <= 0 or is_dragging_from_pile:
				return

			is_dragging_from_pile = true
			Cursors.use_pointing()
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
