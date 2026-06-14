class_name TributeManager
extends Node

signal tribute_changed(status_text: String)

var permanent_tribute_cards: Array[CardData] = []
var temporary_tribute_cards: Array[CardData] = []

var permanent_tp: int = 0
var current_permanent_tp: int = 0
var temporary_tp: int = 0
var current_tribute_points: int = 0


func offer_card_to_tribute(card_data: CardData) -> bool:
	if card_data == null:
		return false

	var type := card_data.card_type.to_lower()

	if type == "spell":
		add_temporary_tribute(card_data)
		return true

	if type == "unit" or type == "equipment":
		add_permanent_tribute(card_data)
		return true

	push_warning("Unknown card_type offered to Tribute: " + card_data.card_type + ". Treating as permanent for now.")
	add_permanent_tribute(card_data)
	return true


func add_permanent_tribute(card_data: CardData) -> void:
	permanent_tribute_cards.append(card_data)

	permanent_tp += 1
	current_permanent_tp += 1

	refresh_tribute_points()


func add_temporary_tribute(card_data: CardData) -> void:
	temporary_tribute_cards.append(card_data)

	temporary_tp += 2

	refresh_tribute_points()


func refresh_tribute_points() -> void:
	current_tribute_points = current_permanent_tp + temporary_tp
	tribute_changed.emit(get_status_text())


func can_afford(cost: int) -> bool:
	return current_tribute_points >= cost


func spend_tribute(cost: int) -> bool:
	if not can_afford(cost):
		return false

	var remaining_cost: int = cost

	# Spend temporary TP first because it disappears at turn end anyway.
	if temporary_tp > 0:
		var temp_spent: int = mini(temporary_tp, remaining_cost)
		temporary_tp -= temp_spent
		remaining_cost -= temp_spent

	if remaining_cost > 0:
		current_permanent_tp -= remaining_cost

	refresh_tribute_points()
	return true
	
	
func add_debug_tribute_points(amount: int = 1) -> void:
	var safe_amount: int = max(amount, 0)

	permanent_tp += safe_amount
	current_permanent_tp += safe_amount

	refresh_tribute_points()


func has_faction_access(faction: String) -> bool:
	var clean_faction := faction.to_lower()

	if clean_faction == "" or clean_faction == "neutral":
		return true

	for card in permanent_tribute_cards:
		if card.race.to_lower() == clean_faction:
			return true

	return false


func cleanup_temporary_tribute() -> void:
	temporary_tribute_cards.clear()
	temporary_tp = 0

	refresh_tribute_points()


func start_new_turn_refresh() -> void:
	current_permanent_tp = permanent_tp
	temporary_tp = 0
	temporary_tribute_cards.clear()

	refresh_tribute_points()


func get_status_text() -> String:
	return "TP: " + str(current_tribute_points) + "/" + str(permanent_tp) + " + Temp " + str(temporary_tp)


func get_counter_text() -> String:
	if temporary_tp > 0:
		return "TP " + str(current_tribute_points) + "/" + str(permanent_tp) + "\nTemp +" + str(temporary_tp)

	return "TP " + str(current_tribute_points) + "/" + str(permanent_tp)


func get_unlocked_factions() -> Array[String]:
	var factions: Array[String] = []

	for card in permanent_tribute_cards:
		var clean_race := card.race.to_lower()

		if clean_race == "":
			continue

		if clean_race == "neutral":
			continue

		if not factions.has(clean_race):
			factions.append(clean_race)

	return factions
