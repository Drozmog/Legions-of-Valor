class_name Card3DTest
extends Node3D

const CARD_WIDTH: float = 1.02
const CARD_HEIGHT: float = 1.34
const CARD_BACK_PATH: String = "res://cards/card_back.png"

@onready var card_body: MeshInstance3D = get_node_or_null("CardBody") as MeshInstance3D

var assigned_card_data: CardData = null
var is_face_down: bool = false
var fallback_label: Label3D = null


func _ready() -> void:
	setup_card_body()
	setup_fallback_label()

	if assigned_card_data != null:
		apply_card_visual()


func assign_card_data(card_data: CardData, place_face_down: bool = false) -> void:
	assigned_card_data = card_data
	is_face_down = place_face_down

	if is_inside_tree():
		apply_card_visual()


func get_card_data() -> CardData:
	return assigned_card_data


func setup_card_body() -> void:
	if card_body == null:
		card_body = MeshInstance3D.new()
		card_body.name = "CardBody"
		add_child(card_body)

	var plane := PlaneMesh.new()
	plane.size = Vector2(CARD_WIDTH, CARD_HEIGHT)

	card_body.mesh = plane
	card_body.position = Vector3(0, 0.012, 0)
	card_body.rotation_degrees = Vector3.ZERO


func setup_fallback_label() -> void:
	fallback_label = get_node_or_null("FallbackLabel") as Label3D

	if fallback_label == null:
		fallback_label = Label3D.new()
		fallback_label.name = "FallbackLabel"
		add_child(fallback_label)

	fallback_label.position = Vector3(0, 0.06, 0)
	fallback_label.pixel_size = 0.006
	fallback_label.font_size = 42
	fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fallback_label.no_depth_test = true
	fallback_label.modulate = Color(1.0, 0.92, 0.65, 1.0)
	fallback_label.outline_size = 8
	fallback_label.outline_modulate = Color(0, 0, 0, 1)
	fallback_label.visible = false


func apply_card_visual() -> void:
	if is_face_down:
		show_back()
	else:
		show_front()


func show_front() -> void:
	is_face_down = false

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	if assigned_card_data != null and assigned_card_data.card_art != null:
		mat.albedo_texture = assigned_card_data.card_art
		mat.albedo_color = Color.WHITE

		if fallback_label != null:
			fallback_label.visible = false
	else:
		mat.albedo_color = Color(0.12, 0.08, 0.045, 1.0)

		if fallback_label != null:
			fallback_label.visible = true

			if assigned_card_data != null:
				fallback_label.text = assigned_card_data.card_name
			else:
				fallback_label.text = "Card"

	card_body.material_override = mat


func show_back() -> void:
	is_face_down = true

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	if ResourceLoader.exists(CARD_BACK_PATH):
		mat.albedo_texture = load(CARD_BACK_PATH) as Texture2D
		mat.albedo_color = Color.WHITE
	else:
		mat.albedo_color = Color(0.08, 0.055, 0.025, 1.0)

	card_body.material_override = mat

	if fallback_label != null:
		fallback_label.visible = false


func reveal_card() -> void:
	show_front()
