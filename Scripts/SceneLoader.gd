extends Node

const LOADING_SCREEN_PATH := "res://Scenes/LoadingScreen.tscn"
const MENU_CLICK_SFX := preload("res://Audio/SFX/menu_click.wav")

var target_scene_path: String = ""

var sfx_player: AudioStreamPlayer


func _ready() -> void:
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)


func go_to_scene(scene_path: String) -> void:
	target_scene_path = scene_path
	play_menu_click()
	get_tree().change_scene_to_file(LOADING_SCREEN_PATH)


func play_menu_click() -> void:
	if MENU_CLICK_SFX == null:
		return

	sfx_player.stream = MENU_CLICK_SFX
	sfx_player.play()
