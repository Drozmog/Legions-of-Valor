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


static func _resolve_volley(ability: AbilityData, context: Dictionary) -> Dictionary:
	return {
		"handled": true,
		"success": true,
		"ability_id": ability.ability_id,
		"allow_diagonal_attack": true,
		"context": context,
	}
