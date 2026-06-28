class_name CardAnimationManager
extends Node3D

const CARD_3D_SCENE: PackedScene = preload("res://cards/Card3D_Test.tscn")

const COMMON_UNIT_DIRECT: StringName = &"COMMON_UNIT_DIRECT"
const RARE_UNIT_3D_SHOWCASE: StringName = &"RARE_UNIT_3D_SHOWCASE"
const COMMON_ACTION_3D_FLASH_DISCARD: StringName = &"COMMON_ACTION_3D_FLASH_DISCARD"
const RARE_ACTION_3D_GOLDEN_DISCARD: StringName = &"RARE_ACTION_3D_GOLDEN_DISCARD"

const ACTION_CARD_TYPES: Array[String] = ["spell", "gambit", "ruse", "trap", "battleplan"]

@export_group("Movement Timing")
@export_range(0.12, 0.40, 0.01) var direct_duration: float = 0.22
@export_range(0.16, 0.50, 0.01) var showcase_move_duration: float = 0.29
@export_range(0.12, 0.45, 0.01) var showcase_effect_duration: float = 0.30
@export_range(0.16, 0.45, 0.01) var destination_move_duration: float = 0.27
@export_range(0.0, 0.20, 0.01) var landing_settle_duration: float = 0.06

@export_group("Movement Shape")
@export_range(0.0, 0.80, 0.01) var arc_height: float = 0.30
@export_range(0.0, 0.40, 0.01) var destination_arc_height: float = 0.14
@export_range(0.0, 0.40, 0.01) var start_hover_height: float = 0.18

@export_group("3D Showcase")
@export_range(1.5, 6.0, 0.05) var showcase_camera_distance: float = 3.15
@export_range(1.0, 1.5, 0.01) var showcase_scale: float = 1.18
@export_range(1.0, 1.12, 0.005) var showcase_pop_scale: float = 1.035

@export_group("Showcase VFX")
@export_range(0.05, 0.30, 0.01) var shine_width: float = 0.10
@export_range(0.5, 1.0, 0.01) var shine_height: float = 0.90
@export_range(0.1, 1.0, 0.05) var normal_vfx_intensity: float = 0.45
@export_range(0.1, 1.5, 0.05) var premium_vfx_intensity: float = 0.78
@export_range(0, 8, 1) var premium_spark_count: int = 5
@export_range(0, 4, 1) var normal_spark_count: int = 2


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
	await animate_card_play_3d(
		card_data,
		source_anchor.global_position + Vector3(0.0, start_hover_height, 0.0),
		target_node,
		face_down
	)


func animate_card_between_nodes(
	card_data: CardData,
	source_node: Node,
	target_node: Node,
	face_down: bool = false
) -> void:
	await animate_card_play_3d(
		card_data,
		get_exact_landing_position(source_node) + Vector3(0.0, start_hover_height, 0.0),
		target_node,
		face_down
	)


func animate_card_from_position_to_node(
	card_data: CardData,
	start_position: Vector3,
	target_node: Node,
	face_down: bool = false
) -> void:
	await animate_card_play_3d(card_data, start_position, target_node, face_down)


func animate_card_play_3d(
	card_data: CardData,
	start_position: Vector3,
	target_node: Node,
	face_down: bool = false
) -> void:
	if card_data == null:
		return
	var end_position := get_exact_landing_position(target_node)
	var end_rotation := get_exact_landing_rotation(target_node)
	var profile := get_play_animation_profile(card_data, target_node, face_down)
	if profile == COMMON_UNIT_DIRECT:
		await animate_card_direct_3d(card_data, start_position, end_position, end_rotation, face_down)
	else:
		await animate_card_showcase_3d(
			card_data,
			start_position,
			end_position,
			end_rotation,
			face_down,
			profile
		)


# Compatibility entry point for callers that only have a raw destination transform.
func animate_card_to_position(
	card_data: CardData,
	start_position: Vector3,
	end_position: Vector3,
	end_rotation: Vector3,
	face_down: bool = false
) -> void:
	await animate_card_direct_3d(card_data, start_position, end_position, end_rotation, face_down)


func get_play_animation_profile(card_data: CardData, target_node: Node, face_down: bool) -> StringName:
	if card_data == null or face_down:
		return COMMON_UNIT_DIRECT
	var card_type := card_data.card_type.to_lower().strip_edges()
	var premium := card_data.is_premium_rarity()
	if card_type == "unit" and is_board_slot_target(target_node):
		return RARE_UNIT_3D_SHOWCASE if premium else COMMON_UNIT_DIRECT
	if ACTION_CARD_TYPES.has(card_type) and is_discard_target(target_node):
		return RARE_ACTION_3D_GOLDEN_DISCARD if premium else COMMON_ACTION_3D_FLASH_DISCARD
	return COMMON_UNIT_DIRECT


func animate_card_direct_3d(
	card_data: CardData,
	start_position: Vector3,
	end_position: Vector3,
	end_rotation: Vector3,
	face_down: bool = false
) -> void:
	var animated_card := create_animated_card(card_data, start_position, end_rotation, face_down)
	if animated_card == null:
		return
	var control := (start_position + end_position) * 0.5 + Vector3.UP * arc_height
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		Callable(self, "set_card_arc_position").bind(animated_card, start_position, control, end_position),
		0.0,
		1.0,
		direct_duration
	)
	await tween.finished
	if is_instance_valid(animated_card):
		animated_card.global_position = end_position
		animated_card.global_rotation = end_rotation
		animated_card.free()


func animate_card_showcase_3d(
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
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		animated_card.free()
		await animate_card_direct_3d(card_data, start_position, end_position, end_rotation, face_down)
		return
	var start_transform := animated_card.global_transform
	var showcase_transform := get_camera_showcase_transform(animated_card, camera)
	await tween_card_transform(animated_card, start_transform, showcase_transform, showcase_move_duration, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	face_card_to_camera(animated_card, camera)
	await play_card_showcase_flash_3d(animated_card, profile)
	var destination_basis := Basis.from_euler(end_rotation)
	var destination_transform := Transform3D(destination_basis, end_position)
	await tween_card_to_destination(animated_card, animated_card.global_transform, destination_transform)
	if landing_settle_duration > 0.0:
		var settle := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		settle.tween_property(animated_card, "scale", Vector3.ONE * 1.018, landing_settle_duration * 0.45)
		settle.tween_property(animated_card, "scale", Vector3.ONE, landing_settle_duration * 0.55)
		await settle.finished
	if is_instance_valid(animated_card):
		animated_card.global_transform = destination_transform
		animated_card.free()


func get_camera_showcase_transform(card_node: Node3D, camera: Camera3D) -> Transform3D:
	var viewport_center := get_viewport().get_visible_rect().size * 0.5
	var position := camera.project_position(viewport_center, showcase_camera_distance)
	var normal := (camera.global_position - position).normalized()
	var screen_up := camera.global_basis.y
	var card_top := screen_up - normal * screen_up.dot(normal)
	if card_top.length_squared() < 0.0001:
		card_top = Vector3.FORWARD
	card_top = card_top.normalized()
	var z_axis := -card_top
	var x_axis := normal.cross(z_axis).normalized()
	var basis := Basis(x_axis, normal, z_axis).orthonormalized()
	basis = basis.scaled(Vector3.ONE * showcase_scale)
	return Transform3D(basis, position)


func face_card_to_camera(card_node: Node3D, camera: Camera3D) -> void:
	if card_node == null or camera == null:
		return
	var current_scale := card_node.scale
	var target := get_camera_showcase_transform(card_node, camera)
	card_node.global_basis = target.basis.orthonormalized().scaled(current_scale)


func play_card_showcase_flash_3d(card_node: Node3D, profile: StringName) -> void:
	if card_node == null:
		return
	var premium := profile == RARE_UNIT_3D_SHOWCASE or profile == RARE_ACTION_3D_GOLDEN_DISCARD
	var effect_color := Color(1.0, 0.78, 0.30, 1.0) if premium else Color(0.78, 0.91, 1.0, 1.0)
	var intensity := premium_vfx_intensity if premium else normal_vfx_intensity
	var shine := play_card_shine_sweep_3d(card_node, premium, effect_color, intensity)
	var sparks := create_controlled_spark_accent_3d(card_node, premium, effect_color, intensity)
	var base_scale := card_node.scale
	var pulse := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(card_node, "scale", base_scale * showcase_pop_scale, showcase_effect_duration * 0.42)
	pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(card_node, "scale", base_scale, showcase_effect_duration * 0.58)
	await get_tree().create_timer(showcase_effect_duration).timeout
	if shine != null and is_instance_valid(shine):
		shine.queue_free()
	for spark in sparks:
		if spark != null and is_instance_valid(spark):
			spark.queue_free()


func play_card_shine_sweep_3d(
	card_node: Node3D,
	_premium: bool,
	color: Color,
	intensity: float
) -> MeshInstance3D:
	var shine := MeshInstance3D.new()
	shine.name = "ShowcaseShineSweep"
	var plane := PlaneMesh.new()
	plane.size = Vector2(shine_width, shine_height)
	shine.mesh = plane
	shine.position = Vector3(-0.54, 0.045, 0.0)
	shine.rotation_degrees.y = -10.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.albedo_color = Color(color.r, color.g, color.b, 0.0)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.3 + intensity
	shine.material_override = material
	card_node.add_child(shine)
	var sweep := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sweep.tween_method(Callable(self, "set_vfx_alpha").bind(material, color), 0.0, intensity * 0.72, showcase_effect_duration * 0.22)
	sweep.parallel().tween_property(shine, "position:x", 0.54, showcase_effect_duration * 0.78)
	sweep.tween_method(Callable(self, "set_vfx_alpha").bind(material, color), intensity * 0.72, 0.0, showcase_effect_duration * 0.22)
	return shine


func create_controlled_spark_accent_3d(
	card_node: Node3D,
	premium: bool,
	color: Color,
	intensity: float
) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var count := premium_spark_count if premium else normal_spark_count
	var positions := [
		Vector3(-0.43, 0.075, -0.52),
		Vector3(0.42, 0.075, -0.34),
		Vector3(-0.38, 0.075, 0.42),
		Vector3(0.44, 0.075, 0.52),
		Vector3(0.05, 0.075, -0.60),
		Vector3(-0.08, 0.075, 0.58),
	]
	for index in range(mini(count, positions.size())):
		var spark := MeshInstance3D.new()
		spark.name = "ShowcaseSpark" + str(index)
		var sphere := SphereMesh.new()
		sphere.radius = 0.018 if premium else 0.014
		sphere.height = sphere.radius * 2.0
		spark.mesh = sphere
		spark.position = positions[index]
		spark.scale = Vector3.ZERO
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.no_depth_test = true
		material.albedo_color = Color(color.r, color.g, color.b, 0.92)
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.6 + intensity
		spark.material_override = material
		card_node.add_child(spark)
		result.append(spark)
		var delay := float(index) * 0.025
		var sparkle := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		sparkle.tween_interval(delay)
		sparkle.tween_property(spark, "scale", Vector3.ONE * (0.9 + intensity * 0.35), showcase_effect_duration * 0.28)
		sparkle.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		sparkle.tween_property(spark, "scale", Vector3.ZERO, showcase_effect_duration * 0.34)
	return result


func create_animated_card(
	card_data: CardData,
	start_position: Vector3,
	start_rotation: Vector3,
	face_down: bool
) -> Node3D:
	var animated_card := CARD_3D_SCENE.instantiate() as Node3D
	if animated_card == null:
		return null
	add_child(animated_card)
	animated_card.top_level = true
	animated_card.global_position = start_position
	animated_card.global_rotation = start_rotation
	if animated_card.has_method("assign_card_data"):
		animated_card.call("assign_card_data", card_data, face_down)
	disable_animation_collisions(animated_card)
	return animated_card


func tween_card_transform(
	card_node: Node3D,
	start: Transform3D,
	finish: Transform3D,
	duration: float,
	transition: Tween.TransitionType,
	easing: Tween.EaseType
) -> void:
	var tween := create_tween().set_trans(transition).set_ease(easing)
	tween.tween_method(Callable(self, "set_interpolated_transform").bind(card_node, start, finish), 0.0, 1.0, duration)
	await tween.finished


func tween_card_to_destination(card_node: Node3D, start: Transform3D, finish: Transform3D) -> void:
	var control := (start.origin + finish.origin) * 0.5 + Vector3.UP * destination_arc_height
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		Callable(self, "set_interpolated_arc_transform").bind(card_node, start, finish, control),
		0.0,
		1.0,
		destination_move_duration
	)
	await tween.finished


func set_interpolated_transform(t: float, card_node: Node3D, start: Transform3D, finish: Transform3D) -> void:
	if card_node != null and is_instance_valid(card_node):
		card_node.global_transform = start.interpolate_with(finish, t)


func set_interpolated_arc_transform(
	t: float,
	card_node: Node3D,
	start: Transform3D,
	finish: Transform3D,
	control: Vector3
) -> void:
	if card_node == null or not is_instance_valid(card_node):
		return
	var transform := start.interpolate_with(finish, t)
	var a := start.origin.lerp(control, t)
	var b := control.lerp(finish.origin, t)
	transform.origin = a.lerp(b, t)
	card_node.global_transform = transform


func set_card_arc_position(
	t: float,
	card_node: Node3D,
	start: Vector3,
	control: Vector3,
	finish: Vector3
) -> void:
	if card_node == null or not is_instance_valid(card_node):
		return
	var a := start.lerp(control, t)
	var b := control.lerp(finish, t)
	card_node.global_position = a.lerp(b, t)


func set_vfx_alpha(alpha: float, material: StandardMaterial3D, color: Color) -> void:
	if material != null:
		material.albedo_color = Color(color.r, color.g, color.b, alpha)


func disable_animation_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		var collision := node as CollisionObject3D
		collision.collision_layer = 0
		collision.collision_mask = 0
	for child in node.get_children():
		disable_animation_collisions(child)


func is_board_slot_target(target_node: Node) -> bool:
	return target_node != null and target_node.has_meta("row") and target_node.has_meta("owner")


func is_discard_target(target_node: Node) -> bool:
	var current := target_node
	while current != null:
		if current is DiscardPile or String(current.name).to_lower().contains("discard"):
			return true
		current = current.get_parent()
	return false


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
	if target_node is Node3D:
		return find_named_landing_anchor(target_node)
	return null


func find_named_landing_anchor(root: Node) -> Node3D:
	var possible_names: Array[String] = [
		"SnapPoint", "CardSnapPoint", "CardAnchor", "CardMount",
		"CardPosition", "PlacementPoint", "PlacePoint", "CardPoint"
	]
	for anchor_name in possible_names:
		var found := root.get_node_or_null(anchor_name)
		if found is Node3D:
			return found as Node3D
	for child in root.get_children():
		if child is Node3D:
			var child_name := String(child.name).to_lower()
			if child_name.contains("snap") or child_name.contains("anchor") or child_name.contains("mount") or child_name.contains("place") or child_name == "cardpoint":
				return child as Node3D
	return null
