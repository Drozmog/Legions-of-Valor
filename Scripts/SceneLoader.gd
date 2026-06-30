class_name SceneLoader
extends Node

const MENU_MUSIC_PATH := "res://Audio/Music/main_menu_theme.ogg"

const SFX_PATHS := {
	"menu_button": "res://Audio/SFX/menu_button.wav",
	"back_button": "res://Audio/SFX/back_button.wav",
	"initial_menu_button": "res://Audio/SFX/initial_menu_button.wav",

	"select_button": "res://Audio/SFX/select_button.wav",
	"attack_button": "res://Audio/SFX/attack_button.wav",
	"check_button": "res://Audio/SFX/check_button.wav",
	"pass_button": "res://Audio/SFX/pass_button.wav",
	"inspect_button": "res://Audio/SFX/inspect_button.wav",
	"alert_sound": "res://Audio/SFX/alert_sound.wav",
}

var music_player: AudioStreamPlayer = null


func _ready() -> void:
	_ensure_music_player()


func _ensure_music_player() -> void:
	if music_player != null and is_instance_valid(music_player):
		return

	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = _get_audio_bus_name("Music")
	add_child(music_player)

	if not music_player.finished.is_connected(_on_music_finished):
		music_player.finished.connect(_on_music_finished)


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
	# Simple manual loop for menu music.
	if music_player == null:
		return

	if music_player.stream == null:
		return

	music_player.play()


func play_sfx(sfx_id: String) -> void:
	if sfx_id == "":
		return

	if not SFX_PATHS.has(sfx_id):
		push_warning("Missing SFX id in SceneLoader: " + sfx_id)
		return

	var path: String = String(SFX_PATHS[sfx_id])

	if not ResourceLoader.exists(path):
		push_warning("Missing SFX file: " + path)
		return

	var stream := load(path) as AudioStream

	if stream == null:
		push_warning("Could not load SFX file: " + path)
		return

	var player := AudioStreamPlayer.new()
	player.name = "SFX_" + sfx_id
	player.stream = stream
	player.bus = _get_audio_bus_name("SFX")
	player.volume_db = 0.0
	add_child(player)

	player.finished.connect(player.queue_free)
	player.play()


func play_menu_button() -> void:
	play_sfx("menu_button")


func play_back_button() -> void:
	play_sfx("back_button")


func play_initial_menu_button() -> void:
	play_sfx("initial_menu_button")


func play_select_button() -> void:
	play_sfx("select_button")


func play_attack_button() -> void:
	play_sfx("attack_button")


func play_check_button() -> void:
	play_sfx("check_button")


func play_pass_button() -> void:
	play_sfx("pass_button")


func play_inspect_button() -> void:
	play_sfx("inspect_button")


func play_alert_sound() -> void:
	play_sfx("alert_sound")


func go_to_scene(scene_path: String, sfx_id: String = "") -> void:
	if sfx_id != "":
		play_sfx(sfx_id)

	call_deferred("_change_scene_deferred", scene_path)


func _change_scene_deferred(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)

	if error != OK:
		push_warning("Could not change scene to: " + scene_path + " | Error: " + str(error))
