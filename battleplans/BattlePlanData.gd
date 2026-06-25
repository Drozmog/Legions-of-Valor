class_name BattlePlanData
extends Resource

## Stable identifier used by rules and save data (for example: "fury_of_the_iron_horde").
@export var battle_plan_id: String = ""
@export var battle_plan_name: String = ""

@export_group("Battleplan Rules")
@export_range(0, 99, 1) var aurion_reward: int = 0
@export_range(0, 99, 1) var initiative: int = 0
@export_range(0, 99, 1) var hand_size: int = 7
@export_range(0, 99, 1) var draw_amount: int = 0
@export_multiline var description: String = ""

@export_group("Card Presentation")
@export var card_art: Texture2D


func is_valid() -> bool:
	return not battle_plan_id.strip_edges().is_empty() and not battle_plan_name.strip_edges().is_empty()


## Keeps the current battlefield and UI code compatible while battleplans move to Resources.
func to_dictionary() -> Dictionary:
	return {
		"id": battle_plan_id,
		"name": battle_plan_name,
		"initiative_mark": initiative,
		"draw_amount": draw_amount,
		"max_hand_size": hand_size,
		"aurion_reward": aurion_reward,
		"objective": description,
		"card_art": card_art,
		"resource": self,
	}
