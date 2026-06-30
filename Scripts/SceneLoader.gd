extends Node

const LOADING_SCREEN_PATH := "res://ui/loading_screen/loading_screen.tscn"
const MAIN_MENU_SCENE_PATH := "res://ui/Menu/prototype_menu.tscn"
const SFX_FOLDER := "res://Audio/SFX/"
const MAX_SIMULTANEOUS_SFX := 8

# Increase this if you still see gray before Deck Builder appears.
const POST_SCENE_BLACK_HOLD_TIME := 0.85
const POST_SCENE_FADE_TIME := 0.35
const MENU_MUSIC_FADE_OUT_TIME := 1.0

var target_scene_path: String = ""
var is_transitioning := false

var sfx_players: Array[AudioStreamPlayer] = []
var cached_sfx: Dictionary = {}

var music_player: AudioStreamPlayer
var music_tween: Tween
var music_default_volume_db := -8.0

var transition_layer: CanvasLayer
var transition_rect: ColorRect
var transition_tween: Tween


func _ready() -> void:
	for i in range(MAX_SIMULTANEOUS_SFX):
		var player := AudioStreamPlayer.new()
		add_child(player)
		sfx_players.append(player)

	music_player = AudioStreamPlayer.new()
	music_player.name = "PersistentMusicPlayer"
	add_child(music_player)

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
	timer.timeout.connect(_finish_post_scene_transition.bind(scene_path))


func _finish_post_scene_transition(scene_path: String) -> void:
	fade_black_overlay_out(POST_SCENE_FADE_TIME)

	# When leaving the menu, keep menu music alive through loading,
	# then fade it after the next scene has appeared.
	if scene_path != MAIN_MENU_SCENE_PATH:
		fade_persistent_music_out(MENU_MUSIC_FADE_OUT_TIME)


func go_to_scene(scene_path: String, sfx_name: String = "menu_button") -> void:
	if is_transitioning:
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


func finish_transition() -> void:
	is_transitioning = false


func take_over_music_from_player(scene_music_player: AudioStreamPlayer) -> void:
	if scene_music_player == null:
		return

	if scene_music_player.stream == null:
		return

	if music_tween != null and music_tween.is_valid():
		music_tween.kill()

	var start_position := 0.0

	if scene_music_player.playing:
		start_position = scene_music_player.get_playback_position()

	music_default_volume_db = scene_music_player.volume_db

	# Stop the scene-owned player so we don't hear duplicate music.
	scene_music_player.stop()

	# If the persistent player is already playing the same stream, keep it going.
	if music_player.stream == scene_music_player.stream and music_player.playing:
		music_player.volume_db = music_default_volume_db
		return

	music_player.stream = scene_music_player.stream
	music_player.bus = scene_music_player.bus
	music_player.volume_db = music_default_volume_db
	music_player.play(start_position)


func fade_persistent_music_out(fade_time: float = MENU_MUSIC_FADE_OUT_TIME) -> void:
	if music_player == null:
		return

	if not music_player.playing:
		return

	if music_tween != null and music_tween.is_valid():
		music_tween.kill()

	music_tween = create_tween()
	music_tween.tween_property(music_player, "volume_db", -80.0, fade_time)
	music_tween.tween_callback(func() -> void:
		music_player.stop()
		music_player.volume_db = music_default_volume_db
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
