extends Node

var normal_cursor: Texture2D = preload("res://cursors/hand_open.png")
var pointing_cursor: Texture2D = preload("res://cursors/hand_point.png")
var grab_cursor: Texture2D = preload("res://cursors/hand_grab.png")

var normal_hotspot := Vector2(24, 24)
var pointing_hotspot := Vector2(8, 8)
var grab_hotspot := Vector2(38, 38)
var current_mode := ""


func _ready() -> void:
	use_normal()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Individual interactions request the grab cursor only after a real object
		# has been picked up. Releasing always prevents a stale closed hand.
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and current_mode == "grab":
			use_normal()


func use_normal() -> void:
	if current_mode == "normal":
		return
	current_mode = "normal"
	Input.set_custom_mouse_cursor(normal_cursor, Input.CURSOR_ARROW, normal_hotspot)
	Input.set_custom_mouse_cursor(pointing_cursor, Input.CURSOR_POINTING_HAND, pointing_hotspot)


func use_pointing() -> void:
	if current_mode == "pointing":
		return
	current_mode = "pointing"
	Input.set_custom_mouse_cursor(pointing_cursor, Input.CURSOR_ARROW, pointing_hotspot)
	Input.set_custom_mouse_cursor(pointing_cursor, Input.CURSOR_POINTING_HAND, pointing_hotspot)


func use_grab() -> void:
	if current_mode == "grab":
		return
	current_mode = "grab"
	Input.set_custom_mouse_cursor(grab_cursor, Input.CURSOR_ARROW, grab_hotspot)
	Input.set_custom_mouse_cursor(grab_cursor, Input.CURSOR_POINTING_HAND, grab_hotspot)
