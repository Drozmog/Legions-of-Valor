class_name DiscardPile
extends Node3D

@export var card_scale: float = 1.0
@export var card_thickness: float = 0.012
@export var max_visible_cards: int = 14
@export var stack_gap: float = 0.008

@export var counter_side_offset: float = 0.55
@export var counter_height: float = 0.55
@export var counter_forward_offset: float = -0.85
@export var counter_pixel_size: float = 0.006

var discarded_cards: Array[CardData] = []
var stacked_cards: Array[Node3D] = []

var counter_label: Label3D = null
var base_node: MeshInstance3D = null


func _ready() -> void:
	create_base()
	create_drop_area()
	create_counter_label()
	build_stack()


func create_base() -> void:
	if base_node != null:
		return

	base_node = CardPileVisual.create_pile_base("DiscardBase")
	add_child(base_node)


func create_drop_area() -> void:
	if get_node_or_null("DropArea") != null:
		return
	var area := Area3D.new()
	area.name = "DropArea"
	area.input_ray_pickable = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.35, 0.45, 1.65)
	collision.shape = shape
	collision.position.y = 0.18
	area.add_child(collision)
	add_child(area)


func create_counter_label() -> void:
	if counter_label != null:
		return

	counter_label = CardPileVisual.create_counter_label(
		"DiscardCounter",
		"Discard: 0",
		Vector3(counter_side_offset, counter_height, counter_forward_offset),
		counter_pixel_size,
		20
	)

	add_child(counter_label)


func update_counter_label() -> void:
	if counter_label == null:
		return

	counter_label.position = Vector3(counter_side_offset, counter_height, counter_forward_offset)
	counter_label.text = "Discard: " + str(discarded_cards.size())


func add_card(card_data: CardData) -> void:
	if card_data == null:
		return

	discarded_cards.append(card_data)
	build_stack()


func peek_top_card() -> CardData:
	if discarded_cards.is_empty():
		return null

	return discarded_cards.back() as CardData


func remove_top_card() -> CardData:
	if discarded_cards.is_empty():
		return null

	var card_data: CardData = discarded_cards.pop_back() as CardData
	build_stack()
	return card_data


func cards_count() -> int:
	return discarded_cards.size()


func build_stack() -> void:
	for card_node in stacked_cards:
		if card_node != null and is_instance_valid(card_node):
			card_node.queue_free()

	stacked_cards.clear()

	var start_index: int = max(0, discarded_cards.size() - max_visible_cards)
	var visible_cards: Array[CardData] = discarded_cards.slice(start_index, discarded_cards.size())

	for i in range(visible_cards.size()):
		var card_data: CardData = visible_cards[i]
		var card_node := CardPileVisual.create_face_up_card_visual(card_data, card_scale)

		card_node.position = Vector3(0.0, 0.045 + float(i) * (card_thickness + stack_gap), 0.0)
		card_node.rotation_degrees = Vector3.ZERO

		add_child(card_node)
		stacked_cards.append(card_node)

	update_counter_label()
