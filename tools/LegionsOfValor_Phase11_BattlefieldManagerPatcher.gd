@tool
extends EditorScript

# Legions of Valor - Phase 11 BattlefieldManager patcher
# This is read/write only on your local project file:
# res://battlefield/BattlefieldManager.gd
# It does not touch GitHub.

const TARGET_PATH := "res://battlefield/BattlefieldManager.gd"

var changes_applied: int = 0
var warnings: Array[String] = []

const OLD_PLAYER_PROMOTION_BLOCK := """\tsend_slot_card_to_discard(slot)

\tvar placed_successfully: bool = slot.place_card(TEST_CARD_SCENE, new_unit, false)"""

const NEW_PLAYER_PROMOTION_BLOCK := """\tvar placed_successfully: bool = promote_slot_unit_preserving_equipment(slot, new_unit, "player")"""

const OLD_AI_PROMOTION_BLOCK := """\t\tawait play_enemy_hand_to_node_animation(card_data, target_slot, false)
\t\tsend_slot_card_to_discard(target_slot)

\t\tif target_slot.has_method("place_card"):
\t\t\tsuccess = target_slot.place_card(TEST_CARD_SCENE, card_data, false)"""

const NEW_AI_PROMOTION_BLOCK := """\t\tawait play_enemy_hand_to_node_animation(card_data, target_slot, false)
\t\tsuccess = promote_slot_unit_preserving_equipment(target_slot, card_data, "enemy")"""

const OLD_DOMINANCE_FUNCTION := """func resolve_dominance_before_cleanup() -> void:
\tif current_phase != BattlePhase.COMBAT:
\t\treturn

\tvar checked_lanes: Array[String] = ["left", "right"]
\tvar dominance_awarded: bool = false

\tfor lane in checked_lanes:
\t\tvar player_ap: int = get_front_lane_ap_total("player", lane)
\t\tvar ai_ap: int = get_front_lane_ap_total("enemy", lane)

\t\tif player_ap > ai_ap:
\t\t\tadd_aurion("player", 1, lane.capitalize() + " lane Dominance: Player AP " + str(player_ap) + " vs AI AP " + str(ai_ap) + ".")
\t\t\tdominance_awarded = true
\t\telif ai_ap > player_ap:
\t\t\tadd_aurion("ai", 1, lane.capitalize() + " lane Dominance: AI AP " + str(ai_ap) + " vs Player AP " + str(player_ap) + ".")
\t\t\tdominance_awarded = true
\t\telse:
\t\t\tlog_msg(lane.capitalize() + " lane Dominance: tied at " + str(player_ap) + " AP. No Aurion gained.")

\tif dominance_awarded:
\t\tlog_msg("Dominance resolved for side lanes before cleanup.")
\telse:
\t\tlog_msg("Dominance resolved. No side-lane advantage gained.")"""

const NEW_DOMINANCE_FUNCTION := """func resolve_dominance_before_cleanup() -> void:
\tif current_phase != BattlePhase.COMBAT:
\t\treturn

\tvar checked_lanes: Array[String] = ["left", "right"]
\tvar player_has_dominance: bool = false
\tvar ai_has_dominance: bool = false

\tfor lane in checked_lanes:
\t\tvar player_ap: int = get_front_lane_ap_total("player", lane)
\t\tvar ai_ap: int = get_front_lane_ap_total("enemy", lane)

\t\tif player_ap > ai_ap:
\t\t\tplayer_has_dominance = true
\t\t\tlog_msg(lane.capitalize() + " lane Dominance: Player AP " + str(player_ap) + " vs AI AP " + str(ai_ap) + ".")
\t\telif ai_ap > player_ap:
\t\t\tai_has_dominance = true
\t\t\tlog_msg(lane.capitalize() + " lane Dominance: AI AP " + str(ai_ap) + " vs Player AP " + str(player_ap) + ".")
\t\telse:
\t\t\tlog_msg(lane.capitalize() + " lane Dominance: tied at " + str(player_ap) + " AP. No Aurion gained.")

\tif player_has_dominance:
\t\tadd_aurion("player", 1, "Dominance: controlled at least one side lane this turn.")

\tif ai_has_dominance:
\t\tadd_aurion("ai", 1, "Dominance: controlled at least one side lane this turn.")

\tif player_has_dominance or ai_has_dominance:
\t\tlog_msg("Dominance resolved. Each side can gain at most +1 Aurion from Dominance this turn.")
\telse:
\t\tlog_msg("Dominance resolved. No side-lane advantage gained.")"""

const OLD_PLAYER_FAILED_CHECK_MARKER := """\tadd_aurion("ai", 1, "Failed Check: " + back_card.card_name + " was a decoy.")
\tenemy_fortified_lanes[lane] = true
\tlog_msg("Check failed. Decoy returns to enemy hand. Enemy is fortified and gains priority in this lane.")"""

const NEW_PLAYER_FAILED_CHECK_MARKER := """\tadd_aurion("ai", 1, "Failed Check: " + back_card.card_name + " was a decoy.")
\tenemy_fortified_lanes[lane] = true
\t# Failed Check spends the checker’s lane action. If AI declines to attack and passes, the lane ends.
\tplayer_passed_current_lane = true
\tlog_msg("Check failed. Decoy returns to enemy hand. Enemy is fortified and gains priority in this lane.")"""

const OLD_AI_FAILED_CHECK_MARKER := """\tadd_aurion("player", 1, "AI failed Check: " + back_card.card_name + " was a decoy.")
\tplayer_fortified_lanes[lane] = true
\tlog_msg("AI Check failed. Your decoy returns to hand. Player is fortified and gains priority in this lane.")"""

const NEW_AI_FAILED_CHECK_MARKER := """\tadd_aurion("player", 1, "AI failed Check: " + back_card.card_name + " was a decoy.")
\tplayer_fortified_lanes[lane] = true
\t# Failed Check spends the checker’s lane action. If Player declines to attack and passes, the lane ends.
\tai_passed_current_lane = true
\tlog_msg("AI Check failed. Your decoy returns to hand. Player is fortified and gains priority in this lane.")"""

const SEND_SLOT_FUNCTION_HEADER := """func send_slot_card_to_discard(slot: Node) -> void:"""

const PROMOTION_HELPER_FUNCTION := """func promote_slot_unit_preserving_equipment(slot: Node, new_unit: CardData, slot_owner: String) -> bool:
\tif slot == null or new_unit == null:
\t\treturn false

\tvar old_unit: CardData = get_slot_card_data(slot)
\tvar equipment_cards: Array[CardData] = []

\tif slot.has_method("get_equipment_cards"):
\t\tvar raw_equipment_cards: Array = slot.get_equipment_cards()

\t\tfor equipment_card in raw_equipment_cards:
\t\t\tif equipment_card == null:
\t\t\t\tcontinue

\t\t\tequipment_cards.append(equipment_card as CardData)

\tif old_unit != null:
\t\tplay_card_to_discard_animation(old_unit, slot, slot_owner)

\t\tif slot_owner == "enemy":
\t\t\tai_discard.append(old_unit)
\t\telif discard_pile != null:
\t\t\tdiscard_pile.add_card(old_unit)

\tif slot.has_method("clear_slot"):
\t\tslot.clear_slot()

\tif not slot.has_method("place_card"):
\t\treturn false

\tvar placed_successfully: bool = slot.place_card(TEST_CARD_SCENE, new_unit, false)

\tif not placed_successfully:
\t\tupdate_ai_visuals()
\t\treturn false

\tfor equipment_card in equipment_cards:
\t\tif equipment_card == null:
\t\t\tcontinue

\t\tif not slot.has_method("attach_equipment"):
\t\t\tcontinue

\t\tif slot.has_method("can_attach_equipment") and not slot.can_attach_equipment():
\t\t\tcontinue

\t\tslot.attach_equipment(TEST_CARD_SCENE, equipment_card)

\tupdate_ai_visuals()
\treturn true"""


func _run() -> void:
	var source: String = _read_text(TARGET_PATH)

	if source == "":
		push_error("Could not read " + TARGET_PATH)
		return

	# Normalize line endings so the exact repo-based replacements work reliably.
	source = source.replace("\r\n", "\n")

	if not source.begins_with("class_name BattlefieldManager\nextends Node3D"):
		push_error("Safety stop: BattlefieldManager.gd does not start with 'class_name BattlefieldManager' and 'extends Node3D'. No changes written.")
		return

	source = _replace_exact(source, OLD_PLAYER_PROMOTION_BLOCK, NEW_PLAYER_PROMOTION_BLOCK, "player promotion preserves equipment")
	source = _replace_exact(source, OLD_AI_PROMOTION_BLOCK, NEW_AI_PROMOTION_BLOCK, "AI promotion preserves equipment")
	source = _replace_exact(source, OLD_DOMINANCE_FUNCTION, NEW_DOMINANCE_FUNCTION, "Dominance max +1 Aurion per side")
	source = _replace_exact(source, OLD_PLAYER_FAILED_CHECK_MARKER, NEW_PLAYER_FAILED_CHECK_MARKER, "failed player Check spends lane action")
	source = _replace_exact(source, OLD_AI_FAILED_CHECK_MARKER, NEW_AI_FAILED_CHECK_MARKER, "failed AI Check spends lane action")

	if source.find("func promote_slot_unit_preserving_equipment(") == -1:
		source = _replace_exact(
			source,
			SEND_SLOT_FUNCTION_HEADER,
			PROMOTION_HELPER_FUNCTION + "\n\n\n" + SEND_SLOT_FUNCTION_HEADER,
			"insert promotion equipment-preservation helper"
		)
	else:
		print("Already present: promotion equipment-preservation helper")

	if warnings.size() > 0:
		for warning in warnings:
			push_warning(warning)

	_write_text(TARGET_PATH, source)
	print("Legions of Valor Phase 11 patch complete. Changes applied: " + str(changes_applied) + ". Target: " + TARGET_PATH)


func _replace_exact(source: String, old_text: String, new_text: String, label: String) -> String:
	if source.find(old_text) != -1:
		changes_applied += 1
		print("Applied: " + label)
		return source.replace(old_text, new_text)

	if source.find(new_text) != -1:
		print("Already applied: " + label)
		return source

	warnings.append("Could not find expected block for: " + label)
	return source


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		return ""

	var text: String = file.get_as_text()
	file.close()
	return text


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		push_error("Could not write " + path)
		return

	file.store_string(text)
	file.close()
