extends MeshInstance3D

signal slot_clicked(slot)
signal slot_right_clicked(slot)

@onready var click_area: Area3D = $ClickArea
@onready var card_point: Marker3D = $CardPoint

var occupied: bool = false
var placed_card: Node3D = null
var equipment_cards: Array[CardData] = []
var equipment_nodes: Array[Node3D] = []
var slot_material: StandardMaterial3D

var default_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var valid_color: Color = Color(0.35, 1.0, 0.35, 1.0)
var invalid_color: Color = Color(1.0, 0.25, 0.25, 1.0)
var promotion_color: Color = Color(1.0, 0.84, 0.12, 1.0)

var highlight_outline: Node3D
var glow_outline: Node3D

var outline_material: StandardMaterial3D
var glow_material: StandardMaterial3D

const SLOT_WIDTH: float = 1.02
const SLOT_HEIGHT: float = 1.34
const MAX_EQUIPMENT_PER_UNIT: int = 2

const OUTLINE_THICKNESS: float = 0.016
const GLOW_THICKNESS: float = 0.085

const OUTLINE_Y_OFFSET: float = 0.030
const GLOW_Y_OFFSET: float = 0.020
const INSPECT_FADE_ALPHA: float = 0.36


func _ready() -> void:
	occupied = get_meta("occupied", false)

	setup_highlight_outline()
	setup_slot_material()

	click_area.input_ray_pickable = true
	click_area.input_event.connect(_on_click_area_input_event)
	click_area.mouse_entered.connect(_on_click_area_mouse_entered)
	click_area.mouse_exited.connect(_on_click_area_mouse_exited)


func set_highlight(active: bool) -> void:
	if highlight_outline == null or glow_outline == null:
		return

	if active:
		set_outline_color(valid_color)
		highlight_outline.visible = true
		glow_outline.visible = true
	else:
		highlight_outline.visible = false
		glow_outline.visible = false


func set_invalid_highlight(active: bool) -> void:
	if highlight_outline == null or glow_outline == null:
		return

	if active:
		set_outline_color(invalid_color)
		highlight_outline.visible = true
		glow_outline.visible = true
	else:
		highlight_outline.visible = false
		glow_outline.visible = false


func set_promotion_highlight(active: bool) -> void:
	if highlight_outline == null or glow_outline == null:
		return

	if active:
		set_outline_color(promotion_color)
		highlight_outline.visible = true
		glow_outline.visible = true
	else:
		highlight_outline.visible = false
		glow_outline.visible = false


func set_insight_highlight(active: bool, color: Color = Color(0.18, 0.55, 1.0, 1.0)) -> void:
	set_meta("insight_selectable", active)
	if active:
		set_outline_color(color)
		highlight_outline.visible = true
		glow_outline.visible = true
	else:
		highlight_outline.visible = false
		glow_outline.visible = false
		_use_cursor(&"use_normal")


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
			set_inspected_faded(true)
			slot_right_clicked.emit(self)
			call_deferred("_watch_inspection_close")


func _watch_inspection_close() -> void:
	var panel := _find_card_inspect_panel(get_tree().current_scene)
	if panel == null or not panel.visible:
		set_inspected_faded(false)
		return
	var clear := Callable(self, "_clear_inspection_fade")
	if not panel.inspection_closed.is_connected(clear):
		panel.inspection_closed.connect(clear)


func _clear_inspection_fade() -> void:
	set_inspected_faded(false)


func _find_card_inspect_panel(node: Node) -> CardInspectPanel:
	if node == null:
		return null
	if node is CardInspectPanel:
		return node as CardInspectPanel
	for child in node.get_children():
		var found := _find_card_inspect_panel(child)
		if found != null:
			return found
	return null


func set_inspected_faded(active: bool) -> void:
	if placed_card == null or not is_instance_valid(placed_card):
		return
	_set_visual_fade_recursive(placed_card, active)


func _set_visual_fade_recursive(node: Node, active: bool) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.material_override is StandardMaterial3D:
			var material := mesh_instance.material_override as StandardMaterial3D
			var next_material := material.duplicate() as StandardMaterial3D
			var color := next_material.albedo_color
			color.a = INSPECT_FADE_ALPHA if active else 1.0
			next_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if active else BaseMaterial3D.TRANSPARENCY_DISABLED
			next_material.albedo_color = color
			mesh_instance.material_override = next_material
	elif node is Sprite3D:
		var sprite := node as Sprite3D
		var color := sprite.modulate
		color.a = INSPECT_FADE_ALPHA if active else 1.0
		sprite.modulate = color
	elif node is Label3D:
		var label := node as Label3D
		var color := label.modulate
		color.a = INSPECT_FADE_ALPHA if active else 1.0
		label.modulate = color
	for child in node.get_children():
		_set_visual_fade_recursive(child, active)


func _on_click_area_mouse_entered() -> void:
	if bool(get_meta("insight_selectable", false)):
		_use_cursor(&"use_pointing")


func _on_click_area_mouse_exited() -> void:
	if bool(get_meta("insight_selectable", false)):
		_use_cursor(&"use_normal")


func _use_cursor(method_name: StringName) -> void:
	var cursors := get_node_or_null("/root/Cursors")
	if cursors != null and cursors.has_method(method_name):
		cursors.call(method_name)


func place_card(card_scene: PackedScene, card_data: CardData, place_face_down: bool = false) -> bool:
	if occupied:
		print(get_meta("slot_id"), " is already occupied.")
		return false

	placed_card = card_scene.instantiate()
	card_point.add_child(placed_card)

	placed_card.position = Vector3.ZERO
	placed_card.rotation = Vector3.ZERO

	if placed_card.has_method("assign_card_data"):
		placed_card.assign_card_data(card_data, place_face_down)

	occupied = true
	set_meta("occupied", true)
	set_meta("face_down", place_face_down)

	print("Placed card on: ", get_meta("slot_id"))
	return true


func can_attach_equipment() -> bool:
	if not occupied:
		return false

	if placed_card == null:
		return false

	if bool(get_meta("face_down", false)):
		return false

	return equipment_cards.size() < MAX_EQUIPMENT_PER_UNIT


func attach_equipment(card_scene: PackedScene, card_data: CardData) -> bool:
	if not can_attach_equipment():
		return false

	var equipment_node := card_scene.instantiate() as Node3D
	card_point.add_child(equipment_node)
	equipment_cards.append(card_data)
	equipment_nodes.append(equipment_node)

	var index := equipment_nodes.size() - 1
	equipment_node.position = Vector3(-0.23 + float(index) * 0.46, 0.055 + float(index) * 0.004, 0.36)
	equipment_node.rotation_degrees = Vector3(0, 0, -6 + 12 * index)
	equipment_node.scale = Vector3(0.46, 0.46, 0.46)

	if equipment_node.has_method("assign_card_data"):
		equipment_node.assign_card_data(card_data, false)

	return true


func get_equipment_count() -> int:
	return equipment_cards.size()


func get_equipment_cards() -> Array[CardData]:
	return equipment_cards.duplicate()


func clear_slot() -> void:
	for equipment_node in equipment_nodes:
		if is_instance_valid(equipment_node):
			equipment_node.queue_free()

	equipment_nodes.clear()
	equipment_cards.clear()

	if placed_card == null:
		occupied = false
		set_meta("occupied", false)
		return

	placed_card.queue_free()
	placed_card = null

	occupied = false
	set_meta("occupied", false)
	set_meta("face_down", false)

	print("Cleared slot: ", get_meta("slot_id"))


func get_placed_card_data() -> CardData:
	if placed_card == null:
		return null

	if placed_card.has_method("get_card_data"):
		return placed_card.get_card_data()

	return null


func get_placed_card_visual() -> Node3D:
	return placed_card


func set_slot_usable_ability_ids(ability_ids: Array[StringName]) -> void:
	if placed_card != null and is_instance_valid(placed_card):
		if placed_card.has_method("set_usable_ability_ids"):
			placed_card.set_usable_ability_ids(ability_ids)


func reveal_card() -> void:
	if placed_card == null:
		return

	if placed_card.has_method("reveal_card"):
		placed_card.reveal_card()

	set_meta("face_down", false)


func set_slot_ability_icons_visible(show_icons: bool) -> void:
	if placed_card != null and is_instance_valid(placed_card):
		if placed_card.has_method("set_ability_icons_visible"):
			placed_card.set_ability_icons_visible(show_icons)
