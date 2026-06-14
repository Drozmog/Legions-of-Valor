class_name CardUI
extends Panel

signal drag_started(card: CardUI)
signal drag_released(card: CardUI, screen_position: Vector2)
signal clicked(card: CardUI, screen_position: Vector2)

@onready var name_label: Label = get_node_or_null("NameLabel") as Label

var card_image: TextureRect = null

var card_data: CardData = null
var is_dragging: bool = false
var is_face_down: bool = false

var mouse_is_pressed: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var press_mouse_position: Vector2 = Vector2.ZERO

@export var drag_start_distance: float = 12.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)

	make_panel_background_transparent()
	setup_card_image()


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


func show_front() -> void:
	is_face_down = false

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

	if card_image != null:
		card_image.visible = false

	if name_label != null:
		name_label.visible = false

	self_modulate = Color(0.08, 0.08, 0.08, 0.95)

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
