class_name DeckSelectionScreen
extends Control

signal deck_selected(slot_index: int)

const SPECIAL_RANDOM_AI_DECK_SLOT := -2

var options_grid: GridContainer
var title_label: Label
var subtitle_label: Label

var selection_panel: PanelContainer
var panel_blur: ColorRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 110
	build_ui()
	get_viewport().size_changed.connect(_layout_to_viewport)
	call_deferred("_layout_to_viewport")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "DeckSelectionDim"
	dim.color = Color(0.0, 0.0, 0.0, 0.26)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	selection_panel = PanelContainer.new()
	selection_panel.name = "DeckSelectionGlassPanel"
	selection_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	selection_panel.clip_contents = true
	selection_panel.add_theme_stylebox_override("panel", make_selection_panel_style())
	add_child(selection_panel)

	panel_blur = ColorRect.new()
	panel_blur.name = "PanelBlur"
	panel_blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_blur.color = Color.WHITE
	panel_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_blur.material = make_selection_blur_material()
	selection_panel.add_child(panel_blur)

	var margin := MarginContainer.new()
	margin.name = "ContentMargin"
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	selection_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	margin.add_child(rows)

	title_label = Label.new()
	title_label.text = "CHOOSE YOUR WAR DECK"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	rows.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Select the saved deck you will bring into this battle."
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.82))
	rows.add_child(subtitle_label)

	options_grid = GridContainer.new()
	options_grid.columns = 5
	options_grid.add_theme_constant_override("h_separation", 12)
	options_grid.add_theme_constant_override("v_separation", 12)
	rows.add_child(options_grid)

	_layout_to_viewport()
	
	
func make_selection_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(18)
	style.shadow_size = 0
	return style


func make_selection_blur_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_lod = 3.8;
uniform vec4 glass_tint = vec4(0.03, 0.035, 0.045, 0.48);

void fragment() {
	vec2 panel_size = vec2(920.0, 352.0);
	float radius = 20.0;

	vec2 p = (UV - vec2(0.5)) * panel_size;
	vec2 q = abs(p) - (panel_size * 0.5 - vec2(radius));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float mask = 1.0 - smoothstep(-2.0, 2.0, d);

	vec3 blurred_world = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb;
	vec3 tinted = mix(blurred_world, glass_tint.rgb, glass_tint.a);

	COLOR = vec4(tinted, 0.86 * mask);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("blur_lod", 3.8)
	material.set_shader_parameter("glass_tint", Color(0.03, 0.035, 0.045, 0.48))
	return material


func make_deck_slot_button_style(bg: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.shadow_size = 0
	return style


func style_deck_slot_button(button: Button, valid: bool) -> void:
	var normal_bg := Color(0.025, 0.025, 0.028, 0.74) if valid else Color(0.012, 0.012, 0.014, 0.36)
	var hover_bg := Color(0.10, 0.10, 0.11, 0.82)
	var pressed_bg := Color(0.15, 0.15, 0.16, 0.90)
	var disabled_bg := Color(0.012, 0.012, 0.014, 0.34)

	button.add_theme_stylebox_override(
		"normal",
		make_deck_slot_button_style(normal_bg, Color(1.0, 1.0, 1.0, 0.12), 1)
	)
	button.add_theme_stylebox_override(
		"hover",
		make_deck_slot_button_style(hover_bg, Color(1.0, 1.0, 1.0, 0.62), 1)
	)
	button.add_theme_stylebox_override(
		"pressed",
		make_deck_slot_button_style(pressed_bg, Color(1.0, 1.0, 1.0, 0.82), 1)
	)
	button.add_theme_stylebox_override(
		"disabled",
		make_deck_slot_button_style(disabled_bg, Color(1.0, 1.0, 1.0, 0.05), 1)
	)

	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.28))
	button.add_theme_font_size_override("font_size", 16)


func _layout_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	position = Vector2.ZERO
	size = viewport_size
	if selection_panel == null:
		return
	var panel_size := Vector2(920.0, 352.0)
	selection_panel.position = (viewport_size - panel_size) * 0.5
	selection_panel.size = panel_size


func show_selection(
	deck_summaries: Array[Dictionary],
	title_text: String = "CHOOSE YOUR WAR DECK",
	subtitle_text: String = "Select the saved deck you will bring into this battle.",
	include_random_ai_deck: bool = false
) -> void:
	_layout_to_viewport()
	mouse_filter = Control.MOUSE_FILTER_STOP

	if title_label != null:
		title_label.text = title_text

	if subtitle_label != null:
		subtitle_label.text = subtitle_text

	for child in options_grid.get_children():
		child.queue_free()

	var has_valid_deck := false

	if include_random_ai_deck:
		var random_button := Button.new()
		random_button.text = "RANDOM SYNERGY\nAI Builds Deck\n40 / 40 CARDS"
		random_button.custom_minimum_size = Vector2(170, 105)
		random_button.focus_mode = Control.FOCUS_NONE
		random_button.disabled = false
		random_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		random_button.pressed.connect(_on_deck_pressed.bind(SPECIAL_RANDOM_AI_DECK_SLOT))
		style_deck_slot_button(random_button, true)
		options_grid.add_child(random_button)
		has_valid_deck = true

	for summary in deck_summaries:
		var slot_index := int(summary.get("slot_index", -1))
		var card_count := int(summary.get("card_count", 0))
		var valid := bool(summary.get("valid", false))
		has_valid_deck = has_valid_deck or valid

		var button := Button.new()
		button.text = (
			"SLOT " + str(slot_index + 1) + "\n"
			+ String(summary.get("deck_name", "Deck")) + "\n"
			+ str(card_count) + " / 40 CARDS"
		)
		button.custom_minimum_size = Vector2(170, 105)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = not valid
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_deck_pressed.bind(slot_index))
		style_deck_slot_button(button, valid)
		options_grid.add_child(button)

	if not has_valid_deck:
		var fallback := Button.new()
		fallback.text = "PROTOTYPE DECK\n40 CARDS"
		fallback.custom_minimum_size = Vector2(170, 105)
		fallback.focus_mode = Control.FOCUS_NONE
		fallback.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		fallback.pressed.connect(_on_deck_pressed.bind(-1))
		style_deck_slot_button(fallback, true)
		options_grid.add_child(fallback)

	show()
	move_to_front()


func _on_deck_pressed(slot_index: int) -> void:
	if SceneLoader != null and SceneLoader.has_method("play_select_button"):
		SceneLoader.play_select_button()

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	deck_selected.emit(slot_index)
