extends Node3D

func _ready() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 4.8, 2.1)
	camera.rotation_degrees.x = -75.0
	camera.current = true
	add_child(camera)
	var manager := CardAnimationManager.new()
	manager.showcase_move_duration = 0.08
	manager.premium_unit_reveal_duration = 0.20
	manager.common_action_flash_duration = 0.14
	manager.premium_action_flash_duration = 0.20
	manager.destination_move_duration = 0.08
	manager.vaporize_duration = 0.10
	manager.reform_duration = 0.10
	add_child(manager)
	var board := Node3D.new()
	board.set_meta("row", "front")
	board.set_meta("owner", "player")
	add_child(board)
	var discard := Node3D.new()
	discard.name = "DiscardTarget"
	discard.position = Vector3(-1.7, 0.0, 1.8)
	add_child(discard)
	for data in [["unit", "◈", board], ["unit", "✩", board], ["gambit", "◈", discard], ["gambit", "✩", discard]]:
		var card := CardData.new()
		card.card_type = data[0]
		card.rarity = data[1]
		await manager.animate_card_from_position_to_node(card, Vector3(0.8, 0.2, 1.0), data[2], false)
	print("REFERENCE_PROFILE_SMOKE_OK")
	get_tree().quit()
