class_name ParrySystem
extends Node

# The Parry Chain subsystem, extracted from BattlefieldManager.
#
# Owns all parry state, the 3D parry pit, and the parry prompt UI, plus the
# sacrifice / resolution logic. Holds a back-reference to the BattlefieldManager
# (`bf`) for shared services it does not own: logging, board/discard/hand access,
# card animations, Aurion scoring, and combat-lane highlighting / phase text.
#
# Behaviour is identical to the original in-manager implementation; only the
# `parry_` name prefixes were dropped (they are now namespaced by this class)
# and external calls were routed through `bf`.

const TEST_CARD_SCENE: PackedScene = preload("res://cards/Card3D_Test.tscn")

var bf: BattlefieldManager = null

# --- Parry chain state ---
var active: bool = false
var lane: String = ""
var attacker_slot: Node = null
var attacker_card: CardData = null
var defender_slot: Node = null
var defender_card: CardData = null
var attacker_ap: int = 0
var defender_ap: int = 0
var required_dp: int = 0
var gathered_dp: int = 0

# --- Pit + prompt nodes ---
var pit_root: Node3D = null
var pit_glow: Node3D = null
var dp_counter: Node = null
var pit_drop_area: Area3D = null
var sacrifice_stack_root: Node3D = null
var sacrifice_nodes: Array[Node3D] = []
var sacrifice_cards: Array[CardData] = []
var prompt_panel: PanelContainer = null
var prompt_label: Label = null
var let_die_button: Button = null

var prompt_title_label: Label = null
var prompt_matchup_label: Label = null
var prompt_instruction_label: Label = null
var prompt_formula_label: Label = null
var prompt_needed_label: Label = null
var prompt_progress_label: Label = null


func setup(manager: BattlefieldManager) -> void:
	bf = manager
	_create_prompt_ui()
	_create_pit()


# Returns true if a dropped node landed inside the parry pit (drop area or root).
func is_node_in_pit(target_node: Node) -> bool:
	if pit_drop_area != null and bf.is_node_inside_target(target_node, pit_drop_area):
		return true
	if pit_root != null and bf.is_node_inside_target(target_node, pit_root):
		return true
	return false


func _create_prompt_ui() -> void:
	if prompt_panel != null:
		return

	prompt_panel = PanelContainer.new()
	prompt_panel.name = "ParryPromptPanel"
	prompt_panel.visible = false
	prompt_panel.anchor_left = 0.5
	prompt_panel.anchor_right = 0.5
	prompt_panel.anchor_top = 0.5
	prompt_panel.anchor_bottom = 0.5
	prompt_panel.offset_left = -380.0
	prompt_panel.offset_right = 380.0
	prompt_panel.offset_top = -145.0
	prompt_panel.offset_bottom = 145.0
	prompt_panel.z_index = 126
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	prompt_panel.clip_contents = true
	prompt_panel.add_theme_stylebox_override("panel", _make_parry_panel_style())

	var blur := ColorRect.new()
	blur.name = "ParryPromptBlur"
	blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur.color = Color.WHITE
	blur.material = _make_parry_blur_material()
	prompt_panel.add_child(blur)

	var margin := MarginContainer.new()
	margin.name = "ContentMargin"
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	prompt_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(34.0, 34.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://ui/ability_icons/protection.png"):
		icon.texture = load("res://ui/ability_icons/protection.png") as Texture2D
	header.add_child(icon)

	prompt_title_label = Label.new()
	prompt_title_label.text = "PARRY CHAIN"
	prompt_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_title_label.add_theme_font_size_override("font_size", 26)
	prompt_title_label.add_theme_color_override("font_color", Color.WHITE)
	prompt_title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	prompt_title_label.add_theme_constant_override("outline_size", 2)
	header.add_child(prompt_title_label)

	prompt_matchup_label = Label.new()
	prompt_matchup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_matchup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_matchup_label.add_theme_font_size_override("font_size", 18)
	prompt_matchup_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.94))
	prompt_matchup_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
	prompt_matchup_label.add_theme_constant_override("outline_size", 1)
	vbox.add_child(prompt_matchup_label)

	prompt_instruction_label = Label.new()
	prompt_instruction_label.text = "Drop hand cards into the glowing pit to add DP."
	prompt_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_instruction_label.add_theme_font_size_override("font_size", 16)
	prompt_instruction_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.76))
	vbox.add_child(prompt_instruction_label)

	var stats_row := HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 10)
	vbox.add_child(stats_row)

	prompt_formula_label = _make_parry_stat_label()
	stats_row.add_child(_wrap_parry_stat(prompt_formula_label))

	prompt_needed_label = _make_parry_stat_label()
	stats_row.add_child(_wrap_parry_stat(prompt_needed_label))

	prompt_progress_label = _make_parry_stat_label()
	stats_row.add_child(_wrap_parry_stat(prompt_progress_label))

	let_die_button = Button.new()
	let_die_button.text = "LET UNIT DIE"
	let_die_button.focus_mode = Control.FOCUS_NONE
	let_die_button.custom_minimum_size = Vector2(220.0, 42.0)
	let_die_button.pressed.connect(_on_let_die_pressed)
	_style_parry_button(let_die_button)
	vbox.add_child(let_die_button)

	bf.get_node("UI").add_child(prompt_panel)


func _make_parry_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 10
	return style


func _make_parry_blur_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_lod = 3.8;
uniform vec4 glass_tint = vec4(0.015, 0.018, 0.024, 0.66);

void fragment() {
	float radius = 0.080;
	vec2 q = abs(UV - vec2(0.5)) - vec2(0.5 - radius);
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float mask = 1.0 - smoothstep(0.0, 0.018, d);

	vec3 blurred_world = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb;
	vec3 tinted = mix(blurred_world, glass_tint.rgb, glass_tint.a);

	COLOR = vec4(tinted, 0.88 * mask);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("blur_lod", 3.8)
	material.set_shader_parameter("glass_tint", Color(0.015, 0.018, 0.024, 0.66))
	return material


func _make_parry_stat_label() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
	label.add_theme_constant_override("outline_size", 1)
	return label


func _wrap_parry_stat(label: Label) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(190.0, 42.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.38)
	style.border_color = Color(1.0, 1.0, 1.0, 0.10)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	margin.add_child(label)
	return panel


func _style_parry_button(button: Button) -> void:
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 15)

	button.add_theme_stylebox_override(
		"normal",
		_make_parry_button_style(Color(0.02, 0.022, 0.026, 0.70), Color(1.0, 1.0, 1.0, 0.16))
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_parry_button_style(Color(0.10, 0.10, 0.11, 0.82), Color(1.0, 1.0, 1.0, 0.42))
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_parry_button_style(Color(0.16, 0.16, 0.17, 0.92), Color(1.0, 1.0, 1.0, 0.62))
	)


func _make_parry_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _create_pit() -> void:
	pit_root = bf.get_node_or_null("ParryPit")

	if pit_root == null:
		pit_root = bf.get_node_or_null("Battlefield3D/ParryPit")

	if pit_root == null and get_tree().current_scene != null:
		pit_root = get_tree().current_scene.get_node_or_null("Battlefield3D/ParryPit")

	if pit_root == null:
		push_error("ParryPit not found. Expected node path: Battlefield3D/ParryPit")
		return

	pit_glow = pit_root.get_node_or_null("ParryPitGlow")
	dp_counter = pit_root.get_node_or_null("ParryDPCounter")
	pit_drop_area = pit_root.get_node_or_null("ParryPitDropArea")
	sacrifice_stack_root = pit_root.get_node_or_null("ParrySacrificeStack")

	if dp_counter == null:
		push_warning("ParryDPCounter not found under ParryPit. Creating fallback Label3D.")
		dp_counter = Label3D.new()
		dp_counter.name = "ParryDPCounter"
		pit_root.add_child(dp_counter)

	if dp_counter is Label3D:
		dp_counter.position = Vector3(-0.60, 0.85, -0.30)
		dp_counter.text = "0/0 DP"
		dp_counter.font_size = 48
		dp_counter.modulate = Color(1.0, 0.92, 0.35, 1.0)
		dp_counter.outline_size = 8
		dp_counter.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
		dp_counter.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		dp_counter.no_depth_test = true
		dp_counter.visible = false

	if dp_counter == null:
		push_warning("ParryDPCounter not found under ParryPit.")

	if pit_drop_area == null:
		push_warning("ParryPitDropArea not found under ParryPit.")

	if sacrifice_stack_root == null:
		sacrifice_stack_root = Node3D.new()
		sacrifice_stack_root.name = "ParrySacrificeStack"
		pit_root.add_child(sacrifice_stack_root)
		sacrifice_stack_root.position = Vector3.ZERO

	pit_root.visible = false
	_update_counter_visual(0, 0)


func _show_pit(req_dp: int) -> void:
	required_dp = req_dp

	if pit_root == null:
		_create_pit()

	if pit_root == null:
		return

	pit_root.visible = true

	if pit_glow != null:
		pit_glow.visible = true

	if dp_counter != null:
		dp_counter.visible = true

	_update_counter_visual(gathered_dp, required_dp)


func _hide_pit() -> void:
	if pit_root == null:
		return

	if pit_glow != null:
		pit_glow.visible = false

	if dp_counter != null:
		dp_counter.visible = false

	pit_root.visible = false

	_update_counter_visual(0, 0)


func _update_counter_visual(current_dp: int, req_dp: int) -> void:
	if dp_counter == null:
		return

	var counter_text := "Parry: 0 / 0"

	if defender_card != null and req_dp > 0:
		var current_total: int = max(0, defender_ap) + max(0, current_dp)
		var target_total: int = max(1, defender_ap + req_dp)
		counter_text = "Parry: %d / %d" % [current_total, target_total]
	else:
		counter_text = "Parry: %d / %d" % [max(0, current_dp), max(0, req_dp)]

	if dp_counter is Label3D:
		dp_counter.text = counter_text
	elif dp_counter is Label:
		dp_counter.text = counter_text
	else:
		dp_counter.set("text", counter_text)


func _add_visible_sacrifice_card(card_data: CardData) -> void:
	if card_data == null:
		return

	if sacrifice_stack_root == null:
		return

	var visual_card := TEST_CARD_SCENE.instantiate() as Node3D
	sacrifice_stack_root.add_child(visual_card)

	if visual_card.has_method("assign_card_data"):
		visual_card.assign_card_data(card_data, false)

	var index: int = sacrifice_nodes.size()

	# Ordered overlap, not a perfect pile.
	var x_offset: float = -0.28 + float(index % 4) * 0.18
	var z_offset: float = -0.18 + float(index % 4) * 0.12
	var y_offset: float = 0.02 + float(index) * 0.012
	var rotation_offset: float = -10.0 + float(index % 5) * 5.0

	visual_card.position = Vector3(x_offset, y_offset, z_offset)
	visual_card.rotation_degrees = Vector3(0, rotation_offset, 0)
	visual_card.scale = Vector3(0.46, 0.46, 0.46)

	sacrifice_nodes.append(visual_card)


func _clear_visible_sacrifice_cards() -> void:
	for visual_card in sacrifice_nodes:
		if visual_card != null and is_instance_valid(visual_card):
			visual_card.queue_free()

	sacrifice_nodes.clear()
	sacrifice_cards.clear()


func begin(
	combat_lane: String,
	atk_slot: Node,
	atk_card: CardData,
	def_slot: Node,
	def_card: CardData,
	atk_power: int = -1,
	def_power: int = -1
) -> void:
	bf.set_active_combat_lane_highlight(combat_lane)

	if atk_card == null or def_card == null:
		return

	active = true
	lane = combat_lane
	attacker_slot = atk_slot
	attacker_card = atk_card
	defender_slot = def_slot
	defender_card = def_card
	attacker_ap = atk_power if atk_power >= 0 else atk_card.ap
	defender_ap = def_power if def_power >= 0 else def_card.ap

	# Required pit DP = attacking AP - endangered unit AP.
	# The visible counter shows endangered unit AP + pit DP / attacking AP.
	required_dp = max(1, attacker_ap - defender_ap)
	gathered_dp = 0

	bf.update_phase_instruction_ui()
	_show_pit(required_dp)

	if prompt_panel != null:
		prompt_panel.visible = true
		prompt_panel.modulate.a = 0.0

		var tween := prompt_panel.create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(prompt_panel, "modulate:a", 1.0, 0.18)

	_refresh_prompt_text()
	_update_counter_label()

	bf.log_msg(
		"Parry prompt: "
		+ def_card.card_name
		+ " needs "
		+ str(required_dp)
		+ " pit DP. Parry: "
		+ str(defender_ap)
		+ " / "
		+ str(attacker_ap)
	)


func _update_counter_label() -> void:
	_update_counter_visual(gathered_dp, required_dp)
	_refresh_prompt_text()


func _refresh_prompt_text() -> void:
	if defender_card == null or attacker_card == null:
		return

	if prompt_matchup_label != null:
		prompt_matchup_label.text = "Your " + defender_card.card_name + " must survive against " + attacker_card.card_name + "."

	if prompt_formula_label != null:
		prompt_formula_label.text = "Target  " + str(defender_ap) + " + pit DP / " + str(attacker_ap) + " AP"

	if prompt_needed_label != null:
		prompt_needed_label.text = "Needed  " + str(required_dp) + " DP"

	if prompt_progress_label != null:
		prompt_progress_label.text = "Pit DP  " + str(gathered_dp) + " / " + str(required_dp)


func sacrifice_card(card_ui: CardUI) -> void:
	if not active:
		return

	if card_ui == null:
		return

	if not is_instance_valid(card_ui):
		return

	var sacrificed_card: CardData = card_ui.card_data

	if sacrificed_card == null:
		bf.return_card_to_hand_safely(card_ui)
		bf.cancel_selected_card()
		return

	if card_ui != null and is_instance_valid(card_ui):
		card_ui.visible = false

	await bf.play_player_hand_to_node_animation(sacrificed_card, pit_root, false)

	var gained_dp: int = max(0, sacrificed_card.dp)
	var deflect := bf.slot_has_protection_ability(defender_slot, &"deflect")
	if gathered_dp == 0 and deflect != null:
		gained_dp += 2
		await bf.show_protection_trigger(deflect, "First Parry card gains +2 DP")
	gathered_dp += gained_dp

	_add_visible_sacrifice_card(sacrificed_card)
	sacrifice_cards.append(sacrificed_card)

	if bf.discard_pile != null:
		bf.discard_pile.add_card(sacrificed_card)

	if bf.hand != null:
		bf.hand.consume_dragged_card(card_ui)

	var parry_total_after_sacrifice: int = 0
	var parry_target_total: int = 0

	if defender_card != null:
		parry_total_after_sacrifice = defender_ap + gathered_dp
		parry_target_total = defender_ap + required_dp

	bf.log_msg(
		"Parry sacrifice: "
		+ sacrificed_card.card_name
		+ " added "
		+ str(gained_dp)
		+ " DP. Parry: "
		+ str(parry_total_after_sacrifice)
		+ " / "
		+ str(parry_target_total)
	)
	_update_counter_label()
	bf.cancel_selected_card()

	if gathered_dp >= required_dp:
		await _complete_success()


func _complete_success() -> void:
	if not active:
		return

	var final_parry_total: int = gathered_dp
	var final_parry_target: int = required_dp

	if defender_card != null:
		final_parry_total = defender_ap + gathered_dp
		final_parry_target = defender_ap + required_dp

	bf.log_msg(
		"Parry successful. "
		+ defender_card.card_name
		+ " survives with Parry "
		+ str(final_parry_total)
		+ " / "
		+ str(final_parry_target)
		+ "."
	)
	await _resolve_successful_parry_abilities()

	_end_prompt()
	await bf.advance_combat_lane_after_resolution()


func _on_let_die_pressed() -> void:
	if not active:
		return

	var destroyed := false
	if defender_slot != null:
		destroyed = await bf.destroy_unit_with_protection(defender_slot, attacker_slot, true)

	if defender_card != null and destroyed:
		bf.log_msg("You let " + defender_card.card_name + " die.")
		bf.add_aurion("ai", bf.get_unit_defeat_aurion_reward(defender_card), "Destroyed " + defender_card.card_name + " in combat.")

	_end_prompt()
	await bf.advance_combat_lane_after_resolution()


func _resolve_successful_parry_abilities() -> void:
	var shield_burst := bf.get_card_protection_ability(sacrifice_cards[0], &"shield_burst") if sacrifice_cards.size() == 1 else null
	if shield_burst != null:
		await bf.show_protection_trigger(shield_burst, "Draw 2 cards")
		for i in range(2):
			var drawn := bf.player_deck.draw_top_card()
			if drawn != null:
				bf.hand.add_card_to_hand(drawn)
	var last_stand := bf.get_card_protection_ability(sacrifice_cards[2], &"last_stand") if sacrifice_cards.size() >= 3 else null
	if last_stand != null:
		await bf.show_protection_trigger(last_stand, "Draw 3 cards")
		for i in range(3):
			var drawn := bf.player_deck.draw_top_card()
			if drawn != null:
				bf.hand.add_card_to_hand(drawn)


func _end_prompt() -> void:
	active = false
	bf.update_phase_instruction_ui()
	lane = ""
	attacker_slot = null
	attacker_card = null
	defender_slot = null
	defender_card = null
	attacker_ap = 0
	defender_ap = 0
	required_dp = 0
	gathered_dp = 0

	_clear_visible_sacrifice_cards()
	_hide_pit()

	if prompt_panel != null:
		prompt_panel.visible = false
	bf.clear_active_combat_lane_highlight()

	if bf.current_phase == BattlefieldManager.BattlePhase.COMBAT and bf.combat_next_lane_index < bf.combat_lane_order.size():
		bf.set_active_combat_lane_highlight(bf.combat_lane_order[bf.combat_next_lane_index])
