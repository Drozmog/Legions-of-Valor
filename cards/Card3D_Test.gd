class_name Card3DTest
extends Node3D

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
var ability_icon_tween: Tween = null


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

	if assigned_card_data.ability_types.is_empty():
		return

	var icon_count: int = assigned_card_data.ability_types.size()
	var total_width: float = ability_icon_spacing * float(icon_count - 1)
	var start_x: float = -total_width / 2.0

	for i in range(icon_count):
		var ability_type: String = String(assigned_card_data.ability_types[i]).to_lower().strip_edges()
		var icon := create_ability_icon_3d(ability_type)

		icon.position = Vector3(
			start_x + ability_icon_spacing * float(i),
			0.0,
			0.0
		)

		ability_icon_root.add_child(icon)
		
		
func create_ability_icon_3d(ability_type: String) -> Node3D:
	var icon_path: String = ABILITY_ICON_PATHS.get(ability_type, "")

	if icon_path != "" and ResourceLoader.exists(icon_path):
		var sprite := Sprite3D.new()
		sprite.name = ability_type.capitalize() + "Icon"
		sprite.texture = load(icon_path) as Texture2D
		sprite.pixel_size = ability_icon_pixel_size
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.no_depth_test = true
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return sprite

	var label := Label3D.new()
	label.name = ability_type.capitalize() + "IconFallback"
	label.text = ability_type.substr(0, 1).to_upper()
	label.pixel_size = 0.004
	label.font_size = 34
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.92, 0.55, 1.0)
	label.outline_size = 8
	label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	return label
	

func set_ability_icons_visible(show_icons: bool, instant: bool = false) -> void:
	if ability_icon_root == null:
		return

	if assigned_card_data == null:
		return

	if assigned_card_data.ability_types.is_empty():
		return

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
		
		
func set_ability_icon_root_alpha(alpha: float) -> void:
	if ability_icon_root == null:
		return

	for child in ability_icon_root.get_children():
		if child is Sprite3D:
			var sprite := child as Sprite3D
			var color := sprite.modulate
			color.a = alpha
			sprite.modulate = color

		if child is Label3D:
			var label := child as Label3D
			var label_color := label.modulate
			label_color.a = alpha
			label.modulate = label_color


func get_ability_icon_root_alpha() -> float:
	if ability_icon_root == null:
		return 0.0

	for child in ability_icon_root.get_children():
		if child is Sprite3D:
			return (child as Sprite3D).modulate.a

		if child is Label3D:
			return (child as Label3D).modulate.a

	return 0.0


func reveal_card() -> void:
	show_front()
