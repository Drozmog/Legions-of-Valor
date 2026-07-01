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
@export_range(0.20, 0.90, 0.01) var premium_unit_reveal_duration: float = 0.58
@export_range(0.12, 0.50, 0.01) var common_action_flash_duration: float = 0.24
@export_range(0.20, 0.90, 0.01) var premium_action_flash_duration: float = 0.50
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
@export_range(0.75, 1.0, 0.01) var shine_height: float = 0.96
@export_range(0.1, 1.0, 0.05) var normal_vfx_intensity: float = 0.45
@export_range(0.1, 1.5, 0.05) var premium_vfx_intensity: float = 0.78
@export_range(0, 8, 1) var premium_spark_count: int = 5
@export_range(0, 4, 1) var normal_spark_count: int = 2
@export_range(0.12, 0.40, 0.01) var vaporize_duration: float = 0.24
@export_range(0.12, 0.40, 0.01) var reform_duration: float = 0.22


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


func animate_card_reveal_between_nodes(
	card_data: CardData,
	source_node: Node,
	target_node: Node,
	face_down: bool = false,
	hold_seconds: float = 0.95
) -> void:
	if card_data == null or source_node == null or target_node == null:
		return
	var start_position := get_exact_landing_position(source_node) + Vector3(0.0, start_hover_height, 0.0)
	var end_position := get_exact_landing_position(target_node)
	var end_rotation := get_exact_landing_rotation(target_node)
	var animated_card := create_animated_card(card_data, start_position, end_rotation, face_down)
	if animated_card == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		animated_card.free()
		await animate_card_direct_3d(card_data, start_position, end_position, end_rotation, face_down)
		return
	var showcase_transform := get_camera_showcase_transform(animated_card, camera)
	await tween_card_transform(animated_card, animated_card.global_transform, showcase_transform, 0.55, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	face_card_to_camera(animated_card, camera)
	await get_tree().create_timer(maxf(hold_seconds, 0.75)).timeout
	var destination := Transform3D(Basis.from_euler(end_rotation), end_position)
	await tween_card_transform(animated_card, animated_card.global_transform, destination, 0.55, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	if is_instance_valid(animated_card):
		animated_card.global_transform = destination
		animated_card.free()


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
	var action_profile := profile == COMMON_ACTION_3D_FLASH_DISCARD or profile == RARE_ACTION_3D_GOLDEN_DISCARD
	if action_profile:
		await vaporize_card_to_destination_3d(animated_card, destination_transform, profile == RARE_ACTION_3D_GOLDEN_DISCARD)
	else:
		await tween_card_to_destination(animated_card, animated_card.global_transform, destination_transform)
	if not action_profile and landing_settle_duration > 0.0:
		var settle := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		settle.tween_property(animated_card, "scale", Vector3.ONE * 1.018, landing_settle_duration * 0.45)
		settle.tween_property(animated_card, "scale", Vector3.ONE, landing_settle_duration * 0.55)
		await settle.finished
	if is_instance_valid(animated_card):
		animated_card.global_transform = destination_transform
		animated_card.free()


func vaporize_card_to_destination_3d(card_node: Node3D, destination: Transform3D, premium: bool) -> void:
	if card_node == null:
		return
	var vapor_color := Color(1.0, 0.76, 0.28, 1.0) if premium else Color(0.72, 0.88, 1.0, 1.0)
	ensure_card_alpha_material(card_node)
	play_vapor_motes_3d(card_node, vapor_color, premium, false)
	var vanish_start := card_node.global_transform
	var vanish_finish := vanish_start
	vanish_finish.basis = vanish_finish.basis.scaled(Vector3.ONE * 0.88)
	var vanish := create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	vanish.tween_method(Callable(self, "set_card_surface_alpha").bind(card_node), 1.0, 0.0, vaporize_duration)
	vanish.parallel().tween_method(Callable(self, "set_interpolated_transform").bind(card_node, vanish_start, vanish_finish), 0.0, 1.0, vaporize_duration)
	await vanish.finished
	var reform_start := destination
	reform_start.basis = reform_start.basis.scaled(Vector3.ONE * 0.88)
	card_node.global_transform = reform_start
	set_card_surface_alpha(0.0, card_node)
	play_vapor_motes_3d(card_node, vapor_color, premium, true)
	var reform := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reform.tween_method(Callable(self, "set_card_surface_alpha").bind(card_node), 0.0, 1.0, reform_duration)
	reform.parallel().tween_method(Callable(self, "set_interpolated_transform").bind(card_node, reform_start, destination), 0.0, 1.0, reform_duration)
	await reform.finished
	card_node.global_transform = destination
	set_card_surface_alpha(1.0, card_node)


func play_vapor_motes_3d(card_node: Node3D, color: Color, premium: bool, reforming: bool) -> void:
	var positions := [
		Vector3(-0.38, 0.075, -0.48), Vector3(0.34, 0.075, -0.42),
		Vector3(-0.43, 0.075, 0.05), Vector3(0.41, 0.075, 0.16),
		Vector3(-0.25, 0.075, 0.49), Vector3(0.28, 0.075, 0.52),
		Vector3(0.02, 0.075, -0.12),
	]
	var mote_count := 7 if premium else 5
	var motes: Array[MeshInstance3D] = []
	for index in range(mote_count):
		var mote := MeshInstance3D.new()
		mote.name = "VaporMote" + str(index)
		var plane := PlaneMesh.new()
		plane.size = Vector2(0.18 if premium else 0.14, 0.24 if premium else 0.19)
		mote.mesh = plane
		var base_position: Vector3 = positions[index]
		var direction := Vector3(base_position.x, 0.0, base_position.z).normalized()
		var spread := direction * (0.13 + float(index % 3) * 0.025)
		mote.position = base_position + spread if reforming else base_position
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;

uniform vec4 vapor_color : source_color;
uniform float vapor_strength = 0.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	p.x += sin(p.y * 4.0) * 0.10;
	float body = exp(-(p.x * p.x * 5.5 + p.y * p.y * 2.7));
	float inner = exp(-(p.x * p.x * 15.0 + p.y * p.y * 6.0));
	float alpha = (body * 0.32 + inner * 0.42) * vapor_strength;
	ALBEDO = vapor_color.rgb;
	EMISSION = vapor_color.rgb * (0.8 + inner);
	ALPHA = alpha;
}
"""
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("vapor_color", color)
		material.set_shader_parameter("vapor_strength", 0.0)
		mote.material_override = material
		card_node.add_child(mote)
		motes.append(mote)
		var finish_position := base_position if reforming else base_position + spread
		var duration := reform_duration if reforming else vaporize_duration
		var drift := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(mote, "position", finish_position, duration)
		var fade := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fade.tween_property(material, "shader_parameter/vapor_strength", 0.78 if premium else 0.55, duration * 0.38)
		fade.tween_property(material, "shader_parameter/vapor_strength", 0.0, duration * 0.62)
	await get_tree().create_timer(reform_duration if reforming else vaporize_duration).timeout
	for mote in motes:
		if mote != null and is_instance_valid(mote):
			mote.queue_free()


func ensure_card_alpha_material(card_node: Node3D) -> void:
	var body := card_node.get_node_or_null("CardBody") as MeshInstance3D
	if body == null or bool(body.get_meta("vapor_alpha_ready", false)):
		return
	if body.material_override is StandardMaterial3D:
		var material := (body.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		body.material_override = material
		body.set_meta("vapor_alpha_ready", true)


func set_card_surface_alpha(alpha: float, card_node: Node3D) -> void:
	if card_node == null or not is_instance_valid(card_node):
		return
	var body := card_node.get_node_or_null("CardBody") as MeshInstance3D
	if body != null and body.material_override is StandardMaterial3D:
		var material := body.material_override as StandardMaterial3D
		var color := material.albedo_color
		color.a = alpha
		material.albedo_color = color
	var fallback := card_node.get_node_or_null("FallbackLabel") as Label3D
	if fallback != null:
		var label_color := fallback.modulate
		label_color.a = alpha
		fallback.modulate = label_color


func get_camera_showcase_transform(_card_node: Node3D, camera: Camera3D) -> Transform3D:
	var viewport_center := get_viewport().get_visible_rect().size * 0.5
	var showcase_position := camera.project_position(viewport_center, showcase_camera_distance)
	var normal := (camera.global_position - showcase_position).normalized()
	var screen_up := camera.global_basis.y
	var card_top := screen_up - normal * screen_up.dot(normal)
	if card_top.length_squared() < 0.0001:
		card_top = Vector3.FORWARD
	card_top = card_top.normalized()
	var z_axis := -card_top
	var x_axis := normal.cross(z_axis).normalized()
	var showcase_basis := Basis(x_axis, normal, z_axis).orthonormalized()
	showcase_basis = showcase_basis.scaled(Vector3.ONE * showcase_scale)
	return Transform3D(showcase_basis, showcase_position)


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
	var action_profile := profile == COMMON_ACTION_3D_FLASH_DISCARD or profile == RARE_ACTION_3D_GOLDEN_DISCARD
	var effect_color := Color(1.0, 0.78, 0.30, 1.0) if premium else Color(0.78, 0.91, 1.0, 1.0)
	var intensity := premium_vfx_intensity if premium else normal_vfx_intensity
	var effect_duration := get_profile_effect_duration(profile)
	var edge_glow := create_card_edge_glow_3d(card_node, effect_color, intensity, effect_duration)
	var shine := play_card_shine_sweep_3d(card_node, premium, effect_color, intensity, effect_duration)
	var sparks := create_controlled_spark_accent_3d(card_node, premium, effect_color, intensity, effect_duration)
	var halo: MeshInstance3D = null
	var bloom: MeshInstance3D = null
	if profile == RARE_UNIT_3D_SHOWCASE:
		halo = create_premium_halo_ring_3d(card_node, effect_color, intensity, effect_duration)
	if action_profile:
		bloom = create_action_flash_bloom_3d(card_node, effect_color, intensity, effect_duration, premium)
	var base_scale := card_node.scale
	var pulse := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(card_node, "scale", base_scale * showcase_pop_scale, effect_duration * 0.42)
	pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(card_node, "scale", base_scale, effect_duration * 0.58)
	await get_tree().create_timer(effect_duration).timeout
	if shine != null and is_instance_valid(shine):
		shine.queue_free()
	if edge_glow != null and is_instance_valid(edge_glow):
		edge_glow.queue_free()
	if halo != null and is_instance_valid(halo):
		halo.queue_free()
	if bloom != null and is_instance_valid(bloom):
		bloom.queue_free()
	for spark in sparks:
		if spark != null and is_instance_valid(spark):
			spark.queue_free()


func get_profile_effect_duration(profile: StringName) -> float:
	match profile:
		RARE_UNIT_3D_SHOWCASE:
			return premium_unit_reveal_duration
		COMMON_ACTION_3D_FLASH_DISCARD:
			return common_action_flash_duration
		RARE_ACTION_3D_GOLDEN_DISCARD:
			return premium_action_flash_duration
	return showcase_effect_duration


func play_card_shine_sweep_3d(
	card_node: Node3D,
	_premium: bool,
	color: Color,
	intensity: float,
	effect_duration: float
) -> MeshInstance3D:
	var shine := MeshInstance3D.new()
	shine.name = "ShowcaseShineSweep"
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.98, 1.28 * shine_height)
	shine.mesh = plane
	shine.position = Vector3(0.0, 0.052, 0.0)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;

uniform vec4 shine_color : source_color;
uniform float sweep_progress = -0.25;
uniform float band_width = 0.10;
uniform float strength = 0.5;

float rounded_card_mask(vec2 uv) {
	vec2 q = abs(uv - vec2(0.5)) - vec2(0.455, 0.465);
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 0.035;
	return 1.0 - smoothstep(-0.008, 0.010, d);
}

void fragment() {
	float diagonal = UV.x + UV.y * 0.28;
	float center = mix(-0.30, 1.58, sweep_progress);
	float distance_to_band = abs(diagonal - center);
	float band = exp(-pow(distance_to_band / max(band_width, 0.01), 2.0) * 2.6);
	float core = exp(-pow(distance_to_band / max(band_width * 0.28, 0.005), 2.0) * 1.8);
	float mask = rounded_card_mask(UV);
	float alpha = (band * 0.32 + core * 0.70) * mask * strength;
	ALBEDO = shine_color.rgb;
	EMISSION = shine_color.rgb * (1.15 + core * 1.4);
	ALPHA = alpha;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("shine_color", color)
	material.set_shader_parameter("sweep_progress", -0.25)
	material.set_shader_parameter("band_width", shine_width)
	material.set_shader_parameter("strength", intensity)
	shine.material_override = material
	card_node.add_child(shine)
	var sweep := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sweep.tween_property(material, "shader_parameter/sweep_progress", 1.0, effect_duration * 0.88)
	return shine


func create_card_edge_glow_3d(card_node: Node3D, color: Color, intensity: float, effect_duration: float) -> MeshInstance3D:
	var glow := MeshInstance3D.new()
	glow.name = "ShowcaseEdgeGlow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.10, 1.44)
	glow.mesh = plane
	glow.position = Vector3(0.0, 0.040, 0.0)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;

uniform vec4 glow_color : source_color;
uniform float glow_strength = 0.0;

void fragment() {
	vec2 q = abs(UV - vec2(0.5)) - vec2(0.425, 0.445);
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 0.045;
	float fine_ring = 1.0 - smoothstep(0.010, 0.032, abs(d));
	float soft_ring = 1.0 - smoothstep(0.025, 0.090, abs(d));
	float alpha = (fine_ring * 0.52 + soft_ring * 0.18) * glow_strength;
	ALBEDO = glow_color.rgb;
	EMISSION = glow_color.rgb * 1.5;
	ALPHA = alpha;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("glow_color", color)
	material.set_shader_parameter("glow_strength", 0.0)
	glow.material_override = material
	card_node.add_child(glow)
	var pulse := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(material, "shader_parameter/glow_strength", intensity * 0.78, effect_duration * 0.40)
	pulse.tween_property(material, "shader_parameter/glow_strength", 0.0, effect_duration * 0.60)
	return glow


func create_premium_halo_ring_3d(
	card_node: Node3D,
	color: Color,
	intensity: float,
	effect_duration: float
) -> MeshInstance3D:
	var halo := MeshInstance3D.new()
	halo.name = "PremiumRevealHalo"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.52, 1.72)
	halo.mesh = plane
	halo.position = Vector3(0.0, 0.034, 0.0)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;

uniform vec4 halo_color : source_color;
uniform float halo_progress = 0.0;
uniform float halo_strength = 0.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.0, 1.10);
	float radius = length(p);
	float ring_radius = mix(0.24, 0.46, halo_progress);
	float ring = exp(-pow((radius - ring_radius) / 0.018, 2.0) * 1.8);
	float aura = exp(-pow((radius - ring_radius) / 0.065, 2.0) * 1.4);
	float rays = pow(max(0.0, cos(atan(p.y, p.x) * 10.0)), 18.0) * smoothstep(0.50, 0.20, radius);
	float alpha = (ring * 0.72 + aura * 0.18 + rays * 0.10) * halo_strength;
	ALBEDO = halo_color.rgb;
	EMISSION = mix(halo_color.rgb, vec3(1.0), ring * 0.45) * 1.6;
	ALPHA = alpha;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("halo_color", color)
	material.set_shader_parameter("halo_progress", 0.0)
	material.set_shader_parameter("halo_strength", 0.0)
	halo.material_override = material
	card_node.add_child(halo)
	var expand := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	expand.tween_property(material, "shader_parameter/halo_progress", 1.0, effect_duration * 0.82)
	var glow := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow.tween_property(material, "shader_parameter/halo_strength", intensity * 0.82, effect_duration * 0.32)
	glow.tween_property(material, "shader_parameter/halo_strength", 0.0, effect_duration * 0.68)
	return halo


func create_action_flash_bloom_3d(
	card_node: Node3D,
	color: Color,
	intensity: float,
	effect_duration: float,
	premium: bool
) -> MeshInstance3D:
	var bloom := MeshInstance3D.new()
	bloom.name = "ActionCardFlashBloom"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.07, 1.40)
	bloom.mesh = plane
	bloom.position = Vector3(0.0, 0.060, 0.0)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;

uniform vec4 bloom_color : source_color;
uniform float bloom_strength = 0.0;
uniform float premium_mix = 0.0;

float rounded_card_mask(vec2 uv) {
	vec2 q = abs(uv - vec2(0.5)) - vec2(0.445, 0.462);
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 0.038;
	return 1.0 - smoothstep(-0.010, 0.012, d);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.0, 0.78);
	float radial = exp(-dot(p, p) * 5.2);
	float core = exp(-dot(p, p) * 17.0);
	float edge = rounded_card_mask(UV);
	float rays = (exp(-abs(p.x) * 30.0) + exp(-abs(p.y) * 34.0)) * premium_mix * 0.20;
	float alpha = (radial * 0.34 + core * 0.62 + rays) * edge * bloom_strength;
	vec3 white_core = mix(bloom_color.rgb, vec3(1.0), core * 0.72);
	ALBEDO = white_core;
	EMISSION = white_core * (1.25 + core * 1.6);
	ALPHA = alpha;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("bloom_color", color)
	material.set_shader_parameter("bloom_strength", 0.0)
	material.set_shader_parameter("premium_mix", 1.0 if premium else 0.0)
	bloom.material_override = material
	card_node.add_child(bloom)
	var flash := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash.tween_property(material, "shader_parameter/bloom_strength", intensity * (1.08 if premium else 0.86), effect_duration * 0.30)
	flash.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flash.tween_property(material, "shader_parameter/bloom_strength", 0.0, effect_duration * 0.70)
	return bloom


func create_controlled_spark_accent_3d(
	card_node: Node3D,
	premium: bool,
	color: Color,
	intensity: float,
	effect_duration: float
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
		var plane := PlaneMesh.new()
		plane.size = Vector2(0.16 if premium else 0.12, 0.16 if premium else 0.12)
		spark.mesh = plane
		spark.position = positions[index]
		spark.rotation_degrees.y = -20.0 + float(index) * 17.0
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;

uniform vec4 spark_color : source_color;
uniform float spark_strength = 0.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float radius = length(p);
	float core = exp(-radius * radius * 24.0);
	float horizontal = exp(-abs(p.y) * 34.0) * smoothstep(1.0, 0.0, abs(p.x));
	float vertical = exp(-abs(p.x) * 34.0) * smoothstep(1.0, 0.0, abs(p.y));
	float diagonal_a = exp(-abs(p.x - p.y) * 28.0) * smoothstep(0.95, 0.0, radius);
	float diagonal_b = exp(-abs(p.x + p.y) * 28.0) * smoothstep(0.95, 0.0, radius);
	float star = core + (horizontal + vertical) * 0.48 + (diagonal_a + diagonal_b) * 0.16;
	ALBEDO = spark_color.rgb;
	EMISSION = spark_color.rgb * 2.0;
	ALPHA = clamp(star * spark_strength, 0.0, 1.0);
}
"""
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("spark_color", color)
		material.set_shader_parameter("spark_strength", 0.0)
		spark.material_override = material
		card_node.add_child(spark)
		result.append(spark)
		var delay := float(index) * 0.025
		var sparkle := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		sparkle.tween_interval(delay)
		sparkle.tween_property(material, "shader_parameter/spark_strength", 0.82 + intensity * 0.22, effect_duration * 0.24)
		sparkle.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		sparkle.tween_property(material, "shader_parameter/spark_strength", 0.0, effect_duration * 0.34)
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
	var interpolated_transform := start.interpolate_with(finish, t)
	var a := start.origin.lerp(control, t)
	var b := control.lerp(finish.origin, t)
	interpolated_transform.origin = a.lerp(b, t)
	card_node.global_transform = interpolated_transform


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
	if target_node != null and target_node.has_method("get_animation_landing_position"):
		return target_node.call("get_animation_landing_position") as Vector3
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
