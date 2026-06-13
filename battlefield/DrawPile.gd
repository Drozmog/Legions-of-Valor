class_name DrawPile
extends Node3D

signal pile_clicked
@export var card_count: int = 15
@export var card_thickness: float = 0.005

@onready var click_area: Area3D = $ClickArea

func _ready() -> void:
	build_stack()
	click_area.input_ray_pickable = true
	click_area.input_event.connect(_on_click_area_input_event)

func build_stack() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, card_thickness, 1.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.74, 0.55) 	# dark card-back colour
	for i in range(card_count):
		var card := MeshInstance3D.new()
		card.mesh = mesh
		card.material_override = mat
		card.position = Vector3(0, (i * card_thickness + 0.004), 0)   # stack upward
		add_child(card)

func _on_click_area_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pile_clicked.emit()
		
