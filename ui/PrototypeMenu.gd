class_name PrototypeMenu
extends Control

const BATTLE_SCENE_PATH := "res://battlefield/battlefield_3d.tscn"
const DECK_BUILDER_SCENE_PATH := "res://ui/deck_builder.tscn"

var title_label: Label
var subtitle_label: Label
var status_label: Label

func _ready() -> void:
	build_menu()


func build_menu() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.color = Color(0.025, 0.018, 0.012, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var vignette := ColorRect.new()
	vignette.color = Color(0.11, 0.075, 0.035, 0.56)
	vignette.anchor_left = 0.06
	vignette.anchor_right = 0.94
	vignette.anchor_top = 0.08
	vignette.anchor_bottom = 0.92
	add_child(vignette)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -360
	panel.offset_right = 360
	panel.offset_top = -260
	panel.offset_bottom = 260
	panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.04, 0.028, 0.018, 0.94), Color(0.78, 0.58, 0.22, 1.0), 2))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	title_label = Label.new()
	title_label.text = "LEGIONS OF VALOR"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45, 1.0))
	vbox.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Prototype Command Table"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.70, 0.55, 1.0))
	vbox.add_child(subtitle_label)

	vbox.add_child(make_rule())

	var start_button := make_menu_button("Start Battle", "Enter the current battlefield prototype.")
	start_button.pressed.connect(_on_start_battle_pressed)
	vbox.add_child(start_button)

	var deck_button := make_menu_button("Deck Builder", "Browse cards, build a deck rack, and save it for battle.")
	deck_button.pressed.connect(_on_deck_builder_pressed)
	vbox.add_child(deck_button)

	var quit_button := make_menu_button("Quit", "Close the prototype.")
	quit_button.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_button)

	status_label = Label.new()
	status_label.text = "Phase 19.3: prototype menu + deck builder foundation"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color(0.67, 0.61, 0.50, 1.0))
	vbox.add_child(status_label)


func make_menu_button(label_text: String, tooltip_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.tooltip_text = tooltip_text
	button.custom_minimum_size = Vector2(420, 54)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	return button


func make_rule() -> HSeparator:
	var rule := HSeparator.new()
	rule.custom_minimum_size = Vector2(1, 20)
	return rule


func make_panel_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.set_corner_radius_all(8)
	return style


func _on_start_battle_pressed() -> void:
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)


func _on_deck_builder_pressed() -> void:
	get_tree().change_scene_to_file(DECK_BUILDER_SCENE_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()
