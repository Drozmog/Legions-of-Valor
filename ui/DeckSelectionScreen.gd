class_name DeckSelectionScreen
extends Control

signal deck_selected(slot_index: int)

var options_grid: GridContainer

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
	dim.color = Color(0.0, 0.0, 0.0, 0.34)
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
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	selection_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "CHOOSE YOUR WAR DECK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42, 1.0))
	rows.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Select the saved deck you will bring into this battle."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color.WHITE)
	rows.add_child(subtitle)

	options_grid = GridContainer.new()
	options_grid.columns = 5
	options_grid.add_theme_constant_override("h_separation", 12)
	options_grid.add_theme_constant_override("v_separation", 12)
	rows.add_child(options_grid)

	_layout_to_viewport()
	
	
func make_selection_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.075, 0.040, 0.46)
	style.border_color = Color(1.0, 0.72, 0.22, 0.88)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 8
	return style


func make_selection_blur_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_lod = 3.8;
uniform vec4 glass_tint = vec4(0.10, 0.065, 0.035, 0.38);

void fragment() {
	vec3 blurred_world = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb;
	vec3 tinted = mix(blurred_world, glass_tint.rgb, glass_tint.a);
	COLOR = vec4(tinted, 0.82);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("blur_lod", 3.8)
	material.set_shader_parameter("glass_tint", Color(0.10, 0.065, 0.035, 0.38))
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
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	style.shadow_size = 3
	return style


func style_deck_slot_button(button: Button, valid: bool) -> void:
	var normal_bg := Color(0.045, 0.035, 0.028, 0.74) if valid else Color(0.025, 0.022, 0.020, 0.42)
	var hover_bg := Color(0.14, 0.10, 0.060, 0.82)
	var pressed_bg := Color(0.18, 0.12, 0.065, 0.90)
	var disabled_bg := Color(0.020, 0.018, 0.016, 0.42)

	button.add_theme_stylebox_override(
		"normal",
		make_deck_slot_button_style(normal_bg, Color(1.0, 1.0, 1.0, 0.10), 1)
	)
	button.add_theme_stylebox_override(
		"hover",
		make_deck_slot_button_style(hover_bg, Color(1.0, 0.78, 0.32, 0.72), 2)
	)
	button.add_theme_stylebox_override(
		"pressed",
		make_deck_slot_button_style(pressed_bg, Color(1.0, 0.84, 0.42, 0.90), 2)
	)
	button.add_theme_stylebox_override(
		"disabled",
		make_deck_slot_button_style(disabled_bg, Color(1.0, 1.0, 1.0, 0.06), 1)
	)

	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.34))
	button.add_theme_font_size_override("font_size", 16)


func _layout_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	position = Vector2.ZERO
	size = viewport_size
	if selection_panel == null:
		return
	var panel_size := Vector2(980.0, 430.0)
	selection_panel.position = (viewport_size - panel_size) * 0.5
	selection_panel.size = panel_size


func show_selection(deck_summaries: Array[Dictionary]) -> void:
	_layout_to_viewport()
	mouse_filter = Control.MOUSE_FILTER_STOP

	for child in options_grid.get_children():
		child.queue_free()

	var has_valid_deck := false

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
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	deck_selected.emit(slot_index)
