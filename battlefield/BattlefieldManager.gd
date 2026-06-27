class_name BattlefieldManager
extends Node3D

signal insight_gambit_slot_chosen(slot: Node)
signal stealth_deployment_slot_chosen(slot: Node)

# Consolidated from BattlefieldManagerPhase.gd, BattlefieldManager.gd, and Phase 1-4 wrapper managers.

const TEST_CARD_SCENE: PackedScene = preload("res://cards/Card3D_Test.tscn")
const MENU_SCENE_PATH := "res://ui/Menu/prototype_menu.tscn"
const BOARD_SLOT_ACTION_BUTTONS_SCENE: PackedScene = preload("res://battlefield/BoardSlotActionButtons3D.tscn")

const ARCH_WIZARD_MAELCOR: CardData = CardDatabase.ARCH_WIZARD_MAELCOR

const IMPERIAL_ARCHIVE_MASTER: CardData = CardDatabase.IMPERIAL_ARCHIVE_MASTER

const JENA_OF_YEL: CardData = CardDatabase.JENA_OF_YEL

const IVAAN_THE_BONE_CRUSHER: CardData = CardDatabase.IVAAN_THE_BONE_CRUSHER

const UPPER_HALL_PROSPECTOR: CardData = CardDatabase.UPPER_HALL_PROSPECTOR

const BLACKMAIL: CardData = CardDatabase.BLACKMAIL

const VAELORI_LONGBOW: CardData = CardDatabase.VAELORI_LONGBOW

const OPPONENT_TEST_CARDS: Array[CardData] = [
	ARCH_WIZARD_MAELCOR,
	IMPERIAL_ARCHIVE_MASTER,
	JENA_OF_YEL,
	IVAAN_THE_BONE_CRUSHER,
	UPPER_HALL_PROSPECTOR
]

enum BattlePhase { BATTLEPLAN, TRIBUTE, DEPLOYMENT, COMBAT }

@onready var board_slots: Node3D = $BoardSlots

@onready var game_log = $GameLog

@onready var tribute_manager: TributeManager = $TributeManager

@onready var battle_plan_manager: BattlePlanManager = get_node_or_null("BattlePlanManager") as BattlePlanManager

@onready var battle_plan_panel: BattlePlanPanel = get_node_or_null("UI/BattlePlanPanel") as BattlePlanPanel

@onready var battle_plan_selection_screen: BattlePlanSelectionScreen = get_node_or_null("UI/BattlePlanSelectionScreen") as BattlePlanSelectionScreen

@onready var discard_pile: DiscardPile = get_node_or_null("DiscardPile") as DiscardPile

@export var hand: HandUI

@export var draw_pile: DrawPile

@export var tribute_pile: TributePile

@export var player_deck: PlayerDeck

var selected_card_scene: PackedScene = null

var selected_card_data: CardData = null

var has_selected_card: bool = false

var game_has_started: bool = false

var waiting_for_battle_plan: bool = true

var deck_selection_complete: bool = false

const BATTLEPLAN_HAND_CLEANUP_TIME: float = 20.0

const PHASE_TITLE_TOTAL_TIME: float = 2.0

var pending_battleplan_draws: int = 0

var battleplan_hand_cleanup_active: bool = false

var battleplan_discard_time_left: float = 0.0

var current_phase: int = BattlePhase.BATTLEPLAN

var opponent_battle_plan: Dictionary = {}

var player_has_initiative: bool = true

var combat_direction_selected: bool = false

var combat_lane_order: Array[String] = []

var combat_next_lane_index: int = 0

var phase_panel: PanelContainer = null

var phase_label: Label = null

var phase_instruction_label: Label = null

var next_phase_button: Button = null

var phase_title_overlay: Label = null

var phase_blur_backdrop: ColorRect = null

var phase_blur_material: ShaderMaterial = null

var phase_title_tween: Tween = null

var discard_warning_overlay: Label = null

var turn_label: Label = null

var turn_number: int = 1

var deck_selection_screen: DeckSelectionScreen = null

var hand_drag_preview: Node3D = null

var player_hand_3d: BattlefieldHand3D = null

var last_player_hand_animation_start := Vector3.ZERO

var has_player_hand_animation_start: bool = false

var hand_drag_preview_target_position := Vector3.ZERO

var hand_drag_preview_target_scale := Vector3.ONE

var hand_was_auto_lowered_for_drag: bool = false

var phase_button_ready_visual: bool = false

var phase_transition_busy: bool = false

var bottom_hud_3d: BattlefieldBottomHud3D = null

var last_bottom_hud_log_text: String = ""

var spawn_opponent_button: Button = null

var ability_prompt_panel: AbilityPromptPanel = null

var insight_presenter: InsightPresentation3D = null

var insight_presentation_active := false

var insight_gambit_selection_active := false

var insight_gambit_candidate_slots: Array[Node] = []

var pending_stealth_deployments: Array[Dictionary] = []

var stealth_deployment_selection_slot: Node = null

const AURION_WIN_TARGET: int = 25

var player_aurion_points: int = 0

var ai_aurion_points: int = 0

var game_over := false

var game_result_overlay: Control = null

var aurion_panel: PanelContainer = null

var aurion_label: Label = null

var ai_deck: Array[CardData] = []

var ai_hand: Array[CardData] = []

var ai_discard: Array[CardData] = []

var ai_tribute: Array[CardData] = []

@export var ai_max_deployments_per_phase: int = 2

var ai_perm_tp: int = 0

var ai_current_perm_tp: int = 0

var ai_temp_tp: int = 0

var ai_current_tp: int = 0

var ai_tribute_used_this_turn: bool = false

var ai_tribute_finished_this_turn: bool = false

var ai_has_starting_hand: bool = false

var ai_deployed_this_deployment_phase: bool = false

var player_passed_deployment: bool = false

var used_battle_plan_keys: Dictionary = {}

var player_face_down_gambits_this_round: int = 0

var ai_face_down_gambits_this_round: int = 0

var pending_spell_card_ui: CardUI = null

var pending_spell_slot: Node = null

var spell_choice_panel: PanelContainer = null

var spell_choice_label: Label = null

var global_ability_icons_visible: bool = false

var parry_system: ParrySystem = null

@onready var opponent_visuals: OpponentVisuals = get_node_or_null("OpponentVisuals") as OpponentVisuals

@onready var card_animation_manager: CardAnimationManager = get_node_or_null("CardAnimationManager") as CardAnimationManager

const BOARD_ACTION_INSPECT: int = 1

const BOARD_ACTION_CANCEL: int = 99
const BOARD_ACTION_ACTIVE_INSIGHT_BASE: int = 100

var board_action_menu: PopupMenu = null

var board_slot_action_rails: Dictionary = {}

var board_action_target_slot: Node = null
var board_action_ability_map: Dictionary = {}

const BOARD_ACTION_ATTACK: int = 2

const COMBAT_LANE_GLOW: Color = Color(1.0, 1.0, 1.0, 0.82)

const COMBAT_LANE_START_DELAY: float = 0.35

const COMBAT_LANE_END_DELAY: float = 0.45

var active_combat_lane: String = ""

var combat_resolution_running: bool = false

const BOARD_ACTION_CHECK: int = 3

const BOARD_ACTION_PASS: int = 4

const BLUFF_REVEAL_DELAY: float = 0.30

var enemy_fortified_lanes: Dictionary = {}

var player_fortified_lanes: Dictionary = {}

var combat_priority_owner: String = ""

var original_combat_priority_owner: String = ""

var player_passed_current_lane: bool = false

var ai_passed_current_lane: bool = false
var used_active_insight_ability_keys: Dictionary = {}


# === Functions ===

func _ready() -> void:
	randomize()
	parry_system = ParrySystem.new()
	parry_system.name = "ParrySystem"
	add_child(parry_system)
	parry_system.setup(self)
	connect_all_slots()
	connect_main_signals()
	create_player_hand_3d()
	create_phase_ui()
	create_bottom_hud_3d()
	create_exit_button()
	create_deck_selection_screen()
	create_ability_prompt_panel()
	create_insight_presenter()
	create_debug_tp_button()
	set_phase(BattlePhase.BATTLEPLAN)
	setup_deck_selection_flow()
	create_spell_choice_panel()
	create_aurion_counter_ui()
	disable_keyboard_focus_for_all_buttons($UI)
	create_board_slot_action_menu()
	create_board_slot_action_buttons()
	patch_game_log_for_scrolling()
	set_process(true)


func _process(delta: float) -> void:
	update_hand_drag_preview(delta)
	update_battleplan_hand_cleanup(delta)
	update_discard_warning_overlay()
	update_phase_progress_state()
	try_auto_advance_combat_phase()
	refresh_bottom_hud_log()
	refresh_board_slot_action_buttons()
	refresh_player_usable_ability_icons()


func connect_main_signals() -> void:
	if hand != null:
		hand.card_drag_started.connect(_on_hand_card_drag_started)
		hand.card_drag_released.connect(_on_hand_card_drag_released)
	if draw_pile != null:
		draw_pile.draw_drag_started.connect(_on_draw_pile_drag_started)
		draw_pile.draw_drag_moved.connect(_on_draw_pile_drag_moved)
		draw_pile.draw_drag_released.connect(_on_draw_pile_drag_released)
	if tribute_pile != null:
		tribute_pile.tribute_pile_clicked.connect(_on_tribute_pile_clicked)
	if tribute_manager != null:
		tribute_manager.tribute_changed.connect(_on_tribute_changed)


func create_player_hand_3d() -> void:
	if hand == null:
		return
	player_hand_3d = BattlefieldHand3D.new()
	player_hand_3d.name = "PlayerHand3D"
	add_child(player_hand_3d)
	player_hand_3d.setup(hand, get_viewport().get_camera_3d())


func create_deck_selection_screen() -> void:
	deck_selection_screen = DeckSelectionScreen.new()
	deck_selection_screen.name = "DeckSelectionScreen"
	deck_selection_screen.deck_selected.connect(_on_prebattle_deck_selected)
	$UI.add_child(deck_selection_screen)


func setup_deck_selection_flow() -> void:
	waiting_for_battle_plan = true
	if battle_plan_selection_screen != null:
		battle_plan_selection_screen.hide_selection()
	if deck_selection_screen == null or player_deck == null:
		deck_selection_complete = true
		setup_battle_plan_flow()
		return
	deck_selection_screen.show_selection(player_deck.get_saved_deck_summaries())
	update_phase_progress_state()


func _on_prebattle_deck_selected(slot_index: int) -> void:
	if player_deck == null:
		return
	if slot_index < 0:
		player_deck.use_fallback_deck()
	else:
		var loaded := player_deck.load_saved_deck_slot(slot_index, true)
		if not loaded:
			log_msg("That saved deck is unavailable or has fewer than 10 valid cards.")
			deck_selection_screen.show_selection(player_deck.get_saved_deck_summaries())
			return
	log_msg("Battle deck selected: " + str(player_deck.cards_remaining()) + " cards.")
	deck_selection_complete = true
	await get_tree().process_frame
	setup_battle_plan_flow()


func setup_battle_plan_flow() -> void:
	waiting_for_battle_plan = true
	if battle_plan_panel != null:
		battle_plan_panel.clear_battle_plan()
	if battle_plan_selection_screen != null:
		if not battle_plan_selection_screen.battle_plan_selected.is_connected(_on_battle_plan_selected):
			battle_plan_selection_screen.battle_plan_selected.connect(_on_battle_plan_selected)
	open_battle_plan_selection()


func open_battle_plan_selection() -> void:
	waiting_for_battle_plan = true
	set_phase(BattlePhase.BATTLEPLAN)
	await get_tree().create_timer(PHASE_TITLE_TOTAL_TIME).timeout
	if current_phase != BattlePhase.BATTLEPLAN:
		return

	if battle_plan_manager == null:
		log_msg("BattlePlanManager is missing.")
		begin_game_after_battle_plan_selection()
		set_phase(BattlePhase.TRIBUTE)
		return

	if battle_plan_selection_screen == null:
		log_msg("BattlePlanSelectionScreen is missing.")
		begin_game_after_battle_plan_selection()
		set_phase(BattlePhase.TRIBUTE)
		return

	var choices: Array[Dictionary] = get_unused_battle_plan_choices(5)

	if choices.is_empty():
		log_msg("No unused Battle Plans remain. Battleplan deck is exhausted.")

		if battle_plan_selection_screen != null:
			battle_plan_selection_screen.visible = false

		return

	if choices.size() < 5:
		log_msg("Battleplan deck is running low. Remaining choices: " + str(choices.size()))

	battle_plan_selection_screen.show_selection(choices)
	update_phase_progress_state()


func _on_battle_plan_selected(plan: Dictionary) -> void:
	if plan.is_empty():
		log_msg("No Battle Plan selected.")
		return

	if is_battle_plan_used(plan):
		log_msg("That Battle Plan has already been used. Drawing new options.")
		open_battle_plan_selection()
		return

	waiting_for_battle_plan = false

	mark_battle_plan_used(plan)

	if battle_plan_manager != null:
		battle_plan_manager.select_battle_plan(plan)

	choose_opponent_battle_plan()

	if battle_plan_panel != null:
		battle_plan_panel.set_battle_plan(plan)

		if battle_plan_panel.has_method("set_opponent_battle_plan"):
			battle_plan_panel.set_opponent_battle_plan(opponent_battle_plan)

	apply_battle_plan_rules(plan)
	apply_initiative_rules(plan)

	log_msg("Selected Battle Plan: " + str(plan.get("name", "Unknown Battle Plan")))

	if opponent_battle_plan.is_empty():
		log_msg("Opponent has no unused Battle Plan.")
	else:
		log_msg("Opponent Battle Plan: " + str(opponent_battle_plan.get("name", "Unknown Battle Plan")))

	if not game_has_started:
		begin_game_after_battle_plan_selection()

	draw_battleplan_cards(plan)


func choose_opponent_battle_plan() -> void:
	opponent_battle_plan = {}

	if battle_plan_manager == null:
		return

	var choices: Array[Dictionary] = get_unused_battle_plan_choices(1)

	if choices.is_empty():
		log_msg("Opponent Battleplan deck is exhausted.")
		return

	opponent_battle_plan = choices[0]
	mark_battle_plan_used(opponent_battle_plan)


func apply_battle_plan_rules(plan: Dictionary) -> void:
	if hand == null:
		return
	var max_hand_size: int = int(plan.get("max_hand_size", 7))
	hand.set_max_hand_size(max_hand_size)
	log_msg("Max hand size set to " + str(max_hand_size) + " by " + str(plan.get("name", "Battle Plan")))


func apply_initiative_rules(plan: Dictionary) -> void:
	var player_initiative: int = int(plan.get("initiative_mark", 0))
	var opponent_initiative: int = int(opponent_battle_plan.get("initiative_mark", 0))
	player_has_initiative = player_initiative >= opponent_initiative
	if player_has_initiative:
		log_msg("Initiative: Player acts first. " + str(player_initiative) + " vs " + str(opponent_initiative))
	else:
		log_msg("Initiative: Opponent acts first. " + str(opponent_initiative) + " vs " + str(player_initiative))


func draw_battleplan_cards(plan: Dictionary) -> void:
	var draw_amount: int = int(plan.get("draw_amount", 0))
	pending_battleplan_draws = 0
	battleplan_hand_cleanup_active = false

	if draw_amount > 0 and player_deck != null and hand != null:
		pending_battleplan_draws = mini(draw_amount, player_deck.cards_remaining())

	if pending_battleplan_draws > 0:
		log_msg(
			"Battleplan draw: drag "
			+ str(pending_battleplan_draws)
			+ " card(s) from the Draw Pile into your hand."
		)
	else:
		log_msg("Battleplan draw: no player cards to draw.")

	if opponent_battle_plan.is_empty():
		log_msg("AI battleplan draw skipped. No unused AI battleplan remains.")
	else:
		var ai_draw_amount: int = int(opponent_battle_plan.get("draw_amount", 0))
		ai_draw_cards(ai_draw_amount)
		log_msg("AI battleplan draw: AI drew " + str(ai_draw_amount) + " cards. AI hand: " + str(ai_hand.size()))

	update_phase_ui()
	if pending_battleplan_draws <= 0:
		begin_battleplan_hand_cleanup_or_tribute()


func begin_battleplan_hand_cleanup_or_tribute() -> void:
	if hand != null and hand.cards.size() > hand.max_hand_size:
		battleplan_hand_cleanup_active = true
		battleplan_discard_time_left = BATTLEPLAN_HAND_CLEANUP_TIME
		log_msg(
			"Hand limit exceeded. Discard "
			+ str(hand.cards.size() - hand.max_hand_size)
			+ " card(s) of your choice within "
			+ str(int(BATTLEPLAN_HAND_CLEANUP_TIME))
			+ " seconds."
		)
		update_phase_ui()
		return
	finish_battleplan_prephase()


func update_battleplan_hand_cleanup(delta: float) -> void:
	if not battleplan_hand_cleanup_active or hand == null:
		return
	if hand.cards.size() <= hand.max_hand_size:
		finish_battleplan_prephase()
		return
	# Do not let the deadline consume a card while the player is physically holding it.
	if hand_drag_preview != null or selected_card_data != null:
		return
	battleplan_discard_time_left = maxf(battleplan_discard_time_left - delta, 0.0)
	update_phase_instruction_ui()
	if battleplan_discard_time_left > 0.0:
		return
	while hand.cards.size() > hand.max_hand_size:
		var card_ui: CardUI = hand.cards.back() as CardUI
		if card_ui == null or card_ui.card_data == null:
			break
		if discard_pile != null:
			discard_pile.add_card(card_ui.card_data)
		hand.consume_dragged_card(card_ui)
	log_msg("Discard timer expired. Excess cards were discarded automatically.")
	finish_battleplan_prephase()


func finish_battleplan_prephase() -> void:
	pending_battleplan_draws = 0
	battleplan_hand_cleanup_active = false
	battleplan_discard_time_left = 0.0
	set_phase(BattlePhase.TRIBUTE)


func begin_game_after_battle_plan_selection() -> void:
	if game_has_started:
		return

	game_has_started = true

	setup_ai_deck()
	ai_draw_cards(3)
	ai_has_starting_hand = true

	update_tribute_counter()
	deal_starting_hand()

	if tribute_manager != null:
		log_msg("Starting Tribute: " + tribute_manager.get_status_text())

	log_msg("AI starting hand dealt. AI hand: " + str(ai_hand.size()) + " | AI deck: " + str(ai_deck.size()))
	update_ai_visuals()


func create_phase_ui() -> void:
	phase_panel = PanelContainer.new()
	phase_panel.name = "PhasePanel"

	# One combined right-side command panel.
	# Sits below enemy discard/deck visuals and above the player tribute pile.
	phase_panel.anchor_left = 1.0
	phase_panel.anchor_right = 1.0
	phase_panel.anchor_top = 0.0
	phase_panel.anchor_bottom = 0.0

	# Phase 19.2: wider/taller panel so instructions are visible.
	phase_panel.offset_left = -350.0
	phase_panel.offset_right = -20.0
	phase_panel.offset_top = 320.0
	phase_panel.offset_bottom = 400.0
	phase_panel.custom_minimum_size = Vector2(330.0, 200.0)
	phase_panel.z_index = 75

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.015, 0.005, 0.78)
	style.border_color = Color(1.0, 0.78, 0.22, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	phase_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	phase_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	margin.add_child(vbox)

	phase_label = Label.new()
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 18)
	phase_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72, 1.0))
	vbox.add_child(phase_label)

	turn_label = Label.new()
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 14)
	turn_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.25, 1.0))
	vbox.add_child(turn_label)

	aurion_label = Label.new()
	aurion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aurion_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	aurion_label.add_theme_font_size_override("font_size", 14)
	aurion_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	vbox.add_child(aurion_label)

	next_phase_button = Button.new()
	next_phase_button.focus_mode = Control.FOCUS_NONE
	next_phase_button.custom_minimum_size = Vector2(0, 34)
	next_phase_button.pressed.connect(_on_next_phase_pressed)
	vbox.add_child(next_phase_button)

	var separator := HSeparator.new()
	vbox.add_child(separator)

	phase_instruction_label = Label.new()
	phase_instruction_label.name = "PhaseInstructionLabel"
	phase_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	phase_instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	phase_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phase_instruction_label.add_theme_font_size_override("font_size", 12)
	phase_instruction_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 1.0))
	phase_instruction_label.custom_minimum_size = Vector2(290.0, 55.0)
	phase_instruction_label.text = ""
	vbox.add_child(phase_instruction_label)

	# No more separate opponent test button.
	spawn_opponent_button = null

	$UI.add_child(phase_panel)
	create_center_screen_overlays()
	update_phase_ui()
	update_aurion_counter_ui()
	update_turn_counter_ui()


func create_center_screen_overlays() -> void:
	phase_blur_backdrop = ColorRect.new()
	phase_blur_backdrop.name = "PhaseBlurBackdrop"
	phase_blur_backdrop.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	phase_blur_backdrop.offset_left = -310.0
	phase_blur_backdrop.offset_top = -62.0
	phase_blur_backdrop.offset_right = 310.0
	phase_blur_backdrop.offset_bottom = 62.0
	phase_blur_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_blur_backdrop.color = Color.WHITE
	phase_blur_backdrop.modulate.a = 0.0
	phase_blur_backdrop.z_index = 119

	var blur_shader := Shader.new()
	blur_shader.code = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 5.0) = 0.0;

void fragment() {
	vec4 blurred = textureLod(screen_texture, SCREEN_UV, blur_lod);
	float edge_x = smoothstep(0.0, 0.13, UV.x) * smoothstep(0.0, 0.13, 1.0 - UV.x);
	float edge_y = smoothstep(0.0, 0.28, UV.y) * smoothstep(0.0, 0.28, 1.0 - UV.y);
	float soft_mask = edge_x * edge_y;
	COLOR = vec4(blurred.rgb * 0.82, soft_mask);
}
"""
	phase_blur_material = ShaderMaterial.new()
	phase_blur_material.shader = blur_shader
	phase_blur_material.set_shader_parameter("blur_lod", 0.0)
	phase_blur_backdrop.material = phase_blur_material
	$UI.add_child(phase_blur_backdrop)

	phase_title_overlay = Label.new()
	phase_title_overlay.name = "PhaseTitleOverlay"
	phase_title_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	phase_title_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_title_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_title_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phase_title_overlay.add_theme_font_size_override("font_size", 44)
	phase_title_overlay.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.98))
	phase_title_overlay.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.035, 0.92))
	phase_title_overlay.add_theme_constant_override("outline_size", 2)
	phase_title_overlay.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.38))
	phase_title_overlay.add_theme_constant_override("shadow_offset_x", 0)
	phase_title_overlay.add_theme_constant_override("shadow_offset_y", 0)
	phase_title_overlay.add_theme_constant_override("shadow_outline_size", 5)
	phase_title_overlay.modulate.a = 0.0
	phase_title_overlay.z_index = 120
	$UI.add_child(phase_title_overlay)

	discard_warning_overlay = Label.new()
	discard_warning_overlay.name = "DiscardWarningOverlay"
	discard_warning_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	discard_warning_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	discard_warning_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_warning_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	discard_warning_overlay.add_theme_font_size_override("font_size", 42)
	discard_warning_overlay.add_theme_color_override("font_color", Color(1.0, 0.18, 0.12, 1.0))
	discard_warning_overlay.add_theme_color_override("font_shadow_color", Color(1.0, 0.0, 0.0, 0.95))
	discard_warning_overlay.add_theme_constant_override("shadow_offset_x", 0)
	discard_warning_overlay.add_theme_constant_override("shadow_offset_y", 0)
	discard_warning_overlay.add_theme_constant_override("shadow_outline_size", 12)
	discard_warning_overlay.visible = false
	discard_warning_overlay.z_index = 121
	$UI.add_child(discard_warning_overlay)


func show_phase_title(title: String) -> void:
	if phase_title_overlay == null or phase_blur_backdrop == null or phase_blur_material == null:
		return
	if phase_title_tween != null and phase_title_tween.is_valid():
		phase_title_tween.kill()
	phase_title_overlay.text = title
	phase_title_overlay.add_theme_font_size_override("font_size", 32 if title.length() > 24 else 44)
	phase_title_overlay.modulate.a = 0.0
	phase_blur_backdrop.modulate.a = 0.0
	phase_blur_material.set_shader_parameter("blur_lod", 0.0)
	phase_title_tween = create_tween()
	phase_title_tween.set_trans(Tween.TRANS_SINE)
	phase_title_tween.set_ease(Tween.EASE_IN_OUT)
	phase_title_tween.tween_property(phase_blur_backdrop, "modulate:a", 0.92, 0.34)
	phase_title_tween.parallel().tween_property(phase_title_overlay, "modulate:a", 1.0, 0.34)
	phase_title_tween.parallel().tween_method(set_phase_blur_amount, 0.0, 2.5, 0.34)
	phase_title_tween.tween_interval(1.12)
	phase_title_tween.tween_property(phase_blur_backdrop, "modulate:a", 0.0, 0.54)
	phase_title_tween.parallel().tween_property(phase_title_overlay, "modulate:a", 0.0, 0.54)
	phase_title_tween.parallel().tween_method(set_phase_blur_amount, 2.5, 0.0, 0.54)


func set_phase_blur_amount(amount: float) -> void:
	if phase_blur_material != null:
		phase_blur_material.set_shader_parameter("blur_lod", amount)


func update_discard_warning_overlay() -> void:
	if discard_warning_overlay == null:
		return
	var discard_count := 0
	if battleplan_hand_cleanup_active and hand != null:
		discard_count = maxi(hand.cards.size() - hand.max_hand_size, 0)
	discard_warning_overlay.visible = discard_count > 0
	if discard_count > 0:
		discard_warning_overlay.text = "Discard " + str(discard_count) + " Cards"


func create_bottom_hud_3d() -> void:
	bottom_hud_3d = BattlefieldBottomHud3D.new()
	bottom_hud_3d.name = "BattlefieldBottomHud3D"
	bottom_hud_3d.phase_action_pressed.connect(_on_next_phase_pressed)
	add_child(bottom_hud_3d)
	if phase_panel != null:
		phase_panel.visible = false
	if battle_plan_panel != null:
		battle_plan_panel.visible = false
	if game_log != null:
		var old_log_panel: Control = game_log.get_node_or_null("PanelContainer") as Control
		if old_log_panel != null:
			old_log_panel.visible = false
	refresh_bottom_hud()


func refresh_bottom_hud() -> void:
	if bottom_hud_3d == null or phase_label == null or next_phase_button == null:
		return
	var score_text := "Aurion  •  Player %d/%d  •  AI %d/%d" % [player_aurion_points, AURION_WIN_TARGET, ai_aurion_points, AURION_WIN_TARGET]
	bottom_hud_3d.update_info(
		phase_label.text,
		"TURN " + str(turn_number),
		score_text,
		get_phase_instruction_text(),
		next_phase_button.text,
		next_phase_button.disabled,
		phase_button_ready_visual
	)
	var player_plan: Dictionary = {}
	if battle_plan_manager != null:
		player_plan = battle_plan_manager.current_battle_plan
	bottom_hud_3d.set_battleplans(player_plan, opponent_battle_plan)


func refresh_bottom_hud_log() -> void:
	if bottom_hud_3d == null or game_log == null:
		return
	var output := "\n".join(game_log.lines)
	if output == last_bottom_hud_log_text:
		return
	last_bottom_hud_log_text = output
	bottom_hud_3d.set_log_output(output)


func create_exit_button() -> void:
	var exit_button := Button.new()
	exit_button.name = "ExitBattleButton"
	exit_button.text = "Exit"
	exit_button.focus_mode = Control.FOCUS_NONE
	exit_button.custom_minimum_size = Vector2(86, 40)
	exit_button.anchor_left = 1.0
	exit_button.anchor_right = 1.0
	exit_button.offset_left = -104.0
	exit_button.offset_top = 18.0
	exit_button.offset_right = -18.0
	exit_button.offset_bottom = 58.0
	exit_button.z_index = 80
	exit_button.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE_PATH))
	$UI.add_child(exit_button)


func update_turn_counter_ui() -> void:
	if turn_label != null:
		turn_label.text = "TURN " + str(turn_number)


func create_ability_prompt_panel() -> void:
	ability_prompt_panel = AbilityPromptPanel.new()
	ability_prompt_panel.ability_choice_made.connect(_on_ability_choice_made)
	$UI.add_child(ability_prompt_panel)


func create_insight_presenter() -> void:
	insight_presenter = InsightPresentation3D.new()
	insight_presenter.name = "InsightPresentation3D"
	$UI.add_child(insight_presenter)
	insight_presenter.setup(self, get_card_inspect_panel())


func _on_ability_choice_made(use_ability: bool, card_data: CardData, ability_text: String) -> void:
	if card_data == null:
		return
	if use_ability:
		log_msg("Used chosen ability: " + card_data.card_name)
		log_msg(ability_text)
	else:
		log_msg("Skipped chosen ability: " + card_data.card_name)


func set_phase(new_phase: int) -> void:
	if current_phase == BattlePhase.COMBAT and new_phase != BattlePhase.COMBAT:
		clear_active_combat_lane_highlight()

	current_phase = new_phase
	update_phase_ui()
	update_slot_highlights()
	if current_phase != BattlePhase.BATTLEPLAN or deck_selection_complete:
		show_phase_title(get_phase_name(current_phase))

	match current_phase:
		BattlePhase.BATTLEPLAN:
			log_msg("Phase: Battleplan")

		BattlePhase.TRIBUTE:
			log_msg("Phase: Tribute")
			ai_start_tribute_phase()

		BattlePhase.DEPLOYMENT:
			begin_deployment_phase()

		BattlePhase.COMBAT:
			begin_combat_phase()


func get_phase_name(phase: int) -> String:
	match phase:
		BattlePhase.BATTLEPLAN:
			return "BATTLEPLAN"
		BattlePhase.TRIBUTE:
			return "TRIBUTE"
		BattlePhase.DEPLOYMENT:
			return "DEPLOYMENT"
		BattlePhase.COMBAT:
			return "COMBAT"
	return ""


func begin_deployment_phase() -> void:
	ai_deployed_this_deployment_phase = false
	player_passed_deployment = false
	log_msg("Phase: Deployment")

	if player_has_initiative:
		log_msg("Player has initiative and deploys first. AI will deploy after you press Go to Combat.")
	else:
		log_msg("AI has initiative and deploys first.")
		await run_ai_deployment_turn_if_needed()


func run_ai_deployment_turn_if_needed() -> void:
	if ai_deployed_this_deployment_phase or phase_transition_busy:
		return
	phase_transition_busy = true

	if next_phase_button != null:
		next_phase_button.disabled = true

	await ai_take_deployment_turn()
	ai_deployed_this_deployment_phase = true
	phase_transition_busy = false

	if next_phase_button != null:
		next_phase_button.disabled = false


func begin_combat_phase() -> void:
	phase_transition_busy = true
	cleanup_face_up_gambits_before_combat()
	reset_combat_state()
	clear_active_combat_lane_highlight()
	await get_tree().create_timer(PHASE_TITLE_TOTAL_TIME).timeout
	if current_phase != BattlePhase.COMBAT:
		phase_transition_busy = false
		return
	phase_transition_busy = false

	if player_has_initiative:
		log_msg("Phase: Combat. Player has initiative. Right-click the leftmost or rightmost lane, then choose Attack, Check, or Pass.")
	else:
		log_msg("Phase: Combat. AI has initiative. AI chooses combat direction and gets first priority in each lane.")
		await get_tree().create_timer(COMBAT_LANE_START_DELAY).timeout
		await ai_take_combat_initiative()

func update_phase_ui() -> void:
	if phase_label == null or next_phase_button == null:
		return

	match current_phase:
		BattlePhase.BATTLEPLAN:
			if pending_battleplan_draws > 0:
				phase_label.text = "BATTLEPLAN DRAW"
				next_phase_button.text = "Draw " + str(pending_battleplan_draws) + " Card(s)"
			elif battleplan_hand_cleanup_active:
				phase_label.text = "HAND LIMIT"
				next_phase_button.text = "Discard Excess Cards"
			else:
				phase_label.text = "BATTLEPLAN PHASE"
				next_phase_button.text = "Choose Battleplan"
		BattlePhase.TRIBUTE:
			phase_label.text = "TRIBUTE PHASE"
			next_phase_button.text = "Tribute in Progress"
		BattlePhase.DEPLOYMENT:
			phase_label.text = "DEPLOYMENT PHASE"
			next_phase_button.text = (
				"Proceed to Combat Phase" if player_passed_deployment else "Pass Deployment"
			)
		BattlePhase.COMBAT:
			phase_label.text = "COMBAT PHASE"
			next_phase_button.text = ""

	update_phase_instruction_ui()
	update_turn_counter_ui()
	update_phase_progress_state()
	refresh_bottom_hud()


func update_phase_progress_state() -> void:
	if next_phase_button == null:
		return
	var ready := is_current_phase_complete()
	next_phase_button.disabled = not ready
	set_phase_button_ready_visual(ready)
	refresh_bottom_hud()


func is_current_phase_complete() -> bool:
	if phase_transition_busy or is_prebattle_modal_open() or hand_drag_preview != null:
		return false
	match current_phase:
		BattlePhase.BATTLEPLAN:
			return false
		BattlePhase.TRIBUTE:
			return false
		BattlePhase.DEPLOYMENT:
			return true
		BattlePhase.COMBAT:
			return (
				combat_direction_selected
				and combat_next_lane_index >= combat_lane_order.size()
				and not combat_resolution_running
				and not parry_system.active
			)
	return false


func try_auto_advance_combat_phase() -> void:
	if game_over or current_phase != BattlePhase.COMBAT:
		return
	if is_current_phase_complete():
		start_next_round()


func is_prebattle_modal_open() -> bool:
	return (
		(deck_selection_screen != null and deck_selection_screen.visible)
		or (battle_plan_selection_screen != null and battle_plan_selection_screen.visible)
		or waiting_for_battle_plan
		or insight_presentation_active
	)


func player_has_remaining_deployment_move() -> bool:
	if hand == null or tribute_manager == null or board_slots == null:
		return false
	var available_tp := tribute_manager.current_tribute_points
	for card_ui in hand.cards:
		if card_ui == null or card_ui.card_data == null:
			continue
		var card_data: CardData = card_ui.card_data
		var card_type := get_clean_card_type(card_data)
		for slot in board_slots.get_children():
			if String(slot.get_meta("owner", "")) != "player":
				continue
			var occupied := bool(slot.get_meta("occupied", false))
			var row := String(slot.get_meta("row", ""))
			if card_type == "equipment":
				if (
					occupied
					and slot.has_method("can_attach_equipment")
					and slot.can_attach_equipment()
					and card_data.tribute_cost <= available_tp
					and player_card_passes_faction_gate(card_data, false)
				):
					return true
				if not occupied and row == "back":
					var equipment_shadowtax := get_player_face_down_card_deployment_cost(card_data, true)
					if equipment_shadowtax <= available_tp:
						return true
				continue
			if occupied or (row != "front" and row != "back"):
				continue
			var can_skip_gate := should_skip_player_faction_gate_for_slot(card_data, slot)
			if not can_skip_gate and not player_card_passes_faction_gate(card_data, false):
				continue
			var face_down := row == "back" and (is_unit_card(card_data) or is_gambit_card(card_data))
			var cost := get_player_face_down_card_deployment_cost(card_data, face_down)
			if cost <= available_tp:
				return true
	return false


func set_phase_button_ready_visual(ready: bool) -> void:
	if phase_button_ready_visual == ready:
		return
	phase_button_ready_visual = ready
	if not ready:
		next_phase_button.remove_theme_stylebox_override("normal")
		next_phase_button.remove_theme_color_override("font_color")
		return
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(0.48, 0.29, 0.045, 0.98)
	glow.border_color = Color(1.0, 0.82, 0.24, 1.0)
	glow.set_border_width_all(3)
	glow.set_corner_radius_all(7)
	glow.shadow_color = Color(1.0, 0.62, 0.08, 0.72)
	glow.shadow_size = 12
	next_phase_button.add_theme_stylebox_override("normal", glow)
	next_phase_button.add_theme_color_override("font_color", Color(1.0, 0.96, 0.72, 1.0))


func update_phase_instruction_ui() -> void:
	if phase_instruction_label == null:
		return

	phase_instruction_label.text = get_phase_instruction_text()


func get_phase_instruction_text() -> String:
	if parry_system.active:
		return (
			"PARRY ACTIVE
"
			+ "Drop hand cards into the glowing Parry Pit.
"
			+ "Add enough DP to reach the target.
"
			+ "Or press Let Unit Die."
		)

	match current_phase:
		BattlePhase.BATTLEPLAN:
			if pending_battleplan_draws > 0:
				return (
					"Physically drag "
					+ str(pending_battleplan_draws)
					+ " awarded card(s) from Draw Pile into your hand."
				)
			if battleplan_hand_cleanup_active and hand != null:
				return (
					"Discard "
					+ str(maxi(hand.cards.size() - hand.max_hand_size, 0))
					+ " card(s) into the Discard Pile.  Time: "
					+ str(int(ceil(battleplan_discard_time_left)))
					+ "s"
				)
			return (
				"Choose 1 Battle Plan.
"
				+ "Initiative decides who acts first.
"
				+ "Plans can affect draw, hand size, and rewards."
			)

		BattlePhase.TRIBUTE:
			if tribute_manager != null and tribute_manager.tribute_card_used_this_turn:
				return "Tribute offered. Deployment will begin automatically."

			return (
				"Drag exactly 1 card from hand to Tribute.
"
				+ "Units/Equipment: +1 permanent TP.
"
				+ "Gambits: +2 temporary TP this turn."
			)

		BattlePhase.DEPLOYMENT:
			if player_passed_deployment:
				return (
					"Your Deployment has been passed.\n"
					+ "Press Proceed to Combat Phase when ready."
				)
			return (
				"Drag cards to glowing valid slots.
"
				+ "Face-down cards use Shadowtax.
"
				+ "Face-up race cards require Faction Gate.
"
				+ "Equipment attaches to face-up units.
"
				+ "Deploy while useful, or pass Deployment at any time."
			)

		BattlePhase.COMBAT:
			if combat_direction_selected and combat_next_lane_index >= combat_lane_order.size():
				return "All combat lanes are resolved."

			if not combat_direction_selected:
				if player_has_initiative:
					return (
						"Right-click the leftmost or rightmost lane.
"
						+ "Choose Attack, Check, or Pass.
"
						+ "This sets combat direction."
					)

				return (
					"AI has initiative.
"
					+ "AI chooses direction and acts first.
"
					+ "Wait for the active lane."
				)

			var lane: String = current_combat_lane()

			if lane == "":
				lane = active_combat_lane

			if combat_priority_owner == "player":
				return (
					"Right-click the glowing "
					+ lane.capitalize()
					+ " lane.
"
					+ "Choose Attack, Check, or Pass.
"
					+ "Resolve hidden back row before Monarch Strike."
				)

			if combat_priority_owner == "ai":
				return (
					"AI has priority in the "
					+ lane.capitalize()
					+ " lane.
"
					+ "Wait for AI to attack, check, or pass."
				)

			return (
				"Combat is ready.
"
				+ "Right-click the glowing lane.
"
				+ "Choose Attack, Check, or Pass."
			)

	return ""


func _on_next_phase_pressed() -> void:
	if is_prebattle_modal_open() or not is_current_phase_complete():
		return
	if next_phase_button != null and next_phase_button.disabled:
		return

	match current_phase:
		BattlePhase.BATTLEPLAN:
			open_battle_plan_selection()

		BattlePhase.TRIBUTE:
			set_phase(BattlePhase.DEPLOYMENT)

		BattlePhase.DEPLOYMENT:
			if not player_passed_deployment:
				player_passed_deployment = true
				log_msg("Player passed Deployment.")
				cancel_selected_card()
				update_slot_highlights()
				if not ai_deployed_this_deployment_phase:
					if player_has_initiative:
						log_msg("AI now takes its Deployment turn.")
					else:
						log_msg("Resolving the AI Deployment turn.")
					await run_ai_deployment_turn_if_needed()
			set_phase(BattlePhase.COMBAT)

func start_next_round() -> void:
	phase_transition_busy = true
	clear_active_combat_lane_highlight()
	reset_face_down_gambit_setup_counters()
	if parry_system.active:
		log_msg("Resolve the parry prompt before ending combat.")
		phase_transition_busy = false
		return
	queue_surviving_stealth_deployments()
	await resolve_pending_stealth_deployments()

	resolve_dominance_before_cleanup()
	cleanup_battlefield_spells()

	if tribute_manager != null:
		tribute_manager.start_new_turn_refresh()
		update_tribute_counter()

	if battle_plan_manager != null:
		battle_plan_manager.advance_round()

	turn_number += 1
	used_active_insight_ability_keys.clear()
	update_turn_counter_ui()
	cancel_selected_card()
	phase_transition_busy = false
	open_battle_plan_selection()


func resolve_pending_stealth_deployments() -> void:
	for pending in pending_stealth_deployments.duplicate():
		var back_slot := pending.get("slot") as Node
		var card_data := pending.get("card") as CardData
		var lane := String(pending.get("lane", ""))
		if back_slot == null or card_data == null or get_slot_card_data(back_slot) != card_data:
			continue
		back_slot.reveal_card()
		back_slot.set_meta("stealth_pending", false)
		var front_slot := find_slot_by_owner_row_lane("player", "front", lane)
		if front_slot == null or get_slot_card_data(front_slot) != null:
			continue
		stealth_deployment_selection_slot = back_slot
		insight_presentation_active = true
		back_slot.call("set_insight_highlight", true, Color(0.72, 0.24, 1.0, 1.0))
		show_phase_title("DEPLOY " + card_data.card_name.to_upper() + " FOR FREE")
		await stealth_deployment_slot_chosen
		back_slot.call("set_insight_highlight", false, Color.WHITE)
		stealth_deployment_selection_slot = null
		insight_presentation_active = false
		if get_slot_card_data(back_slot) == card_data and get_slot_card_data(front_slot) == null:
			back_slot.clear_slot()
			front_slot.call("place_card", TEST_CARD_SCENE, card_data, false)
	pending_stealth_deployments.clear()


func queue_surviving_stealth_deployments() -> void:
	if board_slots == null:
		return
	for slot in board_slots.get_children():
		if String(slot.get_meta("owner", "")) != "player" or String(slot.get_meta("row", "")) != "back":
			continue
		if not bool(slot.get_meta("face_down", false)):
			continue
		var card_data := get_slot_card_data(slot)
		if card_data == null or get_card_insight_ability(card_data, &"stealth") == null:
			continue
		var already_pending := false
		for pending in pending_stealth_deployments:
			if pending.get("slot") == slot:
				already_pending = true
				break
		if not already_pending:
			pending_stealth_deployments.append({
				"slot": slot,
				"card": card_data,
				"lane": get_slot_lane(slot),
			})


func reset_combat_state() -> void:
	combat_direction_selected = false
	combat_lane_order.clear()
	combat_next_lane_index = 0
	original_combat_priority_owner = get_initiative_priority_owner()
	combat_priority_owner = original_combat_priority_owner
	player_passed_current_lane = false
	ai_passed_current_lane = false
	enemy_fortified_lanes.clear()
	player_fortified_lanes.clear()
	combat_resolution_running = false
	active_combat_lane = ""

func connect_all_slots() -> void:
	if board_slots == null:
		return
	for slot in board_slots.get_children():
		if slot.has_signal("slot_clicked"):
			slot.slot_clicked.connect(_on_slot_clicked)
		if slot.has_signal("slot_right_clicked"):
			slot.slot_right_clicked.connect(_on_slot_right_clicked)


func _on_hand_card_drag_started(card: CardUI) -> void:
	if waiting_for_battle_plan or card == null:
		return
	select_card(card.card_data)
	start_hand_drag_preview(card)


func _on_hand_card_drag_released(card: CardUI, screen_position: Vector2) -> void:
	finish_hand_drag_preview()
	if card == null:
		cancel_selected_card()
		return

	if not is_instance_valid(card):
		cancel_selected_card()
		return
	card.visible = player_hand_3d == null

	if selected_card_data == null and card.card_data != null:
		select_card(card.card_data)

	var dragged_card_data: CardData = selected_card_data

	var target_node: Node = get_3d_node_under_screen_position(screen_position)
	var target_slot: Node = find_board_slot_from_node(target_node)

	if parry_system.active:
		if parry_system.is_node_in_pit(target_node):
			await parry_system.sacrifice_card(card)
			return

		log_msg("Drop cards into the glowing pit to parry, or press Let Unit Die.")
		return_card_to_hand_safely(card)
		cancel_selected_card()
		return

	if battleplan_hand_cleanup_active:
		if is_node_inside_target(target_node, discard_pile):
			if dragged_card_data != null and discard_pile != null:
				card.visible = false
				await play_player_hand_to_node_animation(dragged_card_data, discard_pile, false)
				discard_pile.add_card(dragged_card_data)
				hand.consume_dragged_card(card)
				log_msg("Card discarded to meet the Battle Plan hand limit.")
			cancel_selected_card()
			if hand.cards.size() <= hand.max_hand_size:
				finish_battleplan_prephase()
			else:
				update_phase_ui()
			return
		log_msg("During hand cleanup, drop excess cards into the Discard Pile.")
		return_card_to_hand_safely(card)
		cancel_selected_card()
		return

	if is_node_inside_target(target_node, tribute_pile):
		if current_phase != BattlePhase.TRIBUTE:
			log_msg("Cards can only be sent to Tribute during the Tribute Phase.")
			return_card_to_hand_safely(card)
			cancel_selected_card()
			return

		if card != null and is_instance_valid(card):
			card.visible = false

		await play_player_hand_to_node_animation(dragged_card_data, tribute_pile, false)

		var sacrificed: bool = try_sacrifice_selected_card_to_tribute()

		if sacrificed:
			if hand != null:
				hand.consume_dragged_card(card)
		else:
			if card != null and is_instance_valid(card):
				card.visible = player_hand_3d == null

			return_card_to_hand_safely(card)

		cancel_selected_card()
		return

	if target_slot != null:
		if current_phase != BattlePhase.DEPLOYMENT:
			log_msg("Cards can only be deployed during the Deployment Phase.")
			return_card_to_hand_safely(card)
			cancel_selected_card()
			return
		if player_passed_deployment:
			log_msg("Deployment has already been passed. Proceed to Combat Phase.")
			return_card_to_hand_safely(card)
			cancel_selected_card()
			return

		var card_type: String = get_clean_card_type(selected_card_data)

		if can_promote_selected_card_on_slot(target_slot):
			if card != null and is_instance_valid(card):
				card.visible = false

			await play_player_hand_to_node_animation(dragged_card_data, target_slot, false)

			var promoted: bool = try_promote_selected_card_on_slot(target_slot)

			if promoted:
				if hand != null:
					hand.consume_dragged_card(card)
			else:
				if card != null and is_instance_valid(card):
					card.visible = player_hand_3d == null

				return_card_to_hand_safely(card)

			cancel_selected_card()
			return

		if card_type == "equipment" and not can_place_selected_equipment_face_down(target_slot):
			if card != null and is_instance_valid(card):
				card.visible = false

			await play_player_hand_to_node_animation(dragged_card_data, target_slot, false)

			var attached: bool = try_attach_selected_equipment_to_slot(target_slot)

			if attached:
				if hand != null:
					hand.consume_dragged_card(card)
			else:
				if card != null and is_instance_valid(card):
					card.visible = player_hand_3d == null

				return_card_to_hand_safely(card)

			cancel_selected_card()
			return

		if is_gambit_card(selected_card_data):
			if String(target_slot.get_meta("owner", "")) != "player":
				log_msg("Spells can only be placed on your side of the board.")
				return_card_to_hand_safely(card)
				cancel_selected_card()
				return

			if bool(target_slot.get_meta("occupied", false)):
				log_msg("That slot is already occupied.")
				return_card_to_hand_safely(card)
				cancel_selected_card()
				return

			var target_row: String = String(target_slot.get_meta("row", ""))

			if target_row == "front":
				if card != null and is_instance_valid(card):
					card.visible = false

				await play_player_hand_to_node_animation(dragged_card_data, target_slot, false)

				var front_spell_placed: bool = try_place_selected_card_on_slot(target_slot)

				if front_spell_placed:
					if hand != null:
						hand.consume_dragged_card(card)
				else:
					if card != null and is_instance_valid(card):
						card.visible = player_hand_3d == null

					return_card_to_hand_safely(card)

				cancel_selected_card()
				return

			if target_row == "back":
				return_card_to_hand_safely(card)
				show_spell_choice_panel(card, target_slot)
				return

			log_msg("Invalid spell placement row.")
			return_card_to_hand_safely(card)
			cancel_selected_card()
			return

		var place_face_down: bool = false
		var slot_row: String = String(target_slot.get_meta("row", ""))

		if (is_unit_card(selected_card_data) or is_equipment_card(selected_card_data)) and slot_row == "back":
			place_face_down = true

		if card != null and is_instance_valid(card):
			card.visible = false

		await play_player_hand_to_node_animation(dragged_card_data, target_slot, place_face_down)

		var placed: bool = try_place_selected_card_on_slot(target_slot)

		if placed:
			if hand != null:
				hand.consume_dragged_card(card)
		else:
			if card != null and is_instance_valid(card):
				card.visible = player_hand_3d == null

			return_card_to_hand_safely(card)

		cancel_selected_card()
		return

	if hand != null and hand.has_method("is_screen_position_in_hand_reorder_zone"):
		if hand.hand_is_raised and hand.is_screen_position_in_hand_reorder_zone(screen_position):
			if hand.has_method("reorder_card_in_hand"):
				hand.reorder_card_in_hand(card, screen_position.x)

			return_card_to_hand_safely(card)
			cancel_selected_card()
			return

	log_msg("Card dropped nowhere valid.")
	return_card_to_hand_safely(card)
	cancel_selected_card()


func start_hand_drag_preview(card: CardUI) -> void:
	finish_hand_drag_preview()
	if card == null or card.card_data == null:
		return
	hand_drag_preview = TEST_CARD_SCENE.instantiate() as Node3D
	hand_was_auto_lowered_for_drag = false
	if bottom_hud_3d != null:
		bottom_hud_3d.set_card_drag_active(true)
	add_child(hand_drag_preview)
	hand_drag_preview.top_level = true
	if hand_drag_preview.has_method("assign_card_data"):
		hand_drag_preview.assign_card_data(card.card_data, false)
	disable_preview_collision(hand_drag_preview)
	hand_drag_preview_target_scale = Vector3(1.12, 1.12, 1.12)
	if player_hand_3d != null:
		hand_drag_preview.global_position = player_hand_3d.get_card_global_position(card)
		hand_drag_preview.global_rotation = player_hand_3d.get_card_global_rotation(card)
		hand_drag_preview.scale = player_hand_3d.get_card_global_scale(card)
		player_hand_3d.hide_card_for_action(card)
	else:
		hand_drag_preview.scale = Vector3(0.92, 0.92, 0.92)
		hand_drag_preview.rotation = Vector3.ZERO
		hand_drag_preview.global_position = screen_to_battle_plane(
			get_viewport().get_mouse_position(),
			0.62
		)
	hand_drag_preview_target_position = hand_drag_preview.global_position
	card.visible = false
	Cursors.use_grab()


func update_hand_drag_preview(delta: float) -> void:
	if hand_drag_preview == null or not is_instance_valid(hand_drag_preview):
		return
	var screen_position := get_viewport().get_mouse_position()
	# Pull the rest of the hand out of the battlefield view once a held card
	# leaves the hand region. It stays sheathed until Space is pressed again.
	if hand != null and hand.hand_is_raised and not hand_was_auto_lowered_for_drag:
		if not hand.is_screen_position_in_hand_reorder_zone(screen_position):
			hand.lower_hand()
			hand_was_auto_lowered_for_drag = true
	var target_node := get_3d_node_under_screen_position(screen_position)
	var target_slot := find_board_slot_from_node(target_node)
	hand_drag_preview_target_scale = Vector3(1.12, 1.12, 1.12)
	if target_slot != null and current_phase == BattlePhase.DEPLOYMENT:
		var card_point := target_slot.get_node_or_null("CardPoint") as Node3D
		hand_drag_preview_target_position = (
			card_point.global_position if card_point != null else (target_slot as Node3D).global_position
		) + Vector3(0.0, 0.48, 0.0)
		hand_drag_preview_target_scale = Vector3(1.18, 1.18, 1.18)
	elif battleplan_hand_cleanup_active and is_node_inside_target(target_node, discard_pile):
		hand_drag_preview_target_position = discard_pile.global_position + Vector3(0.0, 0.52, 0.0)
		hand_drag_preview_target_scale = Vector3(1.18, 1.18, 1.18)
	elif is_node_inside_target(target_node, tribute_pile) and current_phase == BattlePhase.TRIBUTE:
		hand_drag_preview_target_position = tribute_pile.global_position + Vector3(0.0, 0.52, 0.0)
		hand_drag_preview_target_scale = Vector3(1.18, 1.18, 1.18)
	else:
		var table_position := screen_to_battle_plane(screen_position, 0.62)
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			var toward_camera := (camera.global_position - table_position).normalized()
			hand_drag_preview_target_position = table_position + toward_camera * 0.42
		else:
			hand_drag_preview_target_position = table_position
	hand_drag_preview.global_position = hand_drag_preview.global_position.lerp(
		hand_drag_preview_target_position,
		clampf(delta * 16.0, 0.0, 1.0)
	)
	hand_drag_preview.scale = hand_drag_preview.scale.lerp(
		hand_drag_preview_target_scale,
		clampf(delta * 11.0, 0.0, 1.0)
	)
	hand_drag_preview.rotation = hand_drag_preview.rotation.lerp(
		Vector3.ZERO,
		clampf(delta * 12.0, 0.0, 1.0)
	)


func finish_hand_drag_preview() -> void:
	if hand_drag_preview != null and is_instance_valid(hand_drag_preview):
		last_player_hand_animation_start = hand_drag_preview.global_position
		has_player_hand_animation_start = true
		hand_drag_preview.queue_free()
	hand_drag_preview = null
	hand_was_auto_lowered_for_drag = false
	if bottom_hud_3d != null:
		bottom_hud_3d.set_card_drag_active(false)
	Cursors.use_normal()


func disable_preview_collision(node: Node) -> void:
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	for child in node.get_children():
		disable_preview_collision(child)


func screen_to_battle_plane(screen_position: Vector2, plane_y: float) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return origin
	var distance := (plane_y - origin.y) / direction.y
	return origin + direction * distance


func deal_starting_hand() -> void:
	if hand == null or player_deck == null:
		log_msg("Hand or PlayerDeck is missing.")
		return
	for i in range(3):
		var drawn_card: CardData = player_deck.draw_top_card()
		if drawn_card == null:
			return
		hand.add_card_to_hand(drawn_card, false)
	if draw_pile != null:
		draw_pile.set_card_count(player_deck.cards_remaining())
	log_msg("Starting hand of 3 cards dealt. Deck remaining: " + str(player_deck.cards_remaining()))


func _on_draw_pile_drag_started(screen_position: Vector2) -> void:
	if waiting_for_battle_plan:
		return
	var is_awarded_draw := current_phase == BattlePhase.BATTLEPLAN and pending_battleplan_draws > 0
	if current_phase == BattlePhase.BATTLEPLAN and not is_awarded_draw:
		return
	if current_phase == BattlePhase.DEPLOYMENT or current_phase == BattlePhase.COMBAT:
		log_msg("You cannot draw cards after Deployment has begun.")
		return
	if hand == null or player_deck == null:
		return
	if not is_awarded_draw and not hand.can_accept_card():
		log_msg("Hand is full. Max hand size: " + str(hand.max_hand_size))
		return
	var preview_card: CardData = player_deck.peek_top_card()
	var started: bool = hand.start_draw_pile_drag(screen_position, preview_card, is_awarded_draw)
	if started:
		if bottom_hud_3d != null:
			bottom_hud_3d.set_card_drag_active(true)
		if player_hand_3d != null and draw_pile != null:
			if hand.draw_drag_card != null:
				hand.draw_drag_card.visible = false
			player_hand_3d.start_draw_preview(preview_card, draw_pile)
			player_hand_3d.update_draw_preview_target(screen_position)
		log_msg("Dragging card from Draw Pile.")
	else:
		log_msg("Draw Pile is empty.")


func _on_draw_pile_drag_moved(screen_position: Vector2) -> void:
	if hand != null:
		hand.update_draw_pile_drag(screen_position)
	if player_hand_3d != null:
		player_hand_3d.update_draw_preview_target(screen_position)


func _on_draw_pile_drag_released(screen_position: Vector2) -> void:
	if bottom_hud_3d != null:
		bottom_hud_3d.set_card_drag_active(false)
	if hand == null or player_deck == null:
		return
	if not hand.is_screen_position_in_hand_drop_zone(screen_position):
		hand.finish_draw_pile_drag(screen_position, null)
		if player_hand_3d != null:
			player_hand_3d.cancel_draw_preview(true)
		return
	var is_awarded_draw := current_phase == BattlePhase.BATTLEPLAN and pending_battleplan_draws > 0
	if not is_awarded_draw and not hand.can_accept_card():
		hand.finish_draw_pile_drag(screen_position, null)
		if player_hand_3d != null:
			player_hand_3d.cancel_draw_preview(true)
		log_msg("Draw cancelled. Hand is full. Max hand size: " + str(hand.max_hand_size))
		return
	var drawn_card: CardData = player_deck.draw_top_card()
	var accepted: bool = hand.finish_draw_pile_drag(screen_position, drawn_card, is_awarded_draw)
	if accepted:
		if player_hand_3d != null:
			player_hand_3d.finish_draw_preview_into_hand(hand.last_drawn_card)
		draw_pile.consume_top_card()
		log_msg("Card drawn into hand. Deck remaining: " + str(player_deck.cards_remaining()))
		if is_awarded_draw:
			pending_battleplan_draws = maxi(pending_battleplan_draws - 1, 0)
			update_phase_ui()
			if pending_battleplan_draws <= 0:
				begin_battleplan_hand_cleanup_or_tribute()
	else:
		if player_hand_3d != null:
			player_hand_3d.cancel_draw_preview(true)


func _on_slot_clicked(slot: Node) -> void:
	if stealth_deployment_selection_slot != null:
		if slot == stealth_deployment_selection_slot:
			stealth_deployment_slot_chosen.emit(slot)
		return
	if insight_gambit_selection_active:
		if insight_gambit_candidate_slots.has(slot):
			insight_gambit_slot_chosen.emit(slot)
		return
	if is_prebattle_modal_open():
		return
	if current_phase == BattlePhase.COMBAT:
		# Combat must never auto-resolve from a normal slot click.
		# Right-click menu actions are the only valid player combat actions.
		# This prevents empty lanes from being skipped by accidental click events
		# after resolving Attack / Check from the board action menu.
		var lane: String = get_slot_lane(slot)
		if lane != "":
			log_msg("Combat action ready in the " + lane + " lane. Right-click and choose Attack, Check, or Pass.")
		else:
			log_msg("Combat actions use the right-click menu.")
		return
	if current_phase != BattlePhase.DEPLOYMENT:
		log_msg("Cards can only be deployed during the Deployment Phase.")
		return
	if player_passed_deployment:
		log_msg("Deployment has already been passed. Proceed to Combat Phase.")
		return
	var placed := try_place_selected_card_on_slot(slot)
	if placed:
		if hand != null:
			hand.remove_selected_card()
		cancel_selected_card()


func _on_slot_right_clicked(slot: Node) -> void:
	if is_prebattle_modal_open():
		return
	show_board_slot_action_menu(slot)


func _on_tribute_pile_clicked() -> void:
	if waiting_for_battle_plan:
		return
	if current_phase != BattlePhase.TRIBUTE:
		log_msg("Tribute pile is only active during the Tribute Phase.")
		return
	if not has_selected_card:
		log_msg("Drag a card from your hand to the Tribute Pile.")
		return
	var sacrificed := try_sacrifice_selected_card_to_tribute()
	if sacrificed:
		if hand != null:
			hand.remove_selected_card()
		cancel_selected_card()


func _input(event: InputEvent) -> void:
	if is_prebattle_modal_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			if hand != null and hand.has_method("toggle_hand"):
				hand.toggle_hand()

			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_SHIFT:
			toggle_global_ability_icons()
			get_viewport().set_input_as_handled()
			return


	if waiting_for_battle_plan:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			select_card(ARCH_WIZARD_MAELCOR)
		if event.keycode == KEY_2:
			select_card(IMPERIAL_ARCHIVE_MASTER)
		if event.keycode == KEY_3:
			select_card(JENA_OF_YEL)
		if event.keycode == KEY_4:
			select_card(IVAAN_THE_BONE_CRUSHER)
		if event.keycode == KEY_5:
			select_card(UPPER_HALL_PROSPECTOR)
		if event.keycode == KEY_6:
			select_card(VAELORI_LONGBOW)
		if event.keycode == KEY_7:
			select_card(BLACKMAIL)
		if event.keycode == KEY_ESCAPE:
			cancel_selected_card()
		if event.keycode == KEY_E:
			_on_next_phase_pressed()
		if event.keycode == KEY_T:
			debug_tribute_selected_card()
		if event.keycode == KEY_Y:
			tribute_manager.refresh_tribute_points()
		if event.keycode == KEY_D and hand != null:
			debug_draw_card()


func debug_draw_card() -> void:
	if current_phase == BattlePhase.DEPLOYMENT or current_phase == BattlePhase.COMBAT:
		log_msg("You cannot draw cards after Deployment has begun.")
		return
	if player_deck == null or not hand.can_accept_card():
		return
	var drawn_card: CardData = player_deck.draw_top_card()
	if drawn_card == null:
		return
	hand.add_card_to_hand(drawn_card)
	if draw_pile != null:
		draw_pile.consume_top_card()


func debug_tribute_selected_card() -> void:
	if selected_card_data == null:
		return

	if try_sacrifice_selected_card_to_tribute():
		log_msg("Debug tribute: " + selected_card_data.card_name + ". " + tribute_manager.get_status_text())


func select_card(card_data: CardData) -> void:
	if card_data == null:
		return
	selected_card_scene = TEST_CARD_SCENE
	selected_card_data = card_data
	has_selected_card = true
	log_msg("Selected: " + card_data.card_name + " | TP " + str(card_data.tribute_cost) + " | " + card_data.card_type)
	update_slot_highlights()


func cancel_selected_card() -> void:
	selected_card_scene = null
	selected_card_data = null
	has_selected_card = false
	update_slot_highlights()





func try_place_selected_card_on_slot(slot: Node) -> bool:
	if slot == null:
		return false

	if not has_selected_card or selected_card_data == null:
		return false

	var slot_id: String = String(slot.get_meta("slot_id", ""))
	var slot_row: String = String(slot.get_meta("row", ""))
	var card_type: String = get_clean_card_type(selected_card_data)

	if can_promote_selected_card_on_slot(slot):
		return try_promote_selected_card_on_slot(slot)

	if card_type == "equipment" and not can_place_selected_equipment_face_down(slot):
		return try_attach_selected_equipment_to_slot(slot)

	if not is_valid_slot_for_selected_card(slot):
		log_msg("Invalid placement for " + selected_card_data.card_name + " on " + slot_id)
		return false

	if not should_skip_player_faction_gate_for_slot(selected_card_data, slot) and not player_card_passes_faction_gate(selected_card_data):
		return false

	var place_face_down: bool = false

	if (card_type == "unit" or card_type == "equipment") and slot_row == "back":
		place_face_down = true

	if is_gambit_card(selected_card_data):
		# Front row Gambits are always face up.
		# Back row Gambits should normally come through confirm_pending_spell_placement().
		place_face_down = false

	var deployment_cost: int = get_player_face_down_card_deployment_cost(selected_card_data, place_face_down)

	if not tribute_manager.can_afford(deployment_cost):
		var cost_reason: String = "Shadowtax face-down setup cost" if place_face_down else "printed cost"
		log_msg("Not enough Tribute Points. Need " + str(deployment_cost) + " TP for " + cost_reason + ", have " + str(tribute_manager.current_tribute_points) + ".")
		return false

	var placed_successfully: bool = slot.place_card(TEST_CARD_SCENE, selected_card_data, place_face_down)

	if placed_successfully:
		tribute_manager.spend_tribute(deployment_cost)

		if place_face_down:
			player_face_down_gambits_this_round += 1
			log_msg("Shadowtax paid for face-down card: " + selected_card_data.card_name + ".")

		log_msg("Spent " + str(deployment_cost) + " TP. " + tribute_manager.get_status_text())
		handle_card_deployed(selected_card_data)
		return true

	return false

func try_sacrifice_selected_card_to_tribute() -> bool:
	if not has_selected_card or selected_card_data == null:
		return false

	if tribute_manager == null:
		return false

	if not tribute_manager.can_offer_card_this_turn():
		log_msg("Tribute already used this turn. Only 1 card can be used as Tribute per turn.")
		return false

	var offered_card_name: String = selected_card_data.card_name
	var offered_card_type: String = get_clean_card_type(selected_card_data)

	if offered_card_type == "gambit":
		tribute_manager.add_temporary_tribute(selected_card_data)
		tribute_manager.tribute_card_used_this_turn = true
		log_msg("Offered " + offered_card_name + " for temporary Tribute. +2 TP this turn.")
	else:
		tribute_manager.add_permanent_tribute(selected_card_data)
		tribute_manager.tribute_card_used_this_turn = true
		log_msg("Offered " + offered_card_name + " for permanent Tribute. +1 permanent TP.")

	if tribute_pile != null:
		tribute_pile.add_card(selected_card_data)

	update_tribute_counter()
	call_deferred("try_auto_advance_tribute_phase")
	return true



func get_clean_card_race(card_data: CardData) -> String:
	return CardRules.get_clean_card_race(card_data)


func should_skip_player_faction_gate_for_slot(card_data: CardData, slot: Node) -> bool:
	if card_data == null or slot == null:
		return false

	# Face-down cards do not need faction access.
	# Current prototype face-down placements happen in the back row.
	var slot_row: String = String(slot.get_meta("row", ""))
	if slot_row != "back":
		return false

	# Units placed in the back row are face down.
	if is_unit_card(card_data):
		return true

	# Gambits in the back row can be chosen face down from the visibility prompt,
	# so the slot should remain legal even without faction access.
	if is_gambit_card(card_data) or is_equipment_card(card_data):
		return true

	return false



func player_card_passes_faction_gate(card_data: CardData, show_log: bool = false) -> bool:
	if card_data == null:
		return false

	var clean_race: String = get_clean_card_race(card_data)

	if clean_race == "" or clean_race == "neutral":
		return true

	if tribute_manager == null:
		if show_log:
			log_msg("Faction Gate blocked " + card_data.card_name + ": TributeManager is missing.")
		return false

	if tribute_manager.has_method("has_faction_access"):
		var has_access: bool = tribute_manager.has_faction_access(clean_race)

		if not has_access and show_log:
			log_msg("Faction Gate locked: need at least 1 " + clean_race.capitalize() + " card in permanent Tribute to play " + card_data.card_name + ".")

		return has_access

	if show_log:
		log_msg("Faction Gate could not check " + card_data.card_name + ". TributeManager has no has_faction_access method.")

	return true


func ai_card_passes_faction_gate(card_data: CardData, show_log: bool = false) -> bool:
	if card_data == null:
		return false

	var clean_race: String = get_clean_card_race(card_data)

	if clean_race == "" or clean_race == "neutral":
		return true

	for tribute_card in ai_tribute:
		if tribute_card == null:
			continue

		# AI Gambits are temporary Tribute, so they do not unlock faction access.
		if is_gambit_card(tribute_card):
			continue

		if get_clean_card_race(tribute_card) == clean_race:
			return true

	if show_log:
		log_msg("AI Faction Gate locked: AI needs at least 1 " + clean_race.capitalize() + " card in permanent Tribute to play " + card_data.card_name + ".")

	return false



func can_promote_selected_card_on_slot(slot: Node) -> bool:
	if current_phase != BattlePhase.DEPLOYMENT:
		return false

	if not has_selected_card or selected_card_data == null:
		return false

	if slot == null:
		return false

	if String(slot.get_meta("owner", "")) != "player":
		return false

	if String(slot.get_meta("row", "")) != "front":
		return false

	if not bool(slot.get_meta("occupied", false)):
		return false

	if bool(slot.get_meta("face_down", false)):
		return false

	if not is_unit_card(selected_card_data):
		return false

	if not player_card_passes_faction_gate(selected_card_data, false):
		return false

	var old_unit: CardData = get_slot_card_data(slot)

	if not is_unit_card(old_unit):
		return false

	var new_race: String = get_clean_card_race(selected_card_data)
	var old_race: String = get_clean_card_race(old_unit)

	if new_race == "" or old_race == "":
		return false

	if new_race != old_race:
		return false

	if selected_card_data.tribute_cost <= old_unit.tribute_cost:
		return false

	return true


func try_promote_selected_card_on_slot(slot: Node) -> bool:
	if not player_card_passes_faction_gate(selected_card_data, true):
		return false

	if not can_promote_selected_card_on_slot(slot):
		log_msg("Invalid promotion target.")
		return false

	if tribute_manager == null:
		return false

	var old_unit: CardData = get_slot_card_data(slot)
	var new_unit: CardData = selected_card_data
	var promotion_cost: int = new_unit.tribute_cost

	if not tribute_manager.can_afford(promotion_cost):
		log_msg("Not enough Tribute Points to promote. Need " + str(promotion_cost) + ", have " + str(tribute_manager.current_tribute_points) + ".")
		return false

	var placed_successfully: bool = promote_slot_unit_preserving_equipment(slot, new_unit, "player")

	if not placed_successfully:
		log_msg("Promotion failed. Could not place " + new_unit.card_name + " after discarding " + old_unit.card_name + ".")
		return false

	tribute_manager.spend_tribute(promotion_cost)
	log_msg("Promoted " + old_unit.card_name + " into " + new_unit.card_name + " for full cost: " + str(promotion_cost) + " TP.")
	log_msg("Spent " + str(promotion_cost) + " TP. " + tribute_manager.get_status_text())
	handle_card_deployed(new_unit)
	return true

func is_valid_slot_for_selected_card(slot: Node) -> bool:
	if current_phase != BattlePhase.DEPLOYMENT:
		return false

	if not has_selected_card or selected_card_data == null:
		return false

	if slot == null:
		return false

	if String(slot.get_meta("owner", "")) != "player":
		return false

	if not should_skip_player_faction_gate_for_slot(selected_card_data, slot):
		if not player_card_passes_faction_gate(selected_card_data, false):
			return false

	var slot_row: String = String(slot.get_meta("row", ""))
	var slot_occupied: bool = bool(slot.get_meta("occupied", false))
	var card_type: String = get_clean_card_type(selected_card_data)

	if card_type == "equipment":
		if not slot_occupied:
			return slot_row == "back"

		if not slot.has_method("can_attach_equipment"):
			return false

		if not slot.can_attach_equipment():
			return false

		var existing_card: CardData = get_slot_card_data(slot)
		return is_unit_card(existing_card)

	if is_gambit_card(selected_card_data):
		# Spells can go front or back, any lane.
		# Front = face up automatically.
		# Back = prompt for face up / face down.
		return (slot_row == "front" or slot_row == "back") and not slot_occupied

	if card_type == "unit":
		# Units can go front face-up or back face-down.
		return (slot_row == "front" or slot_row == "back") and not slot_occupied

	return false


func can_place_selected_equipment_face_down(slot: Node) -> bool:
	if slot == null or selected_card_data == null:
		return false
	return (
		is_equipment_card(selected_card_data)
		and String(slot.get_meta("owner", "")) == "player"
		and String(slot.get_meta("row", "")) == "back"
		and not bool(slot.get_meta("occupied", false))
	)


func update_slot_highlights() -> void:
	if board_slots == null:
		return

	for slot in board_slots.get_children():
		if not slot.has_method("set_highlight") or not slot.has_method("set_invalid_highlight"):
			continue

		var has_promotion_highlight: bool = slot.has_method("set_promotion_highlight")

		slot.set_highlight(false)
		slot.set_invalid_highlight(false)

		if has_promotion_highlight:
			slot.set_promotion_highlight(false)

		if not has_selected_card or current_phase != BattlePhase.DEPLOYMENT or player_passed_deployment:
			continue

		if can_promote_selected_card_on_slot(slot):
			if has_promotion_highlight:
				slot.set_promotion_highlight(true)
			else:
				slot.set_highlight(true)

				if slot.has_method("set_outline_color"):
					slot.set_outline_color(Color(1.0, 0.82, 0.12, 1.0))
		elif is_valid_slot_for_selected_card(slot):
			slot.set_highlight(true)
		else:
			slot.set_invalid_highlight(true)

func handle_card_deployed(card_data: CardData) -> void:
	if card_data == null:
		return
	var resolved_insight := await resolve_insight_abilities(card_data, &"on_deploy")
	if resolved_insight:
		return
	var ability_text_lower: String = card_data.get_ability_text().to_lower()
	if ability_text_lower == "":
		return
	if ability_text_lower.contains("on deploy") or ability_text_lower.contains("when deployed"):
		if ability_requires_choice(card_data):
			if ability_prompt_panel != null:
				ability_prompt_panel.show_for_card(card_data)
		else:
			log_msg("On-deploy ability triggered: " + card_data.card_name)
			log_msg(card_data.get_ability_text())
		return
	log_msg("Passive ability active: " + card_data.card_name)


func resolve_insight_abilities(card_data: CardData, trigger: StringName, extra_context: Dictionary = {}) -> bool:
	if card_data == null:
		return false
	var resolved_any := false
	for ability in card_data.get_abilities():
		if ability == null:
			continue
		if ability.category.to_lower() != "insight":
			continue
		if StringName(ability.trigger) != trigger:
			continue
		var result := await resolve_insight_with_presentation(ability, extra_context)
		resolved_any = true
		if not bool(result.get("success", false)):
			log_msg("Insight ability failed: " + ability.ability_name + " (" + String(result.get("reason", "unknown")) + ").")
	return resolved_any


func resolve_insight_with_presentation(ability: AbilityData, extra_context: Dictionary = {}) -> Dictionary:
	if ability == null:
		return {"success": false, "reason": "missing_ability"}
	match ability.get_handler_id():
		&"intel":
			return await present_intel()
		&"intelligence":
			return await present_intelligence()
		&"secrecy":
			return await present_secrecy()
		&"seer":
			return await present_ai_deck_choice()
		&"vantage":
			return await present_ai_deck_choice()
		&"vision":
			return await present_vision()
		&"intuition", &"true_sight":
			return await present_hidden_enemy_gambit_choice(ability)
	return AbilityResolver.resolve(ability, build_ability_context(extra_context))


func present_insight_cards(cards: Array[CardData], config: Dictionary) -> Dictionary:
	if insight_presenter == null or cards.is_empty():
		return {"success": false, "reason": "no_cards_to_present"}
	insight_presentation_active = true
	insight_presenter.present(cards, config)
	var result: Dictionary = await insight_presenter.completed
	insight_presentation_active = false
	result["success"] = true
	return result


func pop_ai_deck_top_cards(count: int) -> Array[CardData]:
	var cards: Array[CardData] = []
	for i in range(mini(count, ai_deck.size())):
		cards.append(ai_deck.pop_back() as CardData)
	return cards


func peek_player_deck_top_cards(count: int) -> Array[CardData]:
	var cards: Array[CardData] = []
	if player_deck == null:
		return cards
	for offset in range(mini(count, player_deck.deck.size())):
		cards.append(player_deck.deck[player_deck.deck.size() - 1 - offset] as CardData)
	return cards


func get_insight_world_position(source_name: String) -> Vector3:
	match source_name:
		"enemy_deck":
			if opponent_visuals != null and opponent_visuals.deck_root != null:
				return opponent_visuals.deck_root.global_position
		"enemy_hand":
			if opponent_visuals != null and opponent_visuals.hand_root != null:
				return opponent_visuals.hand_root.global_position
		"enemy_discard":
			if opponent_visuals != null and opponent_visuals.discard_root != null:
				return opponent_visuals.discard_root.global_position
		"player_deck":
			if draw_pile != null:
				return draw_pile.global_position
		"player_hand":
			var hand_origin := get_node_or_null("CardAnimationManager/PlayerHandOrigin") as Node3D
			if hand_origin != null:
				return hand_origin.global_position
	return Vector3(0.0, 0.8, 0.8)


func present_intel() -> Dictionary:
	var cards := pop_ai_deck_top_cards(3)
	if cards.is_empty():
		show_phase_title("NO CARDS TO REVEAL")
		return {"success": false, "reason": "opponent_deck_empty"}
	update_ai_visuals()
	var result := await present_insight_cards(cards, {
		"mode": "choose",
		"source_position": get_insight_world_position("enemy_deck"),
		"chosen_destination": get_insight_world_position("player_hand"),
		"other_destination": get_insight_world_position("enemy_deck") + Vector3(0.0, -0.04, 0.0),
		"lift_return_pile": opponent_visuals.deck_root if opponent_visuals != null else null,
	})
	var chosen_index := clampi(int(result.get("index", 0)), 0, cards.size() - 1)
	var chosen := cards[chosen_index]
	if hand != null:
		var old_limit := hand.max_hand_size
		if not hand.can_accept_card():
			hand.max_hand_size = old_limit + 1
		hand.add_card_to_hand(chosen)
		hand.max_hand_size = old_limit
	for index in range(cards.size()):
		if index != chosen_index:
			ai_deck.insert(0, cards[index])
	update_ai_visuals()
	return {"success": true, "cards_seen": cards, "card_taken": chosen}


func present_ai_deck_choice() -> Dictionary:
	var cards := pop_ai_deck_top_cards(3)
	if cards.is_empty():
		show_phase_title("NO CARDS TO REVEAL")
		return {"success": false, "reason": "opponent_deck_empty"}
	update_ai_visuals()
	var result := await present_insight_cards(cards, {
		"mode": "choose",
		"source_position": get_insight_world_position("enemy_deck"),
		"chosen_destination": get_insight_world_position("enemy_discard"),
		"other_destination": get_insight_world_position("enemy_deck"),
	})
	var chosen_index := clampi(int(result.get("index", 0)), 0, cards.size() - 1)
	var discarded := cards[chosen_index]
	ai_discard.append(discarded)
	var returned: Array[CardData] = []
	for index in range(cards.size()):
		if index != chosen_index:
			returned.append(cards[index])
	for index in range(returned.size() - 1, -1, -1):
		ai_deck.append(returned[index])
	update_ai_visuals()
	return {"success": true, "cards_seen": cards, "card_discarded": discarded}


func present_intelligence() -> Dictionary:
	var cards: Array[CardData] = []
	for card in ai_hand:
		cards.append(card as CardData)
	if cards.is_empty():
		show_phase_title("OPPONENT HAND IS EMPTY")
		return {"success": false, "reason": "opponent_hand_empty"}
	if opponent_visuals != null:
		for index in range(cards.size()):
			opponent_visuals.set_hand_card_action_hidden(index, true)
	var result := await present_insight_cards(cards, {
		"mode": "hidden_pick",
		"face_down": true,
		"shuffle": true,
		"source_position": get_insight_world_position("enemy_hand"),
	})
	if opponent_visuals != null:
		for index in range(cards.size()):
			opponent_visuals.set_hand_card_action_hidden(index, false)
	return {"success": true, "cards_seen": [result.get("card")]}


func present_secrecy() -> Dictionary:
	var indexes: Array[int] = []
	for index in range(ai_hand.size()):
		indexes.append(index)
	indexes.shuffle()
	var cards: Array[CardData] = []
	for index in range(mini(2, indexes.size())):
		cards.append(ai_hand[indexes[index]] as CardData)
	if cards.is_empty():
		show_phase_title("OPPONENT HAND IS EMPTY")
		return {"success": false, "reason": "opponent_hand_empty"}
	if opponent_visuals != null:
		for index in indexes.slice(0, cards.size()):
			opponent_visuals.set_hand_card_action_hidden(int(index), true)
	await present_insight_cards(cards, {
		"mode": "reveal",
		"source_position": get_insight_world_position("enemy_hand"),
	})
	if opponent_visuals != null:
		for index in indexes.slice(0, cards.size()):
			opponent_visuals.set_hand_card_action_hidden(int(index), false)
	return {"success": true, "cards_seen": cards}


func present_vision() -> Dictionary:
	var cards := peek_player_deck_top_cards(3)
	if cards.is_empty():
		show_phase_title("NO CARDS TO REVEAL")
		return {"success": false, "reason": "player_deck_empty"}
	await present_insight_cards(cards, {
		"mode": "reveal",
		"source_position": get_insight_world_position("player_deck"),
	})
	return {"success": true, "cards_seen": cards}


func present_hidden_enemy_gambit_choice(ability: AbilityData) -> Dictionary:
	insight_gambit_candidate_slots.clear()
	if board_slots != null:
		for slot in board_slots.get_children():
			if String(slot.get_meta("owner", "")) != "enemy":
				continue
			if String(slot.get_meta("row", "")) != "back" or not bool(slot.get_meta("face_down", false)):
				continue
			if not is_gambit_card(get_slot_card_data(slot)):
				continue
			insight_gambit_candidate_slots.append(slot)
	if insight_gambit_candidate_slots.is_empty():
		show_phase_title("NO GAMBITS TO REVEAL")
		return {"success": false, "reason": "no_hidden_enemy_gambits"}
	var reveal_all := ability.get_handler_id() == &"true_sight"
	var remaining_slots: Array[Node] = insight_gambit_candidate_slots.duplicate()
	var cards_seen: Array[CardData] = []
	while not remaining_slots.is_empty():
		insight_gambit_candidate_slots = remaining_slots.duplicate()
		insight_gambit_selection_active = true
		insight_presentation_active = true
		for slot in remaining_slots:
			slot.call("set_insight_highlight", true, Color(0.18, 0.55, 1.0, 1.0))
		var chosen_slot: Node = await insight_gambit_slot_chosen
		for slot in remaining_slots:
			slot.call("set_insight_highlight", false, Color.WHITE)
		insight_gambit_selection_active = false
		insight_presentation_active = false
		var card_data := get_slot_card_data(chosen_slot)
		if card_data != null:
			cards_seen.append(card_data)
			var revealed_cards: Array[CardData] = [card_data]
			await present_insight_cards(revealed_cards, {
				"mode": "reveal",
				"source_position": (chosen_slot as Node3D).global_position,
			})
		remaining_slots.erase(chosen_slot)
		if not reveal_all:
			break
	insight_gambit_candidate_slots.clear()
	return {"success": true, "cards_seen": cards_seen}


func build_ability_context(extra_context: Dictionary = {}) -> Dictionary:
	var context := {
		"battlefield": self,
		"log": Callable(self, "log_msg"),
		"player_deck": player_deck,
		"draw_pile": draw_pile,
		"hand": hand,
		"ai_deck": ai_deck,
		"ai_hand": ai_hand,
		"ai_discard": ai_discard,
	}
	context.merge(extra_context, true)
	return context


func ability_requires_choice(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var ability_text_lower: String = card_data.get_ability_text().to_lower()
	return card_data.has_ability(&"volley") or ability_text_lower.contains("may ") or ability_text_lower.contains("choose")


func spawn_random_opponent_cards() -> void:
	# Old test-spawn disabled.
	# AI must deploy through hand + TP + phase rules.
	log_msg("Old opponent test spawn is disabled. AI uses legal deployment now.")


func get_random_opponent_test_card() -> CardData:
	if OPPONENT_TEST_CARDS.is_empty():
		return null
	var index: int = randi() % OPPONENT_TEST_CARDS.size()
	return OPPONENT_TEST_CARDS[index]


func handle_combat_lane_click(slot: Node) -> void:
	if slot == null:
		return

	if current_phase != BattlePhase.COMBAT:
		return

	if parry_system.active:
		log_msg("Resolve the current parry prompt first.")
		return

	var lane: String = get_slot_lane(slot)

	if lane == "":
		return

	# Phase 7: combat actions must come from the right-click dropdown.
	# A normal left-click can choose the first flank lane only; it does not auto-resolve combat.
	if not combat_direction_selected:
		if combat_priority_owner != "player":
			log_msg("AI has priority. You can choose the starting lane only after AI passes.")
			return

		if lane == "left":
			set_combat_lane_order_from_left()
			set_lane_priority_to_player(lane, "Starting lane selected. Choose Attack, Check, or Pass from the dropdown.")
			return

		if lane == "right":
			set_combat_lane_order_from_right()
			set_lane_priority_to_player(lane, "Starting lane selected. Choose Attack, Check, or Pass from the dropdown.")
			return

		log_msg("Choose the leftmost or rightmost lane first to set combat direction.")
		return

	if lane != current_combat_lane():
		log_msg("Next combat must resolve in the " + current_combat_lane() + " lane.")
		return

	log_msg("Use the right-click dropdown to Attack, Check, Pass, or Inspect.")

func set_combat_lane_order_from_left() -> void:
	combat_direction_selected = true
	combat_lane_order.clear()
	combat_lane_order.append("left")
	combat_lane_order.append("middle")
	combat_lane_order.append("right")
	combat_next_lane_index = 0
	if original_combat_priority_owner == "":
		original_combat_priority_owner = get_initiative_priority_owner()
	reset_priority_for_current_lane()
	set_active_combat_lane_highlight(current_combat_lane())

	log_msg("Combat direction selected: left to right.")

func set_combat_lane_order_from_right() -> void:
	combat_direction_selected = true
	combat_lane_order.clear()
	combat_lane_order.append("right")
	combat_lane_order.append("middle")
	combat_lane_order.append("left")
	combat_next_lane_index = 0
	if original_combat_priority_owner == "":
		original_combat_priority_owner = get_initiative_priority_owner()
	reset_priority_for_current_lane()
	set_active_combat_lane_highlight(current_combat_lane())

	log_msg("Combat direction selected: right to left.")

func resolve_next_combat_lane(clicked_lane: String) -> void:
	if parry_system.active:
		log_msg("Resolve the current parry prompt first.")
		return

	if combat_next_lane_index >= combat_lane_order.size():
		log_msg("All combat lanes are already resolved.")
		return

	var expected_lane: String = combat_lane_order[combat_next_lane_index]

	if clicked_lane != expected_lane:
		log_msg("Next combat must resolve in the " + expected_lane + " lane.")
		return

	if combat_priority_owner == "ai":
		await resolve_ai_current_priority_lane(expected_lane)
	else:
		set_lane_priority_to_player(expected_lane, "Player has priority. Use the right-click dropdown to act or pass.")

func resolve_lane_combat(lane: String, player_slot: Node, opponent_slot: Node) -> void:
	var player_card: CardData = get_slot_card_data(player_slot)
	var opponent_card: CardData = get_slot_card_data(opponent_slot)

	var player_has_unit: bool = is_unit_card(player_card)
	var opponent_has_unit: bool = is_unit_card(opponent_card)

	if not player_has_unit and not opponent_has_unit:
		log_msg(lane.capitalize() + " lane: no front-row units on either side.")
		return

	if player_has_unit and not opponent_has_unit:
		resolve_monarch_strike(lane, player_card)
		return

	if not player_has_unit and opponent_has_unit:
		resolve_ai_monarch_strike(lane, opponent_card)
		return

	if player_has_initiative:
		await resolve_directed_clash(lane, player_slot, player_card, opponent_slot, opponent_card, true)
	else:
		await resolve_directed_clash(lane, opponent_slot, opponent_card, player_slot, player_card, false)


func resolve_directed_clash(
	lane: String,
	_attacker_slot: Node,
	attacker_card: CardData,
	defender_slot: Node,
	defender_card: CardData,
	player_is_attacker: bool
) -> void:
	if attacker_card == null or defender_card == null:
		return

	var attacker_label: String = "Player" if player_is_attacker else "Opponent"
	var defender_label: String = "Opponent" if player_is_attacker else "Player"

	log_msg(
		lane.capitalize()
		+ " lane attack: "
		+ attacker_label
		+ " "
		+ attacker_card.card_name
		+ " AP "
		+ str(attacker_card.ap)
		+ " vs "
		+ defender_label
		+ " "
		+ defender_card.card_name
		+ " AP "
		+ str(defender_card.ap)
	)

	if attacker_card.ap == defender_card.ap:
		send_slot_card_to_discard(defender_slot)
		send_slot_card_to_discard(_attacker_slot)

		log_msg(
			lane.capitalize()
			+ " lane kamikaze clash: "
			+ attacker_label
			+ " "
			+ attacker_card.card_name
			+ " and "
			+ defender_label
			+ " "
			+ defender_card.card_name
			+ " destroyed each other."
		)

		return

	if attacker_card.ap > defender_card.ap:
		if not player_is_attacker:
			parry_system.begin(lane, _attacker_slot, attacker_card, defender_slot, defender_card)
			return

		await resolve_ai_parry_attempt(attacker_card, defender_slot, defender_card)
		return

	# The attacker knowingly chose to fight into a stronger unit.
	# Voluntary lower-AP attacks are suicide and do not open the Parry Chain.
	send_slot_card_to_discard(_attacker_slot)
	log_msg(
		"Suicide attack: "
		+ attacker_label
		+ " "
		+ attacker_card.card_name
		+ " AP "
		+ str(attacker_card.ap)
		+ " attacked into "
		+ defender_label
		+ " "
		+ defender_card.card_name
		+ " AP "
		+ str(defender_card.ap)
		+ " and was destroyed."
	)

	var defender_score_owner: String = "ai" if player_is_attacker else "player"
	add_aurion(defender_score_owner, get_unit_defeat_aurion_reward(attacker_card), "Destroyed " + attacker_card.card_name + " after it knowingly attacked a higher-AP unit.")
	return


func resolve_ai_parry_attempt(attacker_card: CardData, defender_slot: Node, defender_card: CardData) -> void:
	var required: int = maxi(attacker_card.ap - defender_card.ap, 1)
	var available_dp := 0
	for hand_card in ai_hand:
		if hand_card != null:
			available_dp += maxi(hand_card.dp, 0)
	if available_dp < required:
		send_slot_card_to_discard(defender_slot)
		log_msg("Opponent could not parry. " + defender_card.card_name + " was destroyed.")
		add_aurion("player", get_unit_defeat_aurion_reward(defender_card), "Destroyed " + defender_card.card_name + " in combat.")
		return

	log_msg("Opponent opens a Parry and needs " + str(required) + " DP.")
	var gathered := 0
	var parry_target := get_enemy_visual_target("EnemyParryPitVisual")
	while gathered < required:
		var remaining := required - gathered
		var hand_index := find_ai_parry_card_index(remaining)
		if hand_index < 0:
			break
		var sacrifice: CardData = ai_hand[hand_index]
		await play_enemy_hand_to_node_animation(sacrifice, parry_target, false)
		ai_hand.pop_at(hand_index)
		ai_discard.append(sacrifice)
		gathered += maxi(sacrifice.dp, 0)
		if opponent_visuals != null and opponent_visuals.has_method("add_parry_card"):
			opponent_visuals.add_parry_card(sacrifice)
		update_ai_visuals()
		log_msg("Opponent parries with " + sacrifice.card_name + " for " + str(maxi(sacrifice.dp, 0)) + " DP.")
		await get_tree().create_timer(0.28).timeout

	if gathered >= required:
		log_msg("Opponent Parry succeeds. " + defender_card.card_name + " survives.")
	else:
		send_slot_card_to_discard(defender_slot)
		log_msg("Opponent Parry fails. " + defender_card.card_name + " was destroyed.")
		add_aurion("player", get_unit_defeat_aurion_reward(defender_card), "Destroyed " + defender_card.card_name + " in combat.")
	await get_tree().create_timer(0.55).timeout
	if opponent_visuals != null and opponent_visuals.has_method("clear_parry_cards"):
		opponent_visuals.clear_parry_cards()


func find_ai_parry_card_index(remaining_dp: int) -> int:
	var exact_or_smallest := -1
	var exact_or_smallest_dp := 1_000_000
	var largest := -1
	var largest_dp := -1
	for index in range(ai_hand.size()):
		var card_data: CardData = ai_hand[index]
		if card_data == null or card_data.dp <= 0:
			continue
		if card_data.dp >= remaining_dp and card_data.dp < exact_or_smallest_dp:
			exact_or_smallest = index
			exact_or_smallest_dp = card_data.dp
		if card_data.dp > largest_dp:
			largest = index
			largest_dp = card_data.dp
	return exact_or_smallest if exact_or_smallest >= 0 else largest


func get_slot_card_data(slot: Node) -> CardData:
	if slot == null:
		return null

	if slot.has_method("get_placed_card_data"):
		return slot.get_placed_card_data()

	return null


func find_slot_by_owner_row_lane(owner_name: String, row: String, lane: String) -> Node:
	if board_slots == null:
		return null

	for slot in board_slots.get_children():
		if String(slot.get_meta("owner", "")) == owner_name and String(slot.get_meta("row", "")) == row and get_slot_lane(slot) == lane:
			return slot

	return null


func lane_has_front_unit(owner_name: String, lane: String) -> bool:
	var slot: Node = find_slot_by_owner_row_lane(owner_name, "front", lane)
	var card_data: CardData = get_slot_card_data(slot)
	return is_unit_card(card_data)


func lane_has_any_front_unit(lane: String) -> bool:
	return lane_has_front_unit("player", lane) or lane_has_front_unit("enemy", lane)


func get_slot_lane(slot: Node) -> String:
	if slot == null:
		return ""

	var slot_id: String = String(slot.get_meta("slot_id", "")).to_lower()

	if slot_id.contains("left"):
		return "left"

	if slot_id.contains("middle"):
		return "middle"

	if slot_id.contains("right"):
		return "right"

	var column: String = String(slot.get_meta("column", "")).to_lower()

	if column == "left" or column == "middle" or column == "right":
		return column

	return ""


func promote_slot_unit_preserving_equipment(slot: Node, new_unit: CardData, slot_owner: String) -> bool:
	if slot == null or new_unit == null:
		return false

	var old_unit: CardData = get_slot_card_data(slot)
	var equipment_cards: Array[CardData] = []

	if slot.has_method("get_equipment_cards"):
		var raw_equipment_cards: Array = slot.get_equipment_cards()

		for equipment_card in raw_equipment_cards:
			if equipment_card == null:
				continue

			equipment_cards.append(equipment_card as CardData)

	if old_unit != null:
		play_card_to_discard_animation(old_unit, slot, slot_owner)

		if slot_owner == "enemy":
			ai_discard.append(old_unit)
		elif discard_pile != null:
			discard_pile.add_card(old_unit)

	if slot.has_method("clear_slot"):
		slot.clear_slot()

	if not slot.has_method("place_card"):
		return false

	var placed_successfully: bool = slot.place_card(TEST_CARD_SCENE, new_unit, false)

	if not placed_successfully:
		update_ai_visuals()
		return false

	for equipment_card in equipment_cards:
		if equipment_card == null:
			continue

		if not slot.has_method("attach_equipment"):
			continue

		if slot.has_method("can_attach_equipment") and not slot.can_attach_equipment():
			continue

		slot.attach_equipment(TEST_CARD_SCENE, equipment_card)

	update_ai_visuals()
	return true


func send_slot_card_to_discard(slot: Node) -> void:
	if slot == null:
		return

	var slot_owner: String = String(slot.get_meta("owner", ""))
	var card_data: CardData = get_slot_card_data(slot)

	if card_data != null:
		play_card_to_discard_animation(card_data, slot, slot_owner)

		if slot_owner == "enemy":
			ai_discard.append(card_data)
		elif discard_pile != null:
			discard_pile.add_card(card_data)

	if slot.has_method("get_equipment_cards"):
		var equipment_cards: Array = slot.get_equipment_cards()

		for equipment_card in equipment_cards:
			if equipment_card == null:
				continue

			play_card_to_discard_animation(equipment_card, slot, slot_owner)

			if slot_owner == "enemy":
				ai_discard.append(equipment_card)
			elif discard_pile != null:
				discard_pile.add_card(equipment_card)

	if slot.has_method("clear_slot"):
		slot.clear_slot()

	update_ai_visuals()


func get_3d_node_under_screen_position(screen_position: Vector2) -> Node:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	return result.get("collider", null)


func find_board_slot_from_node(node: Node) -> Node:
	var current := node
	while current != null:
		if current.has_method("place_card") and current.has_meta("slot_id"):
			return current
		current = current.get_parent()
	return null


func is_node_inside_target(node: Node, target: Node) -> bool:
	if node == null or target == null:
		return false
	var current := node
	while current != null:
		if current == target:
			return true
		current = current.get_parent()
	return false


func _on_tribute_changed(_status_text: String) -> void:
	update_tribute_counter()
	try_auto_advance_tribute_phase()


func try_auto_advance_tribute_phase() -> void:
	if current_phase != BattlePhase.TRIBUTE:
		return
	if tribute_manager == null or not tribute_manager.tribute_card_used_this_turn:
		return
	if not ai_tribute_finished_this_turn:
		return
	set_phase(BattlePhase.DEPLOYMENT)


func update_tribute_counter() -> void:
	if tribute_pile == null or tribute_manager == null:
		return
	if tribute_pile.has_method("set_status_text"):
		tribute_pile.set_status_text(tribute_manager.get_counter_text())


func create_debug_tp_button() -> void:
	if get_node_or_null("UI/DebugAddTPButton") != null:
		return

	var button := Button.new()
	button.name = "DebugAddTPButton"
	button.text = "+1 TP"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(120, 44)

	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 0.0
	button.anchor_bottom = 0.0

	button.offset_left = -150.0
	button.offset_right = -20.0

	# Moved lower so it does not overlap the Player Status panel.
	button.offset_top = 265.0
	button.offset_bottom = 309.0

	button.pressed.connect(_on_debug_add_tp_pressed)
	$UI.add_child(button)


func _on_debug_add_tp_pressed() -> void:
	if tribute_manager == null:
		return
	tribute_manager.add_debug_tribute_points(1)
	update_tribute_counter()
	log_msg("Debug added +1 TP. " + tribute_manager.get_status_text())


func log_msg(message: String) -> void:
	if game_log != null and game_log.has_method("add_log"):
		game_log.add_log(message)
	else:
		print("LOG FALLBACK: " + message)

	update_phase_instruction_ui()


func get_battle_plan_key(plan: Dictionary) -> String:
	if plan.is_empty():
		return ""

	if plan.has("id"):
		return str(plan.get("id", "")).strip_edges()

	if plan.has("battle_plan_id"):
		return str(plan.get("battle_plan_id", "")).strip_edges()

	if plan.has("plan_id"):
		return str(plan.get("plan_id", "")).strip_edges()

	return str(plan.get("name", "Unknown Battle Plan")).strip_edges()


func is_battle_plan_used(plan: Dictionary) -> bool:
	var key: String = get_battle_plan_key(plan)

	if key == "":
		return false

	return used_battle_plan_keys.has(key)


func mark_battle_plan_used(plan: Dictionary) -> void:
	var key: String = get_battle_plan_key(plan)

	if key == "":
		return

	used_battle_plan_keys[key] = true


func get_unused_battle_plan_choices(amount: int) -> Array[Dictionary]:
	var final_choices: Array[Dictionary] = []

	if battle_plan_manager == null:
		return final_choices

	if amount <= 0:
		return final_choices

	var resource_choices: Array[Dictionary] = []
	var fallback_choices: Array[Dictionary] = []
	for plan in battle_plan_manager.get_all_battle_plans():
		var key := get_battle_plan_key(plan)
		if key.is_empty() or used_battle_plan_keys.has(key):
			continue
		if plan.get("card_art", null) is Texture2D:
			resource_choices.append(plan)
		else:
			fallback_choices.append(plan)

	resource_choices.shuffle()
	fallback_choices.shuffle()
	resource_choices.append_array(fallback_choices)
	for plan in resource_choices:
		final_choices.append(plan)
		if final_choices.size() >= amount:
			break

	return final_choices


func update_ai_visuals() -> void:
	if opponent_visuals == null:
		return

	if opponent_visuals.has_method("set_all_card_data"):
		opponent_visuals.set_all_card_data(
			ai_deck.size(),
			ai_hand.size(),
			ai_tribute,
			ai_discard
		)


func play_player_hand_to_node_animation(card_data: CardData, target_node: Node, face_down: bool = false) -> void:
	if card_animation_manager == null:
		return
	var start_position := last_player_hand_animation_start
	if not has_player_hand_animation_start and player_hand_3d != null:
		start_position = player_hand_3d.get_card_position_for_data(card_data)
	if has_player_hand_animation_start or start_position != Vector3.ZERO:
		has_player_hand_animation_start = false
		await card_animation_manager.animate_card_from_position_to_node(
			card_data,
			start_position,
			target_node,
			face_down
		)
		return
	await card_animation_manager.animate_card_from_anchor_to_node(
		card_data,
		"PlayerHandOrigin",
		target_node,
		face_down
	)


func play_enemy_hand_to_node_animation(card_data: CardData, target_node: Node, face_down: bool = false) -> void:
	if card_animation_manager == null:
		return
	var hand_index := ai_hand.find(card_data)
	if opponent_visuals != null and hand_index >= 0:
		var start_position := opponent_visuals.get_hand_card_global_position(hand_index)
		if start_position != Vector3.ZERO:
			opponent_visuals.set_hand_card_action_hidden(hand_index, true)
			await card_animation_manager.animate_card_from_position_to_node(
				card_data,
				start_position,
				target_node,
				face_down
			)
			opponent_visuals.set_hand_card_action_hidden(hand_index, false)
			return
	await card_animation_manager.animate_card_from_anchor_to_node(
		card_data,
		"EnemyHandOrigin",
		target_node,
		face_down
	)


func play_card_to_discard_animation(card_data: CardData, source_node: Node, slot_owner: String) -> void:
	if card_animation_manager == null:
		return

	var target_node: Node = discard_pile

	if slot_owner == "enemy":
		target_node = get_enemy_visual_target("EnemyDiscardPileVisual")

	card_animation_manager.animate_card_between_nodes(
		card_data,
		source_node,
		target_node,
		false
	)


func get_enemy_visual_target(node_name: String) -> Node:
	if opponent_visuals == null:
		return null

	return opponent_visuals.get_node_or_null(node_name)


func create_aurion_counter_ui() -> void:
	# Aurion is now displayed inside the combined PhasePanel.
	# Keep this function so _ready() can still call it safely.
	if aurion_label != null:
		update_aurion_counter_ui()


func update_aurion_counter_ui() -> void:
	if aurion_label == null:
		return

	aurion_label.text = (
		"Aurion  |  Player "
		+ str(player_aurion_points)
		+ "/"
		+ str(AURION_WIN_TARGET)
		+ "    AI "
		+ str(ai_aurion_points)
		+ "/"
		+ str(AURION_WIN_TARGET)
	)
	refresh_bottom_hud()


func add_aurion(scoring_owner: String, amount: int, reason: String = "") -> void:
	if amount <= 0:
		return

	var clean_owner: String = scoring_owner.to_lower().strip_edges()

	if clean_owner == "player":
		player_aurion_points += amount
		log_msg("Player gains +" + str(amount) + " Aurion. " + reason)

	elif clean_owner == "ai" or clean_owner == "enemy" or clean_owner == "opponent":
		ai_aurion_points += amount
		log_msg("AI gains +" + str(amount) + " Aurion. " + reason)

	else:
		log_msg("Unknown Aurion owner: " + scoring_owner)
		return

	update_aurion_counter_ui()
	check_aurion_victory()


func get_unit_defeat_aurion_reward(card_data: CardData) -> int:
	return CardRules.get_defeat_aurion_reward(card_data)


func check_aurion_victory() -> void:
	if game_over:
		return
	if player_aurion_points >= AURION_WIN_TARGET:
		log_msg("Player has reached " + str(AURION_WIN_TARGET) + " Aurion.")
		show_game_result(true)
		return

	if ai_aurion_points >= AURION_WIN_TARGET:
		log_msg("AI has reached " + str(AURION_WIN_TARGET) + " Aurion.")
		show_game_result(false)


func show_game_result(player_won: bool) -> void:
	if game_result_overlay != null:
		return
	game_over = true
	cancel_selected_card()
	if battle_plan_selection_screen != null:
		battle_plan_selection_screen.visible = false
	if deck_selection_screen != null:
		deck_selection_screen.visible = false
	if spell_choice_panel != null:
		spell_choice_panel.visible = false
	if board_action_menu != null:
		board_action_menu.hide()

	game_result_overlay = Control.new()
	game_result_overlay.name = "GameResultOverlay"
	game_result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	game_result_overlay.z_index = 500
	$UI.add_child(game_result_overlay)
	game_result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$UI.move_child(game_result_overlay, $UI.get_child_count() - 1)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.005, 0.002, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_result_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260.0
	panel.offset_right = 260.0
	panel.offset_top = -155.0
	panel.offset_bottom = 155.0
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.z_index = 1
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.025, 0.012, 0.98)
	panel_style.border_color = Color(0.92, 0.68, 0.18, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(14)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.75)
	panel_style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	game_result_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)

	var title := Label.new()
	title.text = "VICTORY" if player_won else "DEFEAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(1.0, 0.80, 0.27, 1.0) if player_won else Color(0.86, 0.25, 0.18, 1.0))
	content.add_child(title)

	var summary := Label.new()
	summary.text = "You reached 25 Aurion." if player_won else "Your opponent reached 25 Aurion."
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 19)
	summary.add_theme_color_override("font_color", Color(0.92, 0.86, 0.72, 1.0))
	content.add_child(summary)

	var menu_button := Button.new()
	menu_button.text = "RETURN TO MENU"
	menu_button.custom_minimum_size = Vector2(270, 48)
	menu_button.focus_mode = Control.FOCUS_NONE
	menu_button.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	menu_button.z_index = 2
	menu_button.pressed.connect(_return_to_menu_from_result)
	content.add_child(menu_button)


func _return_to_menu_from_result() -> void:
	Cursors.use_normal()
	var tree := get_tree()
	if tree != null:
		tree.change_scene_to_file(MENU_SCENE_PATH)


func disable_keyboard_focus_for_all_buttons(root: Node) -> void:
	if root == null:
		return

	if root is Button:
		var button := root as Button
		button.focus_mode = Control.FOCUS_NONE

	for child in root.get_children():
		disable_keyboard_focus_for_all_buttons(child)


func toggle_global_ability_icons() -> void:
	global_ability_icons_visible = !global_ability_icons_visible
	set_global_ability_icons_visible(global_ability_icons_visible)


func set_global_ability_icons_visible(show_icons: bool) -> void:
	if hand != null and hand.has_method("set_all_ability_icons_visible"):
		hand.set_all_ability_icons_visible(show_icons)

	set_battlefield_ability_icons_visible(show_icons)


func set_battlefield_ability_icons_visible(show_icons: bool) -> void:
	if board_slots == null:
		return

	for slot in board_slots.get_children():
		if slot == null:
			continue

		if slot.has_method("set_slot_ability_icons_visible"):
			slot.set_slot_ability_icons_visible(show_icons)


func refresh_player_usable_ability_icons() -> void:
	if board_slots == null:
		return

	for slot in board_slots.get_children():
		if slot == null:
			continue

		var usable_ids: Array[StringName] = []
		var card_data := get_slot_card_data(slot)
		var is_player_slot := String(slot.get_meta("owner", "")) == "player"
		var is_face_down := bool(slot.get_meta("face_down", false))

		if is_player_slot and card_data != null and not is_face_down and not phase_transition_busy:
			for ability in card_data.get_abilities():
				if ability == null:
					continue
				if ability.category.to_lower() != "insight" or ability.trigger != "active":
					continue
				if can_activate_insight_ability(slot, ability):
					usable_ids.append(ability.ability_id)

		if slot.has_method("set_slot_usable_ability_ids"):
			slot.set_slot_usable_ability_ids(usable_ids)

		connect_card_ability_icon_signals(slot)


func connect_card_ability_icon_signals(slot: Node) -> void:
	if slot == null or not slot.has_method("get_placed_card_visual"):
		return
	var visual := slot.call("get_placed_card_visual") as Node
	if visual == null:
		return
	if visual.has_signal("ability_icon_pressed"):
		var pressed_callable := Callable(self, "_on_card_ability_icon_pressed").bind(slot)
		if not visual.is_connected("ability_icon_pressed", pressed_callable):
			visual.connect("ability_icon_pressed", pressed_callable)
	if visual.has_signal("ability_icon_hovered"):
		var hovered_callable := Callable(self, "_on_card_ability_icon_hovered").bind(slot)
		if not visual.is_connected("ability_icon_hovered", hovered_callable):
			visual.connect("ability_icon_hovered", hovered_callable)


func _on_card_ability_icon_pressed(_card_visual: Node, ability: AbilityData, slot: Node) -> void:
	await activate_insight_ability_from_slot(slot, ability)


func _on_card_ability_icon_hovered(_card_visual: Node, ability: AbilityData, _slot: Node) -> void:
	if ability != null:
		log_msg(ability.ability_name + ": " + ability.rules_text)


func create_spell_choice_panel() -> void:
	if spell_choice_panel != null:
		return

	spell_choice_panel = PanelContainer.new()
	spell_choice_panel.name = "SpellChoicePanel"
	spell_choice_panel.visible = false
	spell_choice_panel.anchor_left = 0.5
	spell_choice_panel.anchor_right = 0.5
	spell_choice_panel.anchor_top = 0.5
	spell_choice_panel.anchor_bottom = 0.5
	spell_choice_panel.offset_left = -180.0
	spell_choice_panel.offset_right = 180.0
	spell_choice_panel.offset_top = -90.0
	spell_choice_panel.offset_bottom = 90.0
	spell_choice_panel.z_index = 80

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.015, 0.94)
	style.border_color = Color(0.9, 0.72, 0.32, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	spell_choice_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	spell_choice_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	spell_choice_label = Label.new()
	spell_choice_label.text = "Place spell as:"
	spell_choice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spell_choice_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(spell_choice_label)

	var face_up_button := Button.new()
	face_up_button.text = "Face Up"
	face_up_button.focus_mode = Control.FOCUS_NONE
	face_up_button.pressed.connect(_on_spell_face_up_pressed)
	vbox.add_child(face_up_button)

	var face_down_button := Button.new()
	face_down_button.text = "Face Down"
	face_down_button.focus_mode = Control.FOCUS_NONE
	face_down_button.pressed.connect(_on_spell_face_down_pressed)
	vbox.add_child(face_down_button)

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(_on_spell_choice_cancel_pressed)
	vbox.add_child(cancel_button)

	$UI.add_child(spell_choice_panel)


func advance_combat_lane_after_resolution() -> void:
	clear_active_combat_lane_highlight()
	combat_next_lane_index += 1
	player_passed_current_lane = false
	ai_passed_current_lane = false

	if current_phase != BattlePhase.COMBAT:
		return

	if parry_system.active:
		return

	await skip_empty_combat_lanes_with_pause()

	if combat_next_lane_index >= combat_lane_order.size():
		combat_priority_owner = ""
		log_msg("All combat lanes resolved. Starting the next round.")
		return

	reset_priority_for_current_lane()
	var next_lane: String = combat_lane_order[combat_next_lane_index]
	set_active_combat_lane_highlight(next_lane)

	if combat_priority_owner == "ai":
		log_msg("Next lane: " + next_lane + ". Initiative returns to AI.")
		await resolve_ai_current_priority_lane(next_lane)
	else:
		set_lane_priority_to_player(next_lane, "Next lane: " + next_lane + ". Initiative returns to Player.")

func skip_empty_combat_lanes_with_pause() -> void:
	while current_phase == BattlePhase.COMBAT and combat_next_lane_index < combat_lane_order.size():
		var lane: String = combat_lane_order[combat_next_lane_index]

		if lane_has_any_front_unit(lane):
			return

		set_active_combat_lane_highlight(lane)
		log_msg(lane.capitalize() + " lane has no front-row units on either side. Skipping after a short pause.")
		await get_tree().create_timer(COMBAT_LANE_START_DELAY).timeout
		clear_active_combat_lane_highlight()
		combat_next_lane_index += 1


func show_spell_choice_panel(card_ui: CardUI, slot: Node) -> void:
	pending_spell_card_ui = card_ui
	pending_spell_slot = slot

	if spell_choice_panel == null:
		create_spell_choice_panel()

	if spell_choice_label != null and selected_card_data != null:
		var face_up_cost: int = selected_card_data.tribute_cost
		var face_down_cost: int = get_player_next_face_down_card_setup_cost()
		spell_choice_label.text = (
			"Place "
			+ selected_card_data.card_name
			+ " as:\nFace Up: "
			+ str(face_up_cost)
			+ " TP | Face Down Shadowtax: "
			+ str(face_down_cost)
			+ " TP"
		)

	spell_choice_panel.visible = true


func hide_spell_choice_panel() -> void:
	if spell_choice_panel != null:
		spell_choice_panel.visible = false

	pending_spell_card_ui = null
	pending_spell_slot = null


func _on_spell_face_up_pressed() -> void:
	confirm_pending_spell_placement(false)


func _on_spell_face_down_pressed() -> void:
	confirm_pending_spell_placement(true)


func _on_spell_choice_cancel_pressed() -> void:
	if pending_spell_card_ui != null:
		return_card_to_hand_safely(pending_spell_card_ui)

	hide_spell_choice_panel()
	cancel_selected_card()


func get_clean_card_type(card_data: CardData) -> String:
	return CardRules.get_clean_card_type(card_data)


func is_gambit_card(card_data: CardData) -> bool:
	return CardRules.is_gambit_card(card_data)


# Legacy wrapper: older code still calls this for the old spell-like bucket.


func is_equipment_card(card_data: CardData) -> bool:
	return CardRules.is_equipment_card(card_data)


func is_trap_card(_card_data: CardData) -> bool:
	return CardRules.is_trap_card(_card_data)


func is_ruse_card(_card_data: CardData) -> bool:
	return CardRules.is_ruse_card(_card_data)


func is_event_card(_card_data: CardData) -> bool:
	return CardRules.is_event_card(_card_data)


func is_spell_card(card_data: CardData) -> bool:
	return CardRules.is_spell_card(card_data)


func get_face_down_card_setup_cost(count_already_set_this_round: int) -> int:
	return CardRules.get_face_down_card_setup_cost(count_already_set_this_round)


func get_player_next_face_down_card_setup_cost() -> int:
	return get_face_down_card_setup_cost(player_face_down_gambits_this_round)


func get_ai_next_face_down_card_setup_cost() -> int:
	return get_face_down_card_setup_cost(ai_face_down_gambits_this_round)


func get_player_face_down_card_deployment_cost(card_data: CardData, place_face_down: bool) -> int:
	if card_data == null:
		return 0

	if place_face_down:
		return get_player_next_face_down_card_setup_cost()

	return card_data.tribute_cost


func get_ai_face_down_card_deployment_cost(card_data: CardData, place_face_down: bool) -> int:
	if card_data == null:
		return 0

	if place_face_down:
		return get_ai_next_face_down_card_setup_cost()

	return card_data.tribute_cost


# Legacy wrappers kept so older code still works.
func get_face_down_gambit_setup_cost(count_already_set_this_round: int) -> int:
	return get_face_down_card_setup_cost(count_already_set_this_round)


func get_player_gambit_deployment_cost(card_data: CardData, place_face_down: bool) -> int:
	return get_player_face_down_card_deployment_cost(card_data, place_face_down)


func get_ai_gambit_deployment_cost(card_data: CardData, place_face_down: bool) -> int:
	return get_ai_face_down_card_deployment_cost(card_data, place_face_down)


func reset_face_down_gambit_setup_counters() -> void:
	player_face_down_gambits_this_round = 0
	ai_face_down_gambits_this_round = 0


func return_card_to_hand_safely(card: CardUI) -> void:
	if hand == null:
		return

	if card != null and is_instance_valid(card):
		card.mouse_is_pressed = false
		card.is_dragging = false
		card.set_process(false)

	if hand.has_method("return_dragged_card_to_hand"):
		hand.return_dragged_card_to_hand(card)
	if player_hand_3d != null:
		player_hand_3d.restore_card(
			card,
			last_player_hand_animation_start,
			has_player_hand_animation_start
		)
	has_player_hand_animation_start = false


func is_unit_card(card_data: CardData) -> bool:
	return CardRules.is_unit_card(card_data)


func try_attach_selected_equipment_to_slot(slot: Node) -> bool:
	if slot == null:
		return false

	if selected_card_data == null:
		return false

	if not is_equipment_card(selected_card_data):
		return false

	if not player_card_passes_faction_gate(selected_card_data, true):
		return false

	if String(slot.get_meta("owner", "")) != "player":
		log_msg("Equipment can only be attached to your units.")
		return false

	if not bool(slot.get_meta("occupied", false)):
		log_msg("Equipment cannot be placed alone. Attach it to an existing unit.")
		return false

	if bool(slot.get_meta("face_down", false)):
		log_msg("Equipment cannot be attached to a face-down card.")
		return false
	
	var existing_card: CardData = get_slot_card_data(slot)

	if not is_unit_card(existing_card):
		log_msg("Equipment can only be attached to a unit.")
		return false

	if not slot.has_method("can_attach_equipment") or not slot.can_attach_equipment():
		log_msg("This unit already has the maximum 2 equipment cards.")
		return false

	if not tribute_manager.can_afford(selected_card_data.tribute_cost):
		log_msg("Not enough Tribute Points. Need " + str(selected_card_data.tribute_cost) + ", have " + str(tribute_manager.current_tribute_points) + ".")
		return false

	if not slot.has_method("attach_equipment"):
		log_msg("This slot does not support equipment attachment.")
		return false

	var attached: bool = slot.attach_equipment(TEST_CARD_SCENE, selected_card_data)

	if attached:
		tribute_manager.spend_tribute(selected_card_data.tribute_cost)
		log_msg("Attached " + selected_card_data.card_name + " to " + existing_card.card_name + ".")
		log_msg("Spent " + str(selected_card_data.tribute_cost) + " TP. " + tribute_manager.get_status_text())
		handle_card_deployed(selected_card_data)
		return true

	return false


func confirm_pending_spell_placement(place_face_down: bool) -> void:
	if pending_spell_slot == null:
		hide_spell_choice_panel()
		cancel_selected_card()
		return

	if selected_card_data == null:
		hide_spell_choice_panel()
		cancel_selected_card()
		return

	if not is_gambit_card(selected_card_data):
		hide_spell_choice_panel()
		cancel_selected_card()
		return

	if not place_face_down:
		if not player_card_passes_faction_gate(selected_card_data, true):
			hide_spell_choice_panel()
			cancel_selected_card()
			return

	if current_phase != BattlePhase.DEPLOYMENT:
		log_msg("Spells can only be placed during the Deployment Phase.")
		hide_spell_choice_panel()
		cancel_selected_card()
		return

	if String(pending_spell_slot.get_meta("owner", "")) != "player":
		log_msg("Spells can only be placed on your side of the board.")
		hide_spell_choice_panel()
		cancel_selected_card()
		return

	if String(pending_spell_slot.get_meta("row", "")) != "back":
		log_msg("Only back-row spells can be placed face down.")
		hide_spell_choice_panel()
		cancel_selected_card()
		return

	if bool(pending_spell_slot.get_meta("occupied", false)):
		log_msg("That slot is already occupied.")
		hide_spell_choice_panel()
		cancel_selected_card()
		return

	if not player_card_passes_faction_gate(selected_card_data):
		log_msg("Faction Gate locked for " + selected_card_data.card_name + ".")
		hide_spell_choice_panel()
		cancel_selected_card()
		return

	var deployment_cost: int = get_player_face_down_card_deployment_cost(selected_card_data, place_face_down)

	if not tribute_manager.can_afford(deployment_cost):
		var cost_reason: String = "face-down setup cost" if place_face_down else "printed cost"
		log_msg("Not enough Tribute Points. Need " + str(deployment_cost) + " TP for " + cost_reason + ", have " + str(tribute_manager.current_tribute_points) + ".")
		hide_spell_choice_panel()
		cancel_selected_card()
		return

	var spell_card_data: CardData = selected_card_data
	var spell_slot: Node = pending_spell_slot
	var spell_card_ui: CardUI = pending_spell_card_ui

	if spell_card_ui != null and is_instance_valid(spell_card_ui):
		spell_card_ui.visible = false

	hide_spell_choice_panel()

	await play_player_hand_to_node_animation(spell_card_data, spell_slot, place_face_down)

	var placed: bool = spell_slot.place_card(TEST_CARD_SCENE, spell_card_data, place_face_down)

	if placed:
		tribute_manager.spend_tribute(deployment_cost)

		if place_face_down:
			player_face_down_gambits_this_round += 1

		var visibility_text: String = "face down" if place_face_down else "face up"
		var cost_text: String = "setup cost" if place_face_down else "printed cost"
		log_msg("Placed Gambit " + spell_card_data.card_name + " " + visibility_text + ".")
		log_msg("Spent " + str(deployment_cost) + " TP " + cost_text + ". " + tribute_manager.get_status_text())

		if spell_card_ui != null and hand != null:
			hand.consume_dragged_card(spell_card_ui)
		elif hand != null:
			hand.remove_selected_card()

		handle_card_deployed(spell_card_data)
	else:
		if spell_card_ui != null and is_instance_valid(spell_card_ui):
			spell_card_ui.visible = true

		if spell_card_ui != null:
			return_card_to_hand_safely(spell_card_ui)

	cancel_selected_card()


func resolve_dominance_before_cleanup() -> void:
	if current_phase != BattlePhase.COMBAT:
		return

	var checked_lanes: Array[String] = ["left", "right"]
	var player_has_dominance: bool = false
	var ai_has_dominance: bool = false

	for lane in checked_lanes:
		var player_ap: int = get_front_lane_ap_total("player", lane)
		var ai_ap: int = get_front_lane_ap_total("enemy", lane)

		if player_ap > ai_ap:
			player_has_dominance = true
			log_msg(lane.capitalize() + " lane Dominance: Player AP " + str(player_ap) + " vs AI AP " + str(ai_ap) + ".")
		elif ai_ap > player_ap:
			ai_has_dominance = true
			log_msg(lane.capitalize() + " lane Dominance: AI AP " + str(ai_ap) + " vs Player AP " + str(player_ap) + ".")
		else:
			log_msg(lane.capitalize() + " lane Dominance: tied at " + str(player_ap) + " AP. No Aurion gained.")

	if player_has_dominance:
		add_aurion("player", 1, "Dominance: controlled at least one side lane this turn.")

	if ai_has_dominance:
		add_aurion("ai", 1, "Dominance: controlled at least one side lane this turn.")

	if player_has_dominance or ai_has_dominance:
		log_msg("Dominance resolved. Each side can gain at most +1 Aurion from Dominance this turn.")
	else:
		log_msg("Dominance resolved. No side-lane advantage gained.")


func get_front_lane_ap_total(owner_name: String, lane: String) -> int:
	var slot: Node = find_slot_by_owner_row_lane(owner_name, "front", lane)
	var card_data: CardData = get_slot_card_data(slot)

	if not is_unit_card(card_data):
		return 0

	return max(0, card_data.ap)


func cleanup_battlefield_spells() -> void:
	cleanup_phase_one_board_cards()


func cleanup_face_up_gambits_before_combat() -> void:
	if board_slots == null:
		return

	var discarded_count: int = 0

	for slot in board_slots.get_children():
		var card_data: CardData = get_slot_card_data(slot)

		if card_data == null:
			continue

		if not is_gambit_card(card_data):
			continue

		var is_face_down: bool = bool(slot.get_meta("face_down", false))

		if is_face_down:
			continue

		var slot_owner: String = String(slot.get_meta("owner", ""))
		discard_slot_card_for_cleanup(slot, card_data, slot_owner)
		discarded_count += 1

	if discarded_count > 0:
		log_msg("Combat setup: removed " + str(discarded_count) + " face-up Gambit card(s) from the battlefield.")

	update_ai_visuals()


func setup_ai_deck() -> void:
	ai_deck.clear()
	ai_hand.clear()
	ai_discard.clear()
	ai_tribute.clear()

	ai_perm_tp = 0
	ai_current_perm_tp = 0
	ai_temp_tp = 0
	ai_current_tp = 0
	ai_tribute_used_this_turn = false

	var pool: Array[CardData] = CardDatabase.get_ai_test_deck()

	for i in range(40):
		ai_deck.append(pool[i % pool.size()])

	ai_deck.shuffle()
	update_ai_visuals()


func ai_draw_cards(amount: int) -> void:
	for i in range(amount):
		if ai_deck.is_empty():
			return

		var drawn_card: CardData = ai_deck.pop_back()

		if drawn_card != null:
			ai_hand.append(drawn_card)
		update_ai_visuals()


func ai_start_tribute_phase() -> void:
	ai_current_perm_tp = ai_perm_tp
	ai_temp_tp = 0
	ai_current_tp = ai_current_perm_tp
	ai_tribute_used_this_turn = false
	ai_tribute_finished_this_turn = false

	if next_phase_button != null:
		next_phase_button.disabled = true

	await ai_offer_one_card_to_tribute()
	ai_tribute_finished_this_turn = true

	if next_phase_button != null:
		next_phase_button.disabled = false

	try_auto_advance_tribute_phase()


func ai_offer_one_card_to_tribute() -> void:
	if ai_tribute_used_this_turn:
		return

	if ai_hand.is_empty():
		log_msg("AI has no cards to offer as Tribute.")
		return

	var tribute_index: int = ai_choose_tribute_card_index()

	if tribute_index < 0:
		log_msg("AI found no valid Tribute card.")
		return

	var tribute_card: CardData = ai_hand[tribute_index]

	if tribute_card == null:
		return

	await play_enemy_hand_to_node_animation(
		tribute_card,
		get_enemy_visual_target("EnemyTributePileVisual"),
		false
	)

	ai_hand.pop_at(tribute_index)
	ai_tribute.append(tribute_card)
	ai_tribute_used_this_turn = true

	var card_type: String = get_clean_card_type(tribute_card)

	if card_type == "gambit":
		ai_temp_tp += 2
		ai_current_tp += 2
		log_msg("AI offered " + tribute_card.card_name + " for +2 temporary TP.")
	else:
		ai_perm_tp += 1
		ai_current_perm_tp += 1
		ai_current_tp += 1
		log_msg("AI offered " + tribute_card.card_name + " for +1 permanent TP.")

	log_msg("AI TP: " + str(ai_current_tp) + "/" + str(ai_perm_tp) + " Temp +" + str(ai_temp_tp))
	update_ai_visuals()


func ai_choose_tribute_card_index() -> int:
	# Prefer unit/equipment for permanent TP.
	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if card_data == null:
			continue

		var card_type: String = get_clean_card_type(card_data)

		if card_type == "unit" or card_type == "equipment":
			return i

	# If no permanent option exists, use a gambit for temporary TP.
	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if is_gambit_card(card_data):
			return i

	return -1


func ai_take_combat_initiative() -> void:
	var start_lane: String = ai_choose_combat_start_lane()

	if start_lane == "right":
		set_combat_lane_order_from_right()
	else:
		set_combat_lane_order_from_left()

	original_combat_priority_owner = "ai"
	reset_priority_for_current_lane()
	set_active_combat_lane_highlight(current_combat_lane())

	log_msg("AI chooses combat direction from the " + start_lane + " lane.")
	await ai_resolve_combat_sequence()

func ai_should_attack_this_combat() -> bool:
	var ai_units: int = ai_count_front_units("enemy")
	var player_units: int = ai_count_front_units("player")

	if ai_units <= 0:
		return false

	if player_units <= 0:
		return true

	var ai_total_ap: int = ai_get_total_front_ap("enemy")
	var player_total_ap: int = ai_get_total_front_ap("player")

	# If AI is clearly stronger, attack.
	if ai_total_ap >= player_total_ap:
		return true

	# If AI is weaker, it can still attack sometimes.
	return (randi() % 100) < 35


func ai_choose_combat_start_lane() -> String:
	var left_score: int = ai_score_combat_direction(["left", "middle", "right"])
	var right_score: int = ai_score_combat_direction(["right", "middle", "left"])

	if left_score > right_score:
		return "left"

	if right_score > left_score:
		return "right"

	if (randi() % 2) == 0:
		return "left"

	return "right"


func ai_score_combat_direction(lanes: Array[String]) -> int:
	var score: int = 0
	var weight: int = 3

	for lane in lanes:
		var ai_slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)
		var player_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)

		var ai_card: CardData = get_slot_card_data(ai_slot)
		var player_card: CardData = get_slot_card_data(player_slot)

		if is_unit_card(ai_card):
			score += ai_card.ap * weight

			if is_unit_card(player_card):
				if ai_card.ap >= player_card.ap:
					score += 20 * weight
				else:
					score -= 10 * weight
			else:
				score += 12 * weight

		weight -= 1

	score += randi() % 10
	return score


func ai_resolve_combat_sequence() -> void:
	if combat_resolution_running:
		return

	combat_resolution_running = true

	while current_phase == BattlePhase.COMBAT and not parry_system.active and combat_next_lane_index < combat_lane_order.size():
		var next_lane: String = combat_lane_order[combat_next_lane_index]

		if combat_priority_owner != "ai":
			break

		await resolve_ai_current_priority_lane(next_lane)

		if parry_system.active:
			break

		if combat_priority_owner != "ai":
			break

		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout

	combat_resolution_running = false

func ai_count_front_units(owner_name: String) -> int:
	var count: int = 0
	var lanes: Array[String] = ["left", "middle", "right"]

	for lane in lanes:
		var slot: Node = find_slot_by_owner_row_lane(owner_name, "front", lane)
		var card_data: CardData = get_slot_card_data(slot)

		if is_unit_card(card_data):
			count += 1

	return count


func ai_get_total_front_ap(owner_name: String) -> int:
	var total_ap: int = 0
	var lanes: Array[String] = ["left", "middle", "right"]

	for lane in lanes:
		var slot: Node = find_slot_by_owner_row_lane(owner_name, "front", lane)
		var card_data: CardData = get_slot_card_data(slot)

		if is_unit_card(card_data):
			total_ap += card_data.ap

	return total_ap


func ai_deploy_one_card() -> void:
	# Legacy wrapper. Other code can still call this safely.
	ai_take_deployment_turn()


func ai_take_deployment_turn() -> void:
	if ai_hand.is_empty():
		log_msg("AI has no hand cards to deploy.")
		return

	var plays_made: int = 0
	var max_plays: int = max(1, ai_max_deployments_per_phase)

	for i in range(max_plays):
		var played: bool = await ai_try_deploy_one_card()

		if not played:
			break

		plays_made += 1

		await get_tree().create_timer(0.25).timeout

		if ai_current_tp <= 0:
			break

	if plays_made == 0:
		log_msg("AI passes deployment. No legal affordable play.")
	else:
		log_msg("AI completed deployment with " + str(plays_made) + " play(s).")


func ai_try_deploy_one_card() -> bool:
	var action: Dictionary = ai_choose_deployment_action()

	if action.is_empty():
		return false

	var card_index: int = int(action.get("card_index", -1))
	var target_slot: Node = action.get("slot", null) as Node
	var action_type: String = String(action.get("action_type", ""))
	var face_down: bool = bool(action.get("face_down", false))

	if card_index < 0 or card_index >= ai_hand.size():
		return false

	if target_slot == null:
		return false

	var card_data: CardData = ai_hand[card_index]

	if card_data == null:
		return false

	if not face_down and not ai_card_passes_faction_gate(card_data, true):
		log_msg("AI cannot play " + card_data.card_name + ": faction gate locked.")
		return false

	var deployment_cost: int = get_ai_face_down_card_deployment_cost(card_data, face_down)

	if deployment_cost > ai_current_tp:
		return false

	var success: bool = false

	if action_type == "equipment":
		await play_enemy_hand_to_node_animation(card_data, target_slot, false)

		if target_slot.has_method("attach_equipment"):
			success = target_slot.attach_equipment(TEST_CARD_SCENE, card_data)

		if success:
			ai_hand.pop_at(card_index)
			ai_spend_tp(card_data.tribute_cost)

			var equipped_unit: CardData = get_slot_card_data(target_slot)
			var equipped_unit_name: String = "unit"

			if equipped_unit != null:
				equipped_unit_name = equipped_unit.card_name

			log_msg("AI attached " + card_data.card_name + " to " + equipped_unit_name + ".")
			log_msg("AI TP after equipment: " + str(ai_current_tp) + "/" + str(ai_perm_tp) + " Temp +" + str(ai_temp_tp))
			update_ai_visuals()
			return true

		return false

	if action_type == "promotion":
		var old_unit: CardData = get_slot_card_data(target_slot)

		if not ai_can_promote_card_to_slot(card_data, target_slot):
			return false

		await play_enemy_hand_to_node_animation(card_data, target_slot, false)
		success = promote_slot_unit_preserving_equipment(target_slot, card_data, "enemy")

		if success:
			ai_hand.pop_at(card_index)
			ai_spend_tp(card_data.tribute_cost)
			log_msg("AI promoted " + old_unit.card_name + " into " + card_data.card_name + " for full cost: " + str(card_data.tribute_cost) + " TP.")
			log_msg("AI TP after promotion: " + str(ai_current_tp) + "/" + str(ai_perm_tp) + " Temp +" + str(ai_temp_tp))
			update_ai_visuals()
			return true

		return false

	if action_type == "unit" or action_type == "gambit" or action_type == "equipment_setup":
		await play_enemy_hand_to_node_animation(card_data, target_slot, face_down)

		if target_slot.has_method("place_card"):
			success = target_slot.place_card(TEST_CARD_SCENE, card_data, face_down)

		if success:
			ai_hand.pop_at(card_index)
			ai_spend_tp(deployment_cost)

			if face_down:
				ai_face_down_gambits_this_round += 1

			var visibility_text: String = "face down" if face_down else "face up"
			var row_text: String = String(target_slot.get_meta("row", "unknown row"))
			var cost_text: String = "Shadowtax setup cost" if face_down else "printed cost"

			log_msg("AI placed " + card_data.card_name + " " + visibility_text + " in enemy " + row_text + " row.")
			log_msg("AI spent " + str(deployment_cost) + " TP " + cost_text + ". AI TP after deployment: " + str(ai_current_tp) + "/" + str(ai_perm_tp) + " Temp +" + str(ai_temp_tp))
			update_ai_visuals()
			return true

	return false


func ai_choose_deployment_action() -> Dictionary:
	var equipment_action: Dictionary = ai_find_equipment_action()
	var spell_action: Dictionary = ai_find_spell_action()
	var promotion_action: Dictionary = ai_find_promotion_action()
	var unit_action: Dictionary = ai_find_unit_action()

	# Testing behavior:
	# Sometimes choose spell/equipment even before full effects exist,
	# so we can verify the board rules.
	var roll: int = randi() % 100

	if roll < 25 and not equipment_action.is_empty():
		return equipment_action

	if roll < 55 and not spell_action.is_empty():
		return spell_action

	if not promotion_action.is_empty():
		return promotion_action

	if not unit_action.is_empty():
		return unit_action

	if not spell_action.is_empty():
		return spell_action

	if not equipment_action.is_empty():
		return equipment_action

	return {}


func ai_make_deployment_action(card_index: int, slot: Node, action_type: String, face_down: bool) -> Dictionary:
	return {
		"card_index": card_index,
		"slot": slot,
		"action_type": action_type,
		"face_down": face_down
	}



func ai_find_promotion_action() -> Dictionary:
	for card_index in range(ai_hand.size()):
		var card_data: CardData = ai_hand[card_index]

		if card_data == null:
			continue

		if not is_unit_card(card_data):
			continue

		if not ai_card_passes_faction_gate(card_data, false):
			continue

		if card_data.tribute_cost > ai_current_tp:
			continue

		for lane in ["left", "middle", "right"]:
			var slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)

			if ai_can_promote_card_to_slot(card_data, slot):
				return ai_make_deployment_action(card_index, slot, "promotion", false)

	return {}


func ai_can_promote_card_to_slot(new_unit: CardData, slot: Node) -> bool:
	if new_unit == null:
		return false

	if not is_unit_card(new_unit):
		return false

	if slot == null:
		return false

	if String(slot.get_meta("owner", "")) != "enemy":
		return false

	if String(slot.get_meta("row", "")) != "front":
		return false

	if not bool(slot.get_meta("occupied", false)):
		return false

	if bool(slot.get_meta("face_down", false)):
		return false

	var old_unit: CardData = get_slot_card_data(slot)

	if not is_unit_card(old_unit):
		return false

	var new_race: String = get_clean_card_race(new_unit)
	var old_race: String = get_clean_card_race(old_unit)

	if new_race == "" or old_race == "":
		return false

	if new_race != old_race:
		return false

	if new_unit.tribute_cost <= old_unit.tribute_cost:
		return false

	return true


func ai_find_unit_action() -> Dictionary:
	var unit_index: int = ai_find_best_affordable_unit_index()

	if unit_index < 0:
		return {}

	var front_slot: Node = ai_find_empty_enemy_slot("front")
	var back_slot: Node = ai_find_empty_enemy_slot("back")

	if front_slot == null and back_slot == null:
		return {}

	var chosen_slot: Node = null
	var face_down: bool = false

	if front_slot != null and back_slot != null:
		# Mostly prefer front row, but sometimes use back row face-down.
		if randi() % 100 < 65:
			chosen_slot = front_slot
			face_down = false
		else:
			chosen_slot = back_slot
			face_down = true
	elif front_slot != null:
		chosen_slot = front_slot
		face_down = false
	else:
		chosen_slot = back_slot
		face_down = true

	return ai_make_deployment_action(unit_index, chosen_slot, "unit", face_down)


func ai_find_best_affordable_unit_index() -> int:
	var best_index: int = -1
	var best_ap: int = -999

	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if card_data == null:
			continue

		if not is_unit_card(card_data):
			continue

		if not ai_card_passes_faction_gate(card_data, false):
			continue

		if card_data.tribute_cost > ai_current_tp:
			continue

		if card_data.ap > best_ap:
			best_ap = card_data.ap
			best_index = i

	return best_index


func ai_find_spell_action() -> Dictionary:
	var front_slot: Node = ai_find_empty_enemy_slot("front")
	var back_slot: Node = ai_find_empty_enemy_slot("back")

	if front_slot == null and back_slot == null:
		return {}

	var chosen_slot: Node = null
	var face_down: bool = false

	if front_slot != null and back_slot != null:
		# Gambits can go front or back.
		# Front is face up and pays printed cost.
		# Back can be face up or face down; face down pays setup cost.
		if randi() % 100 < 45:
			chosen_slot = front_slot
			face_down = false
		else:
			chosen_slot = back_slot
			face_down = randi() % 100 < 50
	elif front_slot != null:
		chosen_slot = front_slot
		face_down = false
	else:
		chosen_slot = back_slot
		face_down = randi() % 100 < 50

	var gambit_index: int = ai_find_affordable_gambit_index_for_visibility(face_down)

	# If the first chosen back-row visibility is not affordable, try the other back-row visibility.
	if gambit_index < 0 and chosen_slot == back_slot:
		face_down = !face_down
		gambit_index = ai_find_affordable_gambit_index_for_visibility(face_down)

	# If back-row options are not affordable but front-row face-up is available, try front.
	if gambit_index < 0 and front_slot != null:
		chosen_slot = front_slot
		face_down = false
		gambit_index = ai_find_affordable_gambit_index_for_visibility(false)

	if gambit_index < 0:
		return {}

	return ai_make_deployment_action(gambit_index, chosen_slot, "gambit", face_down)

func ai_find_affordable_gambit_index_for_visibility(face_down: bool) -> int:
	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if card_data == null:
			continue

		if not is_gambit_card(card_data):
			continue

		if not ai_card_passes_faction_gate(card_data, false):
			continue

		var deployment_cost: int = get_ai_face_down_card_deployment_cost(card_data, face_down)

		if deployment_cost > ai_current_tp:
			continue

		return i

	return -1


func ai_find_affordable_spell_index() -> int:
	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if card_data == null:
			continue

		if not is_gambit_card(card_data):
			continue

		if card_data.tribute_cost > ai_current_tp:
			continue

		return i

	return -1


func ai_find_equipment_action() -> Dictionary:
	var target_slot: Node = ai_find_enemy_unit_slot_that_can_take_equipment()

	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if card_data == null:
			continue

		if not is_equipment_card(card_data):
			continue

		if target_slot != null and ai_card_passes_faction_gate(card_data, false) and card_data.tribute_cost <= ai_current_tp:
			return ai_make_deployment_action(i, target_slot, "equipment", false)

		var back_slot := ai_find_empty_enemy_slot("back")
		var shadowtax := get_ai_face_down_card_deployment_cost(card_data, true)
		if back_slot != null and shadowtax <= ai_current_tp:
			return ai_make_deployment_action(i, back_slot, "equipment_setup", true)

	return {}


func ai_find_enemy_unit_slot_that_can_take_equipment() -> Node:
	if board_slots == null:
		return null

	for slot in board_slots.get_children():
		if String(slot.get_meta("owner", "")) != "enemy":
			continue

		if not bool(slot.get_meta("occupied", false)):
			continue

		if bool(slot.get_meta("face_down", false)):
			continue

		var existing_card: CardData = get_slot_card_data(slot)

		if not is_unit_card(existing_card):
			continue

		if not slot.has_method("can_attach_equipment"):
			continue

		if not slot.can_attach_equipment():
			continue

		return slot

	return null


func ai_find_empty_enemy_slot(row: String) -> Node:
	if board_slots == null:
		return null

	var empty_slots: Array[Node] = []

	for slot in board_slots.get_children():
		if String(slot.get_meta("owner", "")) != "enemy":
			continue

		if String(slot.get_meta("row", "")) != row:
			continue

		if bool(slot.get_meta("occupied", false)):
			continue

		empty_slots.append(slot)

	if empty_slots.is_empty():
		return null

	empty_slots.shuffle()
	return empty_slots[0]


func ai_choose_slot_for_card(card_data: CardData) -> Node:
	if card_data == null:
		return null

	if is_unit_card(card_data):
		return ai_choose_front_slot_for_card(card_data)

	if is_equipment_card(card_data):
		return ai_choose_equipment_target_slot(card_data)

	if is_gambit_card(card_data):
		return ai_choose_spell_like_slot(card_data)

	return null


func ai_should_place_card_face_down(card_data: CardData, target_slot: Node) -> bool:
	if card_data == null or target_slot == null:
		return false

	var row: String = String(target_slot.get_meta("row", ""))

	if row == "front":
		return false

	if row == "back":
		return is_unit_card(card_data) or is_gambit_card(card_data) or is_equipment_card(card_data)

	return false


func ai_choose_empty_back_slot_for_tactic(_card_data: CardData) -> Node:
	var candidate_slots: Array[Node] = []
	var lanes: Array[String] = ["left", "middle", "right"]

	for lane in lanes:
		var slot: Node = find_slot_by_owner_row_lane("enemy", "back", lane)

		if slot == null:
			continue

		if get_slot_card_data(slot) == null:
			candidate_slots.append(slot)

	if candidate_slots.is_empty():
		return null

	# Prefer back-row tactics behind an AI front unit.
	var protected_slots: Array[Node] = []

	for slot in candidate_slots:
		var lane: String = get_slot_lane(slot)
		var front_slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)
		var front_card: CardData = get_slot_card_data(front_slot)

		if is_unit_card(front_card):
			protected_slots.append(slot)

	if not protected_slots.is_empty():
		return protected_slots.pick_random()

	return candidate_slots.pick_random()


func ai_choose_spell_like_slot(card_data: CardData) -> Node:
	var front_slots: Array[Node] = []
	var back_slots: Array[Node] = []
	var lanes: Array[String] = ["left", "middle", "right"]

	for lane in lanes:
		var front_slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)

		if front_slot != null and get_slot_card_data(front_slot) == null:
			front_slots.append(front_slot)

		var back_slot: Node = find_slot_by_owner_row_lane("enemy", "back", lane)

		if back_slot != null and get_slot_card_data(back_slot) == null:
			back_slots.append(back_slot)

	if front_slots.is_empty() and back_slots.is_empty():
		return null

	# Traps and ruses prefer the back row.
	if is_trap_card(card_data) or is_ruse_card(card_data):
		if not back_slots.is_empty():
			return back_slots.pick_random()

		return front_slots.pick_random()

	# Spells and events can go front or back.
	if is_spell_card(card_data) or is_event_card(card_data):
		if not front_slots.is_empty() and not back_slots.is_empty():
			if (randi() % 100) < 60:
				return front_slots.pick_random()

			return back_slots.pick_random()

		if not front_slots.is_empty():
			return front_slots.pick_random()

		return back_slots.pick_random()

	var all_slots: Array[Node] = []
	all_slots.append_array(front_slots)
	all_slots.append_array(back_slots)
	return all_slots.pick_random()


func ai_choose_equipment_target_slot(_card_data: CardData) -> Node:
	var candidate_slots: Array[Node] = []
	var lanes: Array[String] = ["left", "middle", "right"]

	for lane in lanes:
		var slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)

		if slot == null:
			continue

		var slot_card: CardData = get_slot_card_data(slot)

		if not is_unit_card(slot_card):
			continue

		if slot.has_method("can_attach_equipment") and not slot.can_attach_equipment():
			continue

		candidate_slots.append(slot)

	if candidate_slots.is_empty():
		return null

	var best_score: int = -999999
	var best_slots: Array[Node] = []

	for slot in candidate_slots:
		var unit_card: CardData = get_slot_card_data(slot)
		var score: int = 0

		if unit_card != null:
			score += unit_card.ap
			score += unit_card.dp

		score += randi() % 10

		if score > best_score:
			best_score = score
			best_slots.clear()
			best_slots.append(slot)
		elif score == best_score:
			best_slots.append(slot)

	return best_slots.pick_random()


func ai_attach_equipment_to_slot(equipment_card: CardData, target_slot: Node) -> bool:
	if equipment_card == null or target_slot == null:
		return false

	if not target_slot.has_method("attach_equipment"):
		log_msg("AI could not attach equipment because target slot has no attach_equipment method.")
		return false

	return target_slot.attach_equipment(TEST_CARD_SCENE, equipment_card)


func ai_choose_front_slot_for_card(card_data: CardData) -> Node:
	var candidate_slots: Array[Node] = ai_get_empty_front_slots()

	if candidate_slots.is_empty():
		return null

	var best_score: int = -999999
	var best_slots: Array[Node] = []

	for slot in candidate_slots:
		var lane: String = get_slot_lane(slot)
		var score: int = ai_score_front_slot_for_card(card_data, lane)

		if score > best_score:
			best_score = score
			best_slots.clear()
			best_slots.append(slot)
		elif score == best_score:
			best_slots.append(slot)

	if best_slots.is_empty():
		return candidate_slots.pick_random()

	return best_slots.pick_random()


func ai_get_empty_front_slots() -> Array[Node]:
	var empty_slots: Array[Node] = []
	var lanes: Array[String] = ["left", "middle", "right"]

	for lane in lanes:
		var slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)

		if slot == null:
			continue

		if get_slot_card_data(slot) == null:
			empty_slots.append(slot)

	return empty_slots


func ai_score_front_slot_for_card(card_data: CardData, lane: String) -> int:
	var score: int = 0

	if card_data == null:
		return score

	var player_front_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)
	var player_back_slot: Node = find_slot_by_owner_row_lane("player", "back", lane)

	var player_front_card: CardData = get_slot_card_data(player_front_slot)
	var player_back_card: CardData = get_slot_card_data(player_back_slot)

	# If the player has a front unit in this lane, AI likes contesting/blocking it.
	if is_unit_card(player_front_card):
		score += 35

		# If AI can beat or match it by AP, this lane becomes very attractive.
		if card_data.ap >= player_front_card.ap:
			score += 35
		else:
			score += 15

		# Strong enemy targets attract AI attention.
		score += min(player_front_card.ap, 10)

	# If the player has no front unit, AI may still choose the open lane.
	else:
		score += 18

	# If the player has something hidden/backline in this lane, AI slightly cares.
	if player_back_card != null:
		score += 8

	# Add randomness so AI does not feel scripted.
	score += randi() % 25

	return score


func ai_find_empty_front_slot() -> Node:
	if board_slots == null:
		return null

	for slot in board_slots.get_children():
		if slot.get_meta("owner", "") == "enemy" and slot.get_meta("row", "") == "front" and not slot.occupied:
			return slot

	return null


func ai_choose_deploy_card_index() -> int:
	var best_index: int = -1
	var best_score: int = -999999

	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if card_data == null:
			continue

		if card_data.tribute_cost > ai_current_tp:
			continue

		# Do not choose cards that currently have nowhere legal/useful to go.
		var possible_slot: Node = ai_choose_slot_for_card(card_data)

		if possible_slot == null:
			continue

		var score: int = ai_score_deploy_card(card_data)

		if score > best_score:
			best_score = score
			best_index = i

	return best_index


func ai_score_deploy_card(card_data: CardData) -> int:
	if card_data == null:
		return -999999

	var score: int = 0
	var card_type: String = get_clean_card_type(card_data)

	match card_type:
		"unit":
			score += 70
			score += card_data.ap * 4
			score += card_data.dp * 2

		"equipment":
			score += 60
			score += card_data.ap * 3
			score += card_data.dp * 3

		"gambit":
			score += 35
		_:
			score -= 100

	# Prefer cheaper cards slightly so AI does not waste its full turn too easily.
	score -= card_data.tribute_cost * 2

	# Randomness so AI is not scripted.
	score += randi() % 20

	return score


func ai_spend_tp(cost: int) -> bool:
	if cost <= 0:
		return true

	if ai_current_tp < cost:
		return false

	var remaining_cost: int = cost

	if ai_temp_tp > 0:
		var temp_spent: int = mini(ai_temp_tp, remaining_cost)
		ai_temp_tp -= temp_spent
		ai_current_tp -= temp_spent
		remaining_cost -= temp_spent

	if remaining_cost > 0:
		ai_current_perm_tp -= remaining_cost
		ai_current_tp -= remaining_cost

	return true


func is_spell_like_card(card_data: CardData) -> bool:
	return CardRules.is_spell_like_card(card_data)


func cleanup_phase_one_board_cards() -> void:
	if board_slots == null:
		return

	var returned_count: int = 0
	var discarded_count: int = 0

	for slot in board_slots.get_children():
		var card_data: CardData = get_slot_card_data(slot)

		if card_data == null:
			continue

		var slot_owner: String = String(slot.get_meta("owner", ""))
		var slot_row: String = String(slot.get_meta("row", ""))
		var is_face_down: bool = bool(slot.get_meta("face_down", false))
		var was_interacted: bool = bool(slot.get_meta("interacted_this_round", false))

		if is_face_down and slot_row == "back" and not was_interacted:
			return_face_down_setup_card_to_owner_hand(slot, card_data, slot_owner)
			returned_count += 1
			continue

		if is_gambit_card(card_data) and not is_face_down:
			discard_slot_card_for_cleanup(slot, card_data, slot_owner)
			discarded_count += 1
			continue

		slot.set_meta("interacted_this_round", false)

	if returned_count > 0:
		log_msg("Returned " + str(returned_count) + " untouched face-down back-row card(s) to hand.")

	if discarded_count > 0:
		log_msg("Cleaned up " + str(discarded_count) + " face-up Gambit card(s).")

	update_ai_visuals()


func return_face_down_setup_card_to_owner_hand(slot: Node, card_data: CardData, slot_owner: String) -> void:
	if card_data == null or slot == null:
		return

	if slot_owner == "enemy":
		ai_hand.append(card_data)
	else:
		if hand != null:
			hand.add_card_to_hand(card_data)

	if slot.has_method("clear_slot"):
		slot.clear_slot()

	slot.set_meta("interacted_this_round", false)


func discard_slot_card_for_cleanup(slot: Node, card_data: CardData, slot_owner: String) -> void:
	if card_data == null or slot == null:
		return

	play_card_to_discard_animation(card_data, slot, slot_owner)

	if slot_owner == "enemy":
		ai_discard.append(card_data)
	elif discard_pile != null:
		discard_pile.add_card(card_data)

	if slot.has_method("clear_slot"):
		slot.clear_slot()

	slot.set_meta("interacted_this_round", false)


func create_board_slot_action_menu() -> void:
	if board_action_menu != null:
		return

	board_action_menu = PopupMenu.new()
	board_action_menu.name = "BoardSlotActionMenu"
	board_action_menu.visible = false
	board_action_menu.exclusive = false
	board_action_menu.id_pressed.connect(_on_board_slot_action_selected)

	$UI.add_child(board_action_menu)


func create_board_slot_action_buttons() -> void:
	if board_slots == null:
		return
	for slot in board_slots.get_children():
		if not slot is Node3D:
			continue
		var slot_id := String(slot.get_meta("slot_id", ""))
		var slide_direction := -1.0 if slot_id.ends_with("_Right") else 1.0
		var rail := BOARD_SLOT_ACTION_BUTTONS_SCENE.instantiate() as BoardSlotActionButtons3D
		(slot as Node3D).add_child(rail)
		rail.setup(slot as Node3D, slide_direction)
		rail.action_pressed.connect(_on_board_slot_action_button_pressed)
		board_slot_action_rails[slot.get_instance_id()] = rail


func refresh_board_slot_action_buttons() -> void:
	if board_slot_action_rails.is_empty() or board_slots == null:
		return
	var controls_blocked := (
		game_over
		or current_phase != BattlePhase.COMBAT
		or phase_transition_busy
		or combat_resolution_running
		or parry_system.active
		or is_prebattle_modal_open()
	)
	for slot in board_slots.get_children():
		var rail := board_slot_action_rails.get(slot.get_instance_id()) as BoardSlotActionButtons3D
		if rail == null:
			continue
		var actions: Array[int] = []
		if not controls_blocked:
			var lane := get_slot_lane(slot)
			var can_pass := can_player_pass_lane_from_menu(lane)
			var slot_owner := String(slot.get_meta("owner", ""))
			var slot_row := String(slot.get_meta("row", ""))
			var card_data := get_slot_card_data(slot)
			if can_pass and slot_owner == "enemy" and slot_row == "front":
				if can_player_attack_lane_from_menu(lane):
					actions.append(BOARD_ACTION_ATTACK)
				var enemy_back_slot := find_slot_by_owner_row_lane("enemy", "back", lane)
				var enemy_back_card := get_slot_card_data(enemy_back_slot)
				var has_hidden_back := (
					enemy_back_slot != null
					and enemy_back_card != null
					and bool(enemy_back_slot.get_meta("face_down", false))
				)
				if has_hidden_back and can_player_check_lane_from_menu(lane):
					actions.append(BOARD_ACTION_CHECK)
				actions.append(BOARD_ACTION_PASS)
			if can_pass and card_data != null:
				actions.append(BOARD_ACTION_INSPECT)
		rail.set_actions(actions)


func _on_board_slot_action_button_pressed(action_id: int, slot: Node) -> void:
	if slot == null or game_over or phase_transition_busy:
		return
	board_action_target_slot = slot
	await _on_board_slot_action_selected(action_id)


func show_board_slot_action_menu(slot: Node) -> void:
	if slot == null or phase_transition_busy:
		return

	if board_action_menu == null:
		create_board_slot_action_menu()

	board_action_target_slot = slot
	board_action_menu.clear()
	board_action_ability_map.clear()

	var lane: String = get_slot_lane(slot)
	var card_data: CardData = get_slot_card_data(slot)
	var can_attack: bool = can_player_attack_lane_from_menu(lane)
	var can_check: bool = can_player_check_lane_from_menu(lane)
	var can_pass: bool = can_player_pass_lane_from_menu(lane)
	var enemy_back_slot: Node = find_slot_by_owner_row_lane("enemy", "back", lane)
	var enemy_back_card: CardData = get_slot_card_data(enemy_back_slot)
	var has_hidden_back: bool = enemy_back_card != null and enemy_back_slot != null and bool(enemy_back_slot.get_meta("face_down", false))
	var added_action: bool = false

	if current_phase == BattlePhase.COMBAT:
		board_action_menu.add_item("Attack", BOARD_ACTION_ATTACK)
		var attack_index: int = board_action_menu.get_item_count() - 1
		if can_attack:
			added_action = true
		else:
			board_action_menu.set_item_disabled(attack_index, true)

		if has_hidden_back:
			board_action_menu.add_item("Check", BOARD_ACTION_CHECK)
			var check_index: int = board_action_menu.get_item_count() - 1
			if can_check:
				added_action = true
			else:
				board_action_menu.set_item_disabled(check_index, true)

		board_action_menu.add_item("Pass", BOARD_ACTION_PASS)
		var pass_index: int = board_action_menu.get_item_count() - 1
		if can_pass:
			added_action = true
		else:
			board_action_menu.set_item_disabled(pass_index, true)

	if card_data != null:
		board_action_menu.add_item("Inspect", BOARD_ACTION_INSPECT)
		add_active_insight_actions_to_board_menu(slot, card_data)
	elif not added_action:
		board_action_menu.add_item("Empty Slot", BOARD_ACTION_CANCEL)
		var empty_index: int = board_action_menu.get_item_count() - 1
		board_action_menu.set_item_disabled(empty_index, true)

	board_action_menu.add_separator()
	board_action_menu.add_item("Cancel", BOARD_ACTION_CANCEL)

	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	board_action_menu.position = Vector2i(int(mouse_position.x), int(mouse_position.y))
	board_action_menu.popup()

func _on_board_slot_action_selected(action_id: int) -> void:
	if action_id >= BOARD_ACTION_ACTIVE_INSIGHT_BASE:
		await activate_insight_from_board_action(action_id, board_action_target_slot)
		board_action_target_slot = null
		if board_action_menu != null:
			board_action_menu.hide()
		return

	match action_id:
		BOARD_ACTION_ATTACK:
			await attack_from_board_action_menu(board_action_target_slot)
		BOARD_ACTION_CHECK:
			await check_from_board_action_menu(board_action_target_slot)
		BOARD_ACTION_PASS:
			await pass_from_board_action_menu(board_action_target_slot)
		BOARD_ACTION_INSPECT:
			inspect_board_slot(board_action_target_slot)
		BOARD_ACTION_CANCEL:
			pass

	board_action_target_slot = null

	if board_action_menu != null:
		board_action_menu.hide()


func add_active_insight_actions_to_board_menu(slot: Node, card_data: CardData) -> void:
	if slot == null or card_data == null:
		return
	if String(slot.get_meta("owner", "")) != "player":
		return
	if bool(slot.get_meta("face_down", false)):
		return
	for ability in card_data.get_abilities():
		if ability == null:
			continue
		if ability.category.to_lower() != "insight" or ability.trigger != "active":
			continue
		var action_id := BOARD_ACTION_ACTIVE_INSIGHT_BASE + board_action_ability_map.size()
		board_action_ability_map[action_id] = ability
		board_action_menu.add_item(ability.ability_name, action_id)
		var item_index := board_action_menu.get_item_count() - 1
		if not can_activate_insight_ability(slot, ability):
			board_action_menu.set_item_disabled(item_index, true)


func can_activate_insight_ability(slot: Node, ability: AbilityData) -> bool:
	if slot == null or ability == null:
		return false
	if current_phase == BattlePhase.COMBAT and parry_system.active:
		return false
	var card_data := get_slot_card_data(slot)
	if card_data == null:
		return false
	var usage_key := get_active_insight_usage_key(slot, ability)
	if used_active_insight_ability_keys.has(usage_key):
		return false
	var handler_id := ability.get_handler_id()
	if handler_id == &"true_sight" or handler_id == &"vantage":
		return can_player_take_priority_action_in_lane(get_slot_lane(slot))
	return true


func activate_insight_from_board_action(action_id: int, slot: Node) -> void:
	var ability := board_action_ability_map.get(action_id) as AbilityData
	await activate_insight_ability_from_slot(slot, ability)


func activate_insight_ability_from_slot(slot: Node, ability: AbilityData) -> void:
	if slot == null or ability == null:
		return
	if not can_activate_insight_ability(slot, ability):
		log_msg("Insight ability is not available right now: " + ability.ability_name)
		return
	var card_data := get_slot_card_data(slot)
	var handler_id := ability.get_handler_id()
	var lane := get_slot_lane(slot)
	if handler_id == &"true_sight" or handler_id == &"vantage":
		if not prepare_player_lane_action(lane):
			return
	var result := await resolve_insight_with_presentation(ability, {
		"card": card_data,
		"slot": slot,
		"trigger": &"active",
		"lane": lane,
	})
	if not bool(result.get("success", false)):
		log_msg("Insight ability failed: " + ability.ability_name + " (" + String(result.get("reason", "unknown")) + ").")
		return
	used_active_insight_ability_keys[get_active_insight_usage_key(slot, ability)] = true
	if handler_id == &"true_sight" or handler_id == &"vantage":
		player_passed_current_lane = true
		set_lane_priority_to_ai(lane, ability.ability_name + " used instead of attacking.")
		await resolve_ai_current_priority_lane(lane)


func get_active_insight_usage_key(slot: Node, ability: AbilityData) -> String:
	return str(slot.get_instance_id()) + ":" + String(ability.ability_id) + ":" + str(turn_number)


func resolve_stealth_hidden_decoy(back_slot: Node, card_data: CardData, owner_name: String, lane: String) -> bool:
	if back_slot == null or card_data == null:
		return false
	var stealth_ability := get_card_insight_ability(card_data, &"stealth")
	if stealth_ability == null:
		return false
	var result := AbilityResolver.resolve(
		stealth_ability,
		build_ability_context({
			"card": card_data,
			"slot": back_slot,
			"trigger": &"active",
			"lane": lane,
			"owner": owner_name,
		})
	)
	if not bool(result.get("success", false)):
		log_msg("Insight ability failed: Stealth (" + String(result.get("reason", "unknown")) + ").")
		return false

	if owner_name == "player":
		pending_stealth_deployments.append({"slot": back_slot, "card": card_data, "lane": lane})
		back_slot.set_meta("stealth_pending", true)
		return true

	var front_slot := find_slot_by_owner_row_lane(owner_name, "front", lane)
	if front_slot != null and get_slot_card_data(front_slot) == null:
		back_slot.clear_slot()
		front_slot.call("place_card", TEST_CARD_SCENE, card_data, false)
	else:
		back_slot.reveal_card()
	update_ai_visuals()
	return true


func get_card_insight_ability(card_data: CardData, ability_id: StringName) -> AbilityData:
	if card_data == null:
		return null
	for ability in card_data.get_abilities():
		if ability != null and ability.category.to_lower() == "insight" and ability.ability_id == ability_id:
			return ability
	return null


func get_hidden_enemy_gambit_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	if board_slots == null:
		return cards
	for slot in board_slots.get_children():
		if String(slot.get_meta("owner", "")) != "enemy":
			continue
		if not bool(slot.get_meta("face_down", false)):
			continue
		var card_data := get_slot_card_data(slot)
		if is_gambit_card(card_data):
			cards.append(card_data)
	return cards


func inspect_board_slot(slot: Node) -> void:
	if slot == null:
		return

	var card_data: CardData = get_slot_card_data(slot)

	if card_data == null:
		log_msg("No card in this slot.")
		return

	var slot_owner: String = String(slot.get_meta("owner", ""))
	var is_face_down: bool = bool(slot.get_meta("face_down", false))
	var slot_id: String = String(slot.get_meta("slot_id", "board slot"))

	if slot_owner == "enemy" and is_face_down:
		log_msg("Inspected " + slot_id + ": enemy face-down card remains hidden.")
		return

	var inspect_panel: CardInspectPanel = get_card_inspect_panel()

	if inspect_panel == null:
		log_msg("CardInspectPanel is missing.")
		return

	var source_position: Vector2 = get_viewport().get_mouse_position()
	inspect_panel.last_source_rect = Rect2(source_position, Vector2(130.0, 180.0))
	inspect_panel.show_card(null, card_data)

	log_msg("Inspecting board card: " + card_data.card_name)


func get_card_inspect_panel() -> CardInspectPanel:
	var inspect_panel: CardInspectPanel = get_node_or_null("UI/CardInspectPanel") as CardInspectPanel

	if inspect_panel != null:
		return inspect_panel

	return find_card_inspect_panel(self)


func find_card_inspect_panel(node: Node) -> CardInspectPanel:
	if node == null:
		return null

	if node is CardInspectPanel:
		return node as CardInspectPanel

	for child in node.get_children():
		var found: CardInspectPanel = find_card_inspect_panel(child)

		if found != null:
			return found

	return null


func can_player_attack_lane_from_menu(lane: String) -> bool:
	if not can_player_take_priority_action_in_lane(lane):
		return false

	var player_front_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)
	var player_card: CardData = get_slot_card_data(player_front_slot)

	# Phase 7: Attack is only legal when the player has a front-row unit in that lane.
	# Empty/playerless lanes can still be selected with Pass to let the opponent act.
	return is_unit_card(player_card)

func can_player_check_lane_from_menu(lane: String) -> bool:
	if not can_player_take_priority_action_in_lane(lane):
		return false

	var player_front_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)
	var player_card: CardData = get_slot_card_data(player_front_slot)

	# Checking a hidden back-row card requires your front-row unit in that lane.
	return is_unit_card(player_card)


func can_player_pass_lane_from_menu(lane: String) -> bool:
	return can_player_take_priority_action_in_lane(lane)


func can_player_take_priority_action_in_lane(lane: String) -> bool:
	if current_phase != BattlePhase.COMBAT:
		return false

	if parry_system.active:
		return false

	if lane == "":
		return false

	if not is_lane_current_or_valid_combat_start(lane):
		return false

	if not combat_direction_selected:
		return player_has_initiative or combat_priority_owner == "player"

	return combat_priority_owner == "player"


func is_lane_current_or_valid_combat_start(lane: String) -> bool:
	if lane == "":
		return false

	if not combat_direction_selected:
		return lane == "left" or lane == "right"

	if combat_next_lane_index >= combat_lane_order.size():
		return false

	var expected_lane: String = combat_lane_order[combat_next_lane_index]
	return lane == expected_lane


func get_initiative_priority_owner() -> String:
	return "player" if player_has_initiative else "ai"


func reset_priority_for_current_lane() -> void:
	if original_combat_priority_owner == "":
		original_combat_priority_owner = get_initiative_priority_owner()
	combat_priority_owner = original_combat_priority_owner
	player_passed_current_lane = false
	ai_passed_current_lane = false

func current_combat_lane() -> String:
	if combat_next_lane_index < 0 or combat_next_lane_index >= combat_lane_order.size():
		return ""

	return combat_lane_order[combat_next_lane_index]


func set_lane_priority_to_player(lane: String, reason: String = "") -> void:
	combat_priority_owner = "player"
	set_active_combat_lane_highlight(lane)
	if reason != "":
		log_msg(reason)

	var player_front_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)
	var enemy_back_slot: Node = find_slot_by_owner_row_lane("enemy", "back", lane)
	var player_card: CardData = get_slot_card_data(player_front_slot)
	var enemy_back_card: CardData = get_slot_card_data(enemy_back_slot)
	var enemy_back_face_down: bool = enemy_back_card != null and enemy_back_slot != null and bool(enemy_back_slot.get_meta("face_down", false))

	if is_unit_card(player_card):
		if enemy_back_face_down:
			log_msg("Player has priority in the " + lane + " lane. Right-click and choose Attack, Check, or Pass.")
		else:
			log_msg("Player has priority in the " + lane + " lane. Right-click and choose Attack or Pass.")
	else:
		log_msg("Player has priority in the " + lane + " lane, but has no front-row unit. Right-click and choose Pass.")


func set_lane_priority_to_ai(lane: String, reason: String = "") -> void:
	combat_priority_owner = "ai"
	set_active_combat_lane_highlight(lane)
	if reason != "":
		log_msg(reason)
	log_msg("AI has priority in the " + lane + " lane.")

func attack_from_board_action_menu(slot: Node) -> void:
	if combat_resolution_running:
		log_msg("Combat is already resolving. Wait for the current lane.")
		return

	if slot == null:
		return

	if current_phase != BattlePhase.COMBAT:
		log_msg("Attack is only available during Combat.")
		return

	if parry_system.active:
		log_msg("Resolve the current parry prompt first.")
		return

	var lane: String = get_slot_lane(slot)

	if lane == "":
		return

	if not can_player_attack_lane_from_menu(lane):
		log_msg("You do not have priority to attack in this lane.")
		return

	await resolve_player_attack_lane_with_visuals(lane)


func pass_from_board_action_menu(slot: Node) -> void:
	if combat_resolution_running:
		log_msg("Combat is already resolving. Wait for the current lane.")
		return

	if slot == null:
		return

	if current_phase != BattlePhase.COMBAT:
		log_msg("Pass is only available during Combat.")
		return

	if parry_system.active:
		log_msg("Resolve the current parry prompt first.")
		return

	var lane: String = get_slot_lane(slot)

	if lane == "":
		return

	if not can_player_pass_lane_from_menu(lane):
		log_msg("You do not have priority to pass in this lane.")
		return

	await resolve_player_pass_lane_with_visuals(lane)

func resolve_monarch_strike(lane: String, attacker_card: CardData) -> void:
	if attacker_card == null:
		return

	add_aurion("player", 1, "Monarch Strike through the " + lane + " lane by " + attacker_card.card_name + ".")
	log_msg(lane.capitalize() + " lane: Player Monarch Strike successful.")


func resolve_ai_monarch_strike(lane: String, attacker_card: CardData) -> void:
	if attacker_card == null:
		return

	add_aurion("ai", 1, "Monarch Strike through the " + lane + " lane by " + attacker_card.card_name + ".")
	log_msg(lane.capitalize() + " lane: AI Monarch Strike successful.")


func patch_game_log_for_scrolling() -> void:
	if game_log == null:
		return

	game_log.set("max_lines", 200)

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


func resolve_player_attack_lane_with_visuals(lane: String) -> void:
	if combat_resolution_running:
		return

	combat_resolution_running = true

	if not prepare_player_lane_action(lane):
		combat_resolution_running = false
		return

	player_passed_current_lane = false
	set_active_combat_lane_highlight(lane)
	log_msg("Resolving player attack in the " + lane + " lane.")
	await get_tree().create_timer(COMBAT_LANE_START_DELAY).timeout

	var player_front_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)
	var enemy_front_slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)
	var enemy_back_slot: Node = find_slot_by_owner_row_lane("enemy", "back", lane)

	var player_card: CardData = get_slot_card_data(player_front_slot)
	var enemy_front_card: CardData = get_slot_card_data(enemy_front_slot)
	var enemy_back_card: CardData = get_slot_card_data(enemy_back_slot)
	var enemy_back_is_face_down: bool = enemy_back_card != null and enemy_back_slot != null and bool(enemy_back_slot.get_meta("face_down", false))

	if not lane_has_any_front_unit(lane):
		log_msg(lane.capitalize() + " lane has no front-row units on either side. Skipping after a short pause.")
		await get_tree().create_timer(COMBAT_LANE_START_DELAY).timeout
		await advance_combat_lane_after_resolution()
		combat_resolution_running = false
		return

	if not is_unit_card(player_card):
		log_msg(lane.capitalize() + " lane: you have no front-row unit to attack with. Use Pass instead.")
		combat_resolution_running = false
		return

	if enemy_back_is_face_down:
		# Attacking a lane with a hidden enemy back-row card always resolves the bluff first.
		# If it is not a Gambit, the decoy is discarded and the player keeps priority,
		# then the player may right-click again to attack the front row or Monarch.
		await resolve_attack_into_face_down_backrow(lane, player_card, enemy_front_slot, enemy_back_slot, enemy_back_card)
		combat_resolution_running = false
		return

	if enemy_front_card == null:
		# Back-row cards do not protect the Monarch once there is no hidden card to resolve.
		# If the player has the only front unit in this lane, the player gets Monarch Strike.
		resolve_monarch_strike(lane, player_card)
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		await advance_combat_lane_after_resolution()
		combat_resolution_running = false
		return

	if enemy_front_card != null:
		await resolve_lane_combat(lane, player_front_slot, enemy_front_slot)

		if parry_system.active:
			combat_resolution_running = false
			return

		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		await advance_combat_lane_after_resolution()
		combat_resolution_running = false
		return

	log_msg(lane.capitalize() + " lane: enemy back row is occupied but not face down. Attack cannot resolve yet.")
	combat_resolution_running = false


func resolve_player_pass_lane_with_visuals(lane: String) -> void:
	if combat_resolution_running:
		return

	combat_resolution_running = true

	if not prepare_player_lane_action(lane):
		combat_resolution_running = false
		return

	set_active_combat_lane_highlight(lane)
	player_passed_current_lane = true
	log_msg("Player passes priority in the " + lane + " lane.")
	await get_tree().create_timer(COMBAT_LANE_START_DELAY).timeout

	if ai_passed_current_lane:
		log_msg("Both players passed in the " + lane + " lane. Moving to next lane.")
		await advance_combat_lane_after_resolution()
		combat_resolution_running = false
		return

	set_lane_priority_to_ai(lane, "Priority passes to AI.")
	await resolve_ai_current_priority_lane(lane)
	combat_resolution_running = false

func resolve_ai_combat_lane_with_visuals(lane: String) -> void:
	await resolve_ai_current_priority_lane(lane)


func resolve_ai_current_priority_lane(lane: String) -> void:
	if current_phase != BattlePhase.COMBAT:
		return

	if parry_system.active:
		return

	if combat_next_lane_index >= combat_lane_order.size():
		return

	var expected_lane: String = combat_lane_order[combat_next_lane_index]

	if lane != expected_lane:
		return

	if combat_priority_owner != "ai":
		return

	set_active_combat_lane_highlight(lane)
	log_msg("AI considers action in the " + lane + " lane.")
	await get_tree().create_timer(COMBAT_LANE_START_DELAY).timeout

	if not lane_has_any_front_unit(lane):
		log_msg(lane.capitalize() + " lane has no front-row units on either side. Skipping after a short pause.")
		await get_tree().create_timer(COMBAT_LANE_START_DELAY).timeout
		await advance_combat_lane_after_resolution()
		return

	var ai_front_slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)
	var player_front_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)
	var player_back_slot: Node = find_slot_by_owner_row_lane("player", "back", lane)

	var ai_card: CardData = get_slot_card_data(ai_front_slot)
	var player_front_card: CardData = get_slot_card_data(player_front_slot)
	var player_back_card: CardData = get_slot_card_data(player_back_slot)
	var player_back_is_face_down: bool = player_back_card != null and player_back_slot != null and bool(player_back_slot.get_meta("face_down", false))

	if not is_unit_card(ai_card):
		await resolve_ai_pass_lane_with_visuals(lane)
		return

	# Phase 13: if AI has a unit and the player's front row is empty,
	# AI must take the open-lane Monarch Strike instead of passing.
	# If a face-down player back-row card exists, resolve that hidden card first.
	if player_front_card == null:
		if player_back_is_face_down:
			await resolve_ai_attack_lane_with_visuals(lane)
			return

		log_msg("AI takes open-lane Monarch Strike in the " + lane + " lane.")
		resolve_ai_monarch_strike(lane, ai_card)
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		await advance_combat_lane_after_resolution()
		return

	if player_back_is_face_down and ai_should_check_hidden_backrow(lane, player_back_card):
		await resolve_ai_check_lane_with_visuals(lane)
		return

	# If AI does not Check the hidden card, it attacks into the lane.
	# resolve_ai_attack_lane_with_visuals handles hidden back-row bluff first.
	await resolve_ai_attack_lane_with_visuals(lane)

func resolve_ai_pass_lane_with_visuals(lane: String) -> void:
	set_active_combat_lane_highlight(lane)
	ai_passed_current_lane = true
	log_msg("AI passes priority in the " + lane + " lane.")
	await get_tree().create_timer(COMBAT_LANE_START_DELAY).timeout

	if player_passed_current_lane:
		log_msg("Both players passed in the " + lane + " lane. Moving to next lane.")
		await advance_combat_lane_after_resolution()
		return

	set_lane_priority_to_player(lane, "Priority passes to Player.")


func ai_should_check_hidden_backrow(_lane: String, _hidden_card: CardData) -> bool:
	# Prototype AI does not know what the hidden card is. It sometimes Checks and sometimes Attacks.
	return (randi() % 100) < 40


func resolve_ai_check_lane_with_visuals(lane: String) -> void:
	var back_slot: Node = find_slot_by_owner_row_lane("player", "back", lane)
	var back_card: CardData = get_slot_card_data(back_slot)

	if back_slot == null or back_card == null or not bool(back_slot.get_meta("face_down", false)):
		await resolve_ai_pass_lane_with_visuals(lane)
		return

	back_slot.set_meta("interacted_this_round", true)

	if back_slot.has_method("reveal_card"):
		back_slot.reveal_card()

	log_msg("AI checks your hidden back-row card in the " + lane + " lane.")
	await get_tree().create_timer(BLUFF_REVEAL_DELAY).timeout

	if is_gambit_card(back_card):
		add_aurion("ai", 1, "Successful Check: " + back_card.card_name + " was a Gambit.")
		log_msg("AI Check successful. Your Gambit is denied and discarded. AI keeps priority in this lane.")
		send_slot_card_to_discard(back_slot)
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		set_lane_priority_to_ai(lane)
		await resolve_ai_current_priority_lane(lane)
		return

	add_aurion("player", 1, "AI failed Check: " + back_card.card_name + " was a decoy.")
	player_fortified_lanes[lane] = true
	# Failed Check spends the checker’s lane action. If Player declines to attack and passes, the lane ends.
	ai_passed_current_lane = true
	log_msg("AI Check failed. Your decoy returns to hand. Player is fortified and gains priority in this lane.")
	return_setup_card(back_slot, back_card, "player")
	await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
	set_lane_priority_to_player(lane)


func resolve_ai_attack_lane_with_visuals(lane: String) -> void:
	var ai_front_slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)
	var player_front_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)
	var player_back_slot: Node = find_slot_by_owner_row_lane("player", "back", lane)

	var ai_card: CardData = get_slot_card_data(ai_front_slot)
	var player_front_card: CardData = get_slot_card_data(player_front_slot)
	var player_back_card: CardData = get_slot_card_data(player_back_slot)
	var player_back_is_face_down: bool = player_back_card != null and player_back_slot != null and bool(player_back_slot.get_meta("face_down", false))

	if not is_unit_card(ai_card):
		await resolve_ai_pass_lane_with_visuals(lane)
		return

	# Hidden back-row cards must be resolved before AI can hit the Monarch.
	if player_back_is_face_down:
		player_back_slot.set_meta("interacted_this_round", true)
		if not is_gambit_card(player_back_card) and get_card_insight_ability(player_back_card, &"stealth") != null:
			if resolve_stealth_hidden_decoy(player_back_slot, player_back_card, "player", lane):
				await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
				await advance_combat_lane_after_resolution()
				return

		if player_back_slot.has_method("reveal_card"):
			player_back_slot.reveal_card()

		log_msg("AI attacks into your hidden back-row card in the " + lane + " lane.")
		await get_tree().create_timer(BLUFF_REVEAL_DELAY).timeout

		if is_gambit_card(player_back_card):
			log_msg("AI Attack failed: " + player_back_card.card_name + " was your hidden Gambit.")
			resolve_immediate_hidden_gambit_cast(player_back_card, "player", lane)
			send_slot_card_to_discard(player_back_slot)
			await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
			await advance_combat_lane_after_resolution()
			return

		add_aurion("ai", 1, "Successful Attack read: " + player_back_card.card_name + " was not a Gambit.")
		log_msg("AI Attack read correctly. Your decoy is discarded. AI keeps priority in this lane.")
		send_slot_card_to_discard(player_back_slot)
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		set_lane_priority_to_ai(lane)
		await resolve_ai_current_priority_lane(lane)
		return

	# Phase 13: once no hidden back row protects the lane, an empty player front row is an open Monarch.
	if player_front_card == null:
		log_msg("AI takes open-lane Monarch Strike in the " + lane + " lane.")
		resolve_ai_monarch_strike(lane, ai_card)
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		await advance_combat_lane_after_resolution()
		return

	# AI is the active attacker here, regardless of who had the original Battleplan initiative.
	resolve_directed_clash(lane, ai_front_slot, ai_card, player_front_slot, player_front_card, false)

	if parry_system.active:
		return

	await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
	await advance_combat_lane_after_resolution()

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


func check_from_board_action_menu(slot: Node) -> void:
	if combat_resolution_running:
		log_msg("Combat is already resolving. Wait for the current lane.")
		return

	if slot == null:
		return

	if current_phase != BattlePhase.COMBAT:
		log_msg("Check is only available during Combat.")
		return

	if parry_system.active:
		log_msg("Resolve the current parry prompt first.")
		return

	var lane: String = get_slot_lane(slot)

	if lane == "":
		return

	if not can_player_check_lane_from_menu(lane):
		log_msg("Check requires your front-row unit and player priority in the current combat lane.")
		return

	await resolve_player_check_lane_with_visuals(lane)

func resolve_player_check_lane_with_visuals(lane: String) -> void:
	if combat_resolution_running:
		return

	combat_resolution_running = true

	if not prepare_player_lane_action(lane):
		combat_resolution_running = false
		return

	player_passed_current_lane = false
	set_active_combat_lane_highlight(lane)
	log_msg("Checking hidden back-row card in the " + lane + " lane.")
	await get_tree().create_timer(COMBAT_LANE_START_DELAY).timeout

	var back_slot: Node = find_slot_by_owner_row_lane("enemy", "back", lane)
	var back_card: CardData = get_slot_card_data(back_slot)

	if back_slot == null or back_card == null or not bool(back_slot.get_meta("face_down", false)):
		log_msg(lane.capitalize() + " lane: no face-down back-row card to check.")
		combat_resolution_running = false
		return

	back_slot.set_meta("interacted_this_round", true)

	if back_slot.has_method("reveal_card"):
		back_slot.reveal_card()

	await get_tree().create_timer(BLUFF_REVEAL_DELAY).timeout

	if is_gambit_card(back_card):
		add_aurion("player", 1, "Successful Check: " + back_card.card_name + " was a Gambit.")
		log_msg("Check successful. Gambit is denied and discarded. Player keeps priority in this lane.")
		send_slot_card_to_discard(back_slot)
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		set_lane_priority_to_player(lane)
		combat_resolution_running = false
		return

	add_aurion("ai", 1, "Failed Check: " + back_card.card_name + " was a decoy.")
	enemy_fortified_lanes[lane] = true
	# Failed Check spends the checker’s lane action. If AI declines to attack and passes, the lane ends.
	player_passed_current_lane = true
	log_msg("Check failed. Decoy returns to enemy hand. Enemy is fortified and gains priority in this lane.")
	return_setup_card(back_slot, back_card, "enemy")
	await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
	set_lane_priority_to_ai(lane)
	await resolve_ai_current_priority_lane(lane)
	combat_resolution_running = false

func prepare_player_lane_action(lane: String) -> bool:
	if lane == "":
		return false

	if not combat_direction_selected:
		if not player_has_initiative and combat_priority_owner != "player":
			log_msg("AI has initiative. You cannot choose the starting lane yet.")
			return false

		if lane == "left":
			set_combat_lane_order_from_left()
		elif lane == "right":
			set_combat_lane_order_from_right()
		else:
			log_msg("Choose the leftmost or rightmost lane first to set combat direction.")
			return false

	if combat_next_lane_index >= combat_lane_order.size():
		log_msg("All combat lanes are already resolved.")
		return false

	var expected_lane: String = combat_lane_order[combat_next_lane_index]

	if lane != expected_lane:
		log_msg("Next combat must resolve in the " + expected_lane + " lane.")
		return false

	if combat_priority_owner != "player":
		log_msg("AI has priority in the " + lane + " lane. You can act after AI passes or resolves its action.")
		return false

	return true

func return_setup_card(slot: Node, card_data: CardData, owner_name: String) -> void:
	if slot == null or card_data == null:
		return

	if slot.has_method("clear_slot"):
		slot.clear_slot()

	if owner_name == "enemy":
		ai_hand.append(card_data)
		update_ai_visuals()
		return

	if hand != null:
		hand.add_card_to_hand(card_data)


func resolve_immediate_hidden_gambit_cast(gambit_card: CardData, caster_owner: String, lane: String) -> void:
	if gambit_card == null:
		return

	var caster_label: String = "Defender"
	var clean_owner: String = caster_owner.to_lower().strip_edges()

	if clean_owner == "enemy" or clean_owner == "ai" or clean_owner == "opponent":
		caster_label = "Enemy"
	elif clean_owner == "player":
		caster_label = "Player"

	log_msg(caster_label + " casts " + gambit_card.card_name + " immediately from the " + lane + " lane.")
	log_msg("Prototype: " + gambit_card.card_name + " effect hook is ready, but this Gambit effect is not implemented yet.")


func resolve_attack_into_face_down_backrow(
	lane: String,
	_attacker_card: CardData,
	_enemy_front_slot: Node,
	enemy_back_slot: Node,
	enemy_back_card: CardData
) -> void:
	if enemy_back_slot == null or enemy_back_card == null:
		return

	enemy_back_slot.set_meta("interacted_this_round", true)

	if enemy_back_slot.has_method("reveal_card"):
		enemy_back_slot.reveal_card()

	await get_tree().create_timer(BLUFF_REVEAL_DELAY).timeout

	if is_gambit_card(enemy_back_card):
		log_msg("Attack failed: " + enemy_back_card.card_name + " was a hidden Gambit.")
		resolve_immediate_hidden_gambit_cast(enemy_back_card, "enemy", lane)
		send_slot_card_to_discard(enemy_back_slot)
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		await advance_combat_lane_after_resolution()
		return

	if resolve_stealth_hidden_decoy(enemy_back_slot, enemy_back_card, "enemy", lane):
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		set_lane_priority_to_player(lane)
		log_msg("Right-click the " + lane + " lane again to attack the front row, Monarch, or Pass.")
		return

	add_aurion("player", 1, "Successful Attack read: " + enemy_back_card.card_name + " was not a Gambit.")
	log_msg("Attack read correctly: " + enemy_back_card.card_name + " was not a Gambit. Decoy is discarded. Player keeps priority in this lane.")
	send_slot_card_to_discard(enemy_back_slot)
	await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
	set_lane_priority_to_player(lane)
	log_msg("Right-click the " + lane + " lane again to attack the front row, Monarch, or Pass.")
