class_name AbilityResolver
extends RefCounted

static var _handlers: Dictionary = {}
static var _defaults_registered := false


static func register_handler(handler_id: StringName, handler: Callable) -> void:
	if handler_id == &"" or not handler.is_valid():
		push_error("AbilityResolver received an invalid handler registration.")
		return
	_handlers[handler_id] = handler


static func unregister_handler(handler_id: StringName) -> void:
	_handlers.erase(handler_id)


static func can_resolve(ability: AbilityData) -> bool:
	_ensure_default_handlers()
	return ability != null and _handlers.has(ability.get_handler_id())


static func resolve(ability: AbilityData, context: Dictionary = {}) -> Dictionary:
	_ensure_default_handlers()
	if ability == null:
		return {"handled": false, "success": false, "reason": "missing_ability"}
	var handler_id := ability.get_handler_id()
	var handler: Callable = _handlers.get(handler_id, Callable())
	if not handler.is_valid():
		return {
			"handled": false,
			"success": false,
			"ability_id": ability.ability_id,
			"reason": "no_handler_registered",
		}
	var result: Variant = handler.call(ability, context)
	if result is Dictionary:
		return result
	return {"handled": true, "success": true, "value": result}


static func resolve_card(card: CardData, trigger: StringName, context: Dictionary = {}) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if card == null:
		return results
	for ability in card.get_abilities():
		if ability != null and (StringName(ability.trigger) == trigger or ability.trigger == "passive"):
			var ability_context := context.duplicate(true)
			ability_context["card"] = card
			ability_context["trigger"] = trigger
			results.append(resolve(ability, ability_context))
	return results


static func _ensure_default_handlers() -> void:
	if _defaults_registered:
		return
	_defaults_registered = true
	register_handler(&"volley", _resolve_volley)
	register_handler(&"flank_swap", _resolve_mobility_flag.bind("swap_whole_lanes"))
	register_handler(&"imperial_decree", _resolve_mobility_flag.bind("discard_frontline_unit"))
	register_handler(&"lane_shift", _resolve_mobility_flag.bind("swap_friendly_units"))
	register_handler(&"mobilize", _resolve_mobility_flag.bind("move_adjacent"))
	register_handler(&"reassign", _resolve_mobility_flag.bind("rearrange_frontline"))
	register_handler(&"siege", _resolve_mobility_flag.bind("prevent_center_intercept"))
	register_handler(&"tactic_flow", _resolve_mobility_flag.bind("move_center_to_side"))
	register_handler(&"vanish", _resolve_mobility_flag.bind("return_to_hand"))
	register_handler(&"vortex", _resolve_mobility_flag.bind("merge_units"))
	register_handler(&"intel", _resolve_intel)
	register_handler(&"intuition", _resolve_intuition)
	register_handler(&"intelligence", _resolve_intelligence)
	register_handler(&"seer", _resolve_seer)
	register_handler(&"secrecy", _resolve_secrecy)
	register_handler(&"stealth", _resolve_stealth)
	register_handler(&"true_sight", _resolve_true_sight)
	register_handler(&"vantage", _resolve_vantage)
	register_handler(&"vision", _resolve_vision)
	for protection_id in [&"aegis", &"deflect", &"equalizer", &"infiltrator", &"last_stand", &"plated", &"shielded", &"shield_burst", &"solidarity", &"solidify", &"spell_shield", &"spiked"]:
		register_handler(protection_id, _resolve_protection_flag)


static func _resolve_volley(ability: AbilityData, context: Dictionary) -> Dictionary:
	return {
		"handled": true,
		"success": true,
		"ability_id": ability.ability_id,
		"allow_diagonal_attack": true,
		"context": context,
	}


static func _resolve_mobility_flag(ability: AbilityData, context: Dictionary, effect: String) -> Dictionary:
	return _ability_success(ability, {
		"effect": effect,
		"context": context,
	})


static func _resolve_protection_flag(ability: AbilityData, context: Dictionary) -> Dictionary:
	return _ability_success(ability, {
		"effect": String(ability.get_handler_id()),
		"context": context,
	})


static func _resolve_intel(ability: AbilityData, context: Dictionary) -> Dictionary:
	var deck := context.get("player_deck") as PlayerDeck
	var hand := context.get("hand") as HandUI
	if deck == null or hand == null:
		return _ability_failed(ability, "missing_player_deck_or_hand")
	var cards := _pop_top_cards_from_player_deck(deck, 3)
	if cards.is_empty():
		return _ability_failed(ability, "player_deck_empty")
	var taken := cards[0] as CardData
	for i in range(cards.size() - 1, 0, -1):
		deck.deck.insert(0, cards[i])
	hand.add_card_to_hand(taken)
	_emit_player_deck_changed(context)
	_log(context, "Insight - Intel: looked at " + _card_names(cards) + ". Took " + _card_name(taken) + "; put the rest on the bottom.")
	return _ability_success(ability, {"cards_seen": cards, "card_taken": taken})


static func _resolve_intuition(ability: AbilityData, context: Dictionary) -> Dictionary:
	var battlefield := context.get("battlefield") as Node
	if battlefield == null or not battlefield.has_method("get_hidden_enemy_gambit_cards"):
		return _ability_failed(ability, "missing_battlefield")
	var gambits: Array = battlefield.call("get_hidden_enemy_gambit_cards")
	if gambits.is_empty():
		_log(context, "Insight - Intuition: opponent has no face-down Gambit to inspect.")
		return _ability_success(ability, {"cards_seen": []})
	var card := gambits[0] as CardData
	_log(context, "Insight - Intuition: inspected hidden Gambit " + _card_name(card) + ".")
	return _ability_success(ability, {"cards_seen": [card]})


static func _resolve_intelligence(ability: AbilityData, context: Dictionary) -> Dictionary:
	var ai_hand: Array = context.get("ai_hand", [])
	if ai_hand.is_empty():
		_log(context, "Insight - Intelligence: opponent hand is empty.")
		return _ability_success(ability, {"cards_seen": []})
	var card := ai_hand[0] as CardData
	_log(context, "Insight - Intelligence: saw opponent hand card " + _card_name(card) + ".")
	return _ability_success(ability, {"cards_seen": [card]})


static func _resolve_seer(ability: AbilityData, context: Dictionary) -> Dictionary:
	return _discard_from_ai_deck_top_three(ability, context, "Seer")


static func _resolve_secrecy(ability: AbilityData, context: Dictionary) -> Dictionary:
	var ai_hand: Array = context.get("ai_hand", [])
	var seen: Array[CardData] = []
	var indexes: Array[int] = []
	for i in range(ai_hand.size()):
		indexes.append(i)
	indexes.shuffle()
	for i in range(mini(2, indexes.size())):
		seen.append(ai_hand[indexes[i]] as CardData)
	_log(context, "Insight - Secrecy: saw opponent hand card(s): " + _card_names(seen) + ".")
	return _ability_success(ability, {"cards_seen": seen})


static func _resolve_stealth(ability: AbilityData, context: Dictionary) -> Dictionary:
	_log(context, "Insight - Stealth: hidden decoy deploys for 0 cost because the opponent attacked instead of checking.")
	return _ability_success(ability, {"deploy_free": true})


static func _resolve_true_sight(ability: AbilityData, context: Dictionary) -> Dictionary:
	var battlefield := context.get("battlefield") as Node
	if battlefield == null or not battlefield.has_method("get_hidden_enemy_gambit_cards"):
		return _ability_failed(ability, "missing_battlefield")
	var gambits: Array = battlefield.call("get_hidden_enemy_gambit_cards")
	_log(context, "Insight - True-Sight: face-down enemy Gambit(s): " + _card_names(gambits) + ".")
	return _ability_success(ability, {"cards_seen": gambits})


static func _resolve_vantage(ability: AbilityData, context: Dictionary) -> Dictionary:
	return _discard_from_ai_deck_top_three(ability, context, "Vantage")


static func _resolve_vision(ability: AbilityData, context: Dictionary) -> Dictionary:
	var deck := context.get("player_deck") as PlayerDeck
	if deck == null:
		return _ability_failed(ability, "missing_player_deck")
	var cards := _peek_top_cards(deck.deck, 3)
	_log(context, "Insight - Vision: top player deck card(s): " + _card_names(cards) + ".")
	return _ability_success(ability, {"cards_seen": cards})


static func _discard_from_ai_deck_top_three(ability: AbilityData, context: Dictionary, label: String) -> Dictionary:
	var ai_deck: Array = context.get("ai_deck", [])
	var ai_discard: Array = context.get("ai_discard", [])
	var seen := _peek_top_cards(ai_deck, 3)
	if seen.is_empty():
		_log(context, "Insight - " + label + ": opponent deck is empty.")
		return _ability_success(ability, {"cards_seen": []})
	var discarded := ai_deck.pop_back() as CardData
	ai_discard.append(discarded)
	var battlefield := context.get("battlefield") as Node
	if battlefield != null and battlefield.has_method("update_ai_visuals"):
		battlefield.call("update_ai_visuals")
	_log(context, "Insight - " + label + ": looked at " + _card_names(seen) + ". Discarded " + _card_name(discarded) + ".")
	return _ability_success(ability, {"cards_seen": seen, "card_discarded": discarded})


static func _pop_top_cards_from_player_deck(deck: PlayerDeck, count: int) -> Array[CardData]:
	var cards: Array[CardData] = []
	for i in range(count):
		var card := deck.draw_top_card()
		if card == null:
			break
		cards.append(card)
	return cards


static func _peek_top_cards(cards: Array, count: int) -> Array[CardData]:
	var result: Array[CardData] = []
	for offset in range(count):
		var index := cards.size() - 1 - offset
		if index < 0:
			break
		result.append(cards[index] as CardData)
	return result


static func _emit_player_deck_changed(context: Dictionary) -> void:
	var deck := context.get("player_deck") as PlayerDeck
	if deck == null:
		return
	deck.deck_changed.emit(deck.cards_remaining())
	var draw_pile := context.get("draw_pile") as DrawPile
	if draw_pile != null and draw_pile.has_method("set_card_count"):
		draw_pile.call("set_card_count", deck.cards_remaining())


static func _log(context: Dictionary, message: String) -> void:
	var logger_value: Variant = context.get("log", Callable())

	if logger_value is Callable:
		var logger: Callable = logger_value as Callable
		if logger.is_valid():
			logger.call(message)


static func _card_names(cards: Array) -> String:
	if cards.is_empty():
		return "none"
	var names: PackedStringArray = []
	for card in cards:
		names.append(_card_name(card as CardData))
	return ", ".join(names)


static func _card_name(card: CardData) -> String:
	return card.card_name if card != null else "Unknown"


static func _ability_success(ability: AbilityData, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"handled": true,
		"success": true,
		"ability_id": ability.ability_id,
	}
	result.merge(extra, true)
	return result


static func _ability_failed(ability: AbilityData, reason: String) -> Dictionary:
	return {
		"handled": true,
		"success": false,
		"ability_id": ability.ability_id if ability != null else &"",
		"reason": reason,
	}
