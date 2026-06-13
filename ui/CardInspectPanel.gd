class_name CardInspectPanel
extends PanelContainer

@export var hand: HandUI

@export var display_offset_left: float = -455.0
@export var display_offset_right: float = -35.0
@export var display_offset_top: float = -610.0
@export var display_offset_bottom: float = -45.0

@export var fly_time: float = 0.34
@export var return_time: float = 0.26

@export var max_yaw_degrees: float = 13.0
@export var max_pitch_degrees: float = 9.0
@export var tilt_smoothing: float = 10.0

var current_tween: Tween = null

var viewport_container: SubViewportContainer = null
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
	for child in get_children():
		remove_child(child)
		child.free()


func setup_position() -> void:
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
	viewport_container = SubViewportContainer.new()
	viewport_container.name = "Card3DPreviewContainer"
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_container.stretch = true

	viewport_container.anchor_left = 0.0
	viewport_container.anchor_top = 0.0
	viewport_container.anchor_right = 1.0
	viewport_container.anchor_bottom = 1.0

	viewport_container.offset_left = 0.0
	viewport_container.offset_top = 0.0
	viewport_container.offset_right = 0.0
	viewport_container.offset_bottom = 0.0

	add_child(viewport_container)

	preview_viewport = SubViewport.new()
	preview_viewport.own_world_3d = true
	preview_viewport.transparent_bg = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_viewport.size = Vector2i(700, 950)

	viewport_container.add_child(preview_viewport)

	var world_root := Node3D.new()
	preview_viewport.add_child(world_root)

	preview_camera = Camera3D.new()
	preview_camera.position = Vector3(0.0, 0.0, 5.2)
	preview_camera.position = Vector3(0.0, 0.0, 6.4)
	preview_camera.fov = 38.0
	preview_camera.current = true
	world_root.add_child(preview_camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30.0, 20.0, 0.0)
	light.light_energy = 1.8
	world_root.add_child(light)

	card_mesh = MeshInstance3D.new()

	var quad := QuadMesh.new()
	quad.size = Vector2(2.25, 3.15)
	card_mesh.mesh = quad

	card_material = StandardMaterial3D.new()
	card_material.albedo_color = Color.WHITE
	card_material.roughness = 0.55
	card_material.metallic = 0.0
	card_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	card_mesh.material_override = card_material
	card_mesh.position = Vector3(0.0, 0.0, 0.0)

	world_root.add_child(card_mesh)
	print("CardInspectPanel children after build: ", get_child_count())
	for child in get_children():
		print(" - ", child.name)


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


func hide_card() -> void:
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
	var target_yaw: float = -normal_x * max_yaw_degrees

	card_mesh.rotation_degrees.x = lerpf(card_mesh.rotation_degrees.x, target_pitch, delta * tilt_smoothing)
	card_mesh.rotation_degrees.y = lerpf(card_mesh.rotation_degrees.y, target_yaw, delta * tilt_smoothing)
	card_mesh.rotation_degrees.z = lerpf(card_mesh.rotation_degrees.z, 0.0, delta * tilt_smoothing)


func return_to_neutral_rotation(delta: float) -> void:
	card_mesh.rotation_degrees.x = lerpf(card_mesh.rotation_degrees.x, 0.0, delta * tilt_smoothing)
	card_mesh.rotation_degrees.y = lerpf(card_mesh.rotation_degrees.y, 0.0, delta * tilt_smoothing)
	card_mesh.rotation_degrees.z = lerpf(card_mesh.rotation_degrees.z, 0.0, delta * tilt_smoothing)


func reset_card_rotation() -> void:
	if card_mesh == null:
		return

	card_mesh.rotation_degrees = Vector3.ZERO


func update_viewport_size() -> void:
	if preview_viewport == null:
		return

	var new_size := Vector2i(maxi(int(size.x), 16), maxi(int(size.y), 16))

	if preview_viewport.size != new_size:
		preview_viewport.size = new_size


func get_display_rect() -> Rect2:
	var viewport_size: Vector2 = get_viewport_rect().size

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
	var rect := Rect2(global_position, size)

	return rect.has_point(mouse_position)


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
