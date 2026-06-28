extends "res://cards/Card3D_Test.gd"

func _ready() -> void:
	ability_icon_pixel_size = 0.0034
	ability_icon_spacing = 0.25
	super._ready()
	call_deferred("_polish_ability_icons")

func rebuild_ability_icons() -> void:
	super.rebuild_ability_icons()
	_polish_ability_icons()

func _polish_ability_icons() -> void:
	if ability_icon_root == null:
		return
	for icon_root in ability_icon_root.get_children():
		var tooltip := icon_root.get_node_or_null("Tooltip") as Label3D
		if tooltip != null:
			tooltip.position = Vector3(-0.34, 0.075, -0.30)
		var area := icon_root.get_node_or_null("ClickArea") as Area3D
		if area != null:
			var collision := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if collision != null and collision.shape is BoxShape3D:
				(collision.shape as BoxShape3D).size = Vector3(0.28, 0.18, 0.28)
