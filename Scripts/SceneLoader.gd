extends Node

const LOADING_SCREEN_PATH := "res://Scenes/LoadingScreen.tscn"
const SFX_FOLDER := "res://Audio/SFX/"
const MAX_SIMULTANEOUS_SFX := 8

var target_scene_path: String = ""

var sfx_players: Array[AudioStreamPlayer] = []
var cached_sfx: Dictionary = {}


func _ready() -> void:
	for i in range(MAX_SIMULTANEOUS_SFX):
		var player := AudioStreamPlayer.new()
		add_child(player)
		sfx_players.append(player)


func go_to_scene(scene_path: String, sfx_name: String = "menu_button") -> void:
	target_scene_path = scene_path

	if sfx_name != "":
		play_sfx(sfx_name)

	var error := get_tree().change_scene_to_file(LOADING_SCREEN_PATH)

	if error != OK:
		push_error("Could not open loading screen: " + LOADING_SCREEN_PATH)


func play_sfx(sfx_name: String) -> void:
	var stream := get_sfx(sfx_name)

	if stream == null:
		return

	var player := get_free_sfx_player()
	player.stream = stream
	player.play()


func get_sfx(sfx_name: String) -> AudioStream:
	if cached_sfx.has(sfx_name):
		return cached_sfx[sfx_name]

	var path := SFX_FOLDER + sfx_name + ".wav"

	if not ResourceLoader.exists(path):
		push_warning("Missing SFX file: " + path)
		return null

	var stream := load(path) as AudioStream

	if stream == null:
		push_warning("Could not load SFX file: " + path)
		return null

	cached_sfx[sfx_name] = stream
	return stream


func get_free_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players:
		if not player.playing:
			return player

	return sfx_players[0]


func play_menu_button() -> void:
	play_sfx("menu_button")


func play_attack_button() -> void:
	play_sfx("attack_button")


func play_check_button() -> void:
	play_sfx("check_button")


func play_pass_button() -> void:
	play_sfx("pass_button")


func play_back_button() -> void:
	play_sfx("back_button")


func play_inspect_button() -> void:
	play_sfx("inspect_button")


func play_select_button() -> void:
	play_sfx("select_button")


func play_board_action_button(action_id: int) -> void:
	match action_id:
		0:
			play_attack_button()
		1:
			play_check_button()
		2:
			play_pass_button()
		3:
			play_inspect_button()
		4:
			play_select_button()
		_:
			play_menu_button()
