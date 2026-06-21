class_name BoardSlotActionButtons3D
extends Node3D

signal action_pressed(action_id: int, slot: Node)

@export var attack_texture: Texture2D
@export var check_texture: Texture2D
@export var pass_texture: Texture2D
@export var inspect_texture: Texture2D

const BUTTON_SIZE := Vector3(0.42, 0.035, 0.27)
const HIDDEN_X := 0.46
const SHOWN_X := 0.83
const BUTTON_Z_SPACING := 0.32
const SLIDE_TIME := 0.18

var slot: Node3D
var slide_direction := 1.0
var buttons: Dictionary = {}
var state_signature := ""


func setup(slot_node: Node3D, direction: float) -> void:
	slot = slot_node
	slide_direction = signf(direction) if not is_zero_approx(direction) else 1.0
	name = "ActionButtonRail"
	position = Vector3.ZERO
	_build_button(2, "Attack", "AttackButtonSlot")
	_build_button(3, "Check", "CheckButtonSlot")
	_build_button(4, "Pass", "PassButtonSlot")
	_build_button(1, "Inspect", "InspectButtonSlot")
	visible = false


func set_actions(action_ids: Array[int]) -> void:
	var signature := ",".join(action_ids.map(func(value: int) -> String: return str(value)))
	if signature == state_signature:
		return
	state_signature = signature
	var action_count := action_ids.size()
	visible = action_count > 0
	for raw_id in buttons.keys():
		var action_id := int(raw_id)
		var button_root := buttons[action_id] as Node3D
		var visual_index := action_ids.find(action_id)
		var should_show := visual_index >= 0
		_set_button_pickable(button_root, should_show)
		if not should_show:
			button_root.set_meta("wanted_visible", false)
			if button_root.visible:
				var retract_target := button_root.position
				retract_target.x = slide_direction * HIDDEN_X
				var retract := create_tween()
				retract.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				retract.tween_property(button_root, "position", retract_target, 0.13)
				retract.tween_callback(_hide_button_if_still_retracted.bind(button_root))
			else:
				button_root.position.x = slide_direction * HIDDEN_X
			continue
		button_root.set_meta("wanted_visible", true)
		button_root.visible = true
		var centered_index := float(visual_index) - float(action_count - 1) * 0.5
		button_root.position = Vector3(
			slide_direction * HIDDEN_X,
			0.16 + float(visual_index) * 0.004,
			centered_index * BUTTON_Z_SPACING
		)
		var target := button_root.position
		target.x = slide_direction * SHOWN_X
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button_root, "position", target, SLIDE_TIME)


func _hide_button_if_still_retracted(button_root: Node3D) -> void:
	if button_root == null or not is_instance_valid(button_root):
		return
	if not bool(button_root.get_meta("wanted_visible", false)):
		button_root.visible = false


func _build_button(action_id: int, caption: String, node_name: String) -> void:
	var button_root := Node3D.new()
	button_root.name = node_name
	add_child(button_root)

	var surface := MeshInstance3D.new()
	surface.name = "ButtonSurface"
	var mesh := BoxMesh.new()
	mesh.size = BUTTON_SIZE
	surface.mesh = mesh
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.105, 0.045, 0.016, 0.98)
	material.emission_enabled = true
	material.emission = Color(0.32, 0.17, 0.035, 1.0)
	material.emission_energy_multiplier = 0.65
	material.no_depth_test = true
	material.render_priority = 110
	var action_texture := get_action_texture(action_id)
	if action_texture != null:
		material.albedo_texture = action_texture
		material.albedo_color = Color.WHITE
	surface.material_override = material
	button_root.add_child(surface)

	var label := Label3D.new()
	label.name = "ButtonLabel"
	label.text = caption.to_upper()
	label.position = Vector3(0.0, 0.026, 0.0)
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	label.pixel_size = 0.0024
	label.font_size = 34
	label.modulate = Color(1.0, 0.86, 0.46, 1.0)
	label.outline_modulate = Color(0.03, 0.01, 0.0, 1.0)
	label.outline_size = 7
	label.no_depth_test = true
	label.render_priority = 111
	label.visible = action_texture == null
	button_root.add_child(label)

	var area := Area3D.new()
	area.name = "ClickArea"
	area.collision_layer = 8
	area.collision_mask = 0
	area.input_ray_pickable = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(BUTTON_SIZE.x, 0.16, BUTTON_SIZE.z)
	collision.shape = shape
	area.add_child(collision)
	button_root.add_child(area)
	area.input_event.connect(_on_button_input_event.bind(action_id))
	area.mouse_entered.connect(_on_button_mouse_entered.bind(button_root))
	area.mouse_exited.connect(_on_button_mouse_exited.bind(button_root))
	buttons[action_id] = button_root


func get_action_texture(action_id: int) -> Texture2D:
	match action_id:
		2:
			return attack_texture
		3:
			return check_texture
		4:
			return pass_texture
		1:
			return inspect_texture
	return null


func _set_button_pickable(button_root: Node3D, pickable: bool) -> void:
	var area := button_root.get_node_or_null("ClickArea") as Area3D
	if area != null:
		area.collision_layer = 8 if pickable else 0
		area.input_ray_pickable = pickable


func _on_button_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_index: int,
	action_id: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			action_pressed.emit(action_id, slot)
			get_viewport().set_input_as_handled()


func _on_button_mouse_entered(button_root: Node3D) -> void:
	Cursors.use_pointing()
	var surface := button_root.get_node_or_null("ButtonSurface") as MeshInstance3D
	if surface != null and surface.material_override is StandardMaterial3D:
		var material := surface.material_override as StandardMaterial3D
		material.emission = Color(0.95, 0.67, 0.18, 1.0)
		material.emission_energy_multiplier = 1.5


func _on_button_mouse_exited(button_root: Node3D) -> void:
	Cursors.use_normal()
	var surface := button_root.get_node_or_null("ButtonSurface") as MeshInstance3D
	if surface != null and surface.material_override is StandardMaterial3D:
		var material := surface.material_override as StandardMaterial3D
		material.emission = Color(0.32, 0.17, 0.035, 1.0)
		material.emission_energy_multiplier = 0.65
