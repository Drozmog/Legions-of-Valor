class_name BattlefieldManagerPhase35CombatReadability
extends "res://battlefield/BattlefieldManagerPhase3CombatMenu.gd"

const COMBAT_LANE_GLOW: Color = Color(1.0, 1.0, 1.0, 0.82)
const COMBAT_LANE_START_DELAY: float = 0.35
const COMBAT_LANE_END_DELAY: float = 0.45

var active_combat_lane: String = ""
var combat_resolution_running: bool = false


func _ready() -> void:
	super._ready()
	patch_game_log_for_scrolling()


func patch_game_log_for_scrolling() -> void:
	if game_log == null:
		return

	if game_log.has_variable("max_lines"):
		game_log.max_lines = 200

	var panel: PanelContainer = game_log.get_node_or_null("PanelContainer") as PanelContainer
	var margin: MarginContainer = game_log.get_node_or_null("PanelContainer/MarginContainer") as MarginContainer
	var log_text: RichTextLabel = game_log.get_node_or_null("PanelContainer/MarginContainer/LogText") as RichTextLabel

	if panel != null:
		panel.offset_left = 20.0
		panel.offset_top = 20.0
		panel.offset_right = 520.0
		panel.offset_bottom = 235.0
		panel.custom_minimum_size = Vector2(500.0, 215.0)

	if margin != null:
		margin.custom_minimum_size = Vector2(480.0, 195.0)
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)

	if log_text != null:
		log_text.custom_minimum_size = Vector2(460.0, 180.0)
		log_text.scroll_active = true
		log_text.scroll_following = true
		log_text.fit_content = false
		log_text.clip_contents = true
		log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		log_text.mouse_filter = Control.MOUSE_FILTER_STOP


func begin_combat_phase() -> void:
	reset_combat_state()
	clear_active_combat_lane_highlight()

	if player_has_initiative:
		log_msg("Phase: Combat. Player has initiative. Right-click the leftmost or rightmost lane, then choose Attack.")
	else:
		log_msg("Phase: Combat. AI has initiative. Combat will resolve lane by lane visually.")
		await get_tree().create_timer(COMBAT_LANE_START_DELAY).timeout
		ai_take_combat_initiative()


func start_next_round() -> void:
	clear_active_combat_lane_highlight()
	super.start_next_round()


func set_phase(new_phase: int) -> void:
	if current_phase == BattlePhase.COMBAT and new_phase != BattlePhase.COMBAT:
		clear_active_combat_lane_highlight()

	super.set_phase(new_phase)


func attack_from_board_action_menu(slot: Node) -> void:
	if combat_resolution_running:
		log_msg("Combat is already resolving. Wait for the current lane.")
		return

	if slot == null:
		return

	if current_phase != BattlePhase.COMBAT:
		log_msg("Attack is only available during Combat.")
		return

	if parry_active:
		log_msg("Resolve the current parry prompt first.")
		return

	if not player_has_initiative:
		log_msg("AI has initiative this combat. You cannot attack from the menu yet.")
		return

	var lane: String = get_slot_lane(slot)

	if lane == "":
		return

	await resolve_player_attack_lane_with_visuals(lane)


func resolve_player_attack_lane_with_visuals(lane: String) -> void:
	if combat_resolution_running:
		return

	combat_resolution_running = true

	if not combat_direction_selected:
		if lane == "left":
			set_combat_lane_order_from_left()
		elif lane == "right":
			set_combat_lane_order_from_right()
		else:
			log_msg("Choose the leftmost or rightmost lane first to set combat direction.")
			combat_resolution_running = false
			return

	if combat_next_lane_index >= combat_lane_order.size():
		log_msg("All combat lanes are already resolved.")
		combat_resolution_running = false
		return

	var expected_lane: String = combat_lane_order[combat_next_lane_index]

	if lane != expected_lane:
		log_msg("Next combat must resolve in the " + expected_lane + " lane.")
		combat_resolution_running = false
		return

	set_active_combat_lane_highlight(lane)
	log_msg("Resolving " + lane + " lane.")
	await get_tree().create_timer(COMBAT_LANE_START_DELAY).timeout

	var player_front_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)
	var enemy_front_slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)
	var enemy_back_slot: Node = find_slot_by_owner_row_lane("enemy", "back", lane)

	var player_card: CardData = get_slot_card_data(player_front_slot)

	if not is_unit_card(player_card):
		log_msg(lane.capitalize() + " lane: you have no front-row unit to attack with.")
		combat_resolution_running = false
		return

	var enemy_front_card: CardData = get_slot_card_data(enemy_front_slot)
	var enemy_back_card: CardData = get_slot_card_data(enemy_back_slot)

	if enemy_front_card == null and enemy_back_card == null:
		resolve_monarch_strike(lane, player_card)
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		advance_combat_lane_after_resolution()
		combat_resolution_running = false
		return

	if enemy_front_card != null:
		resolve_lane_combat(lane, player_front_slot, enemy_front_slot)

		if parry_active:
			combat_resolution_running = false
			return

		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		advance_combat_lane_after_resolution()
		combat_resolution_running = false
		return

	log_msg(lane.capitalize() + " lane: enemy back row is occupied. Check system comes in the next phase.")
	combat_resolution_running = false


func ai_resolve_combat_sequence() -> void:
	if combat_resolution_running:
		return

	combat_resolution_running = true

	while current_phase == BattlePhase.COMBAT and not parry_active and combat_next_lane_index < combat_lane_order.size():
		var next_lane: String = combat_lane_order[combat_next_lane_index]
		await resolve_ai_combat_lane_with_visuals(next_lane)
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout

	combat_resolution_running = false


func resolve_ai_combat_lane_with_visuals(lane: String) -> void:
	if current_phase != BattlePhase.COMBAT:
		return

	if combat_next_lane_index >= combat_lane_order.size():
		return

	var expected_lane: String = combat_lane_order[combat_next_lane_index]

	if lane != expected_lane:
		return

	set_active_combat_lane_highlight(lane)
	log_msg("AI resolving " + lane + " lane.")
	await get_tree().create_timer(COMBAT_LANE_START_DELAY).timeout

	var player_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)
	var opponent_slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)

	resolve_lane_combat(lane, player_slot, opponent_slot)

	if parry_active:
		return

	advance_combat_lane_after_resolution()


func advance_combat_lane_after_resolution() -> void:
	clear_active_combat_lane_highlight()
	super.advance_combat_lane_after_resolution()

	if current_phase != BattlePhase.COMBAT:
		return

	if parry_active:
		return

	if combat_next_lane_index < combat_lane_order.size():
		set_active_combat_lane_highlight(combat_lane_order[combat_next_lane_index])


func begin_parry_prompt(
	lane: String,
	attacker_slot: Node,
	attacker_card: CardData,
	defender_slot: Node,
	defender_card: CardData
) -> void:
	set_active_combat_lane_highlight(lane)
	super.begin_parry_prompt(lane, attacker_slot, attacker_card, defender_slot, defender_card)


func end_parry_prompt() -> void:
	super.end_parry_prompt()
	clear_active_combat_lane_highlight()

	if current_phase == BattlePhase.COMBAT and combat_next_lane_index < combat_lane_order.size():
		set_active_combat_lane_highlight(combat_lane_order[combat_next_lane_index])


func set_active_combat_lane_highlight(lane: String) -> void:
	if lane == "":
		return

	clear_active_combat_lane_highlight()
	active_combat_lane = lane

	if board_slots == null:
		return

	for slot in board_slots.get_children():
		if slot == null:
			continue

		if get_slot_lane(slot) != lane:
			continue

		if slot.has_method("set_highlight"):
			slot.set_highlight(true)

		if slot.has_method("set_outline_color"):
			slot.set_outline_color(COMBAT_LANE_GLOW)


func clear_active_combat_lane_highlight() -> void:
	if board_slots == null:
		active_combat_lane = ""
		return

	for slot in board_slots.get_children():
		if slot == null:
			continue

		if active_combat_lane != "" and get_slot_lane(slot) != active_combat_lane:
			continue

		if slot.has_method("set_highlight"):
			slot.set_highlight(false)

	active_combat_lane = ""
