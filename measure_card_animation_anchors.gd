extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://battlefield/battlefield_3d.tscn") as PackedScene
	var battlefield := packed.instantiate()
	add_child(battlefield)
	for _frame in range(12):
		await get_tree().process_frame
	var card := load("res://cards/definitions/unit/human/lady_carmelia.tres") as CardData
	battlefield.deck_selection_screen.hide()
	battlefield.blurred_modal_input_depth = 0
	battlefield.hand.raise_hand()
	battlefield.hand.add_card_to_hand(card, false)
	battlefield.ai_hand = [card, card, card, card, card]
	battlefield.update_ai_visuals()
	for _frame in range(30):
		await get_tree().process_frame
	var player_proxy := battlefield.hand.cards[0] as CardUI
	var player_position: Vector3 = battlefield.player_hand_3d.get_card_global_position(player_proxy)
	var enemy_positions: Array[Vector3] = []
	for enemy_card in battlefield.opponent_visuals.hand_card_nodes:
		enemy_positions.append(enemy_card.global_position)
	var enemy_center: Vector3 = Vector3.ZERO
	for position in enemy_positions:
		enemy_center += position
	if not enemy_positions.is_empty():
		enemy_center /= float(enemy_positions.size())
	print("MEASURE_PLAYER_HAND=", player_position)
	print("MEASURE_ENEMY_HAND_CENTER=", enemy_center)
	for path in ["DrawPile", "TributePile", "DiscardPile", "OpponentVisuals/EnemyDrawPileVisual", "OpponentVisuals/EnemyTributePileVisual", "OpponentVisuals/EnemyDiscardPileVisual", "ParryPit", "OpponentVisuals/EnemyParryPitVisual"]:
		var target := battlefield.get_node(path) as Node3D
		print("MEASURE_", path.replace("/", "_").to_upper(), "=", target.global_position)
	get_tree().quit(0)
