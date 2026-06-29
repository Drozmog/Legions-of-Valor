class_name AIRandomDeckBuilder
extends RefCounted

## Builds a legal, synergy-weighted 40-card enemy deck.
## Dependency: an optional Callable(String) used for battle-log reporting.

var _log_message: Callable


func _init(log_message: Callable = Callable()) -> void:
	_log_message = log_message


func log_msg(message: String) -> void:
	if _log_message.is_valid():
		_log_message.call(message)

func ai_build_random_synergy_deck() -> Array[CardData]:
	var all_cards: Array[CardData] = CardDatabase.get_all_test_cards()
	var deck: Array[CardData] = []

	if all_cards.is_empty():
		return deck

	var archetype := ai_choose_random_deck_archetype()
	var primary_race := ai_choose_random_deck_primary_race(all_cards)
	var secondary_race := ai_choose_random_deck_secondary_race(all_cards, primary_race)
	var copy_counts: Dictionary = {}

	var low_cost_primary_units := ai_random_deck_filter_cards(
		all_cards,
		"unit",
		primary_race,
		secondary_race,
		3
	)

	var all_units := ai_random_deck_filter_cards(
		all_cards,
		"unit",
		primary_race,
		secondary_race,
		-1
	)

	var all_equipment := ai_random_deck_filter_cards(
		all_cards,
		"equipment",
		primary_race,
		secondary_race,
		-1
	)

	var all_gambits := ai_random_deck_filter_cards(
		all_cards,
		"gambit",
		primary_race,
		secondary_race,
		-1
	)

	# Early playable cards so the deck does not brick on Tribute/Faction Gate.
	ai_random_deck_add_best_cards(deck, copy_counts, low_cost_primary_units, 8, archetype, primary_race, secondary_race)

	# Main deck shape: unit-heavy, with some equipment and gambits.
	ai_random_deck_add_best_cards(deck, copy_counts, all_units, 24, archetype, primary_race, secondary_race)
	ai_random_deck_add_best_cards(deck, copy_counts, all_equipment, 30, archetype, primary_race, secondary_race)
	ai_random_deck_add_best_cards(deck, copy_counts, all_gambits, 40, archetype, primary_race, secondary_race)

	# Safety fill if the current card pool cannot satisfy the exact shape.
	if deck.size() < 40:
		ai_random_deck_add_best_cards(deck, copy_counts, all_cards, 40, archetype, primary_race, secondary_race, true)

	while deck.size() > 40:
		deck.pop_back()

	deck.shuffle()

	log_msg(
		"AI built a Random Synergy Deck: "
		+ String(archetype.get("name", "Unknown Archetype"))
		+ " | Race: "
		+ primary_race.capitalize()
		+ ((" / " + secondary_race.capitalize()) if secondary_race != "" else "")
		+ " | Cards: "
		+ str(deck.size())
	)

	return deck


func ai_choose_random_deck_archetype() -> Dictionary:
	var archetypes: Array[Dictionary] = [
		{
			"name": "Vanguard Assault",
			"preferred_categories": ["assault", "mobility", "protection"],
			"preferred_triggers": ["on_attack", "attack_targeting", "combat_power", "on_clash_won"],
		},
		{
			"name": "Bulwark Control",
			"preferred_categories": ["protection", "control", "insight"],
			"preferred_triggers": ["on_defense", "protection_check", "parry_check", "active"],
		},
		{
			"name": "Attrition Engine",
			"preferred_categories": ["attrition", "economy", "control"],
			"preferred_triggers": ["on_destroyed", "on_discard", "on_turn_end", "on_deploy"],
		},
		{
			"name": "Mobility Tempo",
			"preferred_categories": ["mobility", "insight", "assault"],
			"preferred_triggers": ["active", "attack_targeting", "on_deploy", "on_monarch_strike"],
		},
		{
			"name": "Resource Pressure",
			"preferred_categories": ["economy", "protection", "insight"],
			"preferred_triggers": ["on_draw", "on_deploy", "deployment_cost", "on_turn_start"],
		},
	]

	return archetypes.pick_random()


func ai_choose_random_deck_primary_race(all_cards: Array[CardData]) -> String:
	var race_counts: Dictionary = {}

	for card_data in all_cards:
		if card_data == null:
			continue

		if ai_random_deck_card_type(card_data) != "unit":
			continue

		var race := ai_random_deck_card_race(card_data)

		if race == "":
			continue

		race_counts[race] = int(race_counts.get(race, 0)) + 1

	var candidates: Array[String] = []

	for race in race_counts.keys():
		if int(race_counts.get(race, 0)) >= 4:
			candidates.append(String(race))

	if candidates.is_empty():
		return ""

	return candidates.pick_random()


func ai_choose_random_deck_secondary_race(all_cards: Array[CardData], primary_race: String) -> String:
	if primary_race == "":
		return ""

	# Most AI random decks should stay single-faction for Faction Gate consistency.
	if randi() % 100 < 70:
		return ""

	var race_counts: Dictionary = {}

	for card_data in all_cards:
		if card_data == null:
			continue

		if ai_random_deck_card_type(card_data) != "unit":
			continue

		var race := ai_random_deck_card_race(card_data)

		if race == "" or race == primary_race:
			continue

		race_counts[race] = int(race_counts.get(race, 0)) + 1

	var candidates: Array[String] = []

	for race in race_counts.keys():
		if int(race_counts.get(race, 0)) >= 4:
			candidates.append(String(race))

	if candidates.is_empty():
		return ""

	return candidates.pick_random()


func ai_random_deck_filter_cards(
	all_cards: Array[CardData],
	wanted_type: String,
	primary_race: String,
	secondary_race: String,
	max_cost: int = -1
) -> Array[CardData]:
	var result: Array[CardData] = []

	for card_data in all_cards:
		if card_data == null:
			continue

		if ai_random_deck_card_type(card_data) != wanted_type:
			continue

		if max_cost >= 0 and card_data.tribute_cost > max_cost:
			continue

		var race := ai_random_deck_card_race(card_data)

		if wanted_type == "unit":
			if primary_race != "" and race != primary_race and race != secondary_race:
				continue
		else:
			# Non-units are allowed if neutral or attached to the chosen race pair.
			if race != "" and primary_race != "" and race != primary_race and race != secondary_race:
				continue

		result.append(card_data)

	return result


func ai_random_deck_add_best_cards(
	deck: Array[CardData],
	copy_counts: Dictionary,
	source_pool: Array[CardData],
	target_size: int,
	archetype: Dictionary,
	primary_race: String,
	secondary_race: String,
	relaxed_copy_limit: bool = false
) -> void:
	if deck.size() >= target_size:
		return

	var scored: Array[Dictionary] = []

	for card_data in source_pool:
		if card_data == null:
			continue

		if not ai_random_deck_can_add_card(card_data, copy_counts, relaxed_copy_limit):
			continue

		scored.append({
			"card": card_data,
			"score": ai_random_deck_score_card(card_data, archetype, primary_race, secondary_race)
		})

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)

	for entry in scored:
		if deck.size() >= target_size:
			return

		var card_data := entry.get("card") as CardData

		if card_data == null:
			continue

		if not ai_random_deck_can_add_card(card_data, copy_counts, relaxed_copy_limit):
			continue

		deck.append(card_data)

		var key := ai_random_deck_copy_key(card_data)
		copy_counts[key] = int(copy_counts.get(key, 0)) + 1


func ai_random_deck_score_card(
	card_data: CardData,
	archetype: Dictionary,
	primary_race: String,
	secondary_race: String
) -> int:
	if card_data == null:
		return -999999

	var score := 0
	var card_type := ai_random_deck_card_type(card_data)
	var race := ai_random_deck_card_race(card_data)
	var preferred_categories: Array = archetype.get("preferred_categories", [])
	var preferred_triggers: Array = archetype.get("preferred_triggers", [])

	match card_type:
		"unit":
			score += 90
			score += card_data.ap * 5
			score += card_data.dp * 3

		"equipment":
			score += 54
			score += card_data.ap * 4
			score += card_data.dp * 4

		"gambit":
			score += 46

		_:
			score -= 80

	if race == primary_race and race != "":
		score += 42
	elif race == secondary_race and race != "":
		score += 16
	elif race == "":
		score += 8
	else:
		score -= 46

	if card_data.tribute_cost <= 1:
		score += 18
	elif card_data.tribute_cost <= 3:
		score += 24
	elif card_data.tribute_cost <= 5:
		score += 14
	elif card_data.tribute_cost <= 7:
		score += 4
	else:
		score -= 18

	for category in card_data.get_ability_categories():
		var clean_category := String(category).to_lower().strip_edges()

		if preferred_categories.has(clean_category):
			score += 28

		# These are the categories currently most supported by the AI implementation.
		if clean_category == "protection" or clean_category == "mobility" or clean_category == "insight":
			score += 10

	for ability in card_data.get_abilities():
		if ability == null:
			continue

		if preferred_triggers.has(String(ability.trigger).to_lower().strip_edges()):
			score += 14

		if String(ability.trigger).to_lower().strip_edges() == "active":
			score += 8

	score += card_data.get_rarity_rank() * 3

	# Small randomness so the AI does not build the exact same deck every time.
	score += randi() % 18

	return score


func ai_random_deck_can_add_card(card_data: CardData, copy_counts: Dictionary, relaxed_copy_limit: bool = false) -> bool:
	if card_data == null:
		return false

	var key := ai_random_deck_copy_key(card_data)
	var current_count := int(copy_counts.get(key, 0))
	var limit := ai_random_deck_max_copies(card_data)

	if relaxed_copy_limit:
		limit += 2

	return current_count < limit


func ai_random_deck_max_copies(card_data: CardData) -> int:
	if card_data == null:
		return 0

	if card_data.is_crown_rarity():
		return 1

	if card_data.is_premium_rarity():
		return 2

	return 3


func ai_random_deck_copy_key(card_data: CardData) -> String:
	if card_data == null:
		return ""

	if card_data.card_id.strip_edges() != "":
		return card_data.card_id.strip_edges().to_lower()

	return card_data.card_name.to_lower().strip_edges().replace(" ", "_")


func ai_random_deck_card_type(card_data: CardData) -> String:
	if card_data == null:
		return ""

	return card_data.card_type.to_lower().strip_edges()


func ai_random_deck_card_race(card_data: CardData) -> String:
	if card_data == null:
		return ""

	return card_data.race.to_lower().strip_edges()
