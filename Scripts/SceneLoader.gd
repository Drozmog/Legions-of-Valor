extends Node

const LOADING_SCREEN_PATH := "res://ui/loading_screen/loading_screen.tscn"
const MENU_MUSIC_PATH := "res://Audio/Music/main_menu_theme.ogg"
const MENU_SCENE_PATH := "res://ui/Menu/prototype_menu.tscn"
const SFX_FOLDER := "res://Audio/SFX/"
const MENU_MUSIC_START_DELAY := 0.5
const MAX_SIMULTANEOUS_SFX := 8
const MENU_MUSIC_FADE_OUT_TIME := 1.25
const SILENT_VOLUME_DB := -40.0
const ABILITY_SFX_CATEGORIES := ["mobility", "assault", "attrition", "control", "economy", "protection", "insight"]

var target_scene_path: String = ""

var music_player: AudioStreamPlayer = null
var menu_music_fade_tween: Tween = null
var menu_music_start_request_id := 0
var menu_music_should_loop := false
var sfx_players: Array[AudioStreamPlayer] = []
var cached_sfx: Dictionary = {}
var missing_sfx: Dictionary = {}


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
	menu_music_should_loop = true
	menu_music_start_request_id += 1

	var request_id := menu_music_start_request_id

	if menu_music_fade_tween != null and menu_music_fade_tween.is_valid():
		menu_music_fade_tween.kill()
		menu_music_fade_tween = null

	if not ResourceLoader.exists(MENU_MUSIC_PATH):
		push_warning("Menu music file missing: " + MENU_MUSIC_PATH)
		return

	var stream := load(MENU_MUSIC_PATH) as AudioStream

	if stream == null:
		push_warning("Could not load menu music: " + MENU_MUSIC_PATH)
		return

	if music_player.stream == stream and music_player.playing:
		music_player.volume_db = 0.0
		return

	if MENU_MUSIC_START_DELAY > 0.0:
		await get_tree().create_timer(MENU_MUSIC_START_DELAY).timeout

		if request_id != menu_music_start_request_id:
			return

		if not menu_music_should_loop:
			return

		if music_player == null or not is_instance_valid(music_player):
			return
	music_player.stream = stream
	music_player.volume_db = 0.0
	music_player.play()


func stop_menu_music(fade_time: float = 0.0) -> void:
	menu_music_should_loop = false
	menu_music_start_request_id += 1

	if music_player == null:
		return

	if menu_music_fade_tween != null and menu_music_fade_tween.is_valid():
		menu_music_fade_tween.kill()
		menu_music_fade_tween = null

	if not music_player.playing:
		music_player.stream = null
		music_player.volume_db = 0.0
		return

	if fade_time <= 0.0:
		music_player.stop()
		music_player.stream = null
		music_player.volume_db = 0.0
		return

	menu_music_fade_tween = create_tween()
	menu_music_fade_tween.set_trans(Tween.TRANS_SINE)
	menu_music_fade_tween.set_ease(Tween.EASE_OUT)
	menu_music_fade_tween.tween_property(music_player, "volume_db", SILENT_VOLUME_DB, fade_time)
	menu_music_fade_tween.tween_callback(_finish_menu_music_fade)
	
	
func _finish_menu_music_fade() -> void:
	if music_player != null:
		music_player.stop()
		music_player.stream = null
		music_player.volume_db = 0.0

	menu_music_fade_tween = null


func _on_music_finished() -> void:
	if not menu_music_should_loop:
		return

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


func change_to_loaded_scene_with_overlay(loaded_scene: PackedScene, scene_path: String = "") -> void:
	if loaded_scene == null:
		push_error("SceneLoader received null loaded scene: " + scene_path)
		finish_transition()
		return

	var final_scene_path := scene_path
	if final_scene_path == "":
		final_scene_path = target_scene_path

	var tree := get_tree()

	var old_scene := tree.current_scene
	var new_scene := loaded_scene.instantiate()

	if new_scene == null:
		push_error("Could not instantiate loaded scene: " + final_scene_path)
		finish_transition()
		return

	tree.root.add_child(new_scene)
	tree.current_scene = new_scene

	if old_scene != null and is_instance_valid(old_scene):
		old_scene.queue_free()

	if final_scene_path == MENU_SCENE_PATH:
		play_menu_music()
	else:
		stop_menu_music(MENU_MUSIC_FADE_OUT_TIME)

	finish_transition()


func finish_transition() -> void:
	target_scene_path = ""


func play_menu_button() -> void:
	play_sfx("menu_button")


func play_initial_menu_button() -> void:
	play_sfx("initial_menu_button")


func play_major_select_button() -> void:
	play_sfx("major_select_button")


func play_hud_select_button() -> void:
	play_sfx("hud_select_button")


func play_hud_deselect_button() -> void:
	play_sfx("hud_deselect_button")


func play_select_button() -> void:
	play_hud_select_button()


func play_back_button() -> void:
	play_hud_deselect_button()


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


func play_battleplan_flip() -> void:
	play_sfx("battleplan_flip")


func play_hand_card_hold() -> void:
	play_sfx("hand_card_hold")


func play_hand_card_return() -> void:
	play_sfx("hand_card_return")


func play_hand_card_release() -> void:
	play_sfx("hand_card_release")


func play_elite_unit_shine() -> void:
	play_sfx("elite_unit_shine")


func play_ability_label(category: String) -> void:
	play_sfx(_clean_ability_category(category) + "_label")


func play_ability_icon_press(category: String) -> void:
	play_sfx(_clean_ability_category(category) + "_icon_press")


func play_board_action_button(action_id: int) -> void:
	match action_id:
		2:
			play_attack_button()
		3:
			play_check_button()
		4:
			play_pass_button()
		1:
			play_inspect_button()
		_:
			play_hud_select_button()


func play_sfx(sfx_name: String) -> void:
	_ensure_sfx_players()

	var stream := get_sfx(sfx_name)

	if stream == null:
		return

	var player := get_free_sfx_player()
	player.stream = stream
	player.volume_db = get_sfx_volume_db(sfx_name)
	player.play()
	
func get_sfx_volume_db(sfx_name: String) -> float:
	match sfx_name:
		"initial_menu_button":
			return 6.0
		_:
			return 0.0


func get_sfx(sfx_name: String) -> AudioStream:
	if sfx_name == "":
		return null

	if cached_sfx.has(sfx_name):
		return cached_sfx[sfx_name]

	if missing_sfx.has(sfx_name):
		return null

	var path := SFX_FOLDER + sfx_name + ".wav"

	if not ResourceLoader.exists(path):
		var fallback_name := _get_sfx_fallback_name(sfx_name)
		if fallback_name != "" and fallback_name != sfx_name:
			var fallback_stream := get_sfx(fallback_name)
			if fallback_stream != null:
				cached_sfx[sfx_name] = fallback_stream
				return fallback_stream

		# Missing optional sounds should not spam the debugger every time an
		# animation requests them. Keep one warning per missing key, then cache it.
		push_warning("Missing SFX file: " + path)
		missing_sfx[sfx_name] = true
		return null

	var stream := load(path) as AudioStream

	if stream == null:
		push_warning("Could not load SFX file: " + path)
		missing_sfx[sfx_name] = true
		return null

	cached_sfx[sfx_name] = stream
	return stream


func _get_sfx_fallback_name(sfx_name: String) -> String:
	var clean_name := sfx_name.to_lower().strip_edges()

	match clean_name:
		"hud_select_button":
			return "select_button"
		"hud_deselect_button":
			return "back_button"
		"major_select_button":
			return "select_button"
		"battleplan_flip", "battleplan_flip_button", "battle_plan_flip":
			return "major_select_button"
		"hand_card_hold":
			return "select_button"
		"hand_card_return":
			return "back_button"
		"hand_card_release":
			return "select_button"
		"elite_unit_shine":
			return "alert_sound"

	if clean_name.ends_with("_label"):
		return "alert_sound"

	if clean_name.ends_with("_icon_press"):
		return "major_select_button"

	return ""


func _clean_ability_category(category: String) -> String:
	var clean_category := category.to_lower().strip_edges()
	if ABILITY_SFX_CATEGORIES.has(clean_category):
		return clean_category
	return "mobility"


func get_free_sfx_player() -> AudioStreamPlayer:
	_ensure_sfx_players()

	for player in sfx_players:
		if player != null and not player.playing:
			return player

	return sfx_players[0]
