extends Node

var normal_cursor: Texture2D = preload("res://cursors/hand_open.png")
var pointing_cursor: Texture2D = preload("res://cursors/hand_point.png")
var grab_cursor: Texture2D = preload("res://cursors/hand_grab.png")


var normal_hotspot := Vector2(24, 24)
var pointing_hotspot := Vector2(40, 4)
var grab_hotspot := Vector2(38, 38)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	use_normal()
	
	Input.set_custom_mouse_cursor(pointing_cursor, Input.CURSOR_POINTING_HAND, pointing_hotspot)

func use_normal() -> void:
	Input.set_custom_mouse_cursor(normal_cursor, Input.CURSOR_ARROW, normal_hotspot)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func use_grab() -> void:
	Input.set_custom_mouse_cursor(grab_cursor, Input.CURSOR_ARROW, grab_hotspot)
