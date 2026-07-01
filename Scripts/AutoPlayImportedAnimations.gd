extends Node

@export var animation_name: StringName = &"Animation"
@export var loop_animation := true
@export var start_on_ready := true


func _ready() -> void:
	if start_on_ready:
		call_deferred("_start_animations")


func _start_animations() -> void:
	var found_animation_player := false

	for node in find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer

		if player == null:
			continue

		found_animation_player = true

		var chosen_animation := animation_name

		if not player.has_animation(chosen_animation):
			var animation_names := player.get_animation_list()

			if animation_names.is_empty():
				push_warning("AnimationPlayer has no animations: " + str(player.get_path()))
				continue

			chosen_animation = animation_names[0]

		if loop_animation:
			var animation := player.get_animation(chosen_animation)
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR

		player.play(chosen_animation)
		print("Playing imported animation: ", chosen_animation, " on ", player.get_path())

	if not found_animation_player:
		push_warning("No AnimationPlayer found under: " + str(get_path()))
