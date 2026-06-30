extends Node

const LOADING_SCREEN_PATH := "res://ui/loading_screen/loading_screen.tscn"
const MENU_MUSIC_PATH := "res://Audio/Music/main_menu_theme.ogg"
const SFX_FOLDER := "res://Audio/SFX/"
const MAX_SIMULTANEOUS_SFX := 8

var target_scene_path: String = ""

var music_player: AudioStreamPlayer = null
var sfx_players: Array[AudioStreamPlayer] = []
var cached_sfx: Dictionary = {}


func _ready() -> void:
	_ensure_music_player()
	_ensure_sfx_players()


func _ensure_music_player() -> void:
	if music_player != null and is_instance_valid(music_player):
		return

	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = _get_audio_bus_name("Music")
	add_child(music_player)

	if not music_player.finished.is_connected(_on_music_finished):
		music_player.finished.connect(_on_music_finished)


func _ensure_sfx_players() -> void:
	if not sfx_players.is_empty():
		return

	for i in range(MAX_SIMULTANEOUS_SFX):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer_" + str(i)
		player.bus = _get_audio_bus_name("SFX")
		add_child(player)
		sfx_players.append(player)


func _get_audio_bus_name(preferred_bus: String) -> String:
	if AudioServer.get_bus_index(preferred_bus) >= 0:
		return preferred_bus

	return "Master"


func play_menu_music() -> void:
	_ensure_music_player()

	if not ResourceLoader.exists(MENU_MUSIC_PATH):
		push_warning("Menu music file missing: " + MENU_MUSIC_PATH)
		return

	var stream := load(MENU_MUSIC_PATH) as AudioStream

	if stream == null:
		push_warning("Could not load menu music: " + MENU_MUSIC_PATH)
		return

	if music_player.stream == stream and music_player.playing:
		return

	music_player.stream = stream
	music_player.volume_db = 0.0
	music_player.play()


func stop_menu_music() -> void:
	if music_player == null:
		return

	music_player.stop()


func _on_music_finished() -> void:
	if music_player == null:
		return

	if music_player.stream == null:
		return

	music_player.play()


func go_to_scene(scene_path: String, sfx_name: String = "menu_button") -> void:
	target_scene_path = scene_path

	if sfx_name != "":
		play_sfx(sfx_name)

	var error := get_tree().change_scene_to_file(LOADING_SCREEN_PATH)

	if error != OK:
		push_error("Could not open loading screen: " + LOADING_SCREEN_PATH + " | Error: " + str(error))


func play_sfx(sfx_name: String) -> void:
	_ensure_sfx_players()

	var stream := get_sfx(sfx_name)

	if stream == null:
		return

	var player := get_free_sfx_player()
	player.stream = stream
	player.play()


func get_sfx(sfx_name: String) -> AudioStream:
	if sfx_name == "":
		return null

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
	_ensure_sfx_players()

	for player in sfx_players:
		if player != null and not player.playing:
			return player

	return sfx_players[0]


func play_menu_button() -> void:
	play_sfx("menu_button")


func play_initial_menu_button() -> void:
	play_sfx("initial_menu_button")


func play_back_button() -> void:
	play_sfx("back_button")


func play_attack_button() -> void:
	play_sfx("attack_button")


func play_check_button() -> void:
	play_sfx("check_button")


func play_pass_button() -> void:
	play_sfx("pass_button")


func play_inspect_button() -> void:
	play_sfx("inspect_button")


func play_select_button() -> void:
	play_sfx("select_button")


func play_alert_sound() -> void:
	play_sfx("alert_sound")


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
