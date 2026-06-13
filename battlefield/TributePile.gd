class_name TributePile
extends Node3D

signal tribute_pile_clicked

@export var card_thickness: float = 0.02
var card_count: int = 0           # starts empty, grows as you sacrifice
var stacked_cards: Array[MeshInstance3D] = []

@onready var click_area: Area3D = $ClickArea

func _ready() -> void:
	create_base()
	build_stack()
	click_area.input_ray_pickable = true
	click_area.input_event.connect(_on_click_area_input_event)

func create_base() -> void:
	var base := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.1, 0.02, 1.5)          # a flat tray, slightly bigger than a card
	base.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.32, 0.12)     # dark gold — marks the spot
	base.material_override = mat
	base.position = Vector3(0, 0.0, 0)
	add_child(base)
	
func build_stack() -> void:
	for c in stacked_cards:
		c.queue_free()
	stacked_cards.clear()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, card_thickness, 1.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.55, 0.25)
	for i in range(card_count):
		var card := MeshInstance3D.new()
		card.mesh = mesh
		card.material_override = mat
		card.position = Vector3(0, i * (card_thickness + 0.004), 0)
		add_child(card)
		stacked_cards.append(card)         # remember it so we can clear it later

func add_card() -> void:
	card_count += 1
	build_stack()                       # rebuild one card taller

func _on_click_area_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tribute_pile_clicked.emit()
