extends Node

const LOADING_SCREEN_PATH := "res://ui/loading_screen/loading_screen.tscn"
const MAIN_MENU_MUSIC_PATH := "res://Audio/Music/main_menu_theme.ogg"

const SFX_FOLDER := "res://Audio/SFX/"
const MAX_SIMULTANEOUS_SFX := 8

const POST_SCENE_BLACK_HOLD_TIME := 0.85
const POST_SCENE_FADE_TIME := 0.35
const MENU_MUSIC_FADE_OUT_TIME := 1.0

var target_scene_path: String = ""
var is_transitioning := false

var sfx_players: Array[AudioStreamPlayer] = []
var cached_sfx: Dictionary = {}

var menu_music_player: AudioStreamPlayer
var music_tween: Tween
var menu_music_volume_db := -8.0

var transition_layer: CanvasLayer
var transition_rect: ColorRect
var transition_tween: Tween


func _ready() -> void:
	for i in range(MAX_SIMULTANEOUS_SFX):
		var player := AudioStreamPlayer.new()
		add_child(player)
		sfx_players.append(player)

	menu_music_player = AudioStreamPlayer.new()
	menu_music_player.name = "PersistentMenuMusicPlayer"
	menu_music_player.volume_db = menu_music_volume_db
	add_child(menu_music_player)

	_build_transition_overlay()

	if get_viewport() != null:
		get_viewport().size_changed.connect(_on_viewport_size_changed)


func _build_transition_overlay() -> void:
	transition_layer = CanvasLayer.new()
	transition_layer.name = "SceneTransitionOverlay"
	transition_layer.layer = 1000
	transition_layer.visible = false
	add_child(transition_layer)

	transition_rect = ColorRect.new()
	transition_rect.name = "BlackCover"
	transition_rect.color = Color.BLACK
	transition_rect.modulate.a = 0.0
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(transition_rect)

	_fit_transition_overlay()


func _on_viewport_size_changed() -> void:
	_fit_transition_overlay()


func _fit_transition_overlay() -> void:
	if transition_rect == null:
		return

	transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func show_black_overlay() -> void:
	if transition_layer == null or transition_rect == null:
		return

	if transition_tween != null and transition_tween.is_valid():
		transition_tween.kill()

	transition_layer.visible = true
	transition_rect.modulate.a = 1.0
	_fit_transition_overlay()


func fade_black_overlay_out(fade_time: float = POST_SCENE_FADE_TIME) -> void:
	if transition_layer == null or transition_rect == null:
		return

	if transition_tween != null and transition_tween.is_valid():
		transition_tween.kill()

	transition_tween = create_tween()
	transition_tween.tween_property(transition_rect, "modulate:a", 0.0, fade_time)
	transition_tween.tween_callback(func() -> void:
		transition_layer.visible = false
	)


func go_to_scene(scene_path: String, sfx_name: String = "menu_button") -> void:
	if is_transitioning:
		push_warning("Scene transition already running. Ignored request for: " + scene_path)
		return

	if sfx_name != "":
		play_sfx(sfx_name)

	if not ResourceLoader.exists(scene_path):
		push_error("Target scene does not exist: " + scene_path)
		return

	if not ResourceLoader.exists(LOADING_SCREEN_PATH):
		push_error("Missing loading screen scene: " + LOADING_SCREEN_PATH)
		return

	is_transitioning = true
	target_scene_path = scene_path

	var error := get_tree().change_scene_to_file(LOADING_SCREEN_PATH)

	if error != OK:
		push_error("Could not open loading screen: " + LOADING_SCREEN_PATH)
		is_transitioning = false


func change_to_loaded_scene_with_overlay(loaded_scene: PackedScene, scene_path: String) -> void:
	if loaded_scene == null:
		push_error("SceneLoader received null loaded scene for: " + scene_path)
		finish_transition()
		return

	show_black_overlay()

	var error := get_tree().change_scene_to_packed(loaded_scene)

	if error != OK:
		push_error("Could not change to loaded scene: " + scene_path)
		finish_transition()
		fade_black_overlay_out(0.1)
		return

	finish_transition()

	var timer := get_tree().create_timer(POST_SCENE_BLACK_HOLD_TIME)
	timer.timeout.connect(_finish_post_scene_transition)


func _finish_post_scene_transition() -> void:
	fade_black_overlay_out(POST_SCENE_FADE_TIME)
	fade_menu_music_out(MENU_MUSIC_FADE_OUT_TIME)


func finish_transition() -> void:
	is_transitioning = false


func play_menu_music() -> void:
	if menu_music_player == null:
		return

	if not ResourceLoader.exists(MAIN_MENU_MUSIC_PATH):
		push_warning("Missing menu music file: " + MAIN_MENU_MUSIC_PATH)
		return

	if music_tween != null and music_tween.is_valid():
		music_tween.kill()

	if menu_music_player.stream == null:
		menu_music_player.stream = load(MAIN_MENU_MUSIC_PATH) as AudioStream

	if menu_music_player.stream == null:
		push_warning("Could not load menu music: " + MAIN_MENU_MUSIC_PATH)
		return

	menu_music_player.volume_db = menu_music_volume_db

	if not menu_music_player.playing:
		menu_music_player.play()


func fade_menu_music_out(fade_time: float = MENU_MUSIC_FADE_OUT_TIME) -> void:
	if menu_music_player == null:
		return

	if not menu_music_player.playing:
		return

	if music_tween != null and music_tween.is_valid():
		music_tween.kill()

	music_tween = create_tween()
	music_tween.tween_property(menu_music_player, "volume_db", -80.0, fade_time)
	music_tween.tween_callback(func() -> void:
		menu_music_player.stop()
		menu_music_player.volume_db = menu_music_volume_db
	)


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
		2:
			play_attack_button()
		3:
			play_check_button()
		4:
			play_pass_button()
		1:
			play_inspect_button()
		_:
			play_menu_button()
