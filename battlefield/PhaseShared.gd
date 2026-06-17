class_name PhaseShared
extends "res://battlefield/BattlefieldManagerPhase35CombatReadability.gd"

const BOARD_ACTION_CHECK: int = 3
const BLUFF_REVEAL_DELAY: float = 0.30

var enemy_fortified_lanes: Dictionary = {}


func reset_combat_state() -> void:
	super.reset_combat_state()
	enemy_fortified_lanes.clear()


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
