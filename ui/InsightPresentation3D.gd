class_name InsightPresentation3D
extends Control

signal completed(result: Dictionary)

const CARD_SCENE: PackedScene = preload("res://cards/Card3D_Test.tscn")
const RENDER_LAYER_NUMBER := 19
const RENDER_LAYER_MASK := 1 << (RENDER_LAYER_NUMBER - 1)
const CARD_PICK_LAYER := 1 << 12
const BUTTON_PICK_LAYER := 1 << 13

var battlefield: Node
var inspect_panel: CardInspectPanel
var blur_layer: ColorRect
var blur_material: ShaderMaterial
var sharp_viewport: SubViewport
var sharp_camera: Camera3D
var sharp_display: TextureRect
var presentation_root: Node3D
var card_entries: Array[Dictionary] = []
var back_button: Button
var options: Dictionary = {}
var active := false
var input_ready := false
var inspected_index := -1
var inspector_returns_to_cards := false
var blur_progress := 0.0
var blur_tween: Tween
var main_camera_old_layer := true
var camera_layer_overridden := false
var inspect_panel_old_z := 100


func setup(owner_battlefield: Node, panel: CardInspectPanel) -> void:
	battlefield = owner_battlefield
	inspect_panel = panel
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 210
	_build_overlay()
	hide()


func _build_overlay() -> void:
	blur_layer = ColorRect.new()
	blur_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur_layer.color = Color.WHITE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_lod = 0.0;
uniform float opacity = 0.0;
void fragment() {
	vec4 blurred = textureLod(screen_texture, SCREEN_UV, blur_lod);
	COLOR = vec4(blurred.rgb * 0.86, opacity);
}
"""
	blur_material = ShaderMaterial.new()
	blur_material.shader = shader
	blur_layer.material = blur_material
	add_child(blur_layer)

	sharp_viewport = SubViewport.new()
	sharp_viewport.transparent_bg = true
	sharp_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sharp_viewport)
	sharp_display = TextureRect.new()
	sharp_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sharp_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sharp_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sharp_display.stretch_mode = TextureRect.STRETCH_SCALE
	sharp_display.texture = sharp_viewport.get_texture()
	sharp_display.z_index = 1
	add_child(sharp_display)

	back_button = Button.new()
	back_button.text = "BACK"
	back_button.custom_minimum_size = Vector2(180.0, 58.0)
	back_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back_button.offset_left = -90.0
	back_button.offset_right = 90.0
	back_button.offset_top = -92.0
	back_button.offset_bottom = -34.0
	back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_button.z_index = 300
	back_button.pressed.connect(_on_back_pressed)
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.055, 0.045, 0.035, 0.96)
	back_style.border_color = Color(0.82, 0.68, 0.38, 0.95)
	back_style.set_border_width_all(2)
	back_style.set_corner_radius_all(5)
	back_button.add_theme_stylebox_override("normal", back_style)
	back_button.visible = false
	add_child(back_button)


func present(cards: Array[CardData], config: Dictionary) -> void:
	if active or cards.is_empty():
		completed.emit({"cancelled": cards.is_empty(), "index": -1})
		return
	active = true
	input_ready = false
	inspected_index = -1
	inspector_returns_to_cards = false
	options = config.duplicate(true)
	show()
	move_to_front()
	_prepare_sharp_viewport()
	_create_world_root()
	_set_blur_progress(0.0)
	blur_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	blur_tween.tween_method(_set_blur_progress, 0.0, 1.0, 0.42)

	var source: Vector3 = options.get("source_position", Vector3(0.0, 0.8, 0.0))
	var face_down := bool(options.get("face_down", false))
	var count := cards.size()
	var spacing := minf(1.48, 7.2 / maxf(float(count), 1.0))
	var start_x := -spacing * float(count - 1) * 0.5
	for index in range(count):
		var target := Vector3(start_x + spacing * index, 0.78 + index * 0.006, 0.72)
		var entry := _create_card_entry(cards[index], index, source, target, face_down)
		card_entries.append(entry)

	if bool(options.get("shuffle", false)):
		await _animate_shuffle()
	await _animate_cards_in()
	if String(options.get("mode", "reveal")) == "reveal":
		back_button.visible = true
	input_ready = true


func _prepare_sharp_viewport() -> void:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d()
	if camera == null:
		return
	var viewport_size := viewport.get_visible_rect().size
	sharp_viewport.size = Vector2i(maxi(1, int(viewport_size.x)), maxi(1, int(viewport_size.y)))
	sharp_viewport.world_3d = viewport.world_3d
	if sharp_camera == null:
		sharp_camera = Camera3D.new()
		sharp_viewport.add_child(sharp_camera)
	sharp_camera.global_transform = camera.global_transform
	sharp_camera.projection = camera.projection
	sharp_camera.fov = camera.fov
	sharp_camera.size = camera.size
	sharp_camera.near = camera.near
	sharp_camera.far = camera.far
	sharp_camera.keep_aspect = camera.keep_aspect
	sharp_camera.cull_mask = RENDER_LAYER_MASK
	sharp_camera.current = true
	main_camera_old_layer = camera.get_cull_mask_value(RENDER_LAYER_NUMBER)
	camera.set_cull_mask_value(RENDER_LAYER_NUMBER, false)
	camera_layer_overridden = true


func _create_world_root() -> void:
	presentation_root = Node3D.new()
	presentation_root.name = "InsightPresentationWorld"
	get_tree().current_scene.add_child(presentation_root)


func _create_card_entry(card: CardData, index: int, source: Vector3, target: Vector3, face_down: bool) -> Dictionary:
	var root := Node3D.new()
	root.name = "InsightCard%d" % index
	root.global_position = source
	root.scale = Vector3.ONE * 0.18
	presentation_root.add_child(root)
	var visual := CARD_SCENE.instantiate() as Node3D
	visual.call("assign_card_data", card, face_down)
	root.add_child(visual)
	_set_visual_layer_recursive(visual)

	var area := Area3D.new()
	area.collision_layer = CARD_PICK_LAYER
	area.collision_mask = 0
	area.input_ray_pickable = true
	root.add_child(area)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.06, 0.14, 1.38)
	collision.shape = shape
	area.add_child(collision)
	area.input_event.connect(_on_card_input.bind(index))
	area.mouse_entered.connect(_use_cursor.bind(&"use_pointing"))
	area.mouse_exited.connect(_use_cursor.bind(&"use_normal"))

	var entry := {"root": root, "visual": visual, "card": card, "target": target, "area": area}
	if String(options.get("mode", "reveal")) == "choose":
		_create_action_button(entry, index, "SELECT", -0.29)
		_create_action_button(entry, index, "INSPECT", 0.29)
	return entry


func _create_action_button(entry: Dictionary, index: int, action: String, x_offset: float) -> void:
	var button := Node3D.new()
	button.position = Vector3(x_offset, 0.07, 0.86)
	(entry["root"] as Node3D).add_child(button)
	var surface := MeshInstance3D.new()
	surface.layers = RENDER_LAYER_MASK
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.52, 0.24)
	surface.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.075, 0.052, 0.027, 0.98)
	var button_texture: Texture2D = null
	if battlefield != null:
		var battleplan_screen := battlefield.get_node_or_null("UI/BattlePlanSelectionScreen") as BattlePlanSelectionScreen
		if battleplan_screen != null:
			button_texture = battleplan_screen.select_button_texture if action == "SELECT" else battleplan_screen.inspect_button_texture
	if button_texture != null:
		material.albedo_texture = button_texture
		material.albedo_color = Color.WHITE
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.texture_repeat = false
	material.emission_enabled = true
	material.emission = Color(0.28, 0.17, 0.045)
	material.emission_energy_multiplier = 0.8
	material.no_depth_test = true
	surface.material_override = material
	button.add_child(surface)
	var label := Label3D.new()
	label.layers = RENDER_LAYER_MASK
	label.text = action
	label.font_size = 28
	label.pixel_size = 0.0024
	label.position.y = 0.012
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.9, 0.68)
	label.visible = button_texture == null
	button.add_child(label)
	var area := Area3D.new()
	area.collision_layer = BUTTON_PICK_LAYER
	area.collision_mask = 0
	area.input_ray_pickable = true
	button.add_child(area)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.52, 0.13, 0.24)
	collision.shape = shape
	area.add_child(collision)
	area.input_event.connect(_on_action_input.bind(index, action))
	area.mouse_entered.connect(_on_button_hover.bind(material, true))
	area.mouse_exited.connect(_on_button_hover.bind(material, false))


func _animate_cards_in() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for index in range(card_entries.size()):
		var entry := card_entries[index]
		var root := entry["root"] as Node3D
		tween.parallel().tween_property(root, "global_position", entry["target"], 0.46).set_delay(index * 0.055)
		tween.parallel().tween_property(root, "scale", Vector3.ONE * 1.08, 0.46).set_delay(index * 0.055)
	await tween.finished


func _animate_shuffle() -> void:
	var center := Vector3(0.0, 0.78, 0.72)
	for step in range(5):
		var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		for index in range(card_entries.size()):
			var root := card_entries[index]["root"] as Node3D
			var offset := Vector3((index - card_entries.size() * 0.5) * 0.035, index * 0.005, step % 2 * 0.05)
			tween.parallel().tween_property(root, "global_position", center + offset, 0.10)
		await tween.finished
	for index in range(card_entries.size()):
		card_entries[index]["target"] = Vector3(
			(float(index) - float(card_entries.size() - 1) * 0.5) * minf(1.48, 7.2 / maxf(float(card_entries.size()), 1.0)),
			0.78 + index * 0.006,
			0.72
		)


func _on_card_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape: int, index: int) -> void:
	if not input_ready or not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	if String(options.get("mode", "reveal")) == "hidden_pick":
		_show_inspector(index, true)
	elif String(options.get("mode", "reveal")) == "reveal":
		_show_inspector(index, false)
	get_viewport().set_input_as_handled()


func _on_action_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape: int, index: int, action: String) -> void:
	if not input_ready or not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	if action == "SELECT":
		await _resolve_choice(index)
	else:
		_show_inspector(index, false)
	get_viewport().set_input_as_handled()


func _show_inspector(index: int, completes_on_back: bool) -> void:
	if inspect_panel == null or index < 0 or index >= card_entries.size():
		return
	inspected_index = index if completes_on_back else -1
	inspector_returns_to_cards = not completes_on_back
	input_ready = false
	for entry in card_entries:
		(entry["root"] as Node3D).visible = false
	var entry := card_entries[index]
	var card := entry["card"] as CardData
	var rect := _card_screen_rect(entry["root"] as Node3D)
	inspect_panel_old_z = inspect_panel.z_index
	inspect_panel.z_index = 260
	inspect_panel.show_texture(card.card_art, rect, false)
	back_button.visible = true


func _on_back_pressed() -> void:
	if inspect_panel != null and inspect_panel.visible:
		inspect_panel.hide_card()
	if inspect_panel != null:
		inspect_panel.z_index = inspect_panel_old_z
	if inspector_returns_to_cards:
		inspector_returns_to_cards = false
		for entry in card_entries:
			(entry["root"] as Node3D).visible = true
		back_button.visible = String(options.get("mode", "reveal")) == "reveal"
		input_ready = true
		return
	if inspected_index >= 0:
		await _finish({"index": inspected_index, "card": card_entries[inspected_index]["card"]})
		return
	if String(options.get("mode", "reveal")) == "reveal":
		await _finish({"index": -1})
		return
	for entry in card_entries:
		(entry["root"] as Node3D).visible = true
	back_button.visible = false
	input_ready = true


func _resolve_choice(index: int) -> void:
	input_ready = false
	var chosen_destination: Vector3 = options.get("chosen_destination", Vector3(0.0, 1.2, 2.8))
	var other_destination: Vector3 = options.get("other_destination", options.get("source_position", Vector3.ZERO))
	var return_pile := options.get("lift_return_pile") as Node3D
	var return_pile_position := Vector3.ZERO
	if return_pile != null:
		return_pile_position = return_pile.position
		var lift_tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		lift_tween.tween_property(return_pile, "position", return_pile_position + Vector3(0.0, 0.13, 0.0), 0.18)
		await lift_tween.finished
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for entry_index in range(card_entries.size()):
		var root := card_entries[entry_index]["root"] as Node3D
		var destination := chosen_destination if entry_index == index else other_destination
		tween.parallel().tween_property(root, "global_position", destination, 0.48).set_delay(entry_index * 0.035)
		tween.parallel().tween_property(root, "scale", Vector3.ONE * 0.18, 0.48).set_delay(entry_index * 0.035)
	await tween.finished
	if return_pile != null:
		var lower_tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		lower_tween.tween_property(return_pile, "position", return_pile_position, 0.24)
		await lower_tween.finished
	await _finish({"index": index, "card": card_entries[index]["card"]})


func _finish(result: Dictionary) -> void:
	back_button.visible = false
	if blur_tween != null and blur_tween.is_valid():
		blur_tween.kill()
	blur_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	blur_tween.tween_method(_set_blur_progress, blur_progress, 0.0, 0.32)
	await blur_tween.finished
	_cleanup()
	completed.emit(result)


func _cleanup() -> void:
	if inspect_panel != null and inspect_panel.visible:
		inspect_panel.hide_card()
	if presentation_root != null and is_instance_valid(presentation_root):
		presentation_root.queue_free()
	presentation_root = null
	card_entries.clear()
	if camera_layer_overridden:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			camera.set_cull_mask_value(RENDER_LAYER_NUMBER, main_camera_old_layer)
	camera_layer_overridden = false
	active = false
	input_ready = false
	_use_cursor(&"use_normal")
	hide()


func _set_blur_progress(progress: float) -> void:
	blur_progress = clampf(progress, 0.0, 1.0)
	if blur_material != null:
		blur_material.set_shader_parameter("blur_lod", 2.1 * blur_progress)
		blur_material.set_shader_parameter("opacity", 0.88 * blur_progress)


func _set_visual_layer_recursive(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = RENDER_LAYER_MASK
	for child in node.get_children():
		_set_visual_layer_recursive(child)


func _card_screen_rect(root: Node3D) -> Rect2:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Rect2()
	var center := camera.unproject_position(root.global_position)
	return Rect2(center - Vector2(90.0, 125.0), Vector2(180.0, 250.0))


func _on_button_hover(material: StandardMaterial3D, hovered: bool) -> void:
	_use_cursor(&"use_pointing" if hovered else &"use_normal")
	if material != null:
		material.emission_energy_multiplier = 1.55 if hovered else 0.8


func _use_cursor(method_name: StringName) -> void:
	var cursors := get_node_or_null("/root/Cursors")
	if cursors != null and cursors.has_method(method_name):
		cursors.call(method_name)
