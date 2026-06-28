class_name CardAnimationManager
extends Node3D

const CARD_3D_SCENE: PackedScene = preload("res://cards/Card3D_Test.tscn")

@export var animation_duration: float = 0.22
@export var arc_height: float = 0.30
@export var start_hover_height: float = 0.18


func animate_card_from_anchor_to_node(
	card_data: CardData,
	anchor_name: String,
	target_node: Node,
	face_down: bool = false
) -> void:
	var source_anchor := get_node_or_null(anchor_name) as Node3D

	if source_anchor == null:
		push_warning("Missing animation anchor: " + anchor_name)
		return

	await animate_card_to_position(
		card_data,
		source_anchor.global_position + Vector3(0.0, start_hover_height, 0.0),
		get_exact_landing_position(target_node),
		get_exact_landing_rotation(target_node),
		face_down
	)


func animate_card_between_nodes(
	card_data: CardData,
	source_node: Node,
	target_node: Node,
	face_down: bool = false
) -> void:
	await animate_card_to_position(
		card_data,
		get_exact_landing_position(source_node) + Vector3(0.0, start_hover_height, 0.0),
		get_exact_landing_position(target_node),
		get_exact_landing_rotation(target_node),
		face_down
	)


func animate_card_from_position_to_node(
	card_data: CardData,
	start_position: Vector3,
	target_node: Node,
	face_down: bool = false
) -> void:
	await animate_card_to_position(
		card_data,
		start_position,
		get_exact_landing_position(target_node),
		get_exact_landing_rotation(target_node),
		face_down
	)


func animate_card_to_position(
	card_data: CardData,
	start_position: Vector3,
	end_position: Vector3,
	end_rotation: Vector3,
	face_down: bool = false
) -> void:
	if card_data == null:
		return

	var animated_card := CARD_3D_SCENE.instantiate() as Node3D
	add_child(animated_card)

	# Keep it independent from CardAnimationManager transform,
	# but do NOT force custom scale. This uses the same scene default scale
	# as the real placed card.
	animated_card.top_level = true
	animated_card.global_position = start_position
	animated_card.global_rotation = end_rotation

	if animated_card.has_method("assign_card_data"):
		animated_card.assign_card_data(card_data, face_down)

	var control := (start_position + end_position) / 2.0
	control.y += arc_height

	var tween := create_tween()

	tween.tween_method(
		Callable(self, "set_card_arc_position").bind(animated_card, start_position, control, end_position),
		0.0,
		1.0,
		animation_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await tween.finished

	# Force the final frame to be EXACTLY the same landing transform.
	# This prevents the tiny visual adjustment at the end.
	if animated_card != null and is_instance_valid(animated_card):
		animated_card.global_position = end_position
		animated_card.global_rotation = end_rotation
		await get_tree().process_frame
		animated_card.queue_free()


func set_card_arc_position(
	t: float,
	card_node: Node3D,
	start: Vector3,
	control: Vector3,
	finish: Vector3
) -> void:
	if card_node == null:
		return

	if not is_instance_valid(card_node):
		return

	var a := start.lerp(control, t)
	var b := control.lerp(finish, t)

	card_node.global_position = a.lerp(b, t)


func get_exact_landing_position(target_node: Node) -> Vector3:
	var landing_anchor := get_landing_anchor(target_node)

	if landing_anchor != null:
		return landing_anchor.global_position

	if target_node is Node3D:
		return (target_node as Node3D).global_position

	if target_node != null and target_node.get_parent() is Node3D:
		return (target_node.get_parent() as Node3D).global_position

	return global_position


func get_exact_landing_rotation(target_node: Node) -> Vector3:
	var landing_anchor := get_landing_anchor(target_node)

	if landing_anchor != null:
		return landing_anchor.global_rotation

	if target_node is Node3D:
		return (target_node as Node3D).global_rotation

	if target_node != null and target_node.get_parent() is Node3D:
		return (target_node.get_parent() as Node3D).global_rotation

	return Vector3.ZERO


func get_landing_anchor(target_node: Node) -> Node3D:
	if target_node == null:
		return null

	if target_node is Node3D:
		var direct_anchor := find_named_landing_anchor(target_node)

		if direct_anchor != null:
			return direct_anchor

	return null


func find_named_landing_anchor(root: Node) -> Node3D:
	var possible_names: Array[String] = [
		"SnapPoint",
		"CardSnapPoint",
		"CardAnchor",
		"CardMount",
		"CardPosition",
		"PlacementPoint",
		"PlacePoint"
	]

	for anchor_name in possible_names:
		var found := root.get_node_or_null(anchor_name)

		if found != null and found is Node3D:
			return found as Node3D

	for child in root.get_children():
		if child is Node3D:
			var child_name := String(child.name).to_lower()

			if child_name.contains("snap") or child_name.contains("anchor") or child_name.contains("mount") or child_name.contains("place"):
				return child as Node3D

	return null
