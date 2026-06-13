extends MeshInstance3D

signal slot_clicked(slot)
signal slot_right_clicked(slot)

@onready var click_area: Area3D = $ClickArea
@onready var card_point: Marker3D = $CardPoint

var occupied: bool = false
var placed_card: Node3D = null
var slot_material: StandardMaterial3D

var default_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var valid_color: Color = Color(0.35, 1.0, 0.35, 1.0)
var invalid_color: Color = Color(1.0, 0.25, 0.25, 1.0)

var highlight_outline: Node3D
var glow_outline: Node3D

var outline_material: StandardMaterial3D
var glow_material: StandardMaterial3D

const SLOT_WIDTH: float = 1.02
const SLOT_HEIGHT: float = 1.34

const OUTLINE_THICKNESS: float = 0.016
const GLOW_THICKNESS: float = 0.085

const OUTLINE_Y_OFFSET: float = 0.030
const GLOW_Y_OFFSET: float = 0.020


func _ready() -> void:
	occupied = get_meta("occupied", false)

	setup_highlight_outline()
	setup_slot_material()

	click_area.input_ray_pickable = true
	click_area.input_event.connect(_on_click_area_input_event)

func set_highlight(active: bool) -> void:
	if highlight_outline == null or glow_outline == null:
		return

	if active:
		set_outline_color(Color(0.35, 1.0, 0.35, 1.0))
		highlight_outline.visible = true
		glow_outline.visible = true
	else:
		highlight_outline.visible = false
		glow_outline.visible = false


func set_invalid_highlight(active: bool) -> void:
	if highlight_outline == null or glow_outline == null:
		return

	if active:
		set_outline_color(Color(1.0, 0.2, 0.2, 1.0))
		highlight_outline.visible = true
		glow_outline.visible = true
	else:
		highlight_outline.visible = false
		glow_outline.visible = false


func set_outline_color(color: Color) -> void:
	if outline_material != null:
		outline_material.albedo_color = color
		outline_material.emission = color

	if glow_material != null:
		glow_material.albedo_color = Color(color.r, color.g, color.b, 0.18)
		glow_material.emission = color

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


func place_card(card_scene: PackedScene, card_data: CardData) -> bool:
	if occupied:
		print(get_meta("slot_id"), " is already occupied.")
		return false

	placed_card = card_scene.instantiate()
	card_point.add_child(placed_card)

	placed_card.position = Vector3.ZERO
	placed_card.rotation = Vector3.ZERO

	if placed_card.has_method("assign_card_data"):
		placed_card.assign_card_data(card_data)

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

func setup_slot_material() -> void:
	var existing_material := get_active_material(0) as StandardMaterial3D

	if existing_material != null:
		slot_material = existing_material.duplicate()
		material_override = slot_material
		default_color = slot_material.albedo_color
	else:
		slot_material = StandardMaterial3D.new()
		slot_material.albedo_color = default_color
		material_override = slot_material

func setup_highlight_outline() -> void:
	# Crisp inner outline
	highlight_outline = Node3D.new()
	highlight_outline.name = "HighlightOutline"
	add_child(highlight_outline)

	outline_material = StandardMaterial3D.new()
	outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_material.albedo_color = Color(0.35, 1.0, 0.35, 1.0)
	outline_material.emission_enabled = true
	outline_material.emission = Color(0.35, 1.0, 0.35, 1.0)
	outline_material.emission_energy_multiplier = 1.2
	outline_material.no_depth_test = true

	# Soft outer glow
	glow_outline = Node3D.new()
	glow_outline.name = "GlowOutline"
	add_child(glow_outline)

	glow_material = StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_material.albedo_color = Color(0.35, 1.0, 0.35, 0.18)
	glow_material.emission_enabled = true
	glow_material.emission = Color(0.35, 1.0, 0.35, 1.0)
	glow_material.emission_energy_multiplier = 2.5
	glow_material.no_depth_test = true

	# INNER OUTLINE BARS
	create_outline_bar(
		highlight_outline,
		"TopBar",
		Vector3(SLOT_WIDTH + OUTLINE_THICKNESS, 0.01, OUTLINE_THICKNESS),
		Vector3(0, OUTLINE_Y_OFFSET, -SLOT_HEIGHT / 2.0),
		outline_material
	)

	create_outline_bar(
		highlight_outline,
		"BottomBar",
		Vector3(SLOT_WIDTH + OUTLINE_THICKNESS, 0.01, OUTLINE_THICKNESS),
		Vector3(0, OUTLINE_Y_OFFSET, SLOT_HEIGHT / 2.0),
		outline_material
	)

	create_outline_bar(
		highlight_outline,
		"LeftBar",
		Vector3(OUTLINE_THICKNESS, 0.01, SLOT_HEIGHT + OUTLINE_THICKNESS),
		Vector3(-SLOT_WIDTH / 2.0, OUTLINE_Y_OFFSET, 0),
		outline_material
	)

	create_outline_bar(
		highlight_outline,
		"RightBar",
		Vector3(OUTLINE_THICKNESS, 0.01, SLOT_HEIGHT + OUTLINE_THICKNESS),
		Vector3(SLOT_WIDTH / 2.0, OUTLINE_Y_OFFSET, 0),
		outline_material
	)

	# OUTER GLOW BARS
	create_outline_bar(
		glow_outline,
		"GlowTop",
		Vector3(SLOT_WIDTH + GLOW_THICKNESS, 0.01, GLOW_THICKNESS),
		Vector3(0, GLOW_Y_OFFSET, -SLOT_HEIGHT / 2.0),
		glow_material
	)

	create_outline_bar(
		glow_outline,
		"GlowBottom",
		Vector3(SLOT_WIDTH + GLOW_THICKNESS, 0.01, GLOW_THICKNESS),
		Vector3(0, GLOW_Y_OFFSET, SLOT_HEIGHT / 2.0),
		glow_material
	)

	create_outline_bar(
		glow_outline,
		"GlowLeft",
		Vector3(GLOW_THICKNESS, 0.01, SLOT_HEIGHT + GLOW_THICKNESS),
		Vector3(-SLOT_WIDTH / 2.0, GLOW_Y_OFFSET, 0),
		glow_material
	)

	create_outline_bar(
		glow_outline,
		"GlowRight",
		Vector3(GLOW_THICKNESS, 0.01, SLOT_HEIGHT + GLOW_THICKNESS),
		Vector3(SLOT_WIDTH / 2.0, GLOW_Y_OFFSET, 0),
		glow_material
	)

	highlight_outline.visible = false
	glow_outline.visible = false

	highlight_outline.visible = false
	
func create_outline_bar(
	parent_node: Node3D,
	bar_name: String,
	bar_size: Vector3,
	bar_position: Vector3,
	material: StandardMaterial3D
) -> MeshInstance3D:
	var bar := MeshInstance3D.new()
	bar.name = bar_name

	var bar_mesh := BoxMesh.new()
	bar_mesh.size = bar_size

	bar.mesh = bar_mesh
	bar.position = bar_position
	bar.material_override = material

	parent_node.add_child(bar)

	return bar
