class_name PrototypeMenu
extends Control

static var skip_intro_once := false

static var selected_ai_difficulty := 2

const AI_DIFFICULTY_LABELS := [
	"NOVICE",
	"SOLDIER",
	"COMMANDER",
	"WARLORD",
	"GRANDMASTER"
]

const AI_DIFFICULTY_DESCRIPTIONS := [
	"1/5",
	"2/5",
	"3/5",
	"4/5",
	"5/5"
]

const BATTLE_SCENE_PATH := "res://battlefield/battlefield_3d.tscn"
const DECK_BUILDER_SCENE_PATH := "res://ui/deck_builder.tscn"

# Main-menu composition controls. These are the values to edit when repositioning
# or resizing the logo and its button group.
const LOGO_CENTER_X_RATIO := 0.34
const LOGO_TOP_RATIO := 0.15
const LOGO_WIDTH_RATIO := 0.40
const LOGO_MAX_WIDTH := 760.0
const LOGO_ASPECT_RATIO := 16.0 / 9.0
const BUTTONS_WIDTH := 620.0
const BUTTONS_HEIGHT := 236.0
const BUTTONS_GAP_BELOW_LOGO := 4.0
const BUTTONS_X_OFFSET := 0.0
const BUTTONS_Y_OFFSET := 0.0
const DIFFICULTY_ROW_WIDTH := 620.0
const DIFFICULTY_ARROW_WIDTH := 48.0
const DIFFICULTY_LABEL_WIDTH := 480.0
const INTRO_LOGO_WIDTH_RATIO := 1
const INTRO_LOGO_MAX_WIDTH := 1500
const INTRO_LOGO_ASPECT_RATIO := 16.0 / 9.0

@onready var menu_background: TextureRect = $MenuBackground
@onready var menu_logo: TextureRect = $MenuLogo
@onready var intro_logo: TextureRect = $IntroLogo
@onready var menu_choices: VBoxContainer = $MenuChoices
@onready var intro_curtain: ColorRect = $IntroCurtain
@onready var continue_prompt: Label = $PressAnyButton

var intro_can_continue := false
var intro_transitioning := false
var ai_difficulty_label: Label = null


func _ready() -> void:
	var skip_intro := skip_intro_once
	if skip_intro:
		skip_intro_once = false
	else:
		await get_tree().process_frame

	_apply_node_order()
	_apply_layout()
	build_menu()
	if skip_intro:
		show_main_menu_immediately()
	else:
		play_intro()


func show_main_menu_immediately() -> void:
	intro_can_continue = false
	intro_transitioning = false
	intro_curtain.visible = false
	intro_logo.visible = false
	continue_prompt.visible = false
	menu_background.visible = true
	menu_background.modulate.a = 1.0
	menu_logo.visible = true
	menu_logo.modulate.a = 1.0
	menu_choices.visible = true
	menu_choices.modulate.a = 1.0
	menu_choices.mouse_filter = Control.MOUSE_FILTER_PASS
	Cursors.use_normal()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if not is_node_ready():
			return
		_apply_layout()


func _apply_node_order() -> void:
	move_child(menu_background, 0)
	move_child(intro_curtain, 1)
	move_child(intro_logo, 2)
	move_child(continue_prompt, 3)
	move_child(menu_logo, 4)
	move_child(menu_choices, 5)


func _apply_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var screen_size := get_viewport_rect().size

	# Background image.
	menu_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	menu_background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Black intro curtain.
	intro_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Logo placement.
	# This puts the logo on the left/middle like your reference image.
	var logo_width: float = minf(screen_size.x * LOGO_WIDTH_RATIO, LOGO_MAX_WIDTH)
	var logo_height: float = logo_width / LOGO_ASPECT_RATIO

	var logo_center_x: float = screen_size.x * LOGO_CENTER_X_RATIO
	var logo_top: float = screen_size.y * LOGO_TOP_RATIO

	# Set texture sizing behavior before assigning size. Otherwise Godot clamps
	# this node back to the source image's large native dimensions.
	menu_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	menu_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_logo.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu_logo.position = Vector2(
		logo_center_x - logo_width * 0.5,
		logo_top
	)
	menu_logo.size = Vector2(logo_width, logo_height)

	# Dedicated black-screen logo. Its texture is intentionally left for you to
	# assign on the IntroLogo node in the scene Inspector.
	var intro_logo_width: float = minf(
		screen_size.x * INTRO_LOGO_WIDTH_RATIO,
		INTRO_LOGO_MAX_WIDTH
	)
	var intro_logo_height: float = intro_logo_width / INTRO_LOGO_ASPECT_RATIO
	intro_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	intro_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	intro_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_logo.set_anchors_preset(Control.PRESET_TOP_LEFT)
	intro_logo.position = Vector2(
		(screen_size.x - intro_logo_width) * 0.5,
		(screen_size.y - intro_logo_height) * 0.1
	)
	intro_logo.size = Vector2(intro_logo_width, intro_logo_height)

	# Buttons underneath logo.
	var buttons_top: float = logo_top + logo_height + BUTTONS_GAP_BELOW_LOGO

	menu_choices.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu_choices.position = Vector2(
		logo_center_x - BUTTONS_WIDTH * 0.5 + BUTTONS_X_OFFSET,
		buttons_top + BUTTONS_Y_OFFSET
	)
	menu_choices.size = Vector2(BUTTONS_WIDTH, BUTTONS_HEIGHT)

	# Press any button prompt.
	var prompt_width: float = 700.0
	var prompt_height: float = 200.0
	var prompt_bottom_margin: float = 70.0

	continue_prompt.set_anchors_preset(Control.PRESET_TOP_LEFT)
	continue_prompt.position = Vector2(
		(screen_size.x - prompt_width) * 0.5,
		screen_size.y - prompt_bottom_margin - prompt_height
	)
	continue_prompt.size = Vector2(prompt_width, prompt_height)
	continue_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	continue_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE


func build_menu() -> void:
	menu_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_choices.add_theme_constant_override("separation", 4)

	for child in menu_choices.get_children():
		child.queue_free()

	var start_button := make_menu_button("START BATTLE")
	start_button.pressed.connect(_on_start_battle_pressed)
	menu_choices.add_child(start_button)

	var difficulty_row := make_difficulty_selector()
	menu_choices.add_child(difficulty_row)

	var deck_button := make_menu_button("DECK BUILDER")
	deck_button.pressed.connect(_on_deck_builder_pressed)
	menu_choices.add_child(deck_button)

	var quit_button := make_menu_button("QUIT")
	quit_button.pressed.connect(_on_quit_pressed)
	menu_choices.add_child(quit_button)


func get_ai_difficulty_label() -> String:
	var index := clampi(selected_ai_difficulty, 0, AI_DIFFICULTY_LABELS.size() - 1)
	return AI_DIFFICULTY_LABELS[index]


func get_ai_difficulty_description() -> String:
	var index := clampi(selected_ai_difficulty, 0, AI_DIFFICULTY_DESCRIPTIONS.size() - 1)
	return AI_DIFFICULTY_DESCRIPTIONS[index]


func get_ai_difficulty_display_text() -> String:
	return "AI DIFFICULTY: " + get_ai_difficulty_label() + "  " + get_ai_difficulty_description()


func set_ai_difficulty_by_delta(delta: int) -> void:
	selected_ai_difficulty = clampi(
		selected_ai_difficulty + delta,
		0,
		AI_DIFFICULTY_LABELS.size() - 1
	)

	refresh_ai_difficulty_label()


func refresh_ai_difficulty_label() -> void:
	if ai_difficulty_label != null:
		ai_difficulty_label.text = get_ai_difficulty_display_text()


func _on_ai_difficulty_decreased() -> void:
	set_ai_difficulty_by_delta(-1)


func _on_ai_difficulty_increased() -> void:
	set_ai_difficulty_by_delta(1)
	
func make_difficulty_selector() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(DIFFICULTY_ROW_WIDTH, 48)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", 8)

	var left_button := make_menu_button("<")
	left_button.custom_minimum_size = Vector2(DIFFICULTY_ARROW_WIDTH, 48)
	left_button.pressed.connect(_on_ai_difficulty_decreased)
	row.add_child(left_button)

	var label_holder := Control.new()
	label_holder.custom_minimum_size = Vector2(DIFFICULTY_LABEL_WIDTH, 48)
	label_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(label_holder)

	ai_difficulty_label = Label.new()
	ai_difficulty_label.text = get_ai_difficulty_display_text()
	ai_difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ai_difficulty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ai_difficulty_label.clip_text = true
	ai_difficulty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ai_difficulty_label.add_theme_font_size_override("font_size", 25)
	ai_difficulty_label.add_theme_color_override("font_color", Color(0.86, 0.85, 0.82, 1.0))
	ai_difficulty_label.add_theme_constant_override("outline_size", 0)
	ai_difficulty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label_holder.add_child(ai_difficulty_label)

	var right_button := make_menu_button(">")
	right_button.custom_minimum_size = Vector2(DIFFICULTY_ARROW_WIDTH, 48)
	right_button.pressed.connect(_on_ai_difficulty_increased)
	row.add_child(right_button)

	return row


func play_intro() -> void:
	intro_can_continue = false
	intro_transitioning = false

	intro_curtain.visible = true
	intro_curtain.color = Color.BLACK
	intro_curtain.modulate.a = 1.0

	menu_background.visible = true
	menu_background.modulate.a = 1.0

	menu_logo.visible = false
	menu_logo.modulate.a = 0.0

	intro_logo.visible = true
	intro_logo.modulate.a = 0.0

	continue_prompt.visible = true
	continue_prompt.text = "PRESS ANY BUTTON TO CONTINUE."
	continue_prompt.modulate.a = 0.0

	menu_choices.visible = false
	menu_choices.modulate.a = 0.0
	menu_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE

	Cursors.use_normal()

	var reveal := create_tween()
	reveal.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reveal.tween_interval(0.35)
	reveal.tween_property(intro_logo, "modulate:a", 1.0, 1.8)
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

	menu_logo.visible = true
	menu_choices.visible = true

	var transition := create_tween()
	transition.set_parallel(true)
	transition.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	transition.tween_property(intro_curtain, "modulate:a", 0.0, 1.0)
	transition.tween_property(intro_logo, "modulate:a", 0.0, 0.65)
	transition.tween_property(continue_prompt, "modulate:a", 0.0, 0.35)
	transition.tween_property(menu_logo, "modulate:a", 1.0, 1.0).set_delay(0.25)
	transition.tween_property(menu_choices, "modulate:a", 1.0, 1.0).set_delay(0.35)

	await transition.finished

	intro_curtain.visible = false
	intro_logo.visible = false
	continue_prompt.visible = false
	menu_choices.mouse_filter = Control.MOUSE_FILTER_PASS
	intro_transitioning = false


func make_menu_button(label_text: String) -> Button:
	var button := Button.new()

	button.text = label_text
	button.custom_minimum_size = Vector2(420, 48)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.flat = true
	button.pivot_offset = button.custom_minimum_size * 0.5

	button.add_theme_font_size_override("font_size", 25)

	button.add_theme_color_override("font_color", Color(0.86, 0.85, 0.82, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.94, 0.94, 0.94, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.86, 0.85, 0.82, 1.0))

	button.add_theme_constant_override("outline_size", 0)

	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)
	button.add_theme_stylebox_override("disabled", empty_style)

	button.mouse_entered.connect(_on_menu_button_hovered.bind(button))
	button.mouse_exited.connect(_on_menu_button_unhovered.bind(button))
	button.resized.connect(_center_button_pivot.bind(button))

	return button


func _center_button_pivot(button: Button) -> void:
	button.pivot_offset = button.size * 0.5


func _on_menu_button_hovered(button: Button) -> void:
	if button.disabled:
		return

	Cursors.use_pointing()

	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_constant_override("outline_size", 0)

	var tween := button.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.035, 1.035), 0.12)


func _on_menu_button_unhovered(button: Button) -> void:
	if button.disabled:
		return

	Cursors.use_normal()

	button.add_theme_color_override("font_color", Color(0.86, 0.85, 0.82, 1.0))
	button.add_theme_constant_override("outline_size", 0)

	var tween := button.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.12)


func _on_start_battle_pressed() -> void:
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)


func _on_deck_builder_pressed() -> void:
	get_tree().change_scene_to_file(DECK_BUILDER_SCENE_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()
