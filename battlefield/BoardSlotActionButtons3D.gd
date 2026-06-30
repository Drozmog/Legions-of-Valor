class_name BoardSlotActionButtons3D
extends Node3D

signal action_pressed(action_id: int, slot: Node)

@export var attack_texture: Texture2D
@export var check_texture: Texture2D
@export var pass_texture: Texture2D
@export var inspect_texture: Texture2D

# 280x130 texture ratio = 2.1538
# X / Z should match that ratio.
const BUTTON_SIZE := Vector3(0.42, 0.035, 0.195)
const BUTTON_SURFACE_SIZE := Vector2(BUTTON_SIZE.x, BUTTON_SIZE.z)

const HIDDEN_X := 0.46
const SHOWN_X := 0.76
const BUTTON_Z_SPACING := 0.23
const SLIDE_TIME := 0.18
const BOARD_ACTION_INSPECT := 1
const CARD_VISUAL_WIDTH := 1.02
const CARD_VISUAL_HEIGHT := 1.34
const INSPECT_FADE_ALPHA := 0.36

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
	if _is_modal_blocked():
		action_ids = []

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

	var mesh := PlaneMesh.new()
	mesh.size = BUTTON_SURFACE_SIZE

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
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.texture_repeat = false

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
		area.collision_layer = 8 if pickable and not _is_modal_blocked() else 0
		area.input_ray_pickable = pickable and not _is_modal_blocked()


func _on_button_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_index: int,
	action_id: int
) -> void:
	if _is_modal_blocked():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if action_id == BOARD_ACTION_INSPECT:
				inspect_slot_card_locally()
			else:
				SceneLoader.play_board_action_button(action_id)
				action_pressed.emit(action_id, slot)
			get_viewport().set_input_as_handled()


func _on_button_mouse_entered(button_root: Node3D) -> void:
	if _is_modal_blocked():
		return
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


func inspect_slot_card_locally() -> void:
	if slot == null or not is_instance_valid(slot):
		return
	if not slot.has_method("get_placed_card_data"):
		return
	var card_data := slot.call("get_placed_card_data") as CardData
	if card_data == null:
		return
	var inspector := find_card_inspect_panel()
	if inspector == null:
		return
	set_slot_card_faded(true)
	var clear_callable := Callable(self, "_clear_slot_inspection_fade")
	if not inspector.inspection_closed.is_connected(clear_callable):
		inspector.inspection_closed.connect(clear_callable)
	inspector.z_index = maxi(inspector.z_index, 950)
	inspector.last_source_rect = get_slot_card_screen_rect()
	inspector.show_card(null, card_data)


func _clear_slot_inspection_fade() -> void:
	set_slot_card_faded(false)


func set_slot_card_faded(active: bool) -> void:
	if slot == null or not is_instance_valid(slot) or not slot.has_method("get_placed_card_visual"):
		return
	var visual := slot.call("get_placed_card_visual") as Node
	if visual == null or not is_instance_valid(visual):
		return
	_set_visual_fade_recursive(visual, active)


func _set_visual_fade_recursive(node: Node, active: bool) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.material_override is StandardMaterial3D:
			var material := mesh_instance.material_override as StandardMaterial3D
			var next_material := material.duplicate() as StandardMaterial3D
			var color := next_material.albedo_color

			if active:
				if not mesh_instance.has_meta("inspect_original_alpha"):
					mesh_instance.set_meta("inspect_original_alpha", color.a)
				next_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				color.a = INSPECT_FADE_ALPHA
			else:
				color.a = float(mesh_instance.get_meta("inspect_original_alpha", 1.0))
				if color.a >= 0.999:
					next_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				if mesh_instance.has_meta("inspect_original_alpha"):
					mesh_instance.remove_meta("inspect_original_alpha")

			next_material.albedo_color = color
			mesh_instance.material_override = next_material

	elif node is Sprite3D:
		var sprite := node as Sprite3D
		var color := sprite.modulate

		if active:
			if not sprite.has_meta("inspect_original_alpha"):
				sprite.set_meta("inspect_original_alpha", color.a)
			color.a = INSPECT_FADE_ALPHA
		else:
			color.a = float(sprite.get_meta("inspect_original_alpha", 1.0))
			if sprite.has_meta("inspect_original_alpha"):
				sprite.remove_meta("inspect_original_alpha")

		sprite.modulate = color

	elif node is Label3D:
		var label := node as Label3D
		var color := label.modulate

		if active:
			if not label.has_meta("inspect_original_alpha"):
				label.set_meta("inspect_original_alpha", color.a)
			color.a = INSPECT_FADE_ALPHA
		else:
			color.a = float(label.get_meta("inspect_original_alpha", 1.0))
			if label.has_meta("inspect_original_alpha"):
				label.remove_meta("inspect_original_alpha")

		label.modulate = color

	for child in node.get_children():
		_set_visual_fade_recursive(child, active)


func get_slot_card_screen_rect() -> Rect2:
	var camera := get_viewport().get_camera_3d()
	if camera == null or slot == null or not is_instance_valid(slot):
		return Rect2(get_viewport().get_mouse_position() - Vector2(65.0, 90.0), Vector2(130.0, 180.0))
	var visual: Variant = null
	if slot.has_method("get_placed_card_visual"):
		visual = slot.call("get_placed_card_visual")
	if not (visual is Node3D):
		visual = slot
	var visual_3d := visual as Node3D
	var half_width := CARD_VISUAL_WIDTH * 0.5
	var half_height := CARD_VISUAL_HEIGHT * 0.5
	var corners := [
		Vector3(-half_width, 0.0, -half_height),
		Vector3(half_width, 0.0, -half_height),
		Vector3(half_width, 0.0, half_height),
		Vector3(-half_width, 0.0, half_height),
	]
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for corner in corners:
		var world_point: Vector3 = visual_3d.global_transform * corner
		if camera.is_position_behind(world_point):
			continue
		var screen_point := camera.unproject_position(world_point)
		min_point.x = minf(min_point.x, screen_point.x)
		min_point.y = minf(min_point.y, screen_point.y)
		max_point.x = maxf(max_point.x, screen_point.x)
		max_point.y = maxf(max_point.y, screen_point.y)
	if min_point.x == INF:
		var center := camera.unproject_position(visual_3d.global_position)
		return Rect2(center - Vector2(65.0, 90.0), Vector2(130.0, 180.0))
	var rect := Rect2(min_point, max_point - min_point).abs()
	var min_size := Vector2(130.0, 180.0)
	if rect.size.x < min_size.x or rect.size.y < min_size.y:
		var center := rect.position + rect.size * 0.5
		rect = Rect2(center - min_size * 0.5, min_size)
	return rect.grow(10.0)


func find_card_inspect_panel() -> CardInspectPanel:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return find_card_inspect_panel_recursive(scene)


func find_card_inspect_panel_recursive(node: Node) -> CardInspectPanel:
	if node is CardInspectPanel:
		return node as CardInspectPanel
	for child in node.get_children():
		var found := find_card_inspect_panel_recursive(child)
		if found != null:
			return found
	return null


func _is_modal_blocked() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var depth: Variant = scene.get("blurred_modal_input_depth")
	return depth != null and int(depth) > 0
