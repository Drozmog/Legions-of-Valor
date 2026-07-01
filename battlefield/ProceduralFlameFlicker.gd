extends Node3D

@export var flicker_speed: float = 4.5
@export var pulse_amount: float = 0.08
@export var vertical_bob: float = 0.035
@export var sway_degrees: float = 3.5
@export var random_offset: float = 0.0

var base_position := Vector3.ZERO
var base_rotation := Vector3.ZERO
var base_scale := Vector3.ONE
var time := 0.0


func _ready() -> void:
	base_position = position
	base_rotation = rotation
	base_scale = scale

	if random_offset == 0.0:
		random_offset = randf() * 100.0


func _process(delta: float) -> void:
	time += delta * flicker_speed

	var a := sin(time + random_offset)
	var b := sin(time * 1.73 + random_offset * 0.37)
	var c := sin(time * 2.41 + random_offset * 0.19)

	var pulse := 1.0 + ((a * 0.5 + b * 0.35 + c * 0.15) * pulse_amount)

	scale = Vector3(
		base_scale.x * pulse,
		base_scale.y * (1.0 + abs(b) * pulse_amount),
		base_scale.z * pulse
	)

	position = base_position + Vector3(
		0.0,
		vertical_bob * abs(a),
		0.0
	)

	rotation = base_rotation
	rotation_degrees.y += sway_degrees * a
	rotation_degrees.z += sway_degrees * 0.45 * b
