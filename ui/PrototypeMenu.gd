class_name PrototypeMenu
extends Control

const BATTLE_SCENE_PATH := "res://battlefield/battlefield_3d.tscn"
const DECK_BUILDER_SCENE_PATH := "res://ui/deck_builder.tscn"

@onready var menu_background: TextureRect = $MenuBackground
@onready var menu_logo: TextureRect = $MenuLogo
@onready var menu_choices: VBoxContainer = $MenuChoices
@onready var intro_curtain: ColorRect = $IntroCurtain
@onready var continue_prompt: Label = $PressAnyButton

var intro_can_continue := false
var intro_transitioning := false

func _ready() -> void:
	build_menu()
	play_intro()


func build_menu() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	menu_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_choices.add_theme_constant_override("separation", 4)

	var start_button := make_menu_button("START BATTLE")
	start_button.pressed.connect(_on_start_battle_pressed)
	menu_choices.add_child(start_button)

	var deck_button := make_menu_button("DECK BUILDER")
	deck_button.pressed.connect(_on_deck_builder_pressed)
	menu_choices.add_child(deck_button)

	var quit_button := make_menu_button("QUIT")
	quit_button.pressed.connect(_on_quit_pressed)
	menu_choices.add_child(quit_button)


func play_intro() -> void:
	intro_curtain.visible = true
	intro_curtain.color = Color.BLACK
	menu_logo.modulate.a = 0.0
	continue_prompt.modulate.a = 0.0
	menu_choices.modulate.a = 0.0
	menu_choices.visible = false
	menu_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Cursors.use_normal()

	var reveal := create_tween()
	reveal.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reveal.tween_interval(0.35)
	reveal.tween_property(menu_logo, "modulate:a", 1.0, 1.8)
	reveal.tween_interval(0.25)
	reveal.tween_property(continue_prompt, "modulate:a", 1.0, 0.75)
	await reveal.finished
	intro_can_continue = true


func _input(event: InputEvent) -> void:
	if not intro_can_continue or intro_transitioning:
		return
	var continue_pressed := false
	if event is InputEventKey:
		continue_pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton:
		continue_pressed = event.pressed
	elif event is InputEventJoypadButton:
		continue_pressed = event.pressed
	elif event is InputEventScreenTouch:
		continue_pressed = event.pressed
	if continue_pressed:
		show_main_menu()


func show_main_menu() -> void:
	intro_can_continue = false
	intro_transitioning = true
	menu_choices.visible = true
	var transition := create_tween()
	transition.set_parallel(true)
	transition.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	transition.tween_property(intro_curtain, "modulate:a", 0.0, 1.0)
	transition.tween_property(continue_prompt, "modulate:a", 0.0, 0.35)
	transition.tween_property(menu_choices, "modulate:a", 1.0, 1.0).set_delay(0.35)
	await transition.finished
	intro_curtain.visible = false
	continue_prompt.visible = false
	menu_choices.mouse_filter = Control.MOUSE_FILTER_PASS
	intro_transitioning = false

func make_menu_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(360, 52)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", Color(0.93, 0.86, 0.70, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.42, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.76, 0.25, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.12, 0.055, 0.01, 0.95))
	button.add_theme_constant_override("outline_size", 4)
	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)
	button.mouse_entered.connect(_on_menu_button_hovered.bind(button))
	button.mouse_exited.connect(_on_menu_button_unhovered.bind(button))
	button.resized.connect(_center_button_pivot.bind(button))
	return button


func _center_button_pivot(button: Button) -> void:
	button.pivot_offset = button.size * 0.5


func _on_menu_button_hovered(button: Button) -> void:
	Cursors.use_pointing()
	button.add_theme_constant_override("outline_size", 8)
	var tween := button.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.045, 1.045), 0.12)


func _on_menu_button_unhovered(button: Button) -> void:
	Cursors.use_normal()
	button.add_theme_constant_override("outline_size", 4)
	var tween := button.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.12)


func _on_start_battle_pressed() -> void:
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)


func _on_deck_builder_pressed() -> void:
	get_tree().change_scene_to_file(DECK_BUILDER_SCENE_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()
