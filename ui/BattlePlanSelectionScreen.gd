class_name BattlePlanSelectionScreen
extends Control

signal battle_plan_selected(plan: Dictionary)

@export var battleplan_back_texture: Texture2D = preload("res://cards/card_back.png")
@export var select_button_texture: Texture2D
@export var inspect_button_texture: Texture2D

const CARD_PICK_LAYER := 16
const BUTTON_PICK_LAYER := 32
const CARD_BACK_SIZE := Vector2(1.48, 2.07) # 2.5 x 3.5 portrait back.
const BATTLEPLAN_SIZE := Vector2(3.08, 2.20) # Exact 3.5 x 2.5 landscape ratio.
# Matches Card3DTest's 0.065 radius on a 1.02-wide card.
const CARD_CORNER_RADIUS_RATIO := 0.064
const CARD_CORNER_SEGMENTS := 8
const BOTTOM_CARD_Z := 2.20
const TOP_CARD_Z := -1.12
const CARD_SURFACE_Y := 0.58
const TOP_SLOT_X := [-3.35, 0.0, 3.35]
const SHUFFLE_STEP_TIME := 0.115
const CARD_MOVE_TIME := 0.26
const BUTTON_SIZE := Vector3(0.78, 0.045, 0.32)

var dim_layer: ColorRect
var selection_root: Node3D
var world_dimmer: MeshInstance3D
var card_entries: Array[Dictionary] = []
var face_viewports: Array[SubViewport] = []
var revealed_indices: Array[int] = []
var action_groups: Dictionary = {}
var selection_ready := false
var actions_ready := false
var inspected_index := -1
var shared_inspector: CardInspectPanel
var inspector_actions: HBoxContainer
var animation_generation := 0
var ui_built := false


func _ready() -> void:
	setup_screen()
	build_base_ui()
	setup_shared_inspector()
	hide_selection()


func setup_shared_inspector() -> void:
	shared_inspector = get_parent().get_node_or_null("CardInspectPanel") as CardInspectPanel
	if shared_inspector != null and not shared_inspector.inspection_closed.is_connected(_on_shared_inspector_closed):
		shared_inspector.inspection_closed.connect(_on_shared_inspector_closed)


func setup_screen() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100


func build_base_ui() -> void:
	if ui_built:
		return
	ui_built = true
	dim_layer = ColorRect.new()
	dim_layer.name = "BattlePlanDimmer"
	dim_layer.color = Color.TRANSPARENT
	dim_layer.visible = false
	dim_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim_layer)


func show_selection(plans: Array[Dictionary]) -> void:
	if not ui_built:
		setup_screen()
		build_base_ui()
	_cleanup_selection_world()
	animation_generation += 1
	selection_ready = false
	actions_ready = false
	inspected_index = -1
	revealed_indices.clear()
	action_groups.clear()
	show()
	move_to_front()
	_create_selection_world(plans)
	if card_entries.size() <= 3:
		_show_remaining_plans_directly()
	else:
		_run_intro_sequence(animation_generation)


func hide_selection() -> void:
	animation_generation += 1
	selection_ready = false
	actions_ready = false
	inspected_index = -1
	_cleanup_inspector_actions()
	if shared_inspector != null and shared_inspector.visible:
		shared_inspector.hide_card()
	_cleanup_selection_world()
	_use_cursor("use_normal")
	hide()


func _create_selection_world(plans: Array[Dictionary]) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	selection_root = Node3D.new()
	selection_root.name = "BattlePlanSelection3D"
	scene_root.add_child(selection_root)
	_create_world_dimmer()

	var shown_count := mini(5, plans.size())
	for card_index in range(shown_count):
		card_entries.append(_create_card_entry(plans[card_index], card_index, shown_count))


func _create_world_dimmer() -> void:
	world_dimmer = MeshInstance3D.new()
	world_dimmer.name = "BattlePlanWorldDimmer"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(40.0, 28.0)
	world_dimmer.mesh = mesh
	world_dimmer.position = Vector3(0.0, CARD_SURFACE_Y - 0.10, 0.0)
	world_dimmer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.0, 0.0, 0.0, 0.48)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 90
	world_dimmer.material_override = material
	selection_root.add_child(world_dimmer)


func _create_card_entry(plan: Dictionary, card_index: int, card_count: int) -> Dictionary:
	var card_root := Node3D.new()
	card_root.name = "BattlePlanCard%d" % (card_index + 1)
	card_root.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	card_root.position = _bottom_card_position(card_index, card_count) + Vector3(0.0, -0.18, 3.0)
	card_root.scale = Vector3(0.82, 0.82, 0.82)
	selection_root.add_child(card_root)

	var visual_root := Node3D.new()
	visual_root.name = "FlipRoot"
	card_root.add_child(visual_root)

	var back := MeshInstance3D.new()
	back.name = "CardBack"
	back.mesh = _create_rounded_card_mesh(CARD_BACK_SIZE)
	back.position.z = 0.014
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	back.material_override = _make_card_material(battleplan_back_texture, 100)
	visual_root.add_child(back)

	var front := MeshInstance3D.new()
	front.name = "BattlePlanFront"
	front.mesh = _create_rounded_card_mesh(BATTLEPLAN_SIZE)
	front.position.z = 0.018
	front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	front.material_override = _make_card_material(_create_battleplan_face_texture(plan), 102)
	front.visible = false
	visual_root.add_child(front)

	var area := Area3D.new()
	area.name = "CardPickArea"
	area.collision_layer = CARD_PICK_LAYER
	area.collision_mask = 0
	area.input_ray_pickable = true
	card_root.add_child(area)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(CARD_BACK_SIZE.x, CARD_BACK_SIZE.y, 0.18)
	collision.shape = shape
	area.add_child(collision)
	area.input_event.connect(_on_card_input_event.bind(card_index))
	area.mouse_entered.connect(_on_card_mouse_entered.bind(card_index))
	area.mouse_exited.connect(_on_card_mouse_exited.bind(card_index))

	return {
		"root": card_root,
		"visual": visual_root,
		"back": back,
		"front": front,
		"area": area,
		"collision": collision,
		"plan": plan,
		"state": "intro",
		"bottom_position": _bottom_card_position(card_index, card_count),
		"slot_index": -1,
	}


func _bottom_card_position(card_index: int, card_count: int) -> Vector3:
	var centered_index := float(card_index) - float(card_count - 1) * 0.5
	return Vector3(centered_index * 2.05, CARD_SURFACE_Y, BOTTOM_CARD_Z)


func _show_remaining_plans_directly() -> void:
	var card_count := card_entries.size()
	if card_count <= 0:
		return

	for card_index in range(card_count):
		var entry: Dictionary = card_entries[card_index]
		var root := entry["root"] as Node3D
		var centered_index := float(card_index) - float(card_count - 1) * 0.5
		root.position = Vector3(centered_index * 3.35, CARD_SURFACE_Y + 0.07, TOP_CARD_Z)
		root.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		root.scale = Vector3.ONE
		entry["state"] = "revealed"
		entry["slot_index"] = card_index
		revealed_indices.append(card_index)
		_show_card_front(card_index)
		_set_card_pickable(entry, true)

	selection_ready = true
	_show_action_buttons()


func _make_card_material(texture: Texture2D, priority: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = texture
	# Keep selector cards in the transparent pass after the world dimmer so the
	# 48% veil affects only the battlefield beneath them.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = priority
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.emission_enabled = true
	material.emission = Color(0.10, 0.055, 0.012, 1.0)
	material.emission_energy_multiplier = 0.18
	return material


func _create_rounded_card_mesh(size: Vector2) -> ArrayMesh:
	var half_size := size * 0.5
	var radius := minf(size.x, size.y) * CARD_CORNER_RADIUS_RATIO
	var outline: Array[Vector2] = []
	_add_card_corner(outline, Vector2(half_size.x - radius, half_size.y - radius), radius, 0.0, 90.0)
	_add_card_corner(outline, Vector2(-half_size.x + radius, half_size.y - radius), radius, 90.0, 180.0)
	_add_card_corner(outline, Vector2(-half_size.x + radius, -half_size.y + radius), radius, 180.0, 270.0)
	_add_card_corner(outline, Vector2(half_size.x - radius, -half_size.y + radius), radius, 270.0, 360.0)

	var vertices := PackedVector3Array([Vector3.ZERO])
	var normals := PackedVector3Array([Vector3.FORWARD])
	var uvs := PackedVector2Array([Vector2(0.5, 0.5)])
	var indices := PackedInt32Array()
	for point in outline:
		vertices.append(Vector3(point.x, point.y, 0.0))
		normals.append(Vector3.FORWARD)
		uvs.append(Vector2(
			(point.x + half_size.x) / size.x,
			1.0 - ((point.y + half_size.y) / size.y)
		))
	for index in range(1, outline.size() + 1):
		var next_index := index + 1 if index < outline.size() else 1
		indices.append(0)
		indices.append(index)
		indices.append(next_index)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_card_corner(
	points: Array[Vector2],
	center: Vector2,
	radius: float,
	start_degrees: float,
	end_degrees: float
) -> void:
	for segment in range(CARD_CORNER_SEGMENTS + 1):
		var weight := float(segment) / float(CARD_CORNER_SEGMENTS)
		var angle := deg_to_rad(lerpf(start_degrees, end_degrees, weight))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)


func _create_battleplan_face_texture(plan: Dictionary) -> Texture2D:
	var supplied_texture := _get_supplied_plan_texture(plan)
	if supplied_texture != null:
		return supplied_texture

	var viewport := SubViewport.new()
	viewport.name = "BattlePlanFaceViewport"
	viewport.size = Vector2i(980, 700)
	viewport.transparent_bg = false
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	face_viewports.append(viewport)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.82, 0.73, 0.55, 1.0)
	panel_style.border_color = Color(0.55, 0.34, 0.07, 1.0)
	panel_style.set_border_width_all(12)
	panel_style.set_corner_radius_all(34)
	panel.add_theme_stylebox_override("panel", panel_style)
	viewport.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	margin.add_child(rows)

	var name_label := Label.new()
	name_label.text = str(plan.get("name", "Battle Plan"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 48)
	name_label.add_theme_color_override("font_color", Color(0.26, 0.105, 0.025, 1.0))
	rows.add_child(name_label)

	var art_panel := ColorRect.new()
	art_panel.custom_minimum_size = Vector2(0.0, 350.0)
	art_panel.color = Color(0.15, 0.095, 0.045, 1.0)
	art_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(art_panel)
	var art_title := Label.new()
	art_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_title.text = "BATTLE PLAN"
	art_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art_title.add_theme_font_size_override("font_size", 42)
	art_title.add_theme_color_override("font_color", Color(0.86, 0.69, 0.30, 1.0))
	art_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_panel.add_child(art_title)

	var stats := Label.new()
	stats.text = "INIT %s    DRAW %s    HAND %s    REWARD +%s" % [
		plan.get("initiative_mark", 0),
		plan.get("draw_amount", 0),
		plan.get("max_hand_size", 0),
		plan.get("aurion_reward", 0),
	]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 27)
	stats.add_theme_color_override("font_color", Color(0.22, 0.085, 0.02, 1.0))
	rows.add_child(stats)

	var objective := Label.new()
	objective.text = str(plan.get("objective", "No objective supplied."))
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective.size_flags_vertical = Control.SIZE_EXPAND_FILL
	objective.add_theme_font_size_override("font_size", 25)
	objective.add_theme_color_override("font_color", Color(0.18, 0.07, 0.018, 1.0))
	rows.add_child(objective)
	return viewport.get_texture()


func _get_supplied_plan_texture(plan: Dictionary) -> Texture2D:
	for key in ["card_art", "battleplan_art", "texture"]:
		var value: Variant = plan.get(key, null)
		if value is Texture2D:
			return value as Texture2D
		if value is String and not String(value).is_empty() and ResourceLoader.exists(String(value)):
			return load(String(value)) as Texture2D
	return null


func _run_intro_sequence(generation: int) -> void:
	await get_tree().process_frame
	if generation != animation_generation or not visible:
		return

	for card_index in range(card_entries.size()):
		var entry: Dictionary = card_entries[card_index]
		var root := entry["root"] as Node3D
		var rise := create_tween()
		rise.tween_interval(float(card_index) * 0.075)
		rise.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rise.tween_property(root, "position", entry["bottom_position"], 0.48)
		rise.parallel().tween_property(root, "scale", Vector3.ONE, 0.48)
	await get_tree().create_timer(0.90).timeout
	if generation != animation_generation or not visible:
		return

	for whirl_step in range(12):
		for card_index in range(card_entries.size()):
			var entry: Dictionary = card_entries[card_index]
			var root := entry["root"] as Node3D
			var angle := (TAU * float(whirl_step) / 6.0) + (TAU * float(card_index) / maxf(1.0, float(card_entries.size())))
			var target := Vector3(cos(angle) * 2.55, CARD_SURFACE_Y + 0.12, 1.05 + sin(angle) * 0.82)
			var whirl := create_tween()
			whirl.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			whirl.tween_property(root, "position", target, SHUFFLE_STEP_TIME)
			whirl.parallel().tween_property(root, "rotation_degrees", Vector3(-90.0, 0.0, float(whirl_step + 1) * 75.0), SHUFFLE_STEP_TIME)
		await get_tree().create_timer(SHUFFLE_STEP_TIME).timeout
		if generation != animation_generation or not visible:
			return

	for card_index in range(card_entries.size()):
		var entry: Dictionary = card_entries[card_index]
		var root := entry["root"] as Node3D
		var settle := create_tween()
		settle.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		settle.tween_property(root, "position", entry["bottom_position"], 0.42)
		settle.parallel().tween_property(root, "rotation_degrees", Vector3(-90.0, 0.0, 0.0), 0.42)
	await get_tree().create_timer(0.46).timeout
	if generation != animation_generation or not visible:
		return
	for entry in card_entries:
		entry["state"] = "available"
	selection_ready = true


func _on_card_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_index: int,
	card_index: int
) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if not selection_ready or card_index < 0 or card_index >= card_entries.size():
		return
	var entry: Dictionary = card_entries[card_index]
	if String(entry["state"]) != "available" or revealed_indices.size() >= 3:
		return
	var slot_index := revealed_indices.size()
	revealed_indices.append(card_index)
	entry["state"] = "moving"
	entry["slot_index"] = slot_index
	_set_card_pickable(entry, false)
	_animate_card_to_slot(card_index, slot_index)
	get_viewport().set_input_as_handled()


func _animate_card_to_slot(card_index: int, slot_index: int) -> void:
	var entry: Dictionary = card_entries[card_index]
	var root := entry["root"] as Node3D
	var visual := entry["visual"] as Node3D
	var target := Vector3(float(TOP_SLOT_X[slot_index]), CARD_SURFACE_Y + 0.07, TOP_CARD_Z)
	var midpoint := (root.position + target) * 0.5 + Vector3(0.0, 0.72, -0.15)

	var lift := create_tween()
	lift.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	lift.tween_property(root, "position", midpoint, CARD_MOVE_TIME)
	lift.parallel().tween_property(root, "rotation_degrees", Vector3(-90.0, 0.0, 180.0), CARD_MOVE_TIME)
	lift.parallel().tween_property(visual, "rotation_degrees", Vector3(0.0, 90.0, 0.0), CARD_MOVE_TIME)
	await lift.finished
	if not visible or root == null or not is_instance_valid(root):
		return
	_show_card_front(card_index)

	var land := create_tween()
	land.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	land.tween_property(root, "position", target, CARD_MOVE_TIME + 0.10)
	land.parallel().tween_property(root, "rotation_degrees", Vector3(-90.0, 0.0, 360.0), CARD_MOVE_TIME + 0.10)
	land.parallel().tween_property(visual, "rotation_degrees", Vector3.ZERO, CARD_MOVE_TIME + 0.10)
	await land.finished
	if not visible or root == null or not is_instance_valid(root):
		return
	root.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	entry["state"] = "revealed"
	_set_card_pickable(entry, true)
	if revealed_indices.size() == 3 and _all_selected_cards_revealed():
		_show_action_buttons()


func _show_card_front(card_index: int) -> void:
	if card_index < 0 or card_index >= card_entries.size():
		return
	var entry: Dictionary = card_entries[card_index]
	(entry["back"] as MeshInstance3D).visible = false
	(entry["front"] as MeshInstance3D).visible = true
	var collision := entry["collision"] as CollisionShape3D
	if collision != null and collision.shape is BoxShape3D:
		(collision.shape as BoxShape3D).size = Vector3(BATTLEPLAN_SIZE.x, BATTLEPLAN_SIZE.y, 0.18)


func _all_selected_cards_revealed() -> bool:
	for card_index in revealed_indices:
		if String(card_entries[card_index]["state"]) != "revealed":
			return false
	return true


func _show_action_buttons() -> void:
	if actions_ready:
		return
	actions_ready = true
	for card_index in revealed_indices:
		var entry: Dictionary = card_entries[card_index]
		var slot_index := int(entry["slot_index"])
		var group := _create_action_group(card_index, slot_index)
		action_groups[card_index] = group


func _create_action_group(card_index: int, slot_index: int) -> Node3D:
	var group := Node3D.new()
	group.name = "BattlePlanActions%d" % (slot_index + 1)
	var entry: Dictionary = card_entries[card_index]
	var card_root := entry["root"] as Node3D
	group.position = Vector3(card_root.position.x, CARD_SURFACE_Y + 0.11, TOP_CARD_Z + 1.34)
	group.scale = Vector3(0.02, 0.02, 0.02)
	selection_root.add_child(group)
	_create_action_button(group, card_index, "select", "SELECT", -0.46, select_button_texture)
	_create_action_button(group, card_index, "inspect", "INSPECT", 0.46, inspect_button_texture)
	var reveal := create_tween()
	reveal.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(group, "scale", Vector3.ONE, 0.24)
	return group


func _action_group_position(slot_index: int) -> Vector3:
	return Vector3(float(TOP_SLOT_X[slot_index]), CARD_SURFACE_Y + 0.11, TOP_CARD_Z + 1.34)


func _create_action_button(
	group: Node3D,
	card_index: int,
	action: String,
	caption: String,
	x_offset: float,
	texture: Texture2D
) -> void:
	var button_root := Node3D.new()
	button_root.name = caption.capitalize() + "Button"
	button_root.position.x = x_offset
	group.add_child(button_root)

	var surface := MeshInstance3D.new()
	surface.name = "ButtonSurface"
	var mesh := BoxMesh.new()
	mesh.size = BUTTON_SIZE
	surface.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.WHITE if texture != null else Color(0.16, 0.075, 0.018, 0.98)
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.34, 0.18, 0.035, 1.0)
	material.emission_energy_multiplier = 0.70
	material.no_depth_test = true
	material.render_priority = 110
	surface.material_override = material
	button_root.add_child(surface)

	var label := Label3D.new()
	label.name = "ButtonLabel"
	label.text = caption
	label.position = Vector3(0.0, 0.03, 0.0)
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	label.pixel_size = 0.0025
	label.font_size = 31
	label.modulate = Color(1.0, 0.88, 0.53, 1.0)
	label.outline_modulate = Color(0.025, 0.008, 0.0, 1.0)
	label.outline_size = 7
	label.no_depth_test = true
	label.render_priority = 111
	label.visible = texture == null
	button_root.add_child(label)

	var area := Area3D.new()
	area.name = "ClickArea"
	area.collision_layer = BUTTON_PICK_LAYER
	area.collision_mask = 0
	area.input_ray_pickable = true
	button_root.add_child(area)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(BUTTON_SIZE.x, 0.18, BUTTON_SIZE.z)
	collision.shape = shape
	area.add_child(collision)
	area.input_event.connect(_on_action_input_event.bind(card_index, action))
	area.mouse_entered.connect(_on_action_mouse_entered.bind(button_root))
	area.mouse_exited.connect(_on_action_mouse_exited.bind(button_root))


func _on_action_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_index: int,
	card_index: int,
	action: String
) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if action == "select":
		_select_plan(card_index)
	else:
		_toggle_inspect(card_index)
	get_viewport().set_input_as_handled()


func _select_plan(card_index: int) -> void:
	if not actions_ready or card_index < 0 or card_index >= card_entries.size():
		return
	var plan: Dictionary = card_entries[card_index]["plan"]
	_cleanup_inspector_actions()
	if shared_inspector != null and shared_inspector.visible:
		shared_inspector.hide_card()
	battle_plan_selected.emit(plan)
	call_deferred("hide_selection")


func _toggle_inspect(card_index: int) -> void:
	if shared_inspector == null:
		setup_shared_inspector()
	if shared_inspector == null:
		return
	if inspected_index == card_index and shared_inspector.visible:
		_close_battleplan_inspector()
		return

	inspected_index = card_index
	for entry in card_entries:
		(entry["root"] as Node3D).visible = true
		_set_card_pickable(entry, false)
	for group in action_groups.values():
		(group as Node3D).visible = false

	var selected_entry: Dictionary = card_entries[card_index]
	var front := selected_entry["front"] as MeshInstance3D
	var texture: Texture2D = null
	if front != null and front.material_override is StandardMaterial3D:
		texture = (front.material_override as StandardMaterial3D).albedo_texture
	shared_inspector.show_texture(texture, _get_battleplan_source_rect(selected_entry), true)
	_build_inspector_actions(card_index)


func _get_battleplan_source_rect(entry: Dictionary) -> Rect2:
	var camera := get_viewport().get_camera_3d()
	var root := entry["root"] as Node3D
	if camera == null or root == null:
		return Rect2()
	var center := camera.unproject_position(root.global_position)
	var source_size := Vector2(330.0, 236.0)
	return Rect2(center - source_size * 0.5, source_size)


func _build_inspector_actions(card_index: int) -> void:
	_cleanup_inspector_actions()
	inspector_actions = HBoxContainer.new()
	inspector_actions.name = "BattlePlanInspectorActions"
	inspector_actions.set_anchors_preset(Control.PRESET_CENTER)
	inspector_actions.offset_left = -170.0
	inspector_actions.offset_right = 170.0
	inspector_actions.offset_top = 330.0
	inspector_actions.offset_bottom = 386.0
	inspector_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	inspector_actions.add_theme_constant_override("separation", 18)
	inspector_actions.mouse_filter = Control.MOUSE_FILTER_PASS
	inspector_actions.z_index = 300
	add_child(inspector_actions)

	var select_button := _make_inspector_button("SELECT")
	select_button.pressed.connect(_select_plan.bind(card_index))
	inspector_actions.add_child(select_button)
	var back_button := _make_inspector_button("BACK")
	back_button.pressed.connect(_close_battleplan_inspector)
	inspector_actions.add_child(back_button)


func _make_inspector_button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(150.0, 52.0)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.045, 0.012, 0.98)
	normal.border_color = Color(0.58, 0.34, 0.06, 1.0)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(7)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.26, 0.12, 0.025, 1.0)
	hover.border_color = Color(1.0, 0.72, 0.22, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Color(1.0, 0.84, 0.48, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 18)
	return button


func _close_battleplan_inspector() -> void:
	if shared_inspector != null and shared_inspector.visible:
		shared_inspector.hide_card()
	_restore_selection_after_inspector()


func _on_shared_inspector_closed() -> void:
	if inspected_index >= 0:
		_restore_selection_after_inspector()


func _restore_selection_after_inspector() -> void:
	_cleanup_inspector_actions()
	inspected_index = -1
	for entry in card_entries:
		(entry["root"] as Node3D).visible = true
		var state := String(entry["state"])
		_set_card_pickable(entry, state == "available" or state == "revealed")
	for group in action_groups.values():
		(group as Node3D).visible = true


func _cleanup_inspector_actions() -> void:
	if inspector_actions != null and is_instance_valid(inspector_actions):
		inspector_actions.queue_free()
	inspector_actions = null


func _restore_inspected_card(card_index: int, immediate: bool = false) -> void:
	if card_index < 0 or card_index >= card_entries.size():
		return
	var entry: Dictionary = card_entries[card_index]
	var slot_index := int(entry["slot_index"])
	var root := entry["root"] as Node3D
	var group := action_groups.get(card_index, null) as Node3D
	var target := Vector3(float(TOP_SLOT_X[slot_index]), CARD_SURFACE_Y + 0.07, TOP_CARD_Z)
	if immediate:
		root.position = target
		root.scale = Vector3.ONE
		if group != null:
			group.position = _action_group_position(slot_index)
	else:
		var restore := create_tween()
		restore.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		restore.tween_property(root, "position", target, 0.26)
		restore.parallel().tween_property(root, "scale", Vector3.ONE, 0.26)
		if group != null:
			restore.parallel().tween_property(group, "position", _action_group_position(slot_index), 0.26)
	if group != null:
		_set_inspect_caption(group, "INSPECT")
	inspected_index = -1
	for card_entry in card_entries:
		(card_entry["root"] as Node3D).visible = true
		var state := String(card_entry["state"])
		_set_card_pickable(card_entry, state == "available" or state == "revealed")
	for raw_group in action_groups.values():
		(raw_group as Node3D).visible = true


func _set_inspect_caption(group: Node3D, caption: String) -> void:
	var label := group.get_node_or_null("InspectButton/ButtonLabel") as Label3D
	if label != null:
		label.text = caption


func _on_card_mouse_entered(card_index: int) -> void:
	_use_cursor("use_pointing")
	if not selection_ready or card_index < 0 or card_index >= card_entries.size():
		return
	var entry: Dictionary = card_entries[card_index]
	if String(entry["state"]) != "available":
		return
	var root := entry["root"] as Node3D
	var hover := create_tween()
	hover.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	hover.tween_property(root, "position:y", CARD_SURFACE_Y + 0.15, 0.14)
	hover.parallel().tween_property(root, "scale", Vector3(1.06, 1.06, 1.06), 0.14)
	_set_card_glow(entry, true)


func _on_card_mouse_exited(card_index: int) -> void:
	_use_cursor("use_normal")
	if card_index < 0 or card_index >= card_entries.size():
		return
	var entry: Dictionary = card_entries[card_index]
	if String(entry["state"]) != "available":
		return
	var root := entry["root"] as Node3D
	var hover := create_tween()
	hover.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	hover.tween_property(root, "position:y", CARD_SURFACE_Y, 0.14)
	hover.parallel().tween_property(root, "scale", Vector3.ONE, 0.14)
	_set_card_glow(entry, false)


func _set_card_glow(entry: Dictionary, enabled: bool) -> void:
	for mesh_key in ["back", "front"]:
		var mesh := entry[mesh_key] as MeshInstance3D
		if mesh != null and mesh.material_override is StandardMaterial3D:
			var material := mesh.material_override as StandardMaterial3D
			material.emission = Color(0.95, 0.67, 0.18, 1.0) if enabled else Color(0.10, 0.055, 0.012, 1.0)
			material.emission_energy_multiplier = 1.10 if enabled else 0.18


func _on_action_mouse_entered(button_root: Node3D) -> void:
	_use_cursor("use_pointing")
	var surface := button_root.get_node_or_null("ButtonSurface") as MeshInstance3D
	if surface != null and surface.material_override is StandardMaterial3D:
		var material := surface.material_override as StandardMaterial3D
		material.emission = Color(1.0, 0.72, 0.22, 1.0)
		material.emission_energy_multiplier = 1.55


func _on_action_mouse_exited(button_root: Node3D) -> void:
	_use_cursor("use_normal")
	var surface := button_root.get_node_or_null("ButtonSurface") as MeshInstance3D
	if surface != null and surface.material_override is StandardMaterial3D:
		var material := surface.material_override as StandardMaterial3D
		material.emission = Color(0.34, 0.18, 0.035, 1.0)
		material.emission_energy_multiplier = 0.70


func _set_card_pickable(entry: Dictionary, pickable: bool) -> void:
	var area := entry["area"] as Area3D
	if area != null:
		area.collision_layer = CARD_PICK_LAYER if pickable else 0
		area.input_ray_pickable = pickable


func _use_cursor(method_name: StringName) -> void:
	var cursors := get_node_or_null("/root/Cursors")
	if cursors != null and cursors.has_method(method_name):
		cursors.call(method_name)


func _cleanup_selection_world() -> void:
	if selection_root != null and is_instance_valid(selection_root):
		selection_root.queue_free()
	selection_root = null
	world_dimmer = null
	card_entries.clear()
	revealed_indices.clear()
	action_groups.clear()
	for viewport in face_viewports:
		if viewport != null and is_instance_valid(viewport):
			viewport.queue_free()
	face_viewports.clear()
