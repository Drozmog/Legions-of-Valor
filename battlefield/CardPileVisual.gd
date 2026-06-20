class_name CardPileVisual
extends RefCounted

const CARD_BACK_TEXTURE: Texture2D = preload("res://cards/card_back.png")
const CARD_3D_SCENE: PackedScene = preload("res://cards/Card3D_Test.tscn")


static func create_pile_base(base_name: String = "PileBase") -> MeshInstance3D:
	var base := MeshInstance3D.new()
	base.name = base_name

	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.12, 0.025, 1.52)
	base.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.065, 0.045, 0.95)
	base.material_override = mat

	base.position = Vector3.ZERO
	return base


static func create_card_back_visual(card_width: float, card_height: float) -> Node3D:
	var card := CARD_3D_SCENE.instantiate() as Node3D
	card.name = "CardBackVisual"
	card.scale = Vector3(card_width / 1.02, 1.0, card_height / 1.34)
	if card.has_method("assign_card_data"):
		card.assign_card_data(null, true)
	return card


static func create_face_up_card_visual(card_data: CardData, card_scale: float) -> Node3D:
	var card_node := CARD_3D_SCENE.instantiate() as Node3D
	card_node.scale = Vector3(card_scale, card_scale, card_scale)

	if card_node.has_method("assign_card_data"):
		card_node.assign_card_data(card_data, false)

	return card_node


static func create_counter_label(
	label_name: String,
	text: String,
	label_position: Vector3,
	pixel_size: float,
	font_size: int = 30
) -> Label3D:
	var label := Label3D.new()
	label.name = label_name
	label.text = text
	label.position = label_position
	label.pixel_size = pixel_size
	label.font_size = font_size
	label.outline_size = 6
	label.modulate = Color(1.0, 0.92, 0.55, 1.0)
	label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
