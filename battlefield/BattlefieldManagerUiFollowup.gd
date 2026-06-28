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
