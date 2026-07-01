@tool
class_name DiscardPile
extends Node3D

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

@export_group("Drop Area")
@export var drop_area_local_offset: Vector3 = Vector3.ZERO:
	set(value):
		drop_area_local_offset = value
		_apply_drop_area_layout()
@export var drop_collision_local_offset: Vector3 = Vector3(0.0, 0.18, 0.0):
	set(value):
		drop_collision_local_offset = value
		_apply_drop_area_layout()

var discarded_cards: Array[CardData] = []
var stacked_cards: Array[Node3D] = []

var counter_label: Label3D = null
var base_node: MeshInstance3D = null


func _ready() -> void:
	create_base()
	create_drop_area()
	create_counter_label()
	_sync_layout_exports_from_existing_children()
	_apply_all_layout()

	if not Engine.is_editor_hint():
		build_stack()


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
	create_drop_area()
	create_counter_label()
	_apply_all_layout()
	if not Engine.is_editor_hint():
		build_stack()


func _apply_all_layout() -> void:
	_apply_base_layout()
	_apply_drop_area_layout()
	update_counter_label()


func _sync_layout_exports_from_existing_children() -> void:
	if base_node != null:
		base_local_offset = base_node.position

	if counter_label != null:
		counter_side_offset = counter_label.position.x
		counter_height = counter_label.position.y
		counter_forward_offset = counter_label.position.z
		counter_pixel_size = counter_label.pixel_size

	var area := get_node_or_null("DropArea") as Area3D
	if area != null:
		drop_area_local_offset = area.position
		var collision := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision != null:
			drop_collision_local_offset = collision.position


func _get_counter_offset() -> Vector3:
	return Vector3(counter_side_offset, counter_height, counter_forward_offset)


func _apply_base_layout() -> void:
	if base_node != null:
		base_node.position = base_local_offset


func _apply_drop_area_layout() -> void:
	var area := get_node_or_null("DropArea") as Area3D
	if area != null:
		area.position = drop_area_local_offset
		var collision := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision != null:
			collision.position = drop_collision_local_offset


func create_base() -> void:
	base_node = get_node_or_null("DiscardBase") as MeshInstance3D
	if base_node != null:
		return

	base_node = CardPileVisual.create_pile_base("DiscardBase")
	add_child(base_node)
	apply_editor_owner(base_node)


func create_drop_area() -> void:
	if get_node_or_null("DropArea") != null:
		return
	var area := Area3D.new()
	area.name = "DropArea"
	area.input_ray_pickable = true
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.35, 0.45, 1.65)
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	apply_editor_owner(area)
	apply_editor_owner(collision)


func create_counter_label() -> void:
	counter_label = get_node_or_null("DiscardCounter") as Label3D
	if counter_label == null:
		counter_label = CardPileVisual.create_counter_label(
			"DiscardCounter",
			"Discard: 0",
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
	counter_label.text = "Discard: " + str(discarded_cards.size())


func add_card(card_data: CardData, rebuild_visual: bool = true) -> void:
	if card_data == null:
		return

	discarded_cards.append(card_data)
	if rebuild_visual:
		build_stack()


func get_animation_landing_position() -> Vector3:
	var visible_height := stack_base_offset.y + float(stacked_cards.size()) * (card_thickness + stack_gap)
	return global_position + global_basis.y.normalized() * visible_height


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


func remove_card(card_data: CardData) -> bool:
	if card_data == null:
		return false
	for index in range(discarded_cards.size() - 1, -1, -1):
		if discarded_cards[index] == card_data:
			discarded_cards.remove_at(index)
			build_stack()
			return true
	return false


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

		card_node.position = stack_base_offset + Vector3(0.0, float(i) * (card_thickness + stack_gap), 0.0)
		card_node.rotation_degrees = Vector3.ZERO

		add_child(card_node)
		stacked_cards.append(card_node)

	update_counter_label()
