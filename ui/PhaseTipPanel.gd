class_name PhaseTipPanel
extends Control

const PANEL_WIDTH := 390.0
const PANEL_HEIGHT := 132.0
const REST_X := 28.0

var body_label: Label
var slide_tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(-PANEL_WIDTH - 30.0, _rest_y())
	size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 72
	_build_visuals()
	visible = false


func _build_visuals() -> void:
	var blur := ColorRect.new()
	blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
void fragment() {
	vec4 blurred = textureLod(screen_texture, SCREEN_UV, 3.0);
	vec2 panel_size = vec2(390.0, 132.0);
	float radius = 18.0;
	vec2 p = (UV - vec2(0.5)) * panel_size;
	vec2 q = abs(p) - (panel_size * 0.5 - vec2(radius));
	float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float mask = 1.0 - smoothstep(-16.0, 5.0, distance_to_edge);
	COLOR = vec4(mix(blurred.rgb, vec3(0.075, 0.085, 0.105), 0.38), 0.88 * mask);
}
"""
	var blur_material := ShaderMaterial.new()
	blur_material.shader = shader
	blur.material = blur_material
	add_child(blur)

	var border := PanelContainer.new()
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(10)
	style.shadow_size = 0
	border.add_theme_stylebox_override("panel", style)
	add_child(border)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	border.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	var title := Label.new()
	title.text = "NEED A HAND?"
	title.add_theme_font_size_override("font_size", 15)
	_apply_white_text(title, 0.82)
	column.add_child(title)
	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 17)
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_white_text(body_label, 1.0)
	column.add_child(body_label)


func _apply_white_text(label: Label, alpha: float) -> void:
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, alpha))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 3)


func show_tip(message: String) -> void:
	if message.strip_edges().is_empty():
		return
	body_label.text = message
	if slide_tween != null and slide_tween.is_valid():
		slide_tween.kill()
	visible = true
	position = Vector2(-PANEL_WIDTH - 30.0, _rest_y())
	modulate.a = 0.0
	slide_tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	slide_tween.tween_property(self, "position:x", REST_X, 0.62)
	slide_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.42)


func _rest_y() -> float:
	# The prominent battlefield crack sits at roughly 60% of the view height.
	# Rest the panel's lower edge on it across window sizes.
	return maxf(24.0, get_viewport_rect().size.y * 0.60 - PANEL_HEIGHT)


func update_tip(message: String) -> void:
	if body_label != null and not message.strip_edges().is_empty() and body_label.text != message:
		body_label.text = message


func hide_tip(immediate: bool = false) -> void:
	if slide_tween != null and slide_tween.is_valid():
		slide_tween.kill()
	if immediate or not visible:
		visible = false
		position.x = -PANEL_WIDTH - 30.0
		return
	slide_tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	slide_tween.tween_property(self, "position:x", -PANEL_WIDTH - 30.0, 0.40)
	slide_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.30)
	slide_tween.tween_callback(func(): visible = false)
