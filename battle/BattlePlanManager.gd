class_name BattlePlanManager
extends Node

signal battle_plan_selected(plan: Dictionary)

const ALL_BATTLE_PLANS: Array[Dictionary] = [
	{
		"id": "fury_of_the_iron_horde",
		"name": "Fury of the Iron Horde",
		"initiative_mark": 10,
		"draw_amount": 1,
		"max_hand_size": 5,
		"aurion_reward": 1,
		"objective": "Successfully score a Monarch Strike, a direct unblocked hit against the enemy commander profile, in any lane this turn."
	},
	{
		"id": "eyes_of_elyndell",
		"name": "Eyes of Elyndell",
		"initiative_mark": 9,
		"draw_amount": 1,
		"max_hand_size": 5,
		"aurion_reward": 1,
		"objective": "Successfully declare a Cautious Strike that reveals and disarms a real active enemy Trap card."
	},
	{
		"id": "elyndell_flank_encirclement",
		"name": "Elyndell Flank Encirclement",
		"initiative_mark": 8,
		"draw_amount": 2,
		"max_hand_size": 6,
		"aurion_reward": 2,
		"objective": "End the turn cycle holding the higher cumulative Attack Power in both the Left and Right Side Lanes simultaneously."
	},
	{
		"id": "brugos_onslaught",
		"name": "Brugo's Onslaught",
		"initiative_mark": 7,
		"draw_amount": 2,
		"max_hand_size": 6,
		"aurion_reward": 2,
		"objective": "Win a Clash where your attacking unit destroys an enemy frontline unit by an overflow margin of 3 or more AP."
	},
	{
		"id": "ascension_of_aethelgard",
		"name": "Ascension of Aethelgard",
		"initiative_mark": 6,
		"draw_amount": 2,
		"max_hand_size": 6,
		"aurion_reward": 2,
		"objective": "Perform a vertical Promotion on a unit, and have that newly promoted unit survive the entire combat round."
	},
	{
		"id": "elyndell_mirage_deception",
		"name": "Elyndell Mirage Deception",
		"initiative_mark": 5,
		"draw_amount": 3,
		"max_hand_size": 7,
		"aurion_reward": 2,
		"objective": "Have a face-down Ruse card you control successfully probed by an opponent's Cautious Strike during the Conflict Phase."
	},
	{
		"id": "jormunds_iron_gate",
		"name": "Jormund's Iron Gate",
		"initiative_mark": 4,
		"draw_amount": 3,
		"max_hand_size": 7,
		"aurion_reward": 2,
		"objective": "Successfully invoke a Center Lane Interception to protect an adjacent side lane, and ensure your center unit survives the resulting Clash."
	},
	{
		"id": "karak_duun_masterwork",
		"name": "Karak-Duun Masterwork",
		"initiative_mark": 3,
		"draw_amount": 3,
		"max_hand_size": 8,
		"aurion_reward": 2,
		"objective": "Have a single active Front Row unit card with both a Weapon and an Armor equipment card simultaneously attached to it at the end of the turn."
	},
	{
		"id": "lower_vein_extraction",
		"name": "Lower-Vein Extraction",
		"initiative_mark": 3,
		"draw_amount": 4,
		"max_hand_size": 8,
		"aurion_reward": 1,
		"objective": "End the Deployment Phase with at least 3 cards of the exact same Faction resting in your Tribute Pile."
	},
	{
		"id": "gravemarch_vanguard_recon",
		"name": "Gravemarch Vanguard Recon",
		"initiative_mark": 2,
		"draw_amount": 3,
		"max_hand_size": 7,
		"aurion_reward": 1,
		"objective": "Successfully declare a Cautious Strike against any enemy face-down Back Row card."
	},
	{
		"id": "channeling_the_aurion_core",
		"name": "Channeling the Aurion Core",
		"initiative_mark": 2,
		"draw_amount": 4,
		"max_hand_size": 8,
		"aurion_reward": 2,
		"objective": "Sacrifice a Spell card to your Tribute pile for a +2 temporary surge, and spend every available Tribute point before ending your deployment."
	},
	{
		"id": "the_last_parry_of_karak_duun",
		"name": "The Last Parry of Karak-Duun",
		"initiative_mark": 1,
		"draw_amount": 4,
		"max_hand_size": 9,
		"aurion_reward": 3,
		"objective": "Discard 3 or more cards straight from your hand during a single Parry Chain to successfully save a unit from destruction."
	},
	{
		"id": "horlons_blood_drunk_charge",
		"name": "Horlon's Blood-Drunk Charge",
		"initiative_mark": 9,
		"draw_amount": 1,
		"max_hand_size": 5,
		"aurion_reward": 2,
		"objective": "Have an active unit in your frontline with a modified AP of 6 or more at the conclusion of the Deployment Phase."
	},
	{
		"id": "the_skar_river_standoff",
		"name": "The Skar River Standoff",
		"initiative_mark": 1,
		"draw_amount": 4,
		"max_hand_size": 8,
		"aurion_reward": 2,
		"objective": "Intentionally hold your lines and choose the Pass command in all lanes, declaring zero attacks during the entire Conflict Phase."
	},
	{
		"id": "standard_of_aethelgard",
		"name": "Standard of Aethelgard",
		"initiative_mark": 5,
		"draw_amount": 3,
		"max_hand_size": 7,
		"aurion_reward": 2,
		"objective": "End the Deployment Phase with an active Front Row unit present in all three lanes simultaneously."
	},
	{
		"id": "deep_mine_reinforcements",
		"name": "Deep-Mine Reinforcements",
		"initiative_mark": 4,
		"draw_amount": 3,
		"max_hand_size": 7,
		"aurion_reward": 2,
		"objective": "Have your Center Lane unit successfully survive a Clash where it acted as the defending target or intercepted an attack."
	},
	{
		"id": "iron_horde_execution",
		"name": "Iron Horde Execution",
		"initiative_mark": 7,
		"draw_amount": 2,
		"max_hand_size": 6,
		"aurion_reward": 2,
		"objective": "Execute a vertical Promotion, and have that newly promoted unit successfully destroy an enemy unit in a Clash during the same turn."
	},
	{
		"id": "veil_of_elyndell",
		"name": "Veil of Elyndell",
		"initiative_mark": 1,
		"draw_amount": 4,
		"max_hand_size": 9,
		"aurion_reward": 2,
		"objective": "End the entire turn cycle with your Back Row cards untouched and still face-down in at least two separate lanes."
	},
	{
		"id": "aegis_of_aethelgard",
		"name": "Aegis of Aethelgard",
		"initiative_mark": 3,
		"draw_amount": 4,
		"max_hand_size": 8,
		"aurion_reward": 2,
		"objective": "Successfully save a Side Lane unit from certain destruction by initiating a Parry Chain."
	},
	{
		"id": "forge_of_karak_duun",
		"name": "Forge of Karak-Duun",
		"initiative_mark": 2,
		"draw_amount": 4,
		"max_hand_size": 8,
		"aurion_reward": 3,
		"objective": "Execute a vertical Promotion where the incoming unit successfully inherits 2 or more attached Equipment cards from the discarded unit."
	},
]

var current_battle_plan: Dictionary = {}
var current_round: int = 1


func get_random_battle_plan_choices(choice_count: int = 3) -> Array[Dictionary]:
	var pool: Array[Dictionary] = ALL_BATTLE_PLANS.duplicate(true)
	pool.shuffle()

	var choices: Array[Dictionary] = []
	var amount := mini(choice_count, pool.size())

	for i in range(amount):
		choices.append(pool[i])

	return choices


func select_battle_plan(plan: Dictionary) -> void:
	current_battle_plan = plan
	battle_plan_selected.emit(plan)


func clear_current_battle_plan() -> void:
	current_battle_plan = {}


func advance_round() -> void:
	current_round += 1
	clear_current_battle_plan()


func get_current_battle_plan_name() -> String:
	if current_battle_plan.is_empty():
		return "None"

	return str(current_battle_plan.get("name", "Unknown Battle Plan"))


func get_current_max_hand_size() -> int:
	if current_battle_plan.is_empty():
		return 7

	return int(current_battle_plan.get("max_hand_size", 7))
