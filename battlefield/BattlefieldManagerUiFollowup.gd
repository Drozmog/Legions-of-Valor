class_name BattlefieldManagerUiFollowup
extends "res://battlefield/BattlefieldManagerIconPatch.gd"

const MOBILITY_PROMPT_ICON_PATH := "res://ui/ability_icons/mobility.png"
const MOBILITY_CHOICE_PANEL_WIDTH := 360.0
const MOBILITY_CHOICE_PANEL_HEIGHT := 58.0
const MOBILITY_CHOICE_PANEL_Y_OFFSET := 92.0


func show_mobility_prompt(text: String) -> void:
	if not phase_title_interaction_locked:
		phase_title_interaction_locked = true
		set_blurred_modal_input_blocked(true)
	phase_title_overlay.text = ""
	phase_title_overlay.modulate.a = 0.0
	phase_blur_backdrop.modulate.a = 0.0
	phase_blur_material.set_shader_parameter("blur_lod", 0.0)
	var row_root := get_or_create_mobility_prompt_row()
	var row_label := row_root.get_node_or_null("CenterRow/PromptLabel") as Label
	if row_label != null:
		row_label.text = text
		row_label.add_theme_font_size_override("font_size", 32 if text.length() > 24 else 44)
	row_root.visible = true
	row_root.modulate.a = 0.0
	phase_title_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	phase_title_tween.tween_property(phase_blur_backdrop, "modulate:a", 0.92, 0.28)
	phase_title_tween.parallel().tween_property(row_root, "modulate:a", 1.0, 0.28)
	phase_title_tween.parallel().tween_method(set_phase_blur_amount, 0.0, 2.5, 0.28)


func hide_mobility_prompt() -> void:
	var row_root := get_node_or_null("UI/MobilityPromptRow") as Control
	phase_title_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	phase_title_tween.tween_property(phase_blur_backdrop, "modulate:a", 0.0, 0.28)
	if row_root != null:
		phase_title_tween.parallel().tween_property(row_root, "modulate:a", 0.0, 0.28)
	phase_title_tween.parallel().tween_method(set_phase_blur_amount, 2.5, 0.0, 0.28)
	await phase_title_tween.finished
	if row_root != null:
		row_root.visible = false
	_finish_phase_title_interaction_lock()


func prompt_mobility_choice(text: String, accept_text: String, decline_text: String) -> bool:
	show_mobility_prompt(text)
	mobility_choice_panel = PanelContainer.new()
	mobility_choice_panel.name = "MobilityChoicePanel"
	mobility_choice_panel.z_index = 132
	mobility_choice_panel.anchor_left = 0.5
	mobility_choice_panel.anchor_right = 0.5
	mobility_choice_panel.anchor_top = 0.5
	mobility_choice_panel.anchor_bottom = 0.5
	mobility_choice_panel.offset_left = -MOBILITY_CHOICE_PANEL_WIDTH * 0.5
	mobility_choice_panel.offset_right = MOBILITY_CHOICE_PANEL_WIDTH * 0.5
	mobility_choice_panel.offset_top = MOBILITY_CHOICE_PANEL_Y_OFFSET
	mobility_choice_panel.offset_bottom = MOBILITY_CHOICE_PANEL_Y_OFFSET + MOBILITY_CHOICE_PANEL_HEIGHT
	mobility_choice_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.018, 0.025, 0.74)
	style.border_color = Color(0.48, 0.68, 1.0, 0.58)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	mobility_choice_panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	mobility_choice_panel.add_child(row)
	var accept := Button.new()
	accept.text = accept_text
	accept.focus_mode = Control.FOCUS_NONE
	accept.custom_minimum_size = Vector2(150.0, 48.0)
	accept.pressed.connect(func(): mobility_choice_made.emit(true))
	row.add_child(accept)
	var decline := Button.new()
	decline.text = decline_text
	decline.focus_mode = Control.FOCUS_NONE
	decline.custom_minimum_size = Vector2(150.0, 48.0)
	decline.pressed.connect(func(): mobility_choice_made.emit(false))
	row.add_child(decline)
	$UI.add_child(mobility_choice_panel)
	var result: bool = await mobility_choice_made
	mobility_choice_panel.queue_free()
	mobility_choice_panel = null
	await hide_mobility_prompt()
	return result


func get_or_create_mobility_prompt_row() -> Control:
	var existing := get_node_or_null("UI/MobilityPromptRow") as Control
	if existing != null:
		return existing
	var root := Control.new()
	root.name = "MobilityPromptRow"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 121
	root.visible = false
	root.modulate.a = 0.0
	$UI.add_child(root)
	var center_row := HBoxContainer.new()
	center_row.name = "CenterRow"
	center_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center_row.add_theme_constant_override("separation", 18)
	root.add_child(center_row)
	var icon := TextureRect.new()
	icon.name = "PromptIcon"
	icon.custom_minimum_size = Vector2(58.0, 58.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(MOBILITY_PROMPT_ICON_PATH):
		icon.texture = load(MOBILITY_PROMPT_ICON_PATH) as Texture2D
	center_row.add_child(icon)
	var label := Label.new()
	label.name = "PromptLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.98))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.035, 0.92))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.38))
	label.add_theme_constant_override("shadow_outline_size", 5)
	center_row.add_child(label)
	return root
