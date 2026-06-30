extends Control

@onready var loading_label: Label = $LoadingLabel
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var fade_rect: ColorRect = $FadeRect

var target_scene_path: String = ""
var loading_started := false


func _ready() -> void:
	target_scene_path = SceneLoader.target_scene_path

	if target_scene_path == "":
		loading_label.text = "No scene selected."
		SceneLoader.finish_transition()
		return

	if not ResourceLoader.exists(target_scene_path):
		loading_label.text = "Scene does not exist."
		push_error("Target scene does not exist: " + target_scene_path)
		SceneLoader.finish_transition()
		return

	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0

	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 1.0

	var fade_in := create_tween()
	fade_in.tween_property(fade_rect, "modulate:a", 0.0, 0.20)

	start_loading()


func start_loading() -> void:
	loading_started = true
	loading_label.text = "Loading..."

	var error := ResourceLoader.load_threaded_request(target_scene_path)

	if error != OK:
		loading_started = false
		loading_label.text = "Failed to start loading."
		push_error("Could not start threaded loading for: " + target_scene_path)
		SceneLoader.finish_transition()


func _process(_delta: float) -> void:
	if not loading_started:
		return

	var progress := []
	var status := ResourceLoader.load_threaded_get_status(target_scene_path, progress)

	if progress.size() > 0:
		progress_bar.value = progress[0] * 100.0

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			loading_label.text = "Loading..."

		ResourceLoader.THREAD_LOAD_LOADED:
			loading_started = false
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
