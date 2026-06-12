extends Node3D

var card_data: CardData = null

@onready var card_body: MeshInstance3D = $CardBody


func assign_card_data(data: CardData) -> void:
	card_data = data
	name = "Card3D_" + data.card_id

	update_visuals()


func update_visuals() -> void:
	if card_data == null:
		return

	var mat := StandardMaterial3D.new()

	if card_data.card_type == "unit":
		mat.albedo_color = Color(0.25, 0.45, 0.85, 1.0)
	elif card_data.card_type == "ruse":
		mat.albedo_color = Color(0.55, 0.35, 0.85, 1.0)
	elif card_data.card_type == "trap":
		mat.albedo_color = Color(0.75, 0.25, 0.25, 1.0)
	else:
		mat.albedo_color = Color(0.8, 0.8, 0.8, 1.0)

	card_body.material_override = mat
