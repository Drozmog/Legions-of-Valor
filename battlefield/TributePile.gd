class_name TributePile
extends Node3D

signal tribute_pile_clicked

@export var card_thickness: float = 0.02

@export var counter_side_offset: float = 0.0
@export var counter_height: float = 0.75
@export var counter_forward_offset: float = -1.15
@export var counter_pixel_size: float = 0.008

var card_count: int = 0
var stacked_cards: Array[MeshInstance3D] = []

var status_label: Label3D = null

@onready var click_area: Area3D = $ClickArea


func _ready() -> void:
	create_base()
	create_status_label()
	build_stack()

	click_area.input_ray_pickable = true
	click_area.input_event.connect(_on_click_area_input_event)

	set_status_text("TP 0/0")


func create_base() -> void:
	var base := MeshInstance3D.new()

	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.1, 0.02, 1.5)

	base.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.32, 0.12)

	base.material_override = mat
	base.position = Vector3(0, 0.0, 0)

	add_child(base)


func create_status_label() -> void:
	if status_label != null:
		return

	status_label = Label3D.new()
	status_label.name = "StatusLabel"
	status_label.text = "TP 0/0"

	# Keep the old working position system.
	status_label.position = Vector3(counter_side_offset, counter_height, counter_forward_offset)
	status_label.pixel_size = counter_pixel_size

	# Smaller than before.
	status_label.font_size = 32
	status_label.outline_size = 6

	status_label.modulate = Color(1.0, 0.92, 0.55, 1.0)
	status_label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.no_depth_test = true

	add_child(status_label)


func set_status_text(text: String) -> void:
	if status_label == null:
		create_status_label()

	status_label.text = text


func build_stack() -> void:
	for c in stacked_cards:
		c.queue_free()

	stacked_cards.clear()

	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, card_thickness, 1.4)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.55, 0.25)

	# Lift the first tribute card above the base slab so it does not phase into it.
	var base_lift: float = 0.035
	var stack_gap: float = 0.006

	for i in range(card_count):
		var card := MeshInstance3D.new()
		card.mesh = mesh
		card.material_override = mat
		card.position = Vector3(0, base_lift + i * (card_thickness + stack_gap), 0)
		add_child(card)
		stacked_cards.append(card)


func add_card() -> void:
	card_count += 1
	build_stack()


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
