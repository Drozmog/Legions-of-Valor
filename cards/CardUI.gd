class_name CardUI
extends Panel

signal drag_started(card: CardUI)
signal drag_released(card: CardUI, screen_position: Vector2)
signal clicked(card: CardUI, screen_position: Vector2)

@onready var name_label: Label = get_node_or_null("NameLabel") as Label
const ABILITY_ICON_PATHS := {
	"assault": "res://ui/ability_icons/assault.png",
	"control": "res://ui/ability_icons/control.png",
	"attrition": "res://ui/ability_icons/attrition.png",
	"economy": "res://ui/ability_icons/economy.png",
	"protection": "res://ui/ability_icons/protection.png",
	"insight": "res://ui/ability_icons/insight.png",
	"mobility": "res://ui/ability_icons/mobility.png",
}

const CARD_BACK_TEXTURE: Texture2D = preload("res://cards/card_back.png")

var card_image: TextureRect = null

var card_data: CardData = null
var is_dragging: bool = false
var is_face_down: bool = false

var mouse_is_pressed: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var press_mouse_position: Vector2 = Vector2.ZERO

@export var drag_start_distance: float = 12.0
@export var ability_icon_size: float = 64.0
@export var ability_icon_spacing: float = 72.0
@export var ability_icon_hidden_y: float = -10.0
@export var ability_icon_shown_y: float = -62.0
@export var ability_icon_tween_time: float = 0.18

var ability_icon_root: Control = null
var ability_icons_are_visible: bool = false
var ability_icon_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)

	make_panel_background_transparent()
	setup_card_image()
	setup_ability_icon_root()


func setup_card_image() -> void:
	card_image = get_node_or_null("CardImage") as TextureRect

	if card_image == null:
		card_image = TextureRect.new()
		card_image.name = "CardImage"
		add_child(card_image)
		move_child(card_image, 0)

	card_image.mouse_filter = Control.MOUSE_FILTER_IGNORE

	card_image.anchor_left = 0.0
	card_image.anchor_top = 0.0
	card_image.anchor_right = 1.0
	card_image.anchor_bottom = 1.0

	card_image.offset_left = 0.0
	card_image.offset_top = 0.0
	card_image.offset_right = 0.0
	card_image.offset_bottom = 0.0

	card_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	card_image.material = create_rounded_card_material()


func setup(data: CardData) -> void:
	card_data = data
	show_front()
	rebuild_ability_icons()


func show_front() -> void:
	is_face_down = false

	make_panel_background_transparent()

	if card_image != null:
		card_image.visible = true

		if card_data != null and card_data.card_art != null:
			card_image.texture = card_data.card_art
		else:
			card_image.texture = null

	if name_label != null:
		if card_data != null and card_data.card_art != null:
			name_label.visible = false
		else:
			name_label.visible = true

			if card_data != null:
				name_label.text = card_data.card_name

	self_modulate = Color(1.0, 1.0, 1.0, 1.0)


func show_back() -> void:
	is_face_down = true

	make_panel_background_transparent()

	if card_image != null:
		card_image.visible = true
		card_image.texture = CARD_BACK_TEXTURE

	if name_label != null:
		name_label.visible = false

	self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	set_ability_icons_visible(false, true)
	
	

func create_rounded_card_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()

	shader.code = """
shader_type canvas_item;

uniform float radius = 0.035;

void fragment() {
	vec2 uv = UV;
	vec2 corner_uv = min(uv, vec2(1.0) - uv);

	if (corner_uv.x < radius && corner_uv.y < radius) {
		vec2 corner_center = vec2(radius, radius);
		vec2 local = corner_uv - corner_center;

		if (length(local) > radius) {
			discard;
		}
	}

	COLOR = texture(TEXTURE, uv);
}
"""

	var rounded_material: ShaderMaterial = ShaderMaterial.new()
	rounded_material.shader = shader
	rounded_material.set_shader_parameter("radius", 0.045)

	return rounded_material
	
	
func make_panel_background_transparent() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = 0
	add_theme_stylebox_override("panel", style)

func setup_ability_icon_root() -> void:
	ability_icon_root = get_node_or_null("AbilityIconRoot") as Control

	if ability_icon_root == null:
		ability_icon_root = Control.new()
		ability_icon_root.name = "AbilityIconRoot"
		add_child(ability_icon_root)

	ability_icon_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_icon_root.z_index = 100
	ability_icon_root.visible = false
	ability_icon_root.modulate.a = 0.0

	position_ability_icon_root(false)


func position_ability_icon_root(shown: bool) -> void:
	if ability_icon_root == null:
		return

	var card_width := size.x

	if card_width <= 1.0:
		card_width = custom_minimum_size.x

	var target_y := ability_icon_hidden_y

	if shown:
		target_y = ability_icon_shown_y

	ability_icon_root.position = Vector2(card_width / 2.0, target_y)


func rebuild_ability_icons() -> void:
	if ability_icon_root == null:
		return

	for child in ability_icon_root.get_children():
		child.queue_free()

	if card_data == null:
		return

	if card_data.ability_types.is_empty():
		return

	var icon_count := card_data.ability_types.size()
	var total_width := ability_icon_spacing * float(icon_count - 1)
	var start_x := -total_width / 2.0

	for i in range(icon_count):
		var ability_type := card_data.ability_types[i].to_lower()
		var icon := create_ability_icon(ability_type)

		icon.position = Vector2(
			start_x + ability_icon_spacing * float(i) - ability_icon_size / 2.0,
			-ability_icon_size / 2.0
		)

		ability_icon_root.add_child(icon)


func create_ability_icon(ability_type: String) -> Control:
	var icon_path: String = ABILITY_ICON_PATHS.get(ability_type, "")

	var icon := TextureRect.new()
	icon.name = ability_type.capitalize() + "Icon"
	icon.custom_minimum_size = Vector2(ability_icon_size, ability_icon_size)
	icon.size = Vector2(ability_icon_size, ability_icon_size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path) as Texture2D
	else:
		icon.texture = null

		var fallback := Label.new()
		fallback.text = ability_type.substr(0, 1).to_upper()
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 28)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback.anchor_right = 1.0
		fallback.anchor_bottom = 1.0
		icon.add_child(fallback)

	return icon


func set_ability_icons_visible(show_icons: bool, instant: bool = false) -> void:
	if ability_icon_root == null:
		return

	if card_data == null:
		return

	if card_data.ability_types.is_empty():
		return

	if is_face_down:
		show_icons = false

	if ability_icons_are_visible == show_icons and not instant:
		return

	ability_icons_are_visible = show_icons

	if ability_icon_tween != null:
		ability_icon_tween.kill()

	var card_width := size.x

	if card_width <= 1.0:
		card_width = custom_minimum_size.x

	var target_y := ability_icon_hidden_y
	var target_alpha := 0.0

	if show_icons:
		target_y = ability_icon_shown_y
		target_alpha = 1.0
		ability_icon_root.visible = true

	if instant:
		ability_icon_root.position = Vector2(card_width / 2.0, target_y)
		ability_icon_root.modulate.a = target_alpha
		ability_icon_root.visible = show_icons
		return

	ability_icon_tween = create_tween()
	ability_icon_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	ability_icon_tween.tween_property(
		ability_icon_root,
		"position",
		Vector2(card_width / 2.0, target_y),
		ability_icon_tween_time
	)

	ability_icon_tween.parallel().tween_property(
		ability_icon_root,
		"modulate:a",
		target_alpha,
		ability_icon_tween_time
	)

	if not show_icons:
		ability_icon_tween.tween_callback(func(): ability_icon_root.visible = false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			start_press()
			accept_event()


func start_press() -> void:
	mouse_is_pressed = true
	is_dragging = false

	press_mouse_position = get_global_mouse_position()
	drag_offset = get_global_mouse_position() - global_position

	set_process(true)


func _process(_delta: float) -> void:
	if not mouse_is_pressed:
		return

	var mouse_position := get_global_mouse_position()

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if is_dragging:
			stop_dragging()
		else:
			finish_click()

		return

	if not is_dragging:
		var distance_moved := press_mouse_position.distance_to(mouse_position)

		if distance_moved >= drag_start_distance:
			begin_dragging()

	if is_dragging:
		global_position = mouse_position - drag_offset


func begin_dragging() -> void:
	is_dragging = true

	move_to_front()
	rotation_degrees = 0

	drag_started.emit(self)


func stop_dragging() -> void:
	mouse_is_pressed = false
	is_dragging = false
	set_process(false)

	drag_released.emit(self, get_viewport().get_mouse_position())


func finish_click() -> void:
	mouse_is_pressed = false
	is_dragging = false
	set_process(false)

	if is_face_down:
		return

	if card_data == null:
		return

	clicked.emit(self, get_viewport().get_mouse_position())
