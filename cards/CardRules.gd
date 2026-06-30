class_name CardRules
extends RefCounted

# Pure, stateless card-classification and cost rules.
#
# Extracted from BattlefieldManager.gd so the battlefield, the deck builder,
# and any future system share one source of truth for "what kind of card is this?".
# Every function here is static and depends ONLY on its arguments -- it touches
# no game state, so it is always safe to call from anywhere.


static func get_clean_card_type(card_data: CardData) -> String:
	if card_data == null:
		return ""

	return card_data.card_type.to_lower().strip_edges()


static func get_clean_card_race(card_data: CardData) -> String:
	if card_data == null:
		return ""

	return card_data.race.to_lower().strip_edges()


static func is_unit_card(card_data: CardData) -> bool:
	return get_clean_card_type(card_data) == "unit"


static func is_gambit_card(card_data: CardData) -> bool:
	return get_clean_card_type(card_data) == "gambit"


static func is_equipment_card(card_data: CardData) -> bool:
	return get_clean_card_type(card_data) == "equipment"


static func is_elite_card(card_data: CardData) -> bool:
	return card_data != null and card_data.is_crown_rarity()


static func get_deck_copy_limit(card_data: CardData) -> int:
	return 2 if is_elite_card(card_data) else 3


static func get_defeat_aurion_reward(card_data: CardData) -> int:
	# Diamond units are normal (+1). Every star-tier unit is elite (+2).
	# Crown rarity remains worth the elite reward as well.
	if is_unit_card(card_data) and card_data.get_rarity_rank() >= 3:
		return 2
	return 1


static func is_trap_card(_card_data: CardData) -> bool:
	return false


static func is_ruse_card(_card_data: CardData) -> bool:
	return false


static func is_event_card(_card_data: CardData) -> bool:
	return false


static func is_spell_card(card_data: CardData) -> bool:
	return is_gambit_card(card_data)


# Legacy alias for the old "spell-like" bucket. Kept so older call sites still work.
static func is_spell_like_card(card_data: CardData) -> bool:
	return is_gambit_card(card_data)


# Generic Shadowtax / Subterfuge cost for placing ANY card face down.
# 1st face-down card this round = 1 TP, 2nd = 3 TP, 3rd = 5 TP, etc.
static func get_face_down_card_setup_cost(count_already_set_this_round: int) -> int:
	return 1 + max(0, count_already_set_this_round) * 2
