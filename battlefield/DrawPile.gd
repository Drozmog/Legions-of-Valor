class_name DrawPile
extends Node3D

signal draw_drag_started(screen_position: Vector2)
signal draw_drag_moved(screen_position: Vector2)
signal draw_drag_released(screen_position: Vector2)

@export var card_count: int = 15
@export var card_thickness: float = 0.005

@onready var click_area: Area3D = $ClickArea

var is_dragging_from_pile: bool = false


func _ready() -> void:
	build_stack()

	click_area.input_ray_pickable = true
	click_area.input_event.connect(_on_click_area_input_event)

	set_process(false)


func build_stack() -> void:
	var card_mesh := BoxMesh.new()
	card_mesh.size = Vector3(1.0, card_thickness, 1.4)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.74, 0.55)

	for i in range(card_count):
		var card := MeshInstance3D.new()
		card.mesh = card_mesh
		card.material_override = mat
		card.position = Vector3(0, i * card_thickness + 0.004, 0)
		add_child(card)


func _on_click_area_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if card_count <= 0:
				return

			is_dragging_from_pile = true
			set_process(true)

			draw_drag_started.emit(get_viewport().get_mouse_position())


func _process(_delta: float) -> void:
	if not is_dragging_from_pile:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	draw_drag_moved.emit(mouse_pos)

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_dragging_from_pile = false
		set_process(false)

		draw_drag_released.emit(mouse_pos)


func consume_top_card() -> void:
	if card_count <= 0:
		return

	card_count -= 1

	for i in range(get_child_count() - 1, -1, -1):
		var child := get_child(i)

		if child is MeshInstance3D:
			child.queue_free()
			return
