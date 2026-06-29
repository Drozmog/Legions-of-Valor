class_name AIDebugPanel
extends PanelContainer

## Read-only diagnostics for adaptive enemy state. Toggled with F8 by the host.
## Dependency: BattlefieldManager's public AI state/query API.

var battlefield: BattlefieldManager
var detail_label: Label


func setup(owner_battlefield: BattlefieldManager) -> void:
	battlefield = owner_battlefield
	name = "AIDebugPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -560.0
	offset_right = -18.0
	offset_top = 18.0
	offset_bottom = 330.0
	z_index = 220
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.72)
	panel_style.border_color = Color(1.0, 1.0, 1.0, 0.16)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", panel_style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	detail_label = Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 14)
	detail_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
	detail_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	detail_label.add_theme_constant_override("outline_size", 1)
	margin.add_child(detail_label)


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	if not visible or battlefield == null:
		return
	var lane := battlefield.current_combat_lane()
	var hidden_rate := int(round(battlefield.ai_memory_player_hidden_gambit_rate() * 100.0))
	var check_rate := int(round(battlefield.ai_memory_player_check_success_rate() * 100.0))
	var profile := battlefield.ai_get_difficulty_profile()
	var turn_key := battlefield.ai_get_active_ability_turn_key()
	var uses := int(battlefield.ai_active_ability_turn_use_counts.get(turn_key, 0))
	detail_label.text = (
		"AI DEBUG  [F8]\n"
		+ "Difficulty: " + battlefield.ai_get_difficulty_name() + "\n"
		+ "Profile: M %s | R %s | L %s | A %s | Active %s\n" % [
			profile.get("memory_weight", 0.0), profile.get("randomness_multiplier", 0.0),
			profile.get("lookahead_weight", 0.0), profile.get("ability_awareness_weight", 0.0),
			profile.get("active_ability_weight", 0.0)]
		+ "Phase: %s | Turn: %d\n" % [battlefield.ai_get_phase_name(), battlefield.turn_number]
		+ "Lane: %s | Priority: %s\n" % [lane, battlefield.combat_priority_owner]
		+ "TP: %d/%d Temp +%d\n" % [battlefield.ai_current_tp, battlefield.ai_perm_tp, battlefield.ai_temp_tp]
		+ "Active uses: %d/%d\n" % [uses, battlefield.ai_max_active_ability_uses_per_turn()]
		+ "Hand: %d | Deck: %d | Discard: %d | Tribute: %d\n\n" % [
			battlefield.ai_hand.size(), battlefield.ai_deck.size(), battlefield.ai_discard.size(), battlefield.ai_tribute.size()]
		+ "Memory:\n- Hidden seen: %d | Gambit rate: %d%%\n" % [battlefield.ai_memory_player_hidden_cards_seen, hidden_rate]
		+ "- Player checks: %d | Success rate: %d%%\n" % [battlefield.ai_memory_player_checks_seen, check_rate]
		+ "- Lane pressure: L %d / M %d / R %d\n\n" % [
			battlefield.ai_memory_player_lane_pressure_score("left"),
			battlefield.ai_memory_player_lane_pressure_score("middle"),
			battlefield.ai_memory_player_lane_pressure_score("right")]
		+ "Last Decisions:\n- Tribute: %s\n- Deployment: %s\n- Active Ability: %s\n- Combat: %s" % [
			battlefield.ai_last_tribute_decision, battlefield.ai_last_deployment_decision,
			battlefield.ai_last_active_ability_decision, battlefield.ai_last_combat_decision]
	)
