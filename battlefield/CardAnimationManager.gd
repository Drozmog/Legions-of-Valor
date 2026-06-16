class_name CardAnimationManager
extends Node3D

const CARD_3D_SCENE: PackedScene = preload("res://cards/Card3D_Test.tscn")

@export var animation_duration: float = 0.45
@export var arc_height: float = 0.55
@export var animated_card_scale: float = 0.85
@export var linger_after_animation: float = 0.04


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
		source_anchor.global_position,
		get_target_position(target_node),
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
		get_target_position(source_node),
		get_target_position(target_node),
		face_down
	)


func animate_card_to_position(
	card_data: CardData,
	start_position: Vector3,
	end_position: Vector3,
	face_down: bool = false
) -> void:
	if card_data == null:
		return

	var animated_card := CARD_3D_SCENE.instantiate() as Node3D
	add_child(animated_card)

	animated_card.global_position = start_position + Vector3(0.0, 0.22, 0.0)
	animated_card.scale = Vector3(animated_card_scale, animated_card_scale, animated_card_scale)

	if animated_card.has_method("assign_card_data"):
		animated_card.assign_card_data(card_data, face_down)

	var middle_position := (start_position + end_position) / 2.0
	middle_position.y += arc_height

	var final_position := end_position + Vector3(0.0, 0.18, 0.0)

	var tween := create_tween()
	tween.tween_property(
		animated_card,
		"global_position",
		middle_position,
		animation_duration * 0.45
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		animated_card,
		"global_position",
		final_position,
		animation_duration * 0.55
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	if linger_after_animation > 0.0:
		await get_tree().create_timer(linger_after_animation).timeout

	if animated_card != null and is_instance_valid(animated_card):
		animated_card.queue_free()


func get_target_position(target_node: Node) -> Vector3:
	if target_node == null:
		return global_position

	if target_node is Node3D:
		return (target_node as Node3D).global_position

	if target_node.get_parent() is Node3D:
		return (target_node.get_parent() as Node3D).global_position

	return global_position
