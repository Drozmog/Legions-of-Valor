class_name Card3DTest
extends Node3D

signal ability_icon_pressed(card_visual: Card3DTest, ability: AbilityData)
signal ability_icon_hovered(card_visual: Card3DTest, ability: AbilityData)
signal ability_icon_unhovered(card_visual: Card3DTest, ability: AbilityData)

const CARD_WIDTH: float = 1.02
const CARD_HEIGHT: float = 1.34
const CARD_CORNER_RADIUS: float = 0.065
const CARD_CORNER_SEGMENTS: int = 8
const CARD_BACK_PATH: String = "res://cards/card_back.png"

const ABILITY_ICON_PATHS := {
	"assault": "res://ui/ability_icons/assault.png",
	"control": "res://ui/ability_icons/control.png",
	"attrition": "res://ui/ability_icons/attrition.png",
	"economy": "res://ui/ability_icons/economy.png",
	"protection": "res://ui/ability_icons/protection.png",
	"insight": "res://ui/ability_icons/insight.png",
	"mobility": "res://ui/ability_icons/mobility.png",
}

static var mipmapped_texture_cache: Dictionary = {}

@onready var card_body: MeshInstance3D = get_node_or_null("CardBody") as MeshInstance3D

var assigned_card_data: CardData = null
var is_face_down: bool = false
var fallback_label: Label3D = null
@export var ability_icon_pixel_size: float = 0.0028
@export var ability_icon_spacing: float = 0.22
@export var ability_icon_hidden_z: float = -0.52
@export var ability_icon_shown_z: float = -0.82
@export var ability_icon_y: float = 0.095
@export var ability_icon_tween_time: float = 0.18

var ability_icon_root: Node3D = null
var ability_icons_are_visible: bool = false
var manual_ability_icons_visible: bool = false
var auto_ability_icons_visible: bool = false
var ability_icon_tween: Tween = null
var usable_ability_ids: Dictionary = {}


func _ready() -> void:
	setup_card_body()
	setup_fallback_label()
	setup_ability_icon_root()
	# Pile and hidden-hand cards intentionally have no CardData. Their face-down
	# state still needs to replace the scene's fallback material after entering
	# the tree.
	apply_card_visual()
	if assigned_card_data != null:
		rebuild_ability_icons()


func assign_card_data(card_data: CardData, place_face_down: bool = false) -> void:
	assigned_card_data = card_data
	is_face_down = place_face_down

	if is_inside_tree():
		apply_card_visual()
		rebuild_ability_icons()


func get_card_data() -> CardData:
	return assigned_card_data


func setup_card_body() -> void:
	if card_body == null:
		card_body = MeshInstance3D.new()
		card_body.name = "CardBody"
		add_child(card_body)

	card_body.mesh = create_rounded_card_mesh(
		CARD_WIDTH,
		CARD_HEIGHT,
		CARD_CORNER_RADIUS,
		CARD_CORNER_SEGMENTS
	)
	card_body.position = Vector3(0, 0.012, 0)
	card_body.rotation_degrees = Vector3.ZERO


func create_rounded_card_mesh(width: float, height: float, radius: float, segments: int) -> ArrayMesh:
	var half_w := width * 0.5
	var half_h := height * 0.5
	var outline: Array[Vector2] = []
	add_card_corner_arc(outline, Vector2(half_w - radius, half_h - radius), radius, 90.0, 0.0, segments)
	add_card_corner_arc(outline, Vector2(half_w - radius, -half_h + radius), radius, 0.0, -90.0, segments)
	add_card_corner_arc(outline, Vector2(-half_w + radius, -half_h + radius), radius, -90.0, -180.0, segments)
	add_card_corner_arc(outline, Vector2(-half_w + radius, half_h - radius), radius, 180.0, 90.0, segments)

	var vertices := PackedVector3Array([Vector3.ZERO])
	var normals := PackedVector3Array([Vector3.UP])
	var uvs := PackedVector2Array([Vector2(0.5, 0.5)])
	var indices := PackedInt32Array()

	for point in outline:
		# Card3D lies on X/Z. Mapping inspector-style +Y to -Z preserves the
		# existing card-art orientation while using the same rounded silhouette.
		vertices.append(Vector3(point.x, 0.0, -point.y))
		normals.append(Vector3.UP)
		uvs.append(Vector2(
			(point.x + half_w) / width,
			1.0 - ((point.y + half_h) / height)
		))

	for i in range(1, outline.size() + 1):
		var next_i := i + 1
		if next_i > outline.size():
			next_i = 1
		indices.append(0)
		indices.append(i)
		indices.append(next_i)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func add_card_corner_arc(
	points: Array[Vector2],
	center: Vector2,
	radius: float,
	start_degrees: float,
	end_degrees: float,
	segments: int
) -> void:
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var angle := deg_to_rad(lerpf(start_degrees, end_degrees, t))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)


func setup_fallback_label() -> void:
	fallback_label = get_node_or_null("FallbackLabel") as Label3D

	if fallback_label == null:
		fallback_label = Label3D.new()
		fallback_label.name = "FallbackLabel"
		add_child(fallback_label)

	fallback_label.position = Vector3(0, 0.06, 0)
	fallback_label.pixel_size = 0.006
	fallback_label.font_size = 42
	fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fallback_label.no_depth_test = true
	fallback_label.modulate = Color(1.0, 0.92, 0.65, 1.0)
	fallback_label.outline_size = 8
	fallback_label.outline_modulate = Color(0, 0, 0, 1)
	fallback_label.visible = false


func apply_card_visual() -> void:
	if is_face_down:
		show_back()
	else:
		show_front()


func show_front() -> void:
	is_face_down = false

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	if assigned_card_data != null and assigned_card_data.card_art != null:
		mat.albedo_texture = get_mipmapped_texture(assigned_card_data.card_art)
		mat.albedo_color = Color.WHITE

		if fallback_label != null:
			fallback_label.visible = false
	else:
		mat.albedo_color = Color(0.12, 0.08, 0.045, 1.0)

		if fallback_label != null:
			fallback_label.visible = true

			if assigned_card_data != null:
				fallback_label.text = assigned_card_data.card_name
			else:
				fallback_label.text = "Card"

	card_body.material_override = mat


func show_back() -> void:
	is_face_down = true

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	if ResourceLoader.exists(CARD_BACK_PATH):
		mat.albedo_texture = get_mipmapped_texture(load(CARD_BACK_PATH) as Texture2D)
		mat.albedo_color = Color.WHITE
	else:
		mat.albedo_color = Color(0.08, 0.055, 0.025, 1.0)

	card_body.material_override = mat

	if fallback_label != null:
		fallback_label.visible = false

	set_ability_icons_visible(false, true)


static func get_mipmapped_texture(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var cache_key := texture.resource_path
	if cache_key.is_empty():
		cache_key = str(texture.get_instance_id())
	if mipmapped_texture_cache.has(cache_key):
		return mipmapped_texture_cache[cache_key] as Texture2D
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	if not image.has_mipmaps():
		image.generate_mipmaps()
	var sharpened := ImageTexture.create_from_image(image)
	mipmapped_texture_cache[cache_key] = sharpened
	return sharpened
	
func setup_ability_icon_root() -> void:
	ability_icon_root = get_node_or_null("AbilityIconRoot") as Node3D

	if ability_icon_root == null:
		ability_icon_root = Node3D.new()
		ability_icon_root.name = "AbilityIconRoot"
		add_child(ability_icon_root)

	ability_icon_root.visible = false
	ability_icon_root.position = Vector3(0, ability_icon_y, ability_icon_hidden_z)
	
func rebuild_ability_icons() -> void:
	if ability_icon_root == null:
		return

	for child in ability_icon_root.get_children():
		child.queue_free()

	if assigned_card_data == null:
		return

	var abilities := assigned_card_data.get_abilities()
	if abilities.is_empty():
		return

	var icon_count: int = abilities.size()
	var total_width: float = ability_icon_spacing * float(icon_count - 1)
	var start_x: float = -total_width / 2.0

	for i in range(icon_count):
		var ability := abilities[i] as AbilityData
		var icon := create_ability_icon_3d(ability)

		icon.position = Vector3(
			start_x + ability_icon_spacing * float(i),
			0.0,
			0.0
		)

		ability_icon_root.add_child(icon)

	refresh_ability_icon_states()
		
		
func create_ability_icon_3d(ability: AbilityData) -> Node3D:
	var ability_type := ability.category.to_lower().strip_edges() if ability != null else ""
	var icon_path: String = ABILITY_ICON_PATHS.get(ability_type, "")
	var root := Node3D.new()
	root.name = ability_type.capitalize() + "AbilityIcon"
	root.set_meta("ability", ability)

	if icon_path != "" and ResourceLoader.exists(icon_path):
		var glow := Sprite3D.new()
		glow.name = "Glow"
		glow.texture = load(icon_path) as Texture2D
		glow.pixel_size = ability_icon_pixel_size * 1.65
		glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		glow.no_depth_test = true
		glow.modulate = Color(1.0, 0.78, 0.22, 0.0)
		glow.visible = false
		root.add_child(glow)

		var sprite := Sprite3D.new()
		sprite.name = "Icon"
		sprite.texture = load(icon_path) as Texture2D
		sprite.pixel_size = ability_icon_pixel_size
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.no_depth_test = true
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.36)
		root.add_child(sprite)
	else:
		var label := Label3D.new()
		label.name = "IconFallback"
		label.text = ability_type.substr(0, 1).to_upper()
		label.pixel_size = 0.004
		label.font_size = 34
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = Color(1.0, 0.92, 0.55, 0.36)
		label.outline_size = 8
		label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
		root.add_child(label)

	var tooltip := Label3D.new()
	tooltip.name = "Tooltip"
	tooltip.text = ability.get_display_text() if ability != null else ability_type.capitalize()
	tooltip.position = Vector3(0.0, 0.045, -0.16)
	tooltip.pixel_size = 0.0022
	tooltip.font_size = 24
	tooltip.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tooltip.no_depth_test = true
	tooltip.modulate = Color(1.0, 0.91, 0.62, 1.0)
	tooltip.outline_size = 8
	tooltip.outline_modulate = Color(0.025, 0.012, 0.0, 1.0)
	tooltip.visible = false
	root.add_child(tooltip)

	var area := Area3D.new()
	area.name = "ClickArea"
	area.collision_layer = 8
	area.collision_mask = 0
	area.input_ray_pickable = false
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.18, 0.12, 0.18)
	collision.shape = shape
	area.add_child(collision)
	area.input_event.connect(_on_ability_icon_input_event.bind(root))
	area.mouse_entered.connect(_on_ability_icon_mouse_entered.bind(root))
	area.mouse_exited.connect(_on_ability_icon_mouse_exited.bind(root))
	root.add_child(area)

	return root
	

func set_ability_icons_visible(show_icons: bool, instant: bool = false) -> void:
	manual_ability_icons_visible = show_icons
	update_ability_icon_visibility(instant)


func set_usable_ability_ids(ability_ids: Array[StringName]) -> void:
	usable_ability_ids.clear()
	for ability_id in ability_ids:
		if ability_id != &"":
			usable_ability_ids[String(ability_id)] = true
	auto_ability_icons_visible = not usable_ability_ids.is_empty()
	refresh_ability_icon_states()
	update_ability_icon_visibility(false)


func update_ability_icon_visibility(instant: bool = false) -> void:
	if ability_icon_root == null:
		return

	if assigned_card_data == null:
		return

	if assigned_card_data.get_abilities().is_empty():
		return

	var show_icons := manual_ability_icons_visible or auto_ability_icons_visible

	if is_face_down:
		show_icons = false

	if ability_icons_are_visible == show_icons and not instant:
		return

	ability_icons_are_visible = show_icons

	if ability_icon_tween != null:
		ability_icon_tween.kill()

	var target_z: float = ability_icon_hidden_z
	var target_alpha: float = 0.0

	if show_icons:
		target_z = ability_icon_shown_z
		target_alpha = 1.0
		ability_icon_root.visible = true

	if instant:
		ability_icon_root.position = Vector3(0, ability_icon_y, target_z)
		set_ability_icon_root_alpha(target_alpha)
		ability_icon_root.visible = show_icons
		return

	ability_icon_tween = create_tween()
	ability_icon_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	ability_icon_tween.tween_property(
		ability_icon_root,
		"position",
		Vector3(0, ability_icon_y, target_z),
		ability_icon_tween_time
	)

	ability_icon_tween.parallel().tween_method(
		set_ability_icon_root_alpha,
		get_ability_icon_root_alpha(),
		target_alpha,
		ability_icon_tween_time
	)

	if not show_icons:
		ability_icon_tween.tween_callback(func(): ability_icon_root.visible = false)


func refresh_ability_icon_states() -> void:
	if ability_icon_root == null:
		return

	for child in ability_icon_root.get_children():
		var ability := child.get_meta("ability", null) as AbilityData
		var usable := ability != null and usable_ability_ids.has(String(ability.ability_id))
		var alpha := 1.0 if usable else 0.36
		var scale_target := Vector3(1.12, 1.12, 1.12) if usable else Vector3.ONE
		child.scale = scale_target

		var sprite := child.get_node_or_null("Icon") as Sprite3D
		if sprite != null:
			sprite.modulate = Color(1.0, 1.0, 1.0, alpha)

		var label := child.get_node_or_null("IconFallback") as Label3D
		if label != null:
			label.modulate = Color(1.0, 0.92, 0.55, alpha)

		var glow := child.get_node_or_null("Glow") as Sprite3D
		if glow != null:
			glow.visible = usable
			glow.modulate = Color(1.0, 0.78, 0.22, 0.34 if usable else 0.0)

		var area := child.get_node_or_null("ClickArea") as Area3D
		if area != null:
			area.input_ray_pickable = usable
			area.collision_layer = 8 if usable else 0


func _on_ability_icon_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_index: int,
	icon_root: Node3D
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var ability := icon_root.get_meta("ability", null) as AbilityData
			if ability != null and usable_ability_ids.has(String(ability.ability_id)):
				ability_icon_pressed.emit(self, ability)
				get_viewport().set_input_as_handled()


func _on_ability_icon_mouse_entered(icon_root: Node3D) -> void:
	var tooltip := icon_root.get_node_or_null("Tooltip") as Label3D
	if tooltip != null:
		tooltip.visible = true
	var ability := icon_root.get_meta("ability", null) as AbilityData
	if ability != null:
		ability_icon_hovered.emit(self, ability)
	Cursors.use_pointing()


func _on_ability_icon_mouse_exited(icon_root: Node3D) -> void:
	var tooltip := icon_root.get_node_or_null("Tooltip") as Label3D
	if tooltip != null:
		tooltip.visible = false
	var ability := icon_root.get_meta("ability", null) as AbilityData
	if ability != null:
		ability_icon_unhovered.emit(self, ability)
	Cursors.use_normal()
		
		
func set_ability_icon_root_alpha(alpha: float) -> void:
	if ability_icon_root == null:
		return

	for child in ability_icon_root.get_children():
		var ability := child.get_meta("ability", null) as AbilityData
		var usable := ability != null and usable_ability_ids.has(String(ability.ability_id))
		var base_alpha := 1.0 if usable else 0.36

		var sprite := child.get_node_or_null("Icon") as Sprite3D
		if sprite != null:
			sprite.modulate = Color(1.0, 1.0, 1.0, base_alpha * alpha)

		var label := child.get_node_or_null("IconFallback") as Label3D
		if label != null:
			label.modulate = Color(1.0, 0.92, 0.55, base_alpha * alpha)

		var glow := child.get_node_or_null("Glow") as Sprite3D
		if glow != null:
			glow.visible = usable and alpha > 0.0
			glow.modulate = Color(1.0, 0.78, 0.22, 0.34 * alpha if usable else 0.0)


func get_ability_icon_root_alpha() -> float:
	if ability_icon_root == null:
		return 0.0

	for child in ability_icon_root.get_children():
		var icon := child.get_node_or_null("Icon") as Sprite3D
		if icon != null:
			return icon.modulate.a

		var label := child.get_node_or_null("IconFallback") as Label3D
		if label != null:
			return label.modulate.a

	return 0.0


func reveal_card() -> void:
	show_front()
