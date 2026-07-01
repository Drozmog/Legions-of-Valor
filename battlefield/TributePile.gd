@tool
class_name TributePile
extends Node3D

signal tribute_pile_clicked

@export var card_scale: float = 1.0
@export var card_thickness: float = 0.012
@export var max_visible_cards: int = 14
@export var stack_gap: float = 0.008

@export var counter_side_offset: float = 0.0
@export var counter_height: float = 0.75
@export var counter_forward_offset: float = -0.85
@export var counter_pixel_size: float = 0.006

var card_count: int = 0
var tribute_cards: Array[CardData] = []
var stacked_cards: Array[Node3D] = []

var status_label: Label3D = null
var base_node: MeshInstance3D = null

@onready var click_area: Area3D = get_node_or_null("ClickArea") as Area3D


func _ready() -> void:
	create_base()
	create_status_label()
	set_status_text("TP 0/0")

	if Engine.is_editor_hint():
		return

	build_stack()

	if click_area != null:
		click_area.input_ray_pickable = true
		click_area.input_event.connect(_on_click_area_input_event)


func apply_editor_owner(node: Node) -> void:
	if not Engine.is_editor_hint():
		return
	if node == null or get_tree() == null:
		return
	var edited_root := get_tree().edited_scene_root
	if edited_root != null and node.owner == null:
		node.owner = edited_root


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
			Vector3(counter_side_offset, counter_height, counter_forward_offset),
			counter_pixel_size,
			20
		)

		add_child(status_label)
		apply_editor_owner(status_label)


func set_status_text(text: String) -> void:
	if status_label == null:
		create_status_label()

	status_label.position = Vector3(counter_side_offset, counter_height, counter_forward_offset)
	status_label.text = text


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

		card_node.position = Vector3(0.0, 0.045 + float(i) * (card_thickness + stack_gap), 0.0)
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
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			tribute_pile_clicked.emit()
