extends Node

const BATTLEPLAN_PHASE := 0
const HAND_LIFT_TO_WORLD_Y := 0.003
const HAND_CAMERA_OFFSET_TO_WORLD := 0.002
const MAX_HAND_WORLD_LIFT := 2.0
const MAX_HAND_CAMERA_OFFSET := 2.0

var advanced_hand_limit_scenes: Dictionary = {}


func _ready() -> void:
	process_priority = 100000
	set_process(true)


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	var hand := scene.get_node_or_null("UI/Hand")
	if hand == null:
		return

	guard_battleplan_draw_pile(scene, hand)
	apply_real_3d_hand_depth(scene, hand)


func guard_battleplan_draw_pile(scene: Node, hand: Node) -> void:
	var draw_pile := scene.get_node_or_null("DrawPile")
	if draw_pile == null:
		return

	var click_area := draw_pile.get_node_or_null("ClickArea") as Area3D
	if click_area == null:
		return

	var current_phase := int(scene.get("current_phase"))
	var pending_draws := int(scene.get("pending_battleplan_draws"))
	var hand_size := get_hand_size(hand)
	var max_hand_size := int(hand.get("max_hand_size"))

	var can_draw_now := current_phase == BATTLEPLAN_PHASE and pending_draws > 0 and hand_size < max_hand_size
	click_area.input_ray_pickable = can_draw_now

	if current_phase == BATTLEPLAN_PHASE and pending_draws > 0 and hand_size >= max_hand_size:
		finish_blocked_battleplan_draws(scene)


func finish_blocked_battleplan_draws(scene: Node) -> void:
	var scene_key := str(scene.get_instance_id()) + ":" + str(scene.get("turn_number"))
	if advanced_hand_limit_scenes.has(scene_key):
		return

	advanced_hand_limit_scenes[scene_key] = true
	scene.set("pending_battleplan_draws", 0)
	if scene.has_method("begin_battleplan_hand_cleanup_or_tribute"):
		scene.call_deferred("begin_battleplan_hand_cleanup_or_tribute")


func apply_real_3d_hand_depth(scene: Node, hand: Node) -> void:
	var hand3d := scene.get_node_or_null("PlayerHand3D")
	if hand3d == null:
		return

	var lift_pixels := float(hand.get("hand_plane_lift"))
	var camera_pixels := float(hand.get("hand_plane_x_offset"))
	var pitch_degrees := float(hand.get("hand_plane_angle_degrees"))

	var world_lift := clampf(lift_pixels * HAND_LIFT_TO_WORLD_Y, -MAX_HAND_WORLD_LIFT, MAX_HAND_WORLD_LIFT)
	var camera_offset := clampf(camera_pixels * HAND_CAMERA_OFFSET_TO_WORLD, -MAX_HAND_CAMERA_OFFSET, MAX_HAND_CAMERA_OFFSET)
	var pitch_radians := deg_to_rad(pitch_degrees)

	if hand3d.get("hand_plane_y") != null:
		hand3d.set("hand_plane_y", 0.58 + world_lift)

	var visuals: Variant = hand3d.get("card_visuals")
	if not visuals is Dictionary:
		return

	for raw_id in (visuals as Dictionary).keys():
		var visual := (visuals as Dictionary)[raw_id] as Node3D
		if visual == null or not is_instance_valid(visual):
			continue

		if camera_offset != 0.0:
			var camera := get_viewport().get_camera_3d()
			if camera != null:
				var direction_to_camera := camera.global_position - visual.global_position
				if direction_to_camera.length() > 0.001:
					visual.global_position += direction_to_camera.normalized() * camera_offset

		visual.global_rotation.x += pitch_radians


func get_hand_size(hand: Node) -> int:
	var cards_variant: Variant = hand.get("cards")
	if cards_variant is Array:
		return (cards_variant as Array).size()
	return 0
