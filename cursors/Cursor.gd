extends Node

var normal_cursor: Texture2D = preload("res://cursors/hand_open.png")
var pointing_cursor: Texture2D = preload("res://cursors/hand_point.png")
var grab_cursor: Texture2D = preload("res://cursors/hand_grab.png")

var normal_hotspot := Vector2(24, 24)
var pointing_hotspot := Vector2(40, 4)
var grab_hotspot := Vector2(38, 38)


func _ready() -> void:
	use_normal()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				use_grab()
			else:
				use_normal()


func use_normal() -> void:
	Input.set_custom_mouse_cursor(normal_cursor, Input.CURSOR_ARROW, normal_hotspot)
	Input.set_custom_mouse_cursor(pointing_cursor, Input.CURSOR_POINTING_HAND, pointing_hotspot)


func use_grab() -> void:
	Input.set_custom_mouse_cursor(grab_cursor, Input.CURSOR_ARROW, grab_hotspot)
	Input.set_custom_mouse_cursor(grab_cursor, Input.CURSOR_POINTING_HAND, grab_hotspot)
