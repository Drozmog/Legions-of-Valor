class_name CardInspectPanel
extends PanelContainer

@export var hand: HandUI

@export var display_offset_left: float = -565.0
@export var display_offset_right: float = 30.0
@export var display_offset_top: float = -750.0
@export var display_offset_bottom: float = -45.0

@export var center_on_screen: bool = false
@export var centered_display_size: Vector2 = Vector2(760.0, 1000.0)
@export_range(0.5, 1.0, 0.01) var centered_viewport_limit: float = 0.90

@export var preview_render_scale: float = 3.0

@export var fly_time: float = 0.34
@export var return_time: float = 0.26

@export var max_yaw_degrees: float = 13.0
@export var max_pitch_degrees: float = 9.0
@export var tilt_smoothing: float = 10.0

@export var gloss_strength: float = 0.20
@export var gloss_width: float = 0.18

@export var card_depth: float = 0.035
@export var card_width: float = 2.25
@export var card_height: float = 3.15
@export var card_corner_radius: float = 0.16
@export var card_corner_segments: int = 24

var card_root: Node3D = null

var card_back_mesh: MeshInstance3D = null
var card_back_material: StandardMaterial3D = null

var gloss_mesh: MeshInstance3D = null
var gloss_material: ShaderMaterial = null

var current_tween: Tween = null

var preview_image: TextureRect = null
var preview_viewport: SubViewport = null
var preview_camera: Camera3D = null
var card_mesh: MeshInstance3D = null
var card_material: StandardMaterial3D = null

var last_source_card: CardUI = null
var last_source_rect: Rect2 = Rect2()

var display_rect: Rect2 = Rect2()
var display_center_position: Vector2 = Vector2.ZERO

var is_animating: bool = false
var is_displayed: bool = false
var is_holding_display_card: bool = false

var pending_source_card: CardUI = null
var pending_card_data: CardData = null
var is_switching_cards: bool = false


func _ready() -> void:
	clear_old_preview_children()
	setup_position()
	setup_visuals()
	build_3d_preview()
	auto_find_missing_references()
	connect_signals()

	visible = false
	modulate.a = 0.0
	z_index = 100

	set_process(true)


func clear_old_preview_children() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()


func setup_position() -> void:
	if center_on_screen:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		var centered_rect := get_display_rect()
		global_position = centered_rect.position
		size = centered_rect.size
		return

	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0

	offset_left = display_offset_left
	offset_right = display_offset_right
	offset_top = display_offset_top
	offset_bottom = display_offset_bottom


func setup_visuals() -> void:
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	panel_style.border_width_left = 0
	panel_style.border_width_right = 0
	panel_style.border_width_top = 0
	panel_style.border_width_bottom = 0

	add_theme_stylebox_override("panel", panel_style)


func build_3d_preview() -> void:
	preview_viewport = SubViewport.new()
	preview_viewport.name = "Card3DRenderViewport"
	preview_viewport.own_world_3d = true
	preview_viewport.transparent_bg = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_viewport.msaa_3d = Viewport.MSAA_8X
	preview_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	preview_viewport.size = Vector2i(1800, 2400)
	add_child(preview_viewport)

	var world_root: Node3D = Node3D.new()
	world_root.name = "CardPreviewWorld"
	preview_viewport.add_child(world_root)

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 1.0, 1.0, 1.0)
	env.ambient_light_energy = 0.95

	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	world_root.add_child(world_env)

	preview_camera = Camera3D.new()
	preview_camera.position = Vector3(0.0, 0.0, 6.8)
	preview_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	preview_camera.fov = 30.0
	preview_camera.current = true
	world_root.add_child(preview_camera)

	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.light_energy = 0.42
	key_light.light_color = Color(1.0, 0.98, 0.95)
	key_light.rotation_degrees = Vector3(-58.0, -46.0, 0.0)
	key_light.shadow_enabled = false
	world_root.add_child(key_light)

	var fill_light: DirectionalLight3D = DirectionalLight3D.new()
	fill_light.light_energy = 0.20
	fill_light.light_color = Color(0.95, 0.97, 1.0)
	fill_light.rotation_degrees = Vector3(30.0, 138.0, 0.0)
	fill_light.shadow_enabled = false
	world_root.add_child(fill_light)

	var rim_light: DirectionalLight3D = DirectionalLight3D.new()
	rim_light.light_energy = 0.14
	rim_light.light_color = Color(1.0, 1.0, 1.0)
	rim_light.rotation_degrees = Vector3(-10.0, 176.0, 0.0)
	rim_light.shadow_enabled = false
	world_root.add_child(rim_light)

	card_root = Node3D.new()
	card_root.name = "PhysicalCardRoot"
	world_root.add_child(card_root)

	# Back face: same rounded size as the front, so no ugly bars/gaps at rest.
	card_back_mesh = MeshInstance3D.new()
	card_back_mesh.name = "CardBackFace"
	card_back_mesh.mesh = create_rounded_card_mesh(
		card_width,
		card_height,
		card_corner_radius,
		card_corner_segments
	)

	card_back_material = StandardMaterial3D.new()
	card_back_material.albedo_color = Color(0.012, 0.010, 0.008, 1.0)
	card_back_material.roughness = 0.85
	card_back_material.metallic = 0.0
	card_back_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	card_back_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	card_back_mesh.material_override = card_back_material
	card_back_mesh.position = Vector3(0.0, 0.0, -card_depth)
	card_root.add_child(card_back_mesh)

	# Front face.
	card_mesh = MeshInstance3D.new()
	card_mesh.name = "CardFrontFace"
	card_mesh.mesh = create_rounded_card_mesh(
		card_width,
		card_height,
		card_corner_radius,
		card_corner_segments
	)

	card_material = StandardMaterial3D.new()
	card_material.albedo_color = Color.WHITE
	card_material.roughness = 0.28
	card_material.metallic = 0.0
	card_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	card_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	card_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	card_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR

	card_mesh.material_override = card_material
	card_mesh.position = Vector3(0.0, 0.0, 0.0)
	card_root.add_child(card_mesh)

	# Gloss layer, slightly above the card front.
	gloss_mesh = MeshInstance3D.new()
	gloss_mesh.name = "GlossLayer"
	gloss_mesh.mesh = create_rounded_card_mesh(
		card_width,
		card_height,
		card_corner_radius,
		card_corner_segments
	)
	gloss_mesh.position = Vector3(0.0, 0.0, 0.018)

	gloss_material = create_gloss_material()
	gloss_mesh.material_override = gloss_material
	card_root.add_child(gloss_mesh)

	# High-resolution viewport texture shown through this TextureRect.
	preview_image = TextureRect.new()
	preview_image.name = "Card3DPreviewImage"
	preview_image.mouse_filter = Control.MOUSE_FILTER_IGNORE

	preview_image.anchor_left = 0.0
	preview_image.anchor_top = 0.0
	preview_image.anchor_right = 1.0
	preview_image.anchor_bottom = 1.0

	preview_image.offset_left = 0.0
	preview_image.offset_top = 0.0
	preview_image.offset_right = 0.0
	preview_image.offset_bottom = 0.0

	preview_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_image.texture = preview_viewport.get_texture()

	add_child(preview_image)


func create_gloss_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()

	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform float strength = 0.0;
uniform float offset = 1.0;
uniform float width = 0.18;
uniform vec4 shine_color : source_color = vec4(1.0, 0.96, 0.82, 1.0);

void fragment() {
	vec2 uv = UV;

	float diagonal = uv.x + uv.y;
	float distance_from_band = abs(diagonal - offset);

	float shine = 1.0 - smoothstep(0.0, width, distance_from_band);

	float edge_fade_x = smoothstep(0.0, 0.08, uv.x) * smoothstep(0.0, 0.08, 1.0 - uv.x);
	float edge_fade_y = smoothstep(0.0, 0.08, uv.y) * smoothstep(0.0, 0.08, 1.0 - uv.y);
	float edge_fade = edge_fade_x * edge_fade_y;

	ALBEDO = shine_color.rgb;
	ALPHA = shine * strength * edge_fade;
}
"""

	var shine_material: ShaderMaterial = ShaderMaterial.new()
	shine_material.shader = shader
	shine_material.set_shader_parameter("strength", 0.0)
	shine_material.set_shader_parameter("offset", 1.0)
	shine_material.set_shader_parameter("width", gloss_width)

	return shine_material


func auto_find_missing_references() -> void:
	if hand != null:
		return

	var root: Node = get_tree().current_scene

	if root == null:
		root = get_tree().root

	hand = find_hand(root)


func find_hand(node: Node) -> HandUI:
	if node is HandUI:
		return node as HandUI

	for child: Node in node.get_children():
		var found: HandUI = find_hand(child)

		if found != null:
			return found

	return null


func connect_signals() -> void:
	if hand == null:
		return

	if not hand.card_inspect_requested.is_connected(show_card):
		hand.card_inspect_requested.connect(show_card)


func show_card(source_card: CardUI, card_data: CardData) -> void:
	if visible and is_displayed and not is_animating:
		pending_source_card = source_card
		pending_card_data = card_data
		return_current_card_then_show_pending()
		return

	if visible and is_animating:
		pending_source_card = source_card
		pending_card_data = card_data
		return

	if card_data == null:
		hide_card()
		return

	if card_data.card_art == null:
		hide_card()
		return

	last_source_card = source_card
	last_source_rect = get_source_card_rect(source_card)

	card_material.albedo_texture = card_data.card_art

	visible = true
	is_animating = true
	is_displayed = false
	is_holding_display_card = false
	modulate.a = 1.0

	reset_card_rotation()

	display_rect = get_display_rect()
	display_center_position = display_rect.position

	global_position = last_source_rect.position
	size = last_source_rect.size
	pivot_offset = size / 2.0
	scale = Vector2.ONE

	if current_tween != null:
		current_tween.kill()

	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	current_tween.tween_property(self, "global_position", display_rect.position, fly_time)
	current_tween.parallel().tween_property(self, "size", display_rect.size, fly_time)
	current_tween.parallel().tween_property(self, "modulate:a", 1.0, fly_time)
	current_tween.tween_callback(_finish_show)


func _finish_show() -> void:
	is_animating = false
	is_displayed = true

	display_rect = get_display_rect()
	display_center_position = display_rect.position

	global_position = display_center_position
	size = display_rect.size
	pivot_offset = size / 2.0
	scale = Vector2.ONE

	update_viewport_size()
	reset_card_rotation()

	if pending_source_card != null and pending_card_data != null:
		return_current_card_then_show_pending()


func return_current_card_then_show_pending() -> void:
	if not visible:
		return

	var target_rect: Rect2 = last_source_rect

	if is_instance_valid(last_source_card):
		target_rect = get_source_card_rect(last_source_card)

	is_switching_cards = true
	is_animating = true
	is_displayed = false
	is_holding_display_card = false

	reset_card_rotation()

	if current_tween != null:
		current_tween.kill()

	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	current_tween.tween_property(self, "global_position", target_rect.position, return_time)
	current_tween.parallel().tween_property(self, "size", target_rect.size, return_time)
	current_tween.parallel().tween_property(self, "modulate:a", 0.0, return_time)
	current_tween.tween_callback(_finish_switch_return)


func _finish_switch_return() -> void:
	var next_source: CardUI = pending_source_card
	var next_data: CardData = pending_card_data

	pending_source_card = null
	pending_card_data = null

	is_switching_cards = false
	is_animating = false
	is_displayed = false
	visible = false

	if next_source != null and next_data != null:
		show_card(next_source, next_data)


func hide_card() -> void:
	pending_source_card = null
	pending_card_data = null
	is_switching_cards = false

	if not visible:
		return

	var target_rect: Rect2 = last_source_rect

	if is_instance_valid(last_source_card):
		target_rect = get_source_card_rect(last_source_card)

	is_animating = true
	is_displayed = false
	is_holding_display_card = false

	reset_card_rotation()

	if current_tween != null:
		current_tween.kill()

	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	current_tween.tween_property(self, "global_position", target_rect.position, return_time)
	current_tween.parallel().tween_property(self, "size", target_rect.size, return_time)
	current_tween.parallel().tween_property(self, "modulate:a", 0.0, return_time)
	current_tween.tween_callback(_finish_hide)


func _finish_hide() -> void:
	visible = false
	is_animating = false
	is_displayed = false
	is_holding_display_card = false

	display_rect = get_display_rect()
	global_position = display_rect.position
	size = display_rect.size

	reset_card_rotation()


func _process(delta: float) -> void:
	if visible:
		update_viewport_size()

	if not visible:
		return

	if is_animating:
		return

	if not is_displayed:
		return

	if is_holding_display_card:
		update_3d_hand_rotation(delta)
	else:
		return_to_neutral_rotation(delta)


func update_3d_hand_rotation(delta: float) -> void:
	var mouse_position: Vector2 = get_global_mouse_position()
	var center: Vector2 = global_position + size / 2.0
	var local_offset: Vector2 = mouse_position - center

	var normal_x: float = clamp(local_offset.x / (size.x / 2.0), -1.0, 1.0)
	var normal_y: float = clamp(local_offset.y / (size.y / 2.0), -1.0, 1.0)

	var target_pitch: float = normal_y * max_pitch_degrees
	var target_yaw: float = normal_x * max_yaw_degrees

	if card_root != null:
		card_root.rotation_degrees.x = lerpf(card_root.rotation_degrees.x, target_pitch, delta * tilt_smoothing)
		card_root.rotation_degrees.y = lerpf(card_root.rotation_degrees.y, target_yaw, delta * tilt_smoothing)
		card_root.rotation_degrees.z = lerpf(card_root.rotation_degrees.z, 0.0, delta * tilt_smoothing)

	update_gloss(delta, normal_x, normal_y)


func return_to_neutral_rotation(delta: float) -> void:
	if card_root != null:
		card_root.rotation_degrees.x = lerpf(card_root.rotation_degrees.x, 0.0, delta * tilt_smoothing)
		card_root.rotation_degrees.y = lerpf(card_root.rotation_degrees.y, 0.0, delta * tilt_smoothing)
		card_root.rotation_degrees.z = lerpf(card_root.rotation_degrees.z, 0.0, delta * tilt_smoothing)

	fade_gloss(delta)


func update_gloss(delta: float, normal_x: float, normal_y: float) -> void:
	if gloss_material == null:
		return

	var tilt_amount: float = clamp((abs(normal_x) + abs(normal_y)) * 0.75, 0.0, 1.0)

	var target_strength: float = gloss_strength * tilt_amount
	var target_offset: float = 1.0 + normal_x * 0.55 - normal_y * 0.25

	var current_strength: float = float(gloss_material.get_shader_parameter("strength"))
	var current_offset: float = float(gloss_material.get_shader_parameter("offset"))

	gloss_material.set_shader_parameter("strength", lerpf(current_strength, target_strength, delta * tilt_smoothing))
	gloss_material.set_shader_parameter("offset", lerpf(current_offset, target_offset, delta * tilt_smoothing))
	gloss_material.set_shader_parameter("width", gloss_width)


func fade_gloss(delta: float) -> void:
	if gloss_material == null:
		return

	var current_strength: float = float(gloss_material.get_shader_parameter("strength"))

	gloss_material.set_shader_parameter("strength", lerpf(current_strength, 0.0, delta * tilt_smoothing))


func reset_card_rotation() -> void:
	if card_root != null:
		card_root.rotation_degrees = Vector3.ZERO

	if card_mesh != null:
		card_mesh.rotation_degrees = Vector3.ZERO

	if card_back_mesh != null:
		card_back_mesh.rotation_degrees = Vector3.ZERO

	if gloss_mesh != null:
		gloss_mesh.rotation_degrees = Vector3.ZERO

	if gloss_material != null:
		gloss_material.set_shader_parameter("strength", 0.0)
		gloss_material.set_shader_parameter("offset", 1.0)


func update_viewport_size() -> void:
	if preview_viewport == null:
		return

	var scaled_width: int = maxi(int(size.x * preview_render_scale), 16)
	var scaled_height: int = maxi(int(size.y * preview_render_scale), 16)

	var new_size: Vector2i = Vector2i(scaled_width, scaled_height)

	if preview_viewport.size != new_size:
		preview_viewport.size = new_size

		if preview_image != null:
			preview_image.texture = preview_viewport.get_texture()


func get_display_rect() -> Rect2:
	var viewport_size: Vector2 = get_viewport_rect().size
	if center_on_screen:
		var target_size := centered_display_size
		var maximum_size := viewport_size * centered_viewport_limit
		var fit_scale := minf(
			1.0,
			minf(maximum_size.x / target_size.x, maximum_size.y / target_size.y)
		)
		target_size *= fit_scale
		return Rect2((viewport_size - target_size) * 0.5, target_size)

	var top_left := Vector2(
		viewport_size.x + display_offset_left,
		viewport_size.y + display_offset_top
	)

	var bottom_right := Vector2(
		viewport_size.x + display_offset_right,
		viewport_size.y + display_offset_bottom
	)

	return Rect2(top_left, bottom_right - top_left)


func get_source_card_rect(source_card: CardUI) -> Rect2:
	if not is_instance_valid(source_card):
		return last_source_rect

	var source_size: Vector2 = source_card.size * source_card.scale

	if source_size.x <= 0.0 or source_size.y <= 0.0:
		source_size = Vector2(130.0, 180.0)

	return Rect2(source_card.global_position, source_size)


func is_mouse_inside_display_card() -> bool:
	var mouse_position: Vector2 = get_global_mouse_position()
	var rect: Rect2 = Rect2(global_position, size)

	return rect.has_point(mouse_position)


func create_rounded_card_mesh(width: float, height: float, radius: float, segments: int) -> ArrayMesh:
	var half_w: float = width / 2.0
	var half_h: float = height / 2.0

	var outline: Array[Vector2] = []

	add_corner_arc(outline, Vector2(half_w - radius, half_h - radius), radius, 90.0, 0.0, segments)
	add_corner_arc(outline, Vector2(half_w - radius, -half_h + radius), radius, 0.0, -90.0, segments)
	add_corner_arc(outline, Vector2(-half_w + radius, -half_h + radius), radius, -90.0, -180.0, segments)
	add_corner_arc(outline, Vector2(-half_w + radius, half_h - radius), radius, 180.0, 90.0, segments)

	var vertices: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()

	vertices.append(Vector3.ZERO)
	uvs.append(Vector2(0.5, 0.5))

	for point: Vector2 in outline:
		vertices.append(Vector3(point.x, point.y, 0.0))

		var uv_x: float = (point.x + half_w) / width
		var uv_y: float = 1.0 - ((point.y + half_h) / height)

		uvs.append(Vector2(uv_x, uv_y))

	var outline_count: int = outline.size()

	for i in range(1, outline_count + 1):
		var next_i: int = i + 1

		if next_i > outline_count:
			next_i = 1

		indices.append(0)
		indices.append(i)
		indices.append(next_i)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return mesh


func add_corner_arc(
	points: Array[Vector2],
	center: Vector2,
	radius: float,
	start_degrees: float,
	end_degrees: float,
	segments: int
) -> void:
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle_degrees: float = lerpf(start_degrees, end_degrees, t)
		var angle_radians: float = deg_to_rad(angle_degrees)

		var point: Vector2 = Vector2(
			center.x + cos(angle_radians) * radius,
			center.y + sin(angle_radians) * radius
		)

		points.append(point)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			hide_card()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			hide_card()

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if visible and is_displayed and not is_animating and is_mouse_inside_display_card():
					is_holding_display_card = true
			else:
				is_holding_display_card = false
