extends MeshInstance3D

signal slot_clicked(slot)
signal slot_right_clicked(slot)

@onready var click_area: Area3D = $ClickArea
@onready var card_point: Marker3D = $CardPoint

var occupied: bool = false
var placed_card: Node3D = null
var slot_material: StandardMaterial3D

var default_color: Color = Color(1.0, 0.82, 0.35, 1.0)
var valid_color: Color = Color(0.35, 1.0, 0.35, 1.0)
var invalid_color: Color = Color(1.0, 0.25, 0.25, 1.0)

func _ready() -> void:
	occupied = get_meta("occupied", false)

	setup_slot_material()

	click_area.input_ray_pickable = true
	click_area.input_event.connect(_on_click_area_input_event)


func _on_click_area_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			slot_clicked.emit(self)

		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			slot_right_clicked.emit(self)


func place_card(card_scene: PackedScene) -> bool:
	if occupied:
		print(get_meta("slot_id"), " is already occupied.")
		return false

	placed_card = card_scene.instantiate()
	card_point.add_child(placed_card)

	placed_card.position = Vector3.ZERO
	placed_card.rotation = Vector3.ZERO

	occupied = true
	set_meta("occupied", true)

	print("Placed card on: ", get_meta("slot_id"))
	return true


func clear_slot() -> void:
	if placed_card == null:
		return

	placed_card.queue_free()
	placed_card = null

	occupied = false
	set_meta("occupied", false)

	print("Cleared slot: ", get_meta("slot_id"))


func set_highlight(active: bool) -> void:
	if slot_material == null:
		setup_slot_material()

	if active:
		slot_material.albedo_color = valid_color
		slot_material.emission_enabled = true
		slot_material.emission = valid_color
		slot_material.emission_energy_multiplier = 0.5
	else:
		slot_material.albedo_color = default_color
		slot_material.emission_enabled = false


func set_invalid_highlight(active: bool) -> void:
	if slot_material == null:
		setup_slot_material()

	if active:
		slot_material.albedo_color = invalid_color
		slot_material.emission_enabled = true
		slot_material.emission = invalid_color
		slot_material.emission_energy_multiplier = 0.5
	else:
		slot_material.albedo_color = default_color
		slot_material.emission_enabled = false


func setup_slot_material() -> void:
	var existing_material := material_override as StandardMaterial3D

	if existing_material != null:
		slot_material = existing_material.duplicate()
		default_color = slot_material.albedo_color
	else:
		slot_material = StandardMaterial3D.new()
		slot_material.albedo_color = default_color

	slot_material.roughness = 1.0
	material_override = slot_material
