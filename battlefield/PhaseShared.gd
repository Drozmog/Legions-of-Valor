class_name PhaseShared
extends "res://battlefield/BattlefieldManagerPhase4BluffCombat.gd"


func return_setup_card(slot: Node, card_data: CardData, owner_name: String) -> void:
	if slot == null or card_data == null:
		return

	if slot.has_method("clear_slot"):
		slot.clear_slot()

	if owner_name == "enemy":
		ai_hand.append(card_data)
		update_ai_visuals()
		return

	if hand != null:
		hand.add_card_to_hand(card_data)
