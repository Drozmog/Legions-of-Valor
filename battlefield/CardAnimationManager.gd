class_name CardAnimationManager
extends Node3D

const CARD_3D_SCENE: PackedScene = preload("res://cards/Card3D_Test.tscn")

const PROFILE_DIRECT := &"direct"
const PROFILE_RARE_UNIT := &"rare_unit"
const PROFILE_COMMON_DISCARD := &"common_discard"
const PROFILE_RARE_DISCARD := &"rare_discard"
const PREMIUM_RARITIES := ["rare", "elite", "legendary"]

@export var animation_duration: float = 0.22
@export var arc_height: float = 0.30
@export var start_hover_height: float = 0.18
@export var center_travel_duration: float = 0.24
@export var center_exit_duration: float = 0.22
@export var center_showcase_height: float = 0.72
@export var center_showcase_scale: float = 1.32
@export var common_flash_duration: float = 0.18
@export var premium_flash_duration: float = 0.30


func animate_card_from_anchor_to_node(
	card_data: CardData,
	anchor_name: String,
	target_node: Node,
	face_down: bool = false
) -> void:
	var source_anchor := get_node_or_null(anchor_name) as Node3D

	if source_anchor == null:
		push_warning("Missing animation anchor: " + anchor_name)
		return

	await animate_card_to_position(
		card_data,
		source_anchor.global_position + Vector3(0.0, start_hover_height, 0.0),
		get_exact_landing_position(target_node),
		get_exact_landing_rotation(target_node),
		face_down,
		get_play_animation_profile(card_data, target_node, face_down)
	)


func animate_card_between_nodes(
	card_data: CardData,
	source_node: Node,
	target_node: Node,
	face_down: bool = false
) -> void:
	await animate_card_to_position(
		card_data,
		get_exact_landing_position(source_node) + Vector3(0.0, start_hover_height, 0.0),
		get_exact_landing_position(target_node),
		get_exact_landing_rotation(target_node),
		face_down,
		get_play_animation_profile(card_data, target_node, face_down)
	)


func animate_card_from_position_to_node(
	card_data: CardData,
	start_position: Vector3,
	target_node: Node,
	face_down: bool = false
) -> void:
	await animate_card_to_position(
		card_data,
		start_position,
		get_exact_landing_position(target_node),
		get_exact_landing_rotation(target_node),
		face_down,
		get_play_animation_profile(card_data, target_node, face_down)
	)


func animate_card_to_position(
	card_data: CardData,
	start_position: Vector3,
	end_position: Vector3,
	end_rotation: Vector3,
	face_down: bool = false,
	profile: StringName = &""
) -> void:
	if card_data == null:
		return
	var resolved_profile := profile if profile != &"" else PROFILE_DIRECT
	if resolved_profile == PROFILE_DIRECT:
		await animate_direct_card_to_position(card_data, start_position, end_position, end_rotation, face_down)
	else:
		await animate_showcase_card_to_position(card_data, start_position, end_position, end_rotation, face_down, resolved_profile)


func animate_direct_card_to_position(
	card_data: CardData,
	start_position: Vector3,
	end_position: Vector3,
	end_rotation: Vector3,
	face_down: bool = false
) -> void:
	var animated_card := create_animated_card(card_data, start_position, end_rotation, face_down)
	if animated_card == null:
		return

	var control := (start_position + end_position) / 2.0
	control.y += arc_height
	var tween := create_tween()
	tween.tween_method(
		Callable(self, "set_card_arc_position").bind(animated_card, start_position, control, end_position),
		0.0,
		1.0,
		animation_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	finish_and_free_animated_card(animated_card, end_position, end_rotation)


func animate_showcase_card_to_position(
	card_data: CardData,
	start_position: Vector3,
	end_position: Vector3,
	end_rotation: Vector3,
	face_down: bool,
	profile: StringName
) -> void:
	var animated_card := create_animated_card(card_data, start_position, end_rotation, face_down)
	if animated_card == null:
		return

	var base_scale := animated_card.scale
	var center_position := get_showcase_position(start_position, end_position)
	var center_control := (start_position + center_position) / 2.0
	center_control.y += arc_height

	var intro_tween := create_tween()
	intro_tween.tween_method(
		Callable(self, "set_card_arc_position").bind(animated_card, start_position, center_control, center_position),
		0.0,
		1.0,
		center_travel_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro_tween.parallel().tween_property(animated_card, "scale", base_scale * center_showcase_scale, center_travel_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await intro_tween.finished

	if animated_card == null or not is_instance_valid(animated_card):
		return

	animated_card.global_position = center_position
	animated_card.global_rotation = end_rotation
	await play_center_flash(animated_card, profile, center_position, end_rotation)

	if animated_card == null or not is_instance_valid(animated_card):
		return

	var exit_duration := center_exit_duration
	if profile == PROFILE_COMMON_DISCARD or profile == PROFILE_RARE_DISCARD:
		exit_duration = 0.18
	var exit_control := (center_position + end_position) / 2.0
	exit_control.y += arc_height
	var exit_tween := create_tween()
	exit_tween.tween_method(
		Callable(self, "set_card_arc_position").bind(animated_card, center_position, exit_control, end_position),
		0.0,
		1.0,
		exit_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	exit_tween.parallel().tween_property(animated_card, "scale", base_scale, exit_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await exit_tween.finished
	finish_and_free_animated_card(animated_card, end_position, end_rotation)


func create_animated_card(card_data: CardData, start_position: Vector3, end_rotation: Vector3, face_down: bool) -> Node3D:
	var animated_card := CARD_3D_SCENE.instantiate() as Node3D
	add_child(animated_card)
	animated_card.top_level = true
	animated_card.global_position = start_position
	animated_card.global_rotation = end_rotation
	if animated_card.has_method("assign_card_data"):
		animated_card.assign_card_data(card_data, face_down)
	return animated_card


func finish_and_free_animated_card(animated_card: Node3D, end_position: Vector3, end_rotation: Vector3) -> void:
	if animated_card != null and is_instance_valid(animated_card):
		animated_card.global_position = end_position
		animated_card.global_rotation = end_rotation
		await get_tree().process_frame
		animated_card.queue_free()


func play_center_flash(animated_card: Node3D, profile: StringName, center_position: Vector3, center_rotation: Vector3) -> void:
	var premium := profile == PROFILE_RARE_UNIT or profile == PROFILE_RARE_DISCARD
	var effect_time := premium_flash_duration if premium else common_flash_duration
	var flash_color := Color(1.0, 0.76, 0.18, 0.52) if premium else Color(0.82, 0.94, 1.0, 0.40)
	var glow_color := Color(1.0, 0.60, 0.12, 0.30) if premium else Color(0.55, 0.78, 1.0, 0.22)
	var sparkle_color := Color(1.0, 0.86, 0.25, 0.95) if premium else Color(0.88, 0.96, 1.0, 0.78)

	var effect_root := Node3D.new()
	effect_root.name = "CardPlayCenterVFX"
	add_child(effect_root)
	effect_root.top_level = true
	effect_root.global_position = center_position
	effect_root.global_rotation = center_rotation

	var flash := create_vfx_plane("FlashPop", 1.95 if premium else 1.55, flash_color)
	flash.position.y = 0.055
	effect_root.add_child(flash)
	var glow := create_vfx_plane("GlowRing", 2.45 if premium else 1.95, glow_color)
	glow.position.y = 0.035
	glow.scale = Vector3(0.68, 0.68, 0.68)
	effect_root.add_child(glow)
	var particles := create_spark_particles(sparkle_color, premium)
	particles.position.y = 0.10
	effect_root.add_child(particles)
	particles.emitting = true

	var shine := create_vfx_plane("CardShineSweep", 0.18 if premium else 0.11, Color(sparkle_color.r, sparkle_color.g, sparkle_color.b, 0.45 if premium else 0.30), 1.65)
	animated_card.add_child(shine)
	shine.position = Vector3(-0.68, 0.075, 0.0)

	var original_scale := animated_card.scale
	var pop_scale := original_scale * (1.13 if premium else 1.07)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(animated_card, "scale", pop_scale, effect_time * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "scale", Vector3(1.58, 1.58, 1.58), effect_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "scale", Vector3(1.36, 1.36, 1.36), effect_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(shine, "position:x", 0.68, effect_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	if animated_card != null and is_instance_valid(animated_card):
		var settle_tween := create_tween()
		settle_tween.tween_property(animated_card, "scale", original_scale, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await settle_tween.finished
	if shine != null and is_instance_valid(shine):
		shine.queue_free()
	if effect_root != null and is_instance_valid(effect_root):
		effect_root.queue_free()


func create_vfx_plane(name: String, width: float, color: Color, depth: float = -1.0) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(width, width if depth < 0.0 else depth)
	var plane := MeshInstance3D.new()
	plane.name = name
	plane.mesh = mesh
	plane.material_override = create_vfx_material(color)
	return plane


func create_vfx_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.no_depth_test = true
	return mat


func create_spark_particles(color: Color, premium: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "Sparkles"
	particles.amount = 42 if premium else 16
	particles.lifetime = premium_flash_duration if premium else common_flash_duration
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.direction = Vector3.UP
	particles.spread = 135.0 if premium else 95.0
	particles.gravity = Vector3(0.0, -0.35, 0.0)
	particles.initial_velocity_min = 0.55 if premium else 0.30
	particles.initial_velocity_max = 1.15 if premium else 0.70
	particles.scale_amount_min = 0.018 if premium else 0.012
	particles.scale_amount_max = 0.035 if premium else 0.022
	particles.color = color
	return particles


func get_play_animation_profile(card_data: CardData, target_node: Node, face_down: bool) -> StringName:
	if card_data == null or face_down:
		return PROFILE_DIRECT
	var premium := PREMIUM_RARITIES.has(card_data.rarity.to_lower().strip_edges())
	var card_type := card_data.card_type.to_lower().strip_edges()
	if is_discard_target(target_node):
		return PROFILE_RARE_DISCARD if premium else PROFILE_COMMON_DISCARD
	if card_type == "unit" and premium:
		return PROFILE_RARE_UNIT
	return PROFILE_DIRECT


func is_discard_target(target_node: Node) -> bool:
	var node := target_node
	while node != null:
		if node is DiscardPile:
			return true
		if String(node.name).to_lower().contains("discard"):
			return true
		node = node.get_parent()
	return false


func get_showcase_position(start_position: Vector3, end_position: Vector3) -> Vector3:
	var fallback := (start_position + end_position) / 2.0
	fallback.y += center_showcase_height
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return fallback
	var viewport_size := get_viewport().get_visible_rect().size
	var midpoint := (start_position + end_position) / 2.0
	var depth := clampf(camera.global_position.distance_to(midpoint), 2.75, 7.5)
	var projected := camera.project_position(viewport_size * 0.5, depth)
	projected.y = maxf(projected.y, fallback.y)
	return projected


func set_card_arc_position(
	t: float,
	card_node: Node3D,
	start: Vector3,
	control: Vector3,
	finish: Vector3
) -> void:
	if card_node == null:
		return

	if not is_instance_valid(card_node):
		return

	var a := start.lerp(control, t)
	var b := control.lerp(finish, t)

	card_node.global_position = a.lerp(b, t)


func get_exact_landing_position(target_node: Node) -> Vector3:
	var landing_anchor := get_landing_anchor(target_node)

	if landing_anchor != null:
		return landing_anchor.global_position

	if target_node is Node3D:
		return (target_node as Node3D).global_position

	if target_node != null and target_node.get_parent() is Node3D:
		return (target_node.get_parent() as Node3D).global_position

	return global_position


func get_exact_landing_rotation(target_node: Node) -> Vector3:
	var landing_anchor := get_landing_anchor(target_node)

	if landing_anchor != null:
		return landing_anchor.global_rotation

	if target_node is Node3D:
		return (target_node as Node3D).global_rotation

	if target_node != null and target_node.get_parent() is Node3D:
		return (target_node.get_parent() as Node3D).global_rotation

	return Vector3.ZERO


func get_landing_anchor(target_node: Node) -> Node3D:
	if target_node == null:
		return null

	if target_node is Node3D:
		var direct_anchor := find_named_landing_anchor(target_node)

		if direct_anchor != null:
			return direct_anchor

	return null


func find_named_landing_anchor(root: Node) -> Node3D:
	var possible_names: Array[String] = [
		"SnapPoint",
		"CardSnapPoint",
		"CardAnchor",
		"CardMount",
		"CardPosition",
		"PlacementPoint",
		"PlacePoint"
	]

	for anchor_name in possible_names:
		var found := root.get_node_or_null(anchor_name)

		if found != null and found is Node3D:
			return found as Node3D

	for child in root.get_children():
		if child is Node3D:
			var child_name := String(child.name).to_lower()

			if child_name.contains("snap") or child_name.contains("anchor") or child_name.contains("mount") or child_name.contains("place"):
				return child as Node3D

	return null
