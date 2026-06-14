class_name DiscardPile
extends Node3D

@export var card_thickness: float = 0.012
@export var card_back_texture: Texture2D

var discarded_cards: Array[CardData] = []
var stacked_cards: Array[MeshInstance3D] = []
var status_label: Label3D = null


func _ready() -> void:
	create_base()
	create_status_label()
	build_stack()


func create_base() -> void:
	var base := MeshInstance3D.new()
	base.name = "DiscardBase"

	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.1, 0.02, 1.5)

	base.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.16, 0.13, 1.0)

	base.material_override = mat
	base.position = Vector3.ZERO

	add_child(base)


func create_status_label() -> void:
	status_label = Label3D.new()
	status_label.name = "DiscardLabel"
	status_label.text = "DISCARD\n0"
	status_label.position = Vector3(0, 0.55, -0.95)
	status_label.pixel_size = 0.007
	status_label.font_size = 38
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.modulate = Color(1.0, 0.92, 0.65, 1.0)
	status_label.outline_size = 8
	status_label.outline_modulate = Color(0, 0, 0, 1)
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.no_depth_test = true

	add_child(status_label)


func add_card(card_data: CardData) -> void:
	if card_data == null:
		return

	discarded_cards.append(card_data)
	build_stack()


func peek_top_card() -> CardData:
	if discarded_cards.is_empty():
		return null

	return discarded_cards.back()


func remove_top_card() -> CardData:
	if discarded_cards.is_empty():
		return null

	var card_data: CardData = discarded_cards.pop_back() as CardData
	build_stack()
	return card_data


func cards_count() -> int:
	return discarded_cards.size()


func build_stack() -> void:
	for card in stacked_cards:
		if is_instance_valid(card):
			card.queue_free()

	stacked_cards.clear()

	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, card_thickness, 1.4)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.08, 0.05, 1.0)

	if card_back_texture != null:
		mat.albedo_texture = card_back_texture
		mat.albedo_color = Color.WHITE

	for i in range(discarded_cards.size()):
		var card := MeshInstance3D.new()
		card.mesh = mesh
		card.material_override = mat
		card.position = Vector3(0, i * (card_thickness + 0.003) + 0.02, 0)
		add_child(card)
		stacked_cards.append(card)

	if status_label != null:
		status_label.text = "DISCARD\n" + str(discarded_cards.size())
