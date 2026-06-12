extends MeshInstance3D

const TEST_CARD_SCENE: PackedScene = preload("res://Scenes/Cards/Card3D_Test.tscn")

@onready var click_area: Area3D = $ClickArea
@onready var card_point: Marker3D = $CardPoint

var occupied: bool = false
var placed_card: Node3D = null


func _ready() -> void:
	occupied = get_meta("occupied", false)

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
			try_place_test_card()

		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			clear_slot()


func try_place_test_card() -> void:
	if occupied:
		print(get_meta("slot_id"), " is already occupied.")
		return

	placed_card = TEST_CARD_SCENE.instantiate()
	card_point.add_child(placed_card)

	placed_card.position = Vector3.ZERO
	placed_card.rotation = Vector3.ZERO

	occupied = true
	set_meta("occupied", true)

	print("Placed test card on: ", get_meta("slot_id"))


func clear_slot() -> void:
	if placed_card == null:
		return

	placed_card.queue_free()
	placed_card = null

	occupied = false
	set_meta("occupied", false)

	print("Cleared slot: ", get_meta("slot_id"))
