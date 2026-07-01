@tool
extends Node3D

@export var grass_scene: PackedScene

@export var columns: int = 8
@export var rows: int = 5

@export var spacing_x: float = 1.2
@export var spacing_z: float = 1.2

@export var random_position_jitter: float = 0.35
@export var random_rotation: bool = true

@export var min_scale: float = 0.8
@export var max_scale: float = 1.25

@export var y_offset: float = 0.0

# Runtime generation keeps the battlefield scene from permanently saving
# dozens/hundreds of animated grass children into battlefield_3d.tscn.
@export var generate_on_ready: bool = true
@export var randomize_animation_time: bool = true
@export var animation_speed: float = 1.0

@export var regenerate_grass: bool:
	get:
		return false
	set(value):
		if value:
			regenerate(true)

@export var clear_grass: bool:
	get:
		return false
	set(value):
		if value:
			clear_generated_grass()


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if generate_on_ready:
		regenerate(false)
	else:
		_restart_existing_grass_animations()


func regenerate(editor_preview: bool = false) -> void:
	if grass_scene == null:
		push_warning("Assign grass_scene first.")
		return

	clear_generated_grass()

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	var start_x: float = -float(columns - 1) * spacing_x * 0.5
	var start_z: float = -float(rows - 1) * spacing_z * 0.5

	for x: int in range(columns):
		for z: int in range(rows):
			var instance: Node = grass_scene.instantiate()

			if not instance is Node3D:
				push_warning("Grass scene root must be Node3D.")
				instance.queue_free()
				return

			var grass: Node3D = instance as Node3D
			grass.name = "generated_grass_%02d_%02d" % [x, z]
			grass.set_meta("generated_grass", true)

			add_child(grass)

			# Only editor previews should be saved. Runtime generation and normal scene
			# loading intentionally leave owner unset so generated grass does not bloat
			# the battlefield scene file.
			if editor_preview and Engine.is_editor_hint() and get_tree() != null:
				grass.owner = get_tree().edited_scene_root

			var px: float = start_x + float(x) * spacing_x
			var pz: float = start_z + float(z) * spacing_z

			px += rng.randf_range(-random_position_jitter, random_position_jitter)
			pz += rng.randf_range(-random_position_jitter, random_position_jitter)

			grass.position = Vector3(px, y_offset, pz)

			if random_rotation:
				grass.rotation.y = rng.randf_range(0.0, TAU)

			var uniform_scale: float = rng.randf_range(min_scale, max_scale)
			grass.scale = Vector3(uniform_scale, uniform_scale, uniform_scale)

			_play_animations(grass, rng)


func clear_generated_grass() -> void:
	for child: Node in get_children():
		if child.has_meta("generated_grass"):
			remove_child(child)
			child.queue_free()


func _restart_existing_grass_animations() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	for child: Node in get_children():
		_play_animations(child, rng)


func _play_animations(root: Node, rng: RandomNumberGenerator) -> void:
	var players: Array[AnimationPlayer] = []
	_find_animation_players(root, players)

	for player: AnimationPlayer in players:
		player.active = true
		player.speed_scale = animation_speed

		var animations: PackedStringArray = player.get_animation_list()

		if animations.is_empty():
			continue

		var animation_name: StringName = StringName(animations[0])
		var animation: Animation = player.get_animation(animation_name)

		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR

		player.play(animation_name)

		if randomize_animation_time and animation != null and animation.length > 0.0:
			player.seek(rng.randf_range(0.0, animation.length), true)


func _find_animation_players(node: Node, result: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		result.append(node as AnimationPlayer)

	for child: Node in node.get_children():
		_find_animation_players(child, result)
