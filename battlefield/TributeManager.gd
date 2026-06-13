extends Node

var tribute_pile_count: int = 0
var current_tribute_points: int = 0


func add_tribute(amount: int = 1) -> void:
	tribute_pile_count += amount
	refresh_tribute_points()


func refresh_tribute_points() -> void:
	current_tribute_points = tribute_pile_count


func can_afford(cost: int) -> bool:
	return current_tribute_points >= cost


func spend_tribute(cost: int) -> bool:
	if not can_afford(cost):
		return false

	current_tribute_points -= cost
	return true


func get_status_text() -> String:
	return "TP: " + str(current_tribute_points) + "/" + str(tribute_pile_count)
