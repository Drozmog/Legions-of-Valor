@tool
class_name TributePile
extends Node3D

signal tribute_pile_clicked

@export_group("Card Stack")
@export var card_scale: float = 1.0:
	set(value):
		card_scale = value
		_refresh_visuals()
@export var card_thickness: float = 0.012:
	set(value):
		card_thickness = value
		_refresh_visuals()
@export var max_visible_cards: int = 14:
	set(value):
		max_visible_cards = max(value, 0)
		_refresh_visuals()
@export var stack_gap: float = 0.008:
	set(value):
		stack_gap = value
		_refresh_visuals()
@export var stack_base_offset: Vector3 = Vector3(0.0, 0.045, 0.0):
	set(value):
		stack_base_offset = value
		_refresh_visuals()

@export_group("Pile Base")
@export var base_local_offset: Vector3 = Vector3.ZERO:
	set(value):
		base_local_offset = value
		_apply_base_layout()

@export_group("Status Label")
@export var counter_side_offset: float = 0.0:
	set(value):
		counter_side_offset = value
		_refresh_status_label_layout()
@export var counter_height: float = 0.75:
	set(value):
		counter_height = value
		_refresh_status_label_layout()
@export var counter_forward_offset: float = -0.85:
	set(value):
		counter_forward_offset = value
		_refresh_status_label_layout()
@export var counter_pixel_size: float = 0.006:
	set(value):
		counter_pixel_size = value
		_refresh_status_label_layout()

@export_group("Interaction Area")
@export var click_area_local_offset: Vector3 = Vector3.ZERO:
	set(value):
		click_area_local_offset = value
		_apply_click_area_layout()

var card_count: int = 0
var tribute_cards: Array[CardData] = []
var stacked_cards: Array[Node3D] = []

var status_label: Label3D = null
var base_node: MeshInstance3D = null

@onready var click_area: Area3D = get_node_or_null("ClickArea") as Area3D


func _ready() -> void:
	create_base()
	create_status_label()
	_sync_layout_exports_from_existing_children()
	_apply_all_layout()
	set_status_text("TP 0/0")

	if not Engine.is_editor_hint():
		build_stack()
		connect_click_area_signals()


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
	create_status_label()
	_apply_all_layout()
	if not Engine.is_editor_hint():
		build_stack()


func _apply_all_layout() -> void:
	_apply_base_layout()
	_apply_click_area_layout()
	_refresh_status_label_layout()


func _sync_layout_exports_from_existing_children() -> void:
	if base_node != null:
		base_local_offset = base_node.position

	if status_label != null:
		counter_side_offset = status_label.position.x
		counter_height = status_label.position.y
		counter_forward_offset = status_label.position.z
		counter_pixel_size = status_label.pixel_size

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


func _refresh_status_label_layout() -> void:
	if status_label == null:
		return
	status_label.position = _get_counter_offset()
	status_label.pixel_size = counter_pixel_size


func create_base() -> void:
	base_node = get_node_or_null("TributeBase") as MeshInstance3D
	if base_node != null:
		return

	base_node = CardPileVisual.create_pile_base("TributeBase")
	add_child(base_node)
	apply_editor_owner(base_node)


func create_status_label() -> void:
	status_label = get_node_or_null("StatusLabel") as Label3D
	if status_label == null:
		status_label = CardPileVisual.create_counter_label(
			"StatusLabel",
			"TP 0/0",
			_get_counter_offset(),
			counter_pixel_size,
			20
		)

		add_child(status_label)
		apply_editor_owner(status_label)


func set_status_text(text: String) -> void:
	if status_label == null:
		create_status_label()

	_refresh_status_label_layout()
	status_label.text = text


func connect_click_area_signals() -> void:
	if click_area == null:
		return

	click_area.input_ray_pickable = true
	if not click_area.input_event.is_connected(_on_click_area_input_event):
		click_area.input_event.connect(_on_click_area_input_event)


func add_card(card_data: CardData = null) -> void:
	if card_data != null:
		tribute_cards.append(card_data)
	else:
		card_count += 1

	build_stack()


func cards_count() -> int:
	if not tribute_cards.is_empty():
		return tribute_cards.size()

	return card_count


func build_stack() -> void:
	for card_node in stacked_cards:
		if card_node != null and is_instance_valid(card_node):
			card_node.queue_free()

	stacked_cards.clear()

	var visible_count: int = mini(tribute_cards.size(), max_visible_cards)
	var start_index: int = max(0, tribute_cards.size() - visible_count)

	for i in range(visible_count):
		var card_data: CardData = tribute_cards[start_index + i]
		var card_node := CardPileVisual.create_face_up_card_visual(card_data, card_scale)

		card_node.position = stack_base_offset + Vector3(0.0, float(i) * (card_thickness + stack_gap), 0.0)
		card_node.rotation_degrees = Vector3.ZERO

		add_child(card_node)
		stacked_cards.append(card_node)

	card_count = tribute_cards.size()


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
			tribute_pile_clicked.emit()
