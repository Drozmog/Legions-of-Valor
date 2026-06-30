class_name BattlefieldVolleyController
extends RefCounted

## Owns the temporary diagonal-lane action context created by Volley. Combat
## resolution remains in BattlefieldCombatController/AbilityController.

signal action_selected(action_id: int)

const ACTION_ATTACK := 2
const ACTION_CHECK := 3
const ACTION_PASS := 4
const ACTION_CANCEL := 99

var bf: BattlefieldManager
var active := false
var source_slot: Node = null
var target_lane := ""
var ability: AbilityData = null
var action_committed := false


func _init(owner_battlefield: BattlefieldManager) -> void:
	bf = owner_battlefield


func resolve(source: Node, volley_ability: AbilityData) -> bool:
	var candidates := bf.get_volley_target_slots_for_slot(source)
	var chosen := await bf.choose_mobility_slot(
		candidates,
		volley_ability.ability_name + "  -  Choose an enemy lane",
		bf.MOBILITY_PROMPT_ICON_PATH,
		volley_ability.rules_text
	)
	if chosen == null:
		return false

	active = true
	source_slot = source
	target_lane = bf.get_slot_lane(chosen)
	ability = volley_ability
	action_committed = false
	bf.log_msg("Volley selected the " + target_lane + " lane. Choose Attack, Check, or Pass.")
	bf.refresh_board_slot_action_buttons()

	while active:
		var action_id: int = await action_selected
		if not active:
			break
		match action_id:
			ACTION_ATTACK:
				action_committed = true
				var follow_up := await bf.resolve_player_attack_lane_from_specific_attacker(target_lane, source_slot, ability.ability_name)
				if follow_up:
					bf.log_msg("Volley keeps priority. Choose the follow-up action in the " + target_lane + " lane.")
					bf.refresh_board_slot_action_buttons()
					continue
				active = false
			ACTION_CHECK:
				action_committed = true
				var follow_up := await bf.resolve_player_check_lane_from_specific_attacker(target_lane, source_slot, ability.ability_name)
				if follow_up:
					bf.log_msg("Volley Check resolved. Choose the follow-up action in the " + target_lane + " lane.")
					bf.refresh_board_slot_action_buttons()
					continue
				active = false
			ACTION_PASS:
				action_committed = true
				active = false
				await bf.resolve_player_pass_lane_with_visuals(bf.get_slot_lane(source_slot))
			ACTION_CANCEL:
				active = false

	var used := action_committed
	clear()
	return used


func submit_action(action_id: int, slot: Node) -> bool:
	if not active or slot == null or bf.get_slot_lane(slot) != target_lane:
		return false
	action_selected.emit(action_id)
	return true


func cancel() -> bool:
	if not active:
		return false
	action_selected.emit(ACTION_CANCEL)
	return true


func get_target_actions() -> Array[int]:
	var actions: Array[int] = []
	if not active or source_slot == null:
		return actions
	actions.append(ACTION_ATTACK)
	var back := bf.find_slot_by_owner_row_lane("enemy", "back", target_lane)
	if back != null and bf.get_slot_card_data(back) != null and bool(back.get_meta("face_down", false)):
		actions.append(ACTION_CHECK)
	actions.append(ACTION_PASS)
	return actions


func clear() -> void:
	active = false
	source_slot = null
	target_lane = ""
	ability = null
	action_committed = false
	bf.refresh_board_slot_action_buttons()
