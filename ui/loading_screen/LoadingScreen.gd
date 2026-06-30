extends Control

@onready var loading_label: Label = $LoadingLabel
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var fade_rect: ColorRect = $FadeRect

var target_scene_path: String = ""
var loading_started := false
var transition_started := false
var elapsed_loading_time := 0.0

const MINIMUM_LOADING_SCREEN_TIME := 0.25


func _ready() -> void:
	_apply_layout()

	target_scene_path = SceneLoader.target_scene_path

	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.show_percentage = false

	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 1.0

	if target_scene_path == "":
		loading_label.text = "No scene selected."
		push_error("LoadingScreen opened without SceneLoader.target_scene_path.")
		SceneLoader.finish_transition()
		return

	if not ResourceLoader.exists(target_scene_path):
		loading_label.text = "Scene does not exist."
		push_error("Target scene does not exist: " + target_scene_path)
		SceneLoader.finish_transition()
		return

	loading_label.text = "Loading..."

	var fade_in := create_tween()
	fade_in.tween_property(fade_rect, "modulate:a", 0.0, 0.18)

	await get_tree().process_frame
	start_loading()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if is_node_ready():
			_apply_layout()


func _apply_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var screen_size := get_viewport_rect().size
	var label_width := 620.0
	var label_height := 80.0
	var bar_width := 620.0
	var bar_height := 24.0
	var center_y := screen_size.y * 0.70

	$Background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	loading_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	loading_label.position = Vector2((screen_size.x - label_width) * 0.5, center_y - 55.0)
	loading_label.size = Vector2(label_width, label_height)
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	progress_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	progress_bar.position = Vector2((screen_size.x - bar_width) * 0.5, center_y + 28.0)
	progress_bar.size = Vector2(bar_width, bar_height)
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func start_loading() -> void:
	loading_started = true
	transition_started = false
	elapsed_loading_time = 0.0
	loading_label.text = "Loading..."

	var error := ResourceLoader.load_threaded_request(target_scene_path)

	if error != OK:
		loading_started = false
		loading_label.text = "Failed to start loading."
		push_error("Could not start threaded loading for: " + target_scene_path)
		SceneLoader.finish_transition()


func _process(delta: float) -> void:
	if not loading_started or transition_started:
		return

	elapsed_loading_time += delta

	var progress := []
	var status := ResourceLoader.load_threaded_get_status(target_scene_path, progress)

	if progress.size() > 0:
		progress_bar.value = clampf(float(progress[0]) * 100.0, 0.0, 100.0)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			loading_label.text = "Loading..."

		ResourceLoader.THREAD_LOAD_LOADED:
			if elapsed_loading_time < MINIMUM_LOADING_SCREEN_TIME:
				return

			loading_started = false
			transition_started = true
			progress_bar.value = 100.0
			transition_to_loaded_scene()

		ResourceLoader.THREAD_LOAD_FAILED:
			loading_started = false
			loading_label.text = "Loading failed."
			push_error("Failed to load scene: " + target_scene_path)
			SceneLoader.finish_transition()

		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			loading_started = false
			loading_label.text = "Invalid scene."
			push_error("Invalid scene path: " + target_scene_path)
			SceneLoader.finish_transition()


func transition_to_loaded_scene() -> void:
	loading_label.text = "Ready"

	var fade_out := create_tween()
	fade_out.tween_property(fade_rect, "modulate:a", 1.0, 0.18)
	await fade_out.finished

	var loaded_scene := ResourceLoader.load_threaded_get(target_scene_path) as PackedScene

	if loaded_scene == null:
		loading_label.text = "Could not open loaded scene."
		push_error("Loaded scene was null: " + target_scene_path)
		SceneLoader.finish_transition()
		return

	SceneLoader.change_to_loaded_scene_with_overlay(loaded_scene, target_scene_path)
