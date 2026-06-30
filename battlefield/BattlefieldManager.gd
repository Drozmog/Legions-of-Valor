class_name BattlefieldManager
extends Node3D

signal insight_gambit_slot_chosen(slot: Node)
signal stealth_deployment_slot_chosen(slot: Node)
signal mobility_slot_chosen(slot: Node)
signal mobility_choice_made(accepted: bool)

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


# BEGIN MOBILITY CLEANUP CONSTANTS
const ABILITY_ICON_POLISHED_META := "ability_icon_hover_polished"
const ABILITY_HOVER_BOX_SIZE := Vector3(0.34, 0.22, 0.34)
const ABILITY_TOOLTIP_OFFSET := Vector2(-370.0, -122.0)
const ABILITY_TOOLTIP_SCREEN_MARGIN := 12.0
const MOBILITY_PROMPT_ICON_PATH := "res://ui/ability_icons/mobility.png"
const PROTECTION_PROMPT_ICON_PATH := "res://ui/ability_icons/protection.png"
const CONTROL_PROMPT_ICON_PATH := "res://ui/ability_icons/control.png"
const MOBILITY_PROMPT_CENTER_Y: float = 0.385
const MOBILITY_CHOICE_PANEL_WIDTH := 360.0
const MOBILITY_CHOICE_PANEL_HEIGHT := 58.0
const MOBILITY_CHOICE_PANEL_Y_OFFSET := 92.0
# END MOBILITY CLEANUP CONSTANTS

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

var opening_hand_deal_active := false
var phase_tip_panel: PhaseTipPanel = null

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

var phase_title_interaction_locked := false

var discard_warning_overlay: Label = null
var discard_warning_backdrop: ColorRect = null
var discard_warning_detail: Label = null

var turn_label: Label = null

var turn_number: int = 1

var deck_selection_screen: DeckSelectionScreen = null
const DECK_SELECTION_CONTEXT_PLAYER := "player"
const DECK_SELECTION_CONTEXT_AI := "ai"

const AI_DECK_SOURCE_FALLBACK := "fallback"
const AI_DECK_SOURCE_RANDOM_SYNERGY := "random_synergy"
const AI_DECK_SOURCE_SAVED := "saved"

const AI_DECK_OPTION_RANDOM_SYNERGY := -2

var deck_selection_context: String = DECK_SELECTION_CONTEXT_PLAYER
var ai_deck_source_mode: String = AI_DECK_SOURCE_FALLBACK
var ai_selected_saved_deck_slot: int = -1

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

var blurred_modal_input_depth := 0

var blurred_modal_hand_filters: Array[Dictionary] = []

var insight_gambit_selection_active := false

var insight_gambit_candidate_slots: Array[Node] = []

var pending_stealth_deployments: Array[Dictionary] = []

var stealth_deployment_selection_slot: Node = null

var mobility_selection_active := false

var mobility_candidate_slots: Array[Node] = []
var mobility_choice_panel: PanelContainer = null
var used_mobility_ability_keys: Dictionary = {}
var ability_tooltip_panel: PanelContainer = null
var ability_tooltip_label: Label = null

var inspected_faded_slots: Array[Node] = []

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
@export_enum("Novice", "Soldier", "Commander", "Warlord", "Grandmaster")
var ai_difficulty: int = AI_DIFFICULTY_COMMANDER

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
var ai_random_deck_builder: AIRandomDeckBuilder = null
var ai_controller: BattlefieldAIController = null
var phase_controller: BattlefieldPhaseController = null
var interaction_controller: BattlefieldInteractionController = null
var combat_controller: BattlefieldCombatController = null
var ability_controller: BattlefieldAbilityController = null
var control_controller: BattlefieldControlController = null
var deployment_controller: BattlefieldDeploymentController = null

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

const AI_DIFFICULTY_NOVICE := 0
const AI_DIFFICULTY_SOLDIER := 1
const AI_DIFFICULTY_COMMANDER := 2
const AI_DIFFICULTY_WARLORD := 3
const AI_DIFFICULTY_GRANDMASTER := 4

var enemy_fortified_lanes: Dictionary = {}

var player_fortified_lanes: Dictionary = {}

var combat_priority_owner: String = ""

var original_combat_priority_owner: String = ""

var player_passed_current_lane: bool = false

var ai_passed_current_lane: bool = false
var used_active_insight_ability_keys: Dictionary = {}
var used_active_control_ability_keys: Dictionary = {}
var control_disabled_lane_turns: Dictionary = {}
var control_no_parry_turns: Dictionary = {}
var control_handicap_turns: Dictionary = {}
var ai_memory_player_hidden_cards_seen: int = 0
var ai_memory_player_hidden_gambits_seen: int = 0
var ai_memory_player_hidden_decoys_seen: int = 0

var ai_memory_player_checks_seen: int = 0
var ai_memory_player_successful_checks: int = 0
var ai_memory_player_failed_checks: int = 0

var ai_memory_player_attacks_into_hidden: int = 0
var ai_memory_player_triggered_hidden_gambits: int = 0

var ai_memory_player_lane_pressure: Dictionary = {
	"left": 0,
	"middle": 0,
	"right": 0
}

var ai_memory_player_backrow_pressure: Dictionary = {
	"left": 0,
	"middle": 0,
	"right": 0
}

var ai_debug_panel: AIDebugPanel = null

var ai_last_tribute_decision: String = "None"
var ai_last_deployment_decision: String = "None"
var ai_last_active_ability_decision: String = "None"
var ai_last_combat_decision: String = "None"
var ai_active_ability_lane_attempt_keys: Dictionary = {}
var ai_active_ability_turn_use_counts: Dictionary = {}


# === Functions ===


func apply_ai_difficulty_from_menu() -> void:
	ai_difficulty = clampi(
		PrototypeMenu.selected_ai_difficulty,
		AI_DIFFICULTY_NOVICE,
		AI_DIFFICULTY_GRANDMASTER
	)


func _ready() -> void:
	randomize()
	phase_controller = BattlefieldPhaseController.new(self)
	interaction_controller = BattlefieldInteractionController.new(self)
	combat_controller = BattlefieldCombatController.new(self)
	ability_controller = BattlefieldAbilityController.new(self)
	control_controller = BattlefieldControlController.new(self)
	deployment_controller = BattlefieldDeploymentController.new(self)
	ai_controller = BattlefieldAIController.new(self)
	apply_ai_difficulty_from_menu()
	ai_random_deck_builder = AIRandomDeckBuilder.new(Callable(self, "log_msg"))
	parry_system = ParrySystem.new()
	parry_system.name = "ParrySystem"
	add_child(parry_system)
	parry_system.setup(self)
	connect_all_slots()
	connect_main_signals()
	create_player_hand_3d()
	create_phase_ui()
	create_ability_tooltip_ui()
	create_bottom_hud_3d()
	create_phase_tip_panel()
	create_exit_button()
	create_deck_selection_screen()
	create_ability_prompt_panel()
	create_insight_presenter()
	create_debug_tp_button()
	set_phase(BattlePhase.BATTLEPLAN)
	setup_deck_selection_flow()
	create_spell_choice_panel()
	create_aurion_counter_ui()
	create_ai_debug_panel()
	disable_keyboard_focus_for_all_buttons($UI)
	create_board_slot_action_menu()
	create_board_slot_action_buttons()
	patch_game_log_for_scrolling()
	set_process(true)


func _process(delta: float) -> void:
	if phase_tip_panel != null:
		phase_tip_panel.update_for_battlefield(delta)
	update_hand_drag_preview(delta)
	update_battleplan_hand_cleanup(delta)
	update_discard_warning_overlay()
	update_phase_progress_state()
	try_auto_advance_combat_phase()
	refresh_bottom_hud_log()
	refresh_board_slot_action_buttons()
	refresh_player_usable_ability_icons()
	update_ai_debug_panel()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey

		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F8:
			if ai_debug_panel != null:
				ai_debug_panel.toggle()

			get_viewport().set_input_as_handled()


func create_ai_debug_panel() -> void:
	if ai_debug_panel != null:
		return
	ai_debug_panel = AIDebugPanel.new()
	ai_debug_panel.setup(self)
	$UI.add_child(ai_debug_panel)


func update_ai_debug_panel() -> void:
	if ai_debug_panel != null:
		ai_debug_panel.refresh()


func ai_get_difficulty_name() -> String:
	return ai_controller.ai_get_difficulty_name()


func ai_get_phase_name() -> String:
	return ai_controller.ai_get_phase_name()


func ai_get_difficulty_profile() -> Dictionary:
	return ai_controller.ai_get_difficulty_profile()


func ai_get_active_ability_lane_attempt_key(lane: String) -> String:
	return ai_controller.ai_get_active_ability_lane_attempt_key(lane)


func ai_get_active_ability_turn_key() -> String:
	return ai_controller.ai_get_active_ability_turn_key()


func ai_max_active_ability_uses_per_turn() -> int:
	return ai_controller.ai_max_active_ability_uses_per_turn()


func ai_can_try_active_ability_in_lane(lane: String) -> bool:
	return ai_controller.ai_can_try_active_ability_in_lane(lane)


func ai_mark_active_ability_lane_attempted(lane: String) -> void:
	ai_controller.ai_mark_active_ability_lane_attempted(lane)


func ai_mark_active_ability_turn_used() -> void:
	ai_controller.ai_mark_active_ability_turn_used()


func ai_is_supported_ai_active_mobility(handler_id: StringName) -> bool:
	return ai_controller.ai_is_supported_ai_active_mobility(handler_id)


func ai_can_place_back_row_in_lane(owner_name: String, lane: String) -> bool:
	return ai_controller.ai_can_place_back_row_in_lane(owner_name, lane)


func ai_get_empty_legal_enemy_back_slots() -> Array[Node]:
	return ai_controller.ai_get_empty_legal_enemy_back_slots()


func ai_min_deployment_score() -> int:
	return ai_controller.ai_min_deployment_score()


func ai_memory_decay_amount() -> int:
	return ai_controller.ai_memory_decay_amount()


func ai_decay_memory_dictionary_values(memory_dict: Dictionary, amount: int) -> Dictionary:
	return ai_controller.ai_decay_memory_dictionary_values(memory_dict, amount)


func ai_decay_player_memory_pressure() -> void:
	ai_controller.ai_decay_player_memory_pressure()


func create_phase_tip_panel() -> void:
	phase_tip_panel = PhaseTipPanel.new()
	phase_tip_panel.name = "PhaseTipPanel"
	$UI.add_child(phase_tip_panel)
	phase_tip_panel.setup(self)


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
	deck_selection_screen.deck_selected.connect(_on_deck_selection_screen_selected)
	$UI.add_child(deck_selection_screen)


func _on_deck_selection_screen_selected(slot_index: int) -> void:
	await phase_controller._on_deck_selection_screen_selected(slot_index)


func setup_deck_selection_flow() -> void:
	phase_controller.setup_deck_selection_flow()


func _on_prebattle_deck_selected(slot_index: int) -> void:
	await phase_controller._on_prebattle_deck_selected(slot_index)


func show_ai_deck_selection() -> void:
	phase_controller.show_ai_deck_selection()


func _on_ai_deck_selected(slot_index: int) -> void:
	await phase_controller._on_ai_deck_selected(slot_index)


func setup_battle_plan_flow() -> void:
	phase_controller.setup_battle_plan_flow()


func open_battle_plan_selection() -> void:
	await phase_controller.open_battle_plan_selection()


func _on_battle_plan_selected(plan: Dictionary) -> void:
	await phase_controller._on_battle_plan_selected(plan)


func choose_opponent_battle_plan() -> void:
	phase_controller.choose_opponent_battle_plan()


func apply_battle_plan_rules(plan: Dictionary) -> void:
	phase_controller.apply_battle_plan_rules(plan)


func apply_initiative_rules(plan: Dictionary) -> void:
	phase_controller.apply_initiative_rules(plan)


func draw_battleplan_cards(plan: Dictionary) -> void:
	phase_controller.draw_battleplan_cards(plan)


func begin_battleplan_hand_cleanup_or_tribute() -> void:
	phase_controller.begin_battleplan_hand_cleanup_or_tribute()


func update_battleplan_hand_cleanup(delta: float) -> void:
	phase_controller.update_battleplan_hand_cleanup(delta)


func finish_battleplan_prephase() -> void:
	phase_controller.finish_battleplan_prephase()


func begin_game_after_battle_plan_selection() -> void:
	await phase_controller.begin_game_after_battle_plan_selection()


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
	phase_blur_backdrop.anchor_left = 0.0
	phase_blur_backdrop.anchor_right = 1.0
	phase_blur_backdrop.anchor_top = 0.5
	phase_blur_backdrop.anchor_bottom = 0.5
	phase_blur_backdrop.offset_left = 0.0
	phase_blur_backdrop.offset_top = -62.0
	phase_blur_backdrop.offset_right = 0.0
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
	float edge_y = smoothstep(0.0, 0.28, UV.y) * smoothstep(0.0, 0.28, 1.0 - UV.y);
	float soft_mask = edge_y;
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

	discard_warning_backdrop = ColorRect.new()
	discard_warning_backdrop.name = "DiscardWarningBackdrop"
	discard_warning_backdrop.anchor_right = 1.0
	discard_warning_backdrop.anchor_top = 0.40
	discard_warning_backdrop.anchor_bottom = 0.60
	discard_warning_backdrop.color = Color(0.015, 0.018, 0.025, 0.68)
	discard_warning_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var discard_blur_material := phase_blur_material.duplicate() as ShaderMaterial
	discard_blur_material.set_shader_parameter("blur_lod", 2.35)
	discard_warning_backdrop.material = discard_blur_material
	discard_warning_backdrop.visible = false
	discard_warning_backdrop.z_index = 121
	$UI.add_child(discard_warning_backdrop)

	discard_warning_overlay = Label.new()
	discard_warning_overlay.name = "DiscardWarningOverlay"
	discard_warning_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	discard_warning_overlay.offset_bottom = -28.0
	discard_warning_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	discard_warning_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_warning_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	discard_warning_overlay.add_theme_font_size_override("font_size", 30)
	discard_warning_overlay.add_theme_color_override("font_color", Color.WHITE)
	discard_warning_overlay.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	discard_warning_overlay.add_theme_constant_override("shadow_offset_x", 2)
	discard_warning_overlay.add_theme_constant_override("shadow_offset_y", 3)
	discard_warning_overlay.add_theme_constant_override("shadow_outline_size", 5)
	discard_warning_overlay.visible = false
	discard_warning_overlay.z_index = 122
	$UI.add_child(discard_warning_overlay)

	discard_warning_detail = Label.new()
	discard_warning_detail.name = "DiscardWarningDetail"
	discard_warning_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	discard_warning_detail.offset_top = 42.0
	discard_warning_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	discard_warning_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_warning_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	discard_warning_detail.add_theme_font_size_override("font_size", 42)
	discard_warning_detail.add_theme_color_override("font_color", Color(1.0, 0.14, 0.12, 1.0))
	discard_warning_detail.add_theme_color_override("font_outline_color", Color(0.10, 0.0, 0.0, 0.95))
	discard_warning_detail.add_theme_constant_override("outline_size", 3)
	discard_warning_detail.visible = false
	discard_warning_detail.z_index = 122
	$UI.add_child(discard_warning_detail)


func show_phase_title(title: String) -> void:
	if phase_title_overlay == null or phase_blur_backdrop == null or phase_blur_material == null:
		return
	if phase_title_tween != null and phase_title_tween.is_valid():
		phase_title_tween.kill()
	if not phase_title_interaction_locked:
		phase_title_interaction_locked = true
		set_blurred_modal_input_blocked(true)
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
	phase_title_tween.tween_callback(_finish_phase_title_interaction_lock)


func _finish_phase_title_interaction_lock() -> void:
	if not phase_title_interaction_locked:
		return
	phase_title_interaction_locked = false
	set_blurred_modal_input_blocked(false)


func choose_mobility_slot(
	candidates: Array[Node],
	prompt: String,
	icon_path: String = MOBILITY_PROMPT_ICON_PATH,
	description: String = ""
) -> Node:
	if candidates.is_empty():
		return null
	mobility_candidate_slots = candidates.duplicate()
	mobility_selection_active = true
	for slot in mobility_candidate_slots:
		if slot != null and slot.has_method("set_mobility_highlight"):
			slot.call("set_mobility_highlight", true)
	var display_text := prompt
	if description.strip_edges() != "":
		display_text += "\n" + description.strip_edges()
	show_mobility_prompt(display_text, icon_path)
	var chosen: Node = await mobility_slot_chosen
	for slot in mobility_candidate_slots:
		if slot != null and slot.has_method("set_mobility_highlight"):
			slot.call("set_mobility_highlight", false)
	mobility_candidate_slots.clear()
	mobility_selection_active = false
	await hide_mobility_prompt()
	return chosen


func show_mobility_prompt(text: String, icon_path: String = MOBILITY_PROMPT_ICON_PATH) -> void:
	if not phase_title_interaction_locked:
		phase_title_interaction_locked = true
		set_blurred_modal_input_blocked(true)
	phase_title_overlay.text = ""
	phase_title_overlay.modulate.a = 0.0
	phase_blur_backdrop.anchor_top = MOBILITY_PROMPT_CENTER_Y
	phase_blur_backdrop.anchor_bottom = MOBILITY_PROMPT_CENTER_Y
	phase_blur_backdrop.modulate.a = 0.0
	phase_blur_material.set_shader_parameter("blur_lod", 0.0)
	var row_root := get_or_create_mobility_prompt_row()
	var row_label := row_root.get_node_or_null("CenterRow/PromptLabel") as Label
	var row_icon := row_root.get_node_or_null("CenterRow/PromptIcon") as TextureRect
	if row_icon != null and ResourceLoader.exists(icon_path):
		row_icon.texture = load(icon_path) as Texture2D
	if row_label != null:
		row_label.text = text
		var multiline := text.contains("\n")
		row_label.add_theme_font_size_override("font_size", 22 if multiline else (32 if text.length() > 24 else 44))
	row_root.visible = true
	row_root.modulate.a = 0.0
	phase_title_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	phase_title_tween.tween_property(phase_blur_backdrop, "modulate:a", 0.92, 0.28)
	phase_title_tween.parallel().tween_property(row_root, "modulate:a", 1.0, 0.28)
	phase_title_tween.parallel().tween_method(set_phase_blur_amount, 0.0, 2.5, 0.28)

func hide_mobility_prompt() -> void:
	var row_root := get_node_or_null("UI/MobilityPromptRow") as Control
	phase_title_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	phase_title_tween.tween_property(phase_blur_backdrop, "modulate:a", 0.0, 0.28)
	if row_root != null:
		phase_title_tween.parallel().tween_property(row_root, "modulate:a", 0.0, 0.28)
	phase_title_tween.parallel().tween_method(set_phase_blur_amount, 2.5, 0.0, 0.28)
	await phase_title_tween.finished
	if row_root != null:
		row_root.visible = false
	phase_blur_backdrop.anchor_top = 0.5
	phase_blur_backdrop.anchor_bottom = 0.5
	_finish_phase_title_interaction_lock()

func set_phase_blur_amount(amount: float) -> void:
	if phase_blur_material != null:
		phase_blur_material.set_shader_parameter("blur_lod", amount)


func update_discard_warning_overlay() -> void:
	if discard_warning_overlay == null:
		return
	var discard_count := 0
	if battleplan_hand_cleanup_active and hand != null:
		discard_count = maxi(hand.cards.size() - hand.max_hand_size, 0)
	var should_show := discard_count > 0
	discard_warning_overlay.visible = should_show
	if discard_warning_backdrop != null:
		discard_warning_backdrop.visible = should_show
	if discard_warning_detail != null:
		discard_warning_detail.visible = should_show
	if discard_count > 0:
		discard_warning_overlay.text = "HAND LIMIT"
		var seconds_left := maxi(int(ceil(battleplan_discard_time_left)), 0)
		discard_warning_detail.text = "Discard %d Cards   %02ds" % [discard_count, seconds_left]


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
	exit_button.pressed.connect(return_to_menu_without_intro)
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


func set_blurred_modal_input_blocked(blocked: bool) -> void:
	blurred_modal_input_depth = maxi(blurred_modal_input_depth + (1 if blocked else -1), 0)
	var should_block := blurred_modal_input_depth > 0
	if blocked and blurred_modal_input_depth == 1:
		blurred_modal_hand_filters.clear()
		_set_control_tree_mouse_blocked(hand, true)
	elif not should_block:
		for state in blurred_modal_hand_filters:
			var control_variant: Variant = state.get("control", null)

			if control_variant == null:
				continue

			if not is_instance_valid(control_variant):
				continue

			if control_variant is Control:
				var control := control_variant as Control
				control.mouse_filter = int(state.get("mouse_filter", Control.MOUSE_FILTER_STOP))

		blurred_modal_hand_filters.clear()
	if bottom_hud_3d != null and bottom_hud_3d.has_method("set_modal_blocked"):
		bottom_hud_3d.call("set_modal_blocked", should_block)
	var exit_button := get_node_or_null("UI/ExitBattleButton") as Button
	if exit_button != null:
		exit_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if should_block else Control.MOUSE_FILTER_STOP


func _set_control_tree_mouse_blocked(node: Node, blocked: bool) -> void:
	if node == null or not blocked:
		return
	if node is Control:
		var control := node as Control
		blurred_modal_hand_filters.append({"control": control, "mouse_filter": control.mouse_filter})
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_control_tree_mouse_blocked(child, true)


func _on_ability_choice_made(use_ability: bool, card_data: CardData, ability_text: String) -> void:
	if card_data == null:
		return
	if use_ability:
		log_msg("Used chosen ability: " + card_data.card_name)
		log_msg(ability_text)
	else:
		log_msg("Skipped chosen ability: " + card_data.card_name)


func set_phase(new_phase: int) -> void:
	phase_controller.set_phase(new_phase)


func get_phase_name(phase: int) -> String:
	return phase_controller.get_phase_name(phase)


func begin_deployment_phase() -> void:
	await phase_controller.begin_deployment_phase()


func run_ai_deployment_turn_if_needed() -> void:
	await phase_controller.run_ai_deployment_turn_if_needed()


func begin_combat_phase() -> void:
	await phase_controller.begin_combat_phase()


func update_phase_ui() -> void:
	phase_controller.update_phase_ui()


func update_phase_progress_state() -> void:
	phase_controller.update_phase_progress_state()


func is_current_phase_complete() -> bool:
	return phase_controller.is_current_phase_complete()


func try_auto_advance_combat_phase() -> void:
	phase_controller.try_auto_advance_combat_phase()


func is_prebattle_modal_open() -> bool:
	return phase_controller.is_prebattle_modal_open()


func player_has_remaining_deployment_move() -> bool:
	return phase_controller.player_has_remaining_deployment_move()


func set_phase_button_ready_visual(ready: bool) -> void:
	phase_controller.set_phase_button_ready_visual(ready)


func update_phase_instruction_ui() -> void:
	phase_controller.update_phase_instruction_ui()


func get_phase_instruction_text() -> String:
	return phase_controller.get_phase_instruction_text()


func _on_next_phase_pressed() -> void:
	await phase_controller._on_next_phase_pressed()


func start_next_round() -> void:
	await phase_controller.start_next_round()


func resolve_pending_stealth_deployments() -> void:
	await phase_controller.resolve_pending_stealth_deployments()


func queue_surviving_stealth_deployments() -> void:
	phase_controller.queue_surviving_stealth_deployments()


func reset_combat_state() -> void:
	combat_controller.reset_combat_state()


func connect_all_slots() -> void:
	if board_slots == null:
		return
	for slot in board_slots.get_children():
		if slot.has_signal("slot_clicked"):
			slot.slot_clicked.connect(_on_slot_clicked)
		if slot.has_signal("slot_right_clicked"):
			slot.slot_right_clicked.connect(_on_slot_right_clicked)
		if slot.has_signal("equipment_inspect_requested"):
			slot.equipment_inspect_requested.connect(_on_equipment_inspect_requested)


func _on_hand_card_drag_started(card: CardUI) -> void:
	interaction_controller._on_hand_card_drag_started(card)


func _on_hand_card_drag_released(card: CardUI, screen_position: Vector2) -> void:
	await interaction_controller._on_hand_card_drag_released(card, screen_position)


func start_hand_drag_preview(card: CardUI) -> void:
	interaction_controller.start_hand_drag_preview(card)


func update_hand_drag_preview(delta: float) -> void:
	interaction_controller.update_hand_drag_preview(delta)


func finish_hand_drag_preview() -> void:
	interaction_controller.finish_hand_drag_preview()


func disable_preview_collision(node: Node) -> void:
	interaction_controller.disable_preview_collision(node)


func screen_to_battle_plane(screen_position: Vector2, plane_y: float) -> Vector3:
	return interaction_controller.screen_to_battle_plane(screen_position, plane_y)


func deal_starting_hand() -> void:
	await interaction_controller.deal_starting_hand()


func _on_draw_pile_drag_started(screen_position: Vector2) -> void:
	interaction_controller._on_draw_pile_drag_started(screen_position)


func _on_draw_pile_drag_moved(screen_position: Vector2) -> void:
	interaction_controller._on_draw_pile_drag_moved(screen_position)


func _on_draw_pile_drag_released(screen_position: Vector2) -> void:
	interaction_controller._on_draw_pile_drag_released(screen_position)


func _on_equipment_inspect_requested(slot: Node, equipment_card: CardData) -> void:
	interaction_controller._on_equipment_inspect_requested(slot, equipment_card)


func _on_slot_clicked(slot: Node) -> void:
	interaction_controller._on_slot_clicked(slot)


func _on_slot_right_clicked(slot: Node) -> void:
	interaction_controller._on_slot_right_clicked(slot)


func _on_tribute_pile_clicked() -> void:
	interaction_controller._on_tribute_pile_clicked()


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
	interaction_controller.debug_draw_card()


func debug_tribute_selected_card() -> void:
	interaction_controller.debug_tribute_selected_card()


func select_card(card_data: CardData) -> void:
	deployment_controller.select_card(card_data)


func cancel_selected_card() -> void:
	deployment_controller.cancel_selected_card()


func try_place_selected_card_on_slot(slot: Node) -> bool:
	return deployment_controller.try_place_selected_card_on_slot(slot)


func try_sacrifice_selected_card_to_tribute() -> bool:
	return deployment_controller.try_sacrifice_selected_card_to_tribute()


func get_clean_card_race(card_data: CardData) -> String:
	return deployment_controller.get_clean_card_race(card_data)


func should_skip_player_faction_gate_for_slot(card_data: CardData, slot: Node) -> bool:
	return deployment_controller.should_skip_player_faction_gate_for_slot(card_data, slot)


func player_card_passes_faction_gate(card_data: CardData, show_log: bool = false) -> bool:
	return deployment_controller.player_card_passes_faction_gate(card_data, show_log)


func ai_card_passes_faction_gate(card_data: CardData, show_log: bool = false) -> bool:
	return ai_controller.ai_card_passes_faction_gate(card_data, show_log)


func can_promote_selected_card_on_slot(slot: Node) -> bool:
	return deployment_controller.can_promote_selected_card_on_slot(slot)


func try_promote_selected_card_on_slot(slot: Node) -> bool:
	return deployment_controller.try_promote_selected_card_on_slot(slot)


func is_valid_slot_for_selected_card(slot: Node) -> bool:
	return deployment_controller.is_valid_slot_for_selected_card(slot)


func can_place_selected_equipment_face_down(slot: Node) -> bool:
	return deployment_controller.can_place_selected_equipment_face_down(slot)


func update_slot_highlights() -> void:
	deployment_controller.update_slot_highlights()


func handle_card_deployed(card_data: CardData, slot: Node = null) -> void:
	await ability_controller.handle_card_deployed(card_data, slot)


func resolve_mobility_deployment(card_data: CardData, slot: Node, owner_name: String = "player") -> bool:
	return await ability_controller.resolve_mobility_deployment(card_data, slot, owner_name)


func resolve_mobility_gambit_effect(ability: AbilityData, caster_owner: String) -> bool:
	return await ability_controller.resolve_mobility_gambit_effect(ability, caster_owner)


func resolve_imperial_decree(ability: AbilityData, caster_owner: String) -> bool:
	return await ability_controller.resolve_imperial_decree(ability, caster_owner)


func resolve_vortex(ability: AbilityData, caster_owner: String) -> bool:
	return await ability_controller.resolve_vortex(ability, caster_owner)


func resolve_reassign(ability: AbilityData) -> void:
	await ability_controller.resolve_reassign(ability)


func prompt_mobility_choice(text: String, accept_text: String, decline_text: String) -> bool:
	show_mobility_prompt(text)
	mobility_choice_panel = PanelContainer.new()
	mobility_choice_panel.name = "MobilityChoicePanel"
	mobility_choice_panel.z_index = 132
	mobility_choice_panel.anchor_left = 0.5
	mobility_choice_panel.anchor_right = 0.5
	mobility_choice_panel.anchor_top = 0.5
	mobility_choice_panel.anchor_bottom = 0.5
	mobility_choice_panel.offset_left = -MOBILITY_CHOICE_PANEL_WIDTH * 0.5
	mobility_choice_panel.offset_right = MOBILITY_CHOICE_PANEL_WIDTH * 0.5
	mobility_choice_panel.offset_top = MOBILITY_CHOICE_PANEL_Y_OFFSET
	mobility_choice_panel.offset_bottom = MOBILITY_CHOICE_PANEL_Y_OFFSET + MOBILITY_CHOICE_PANEL_HEIGHT
	mobility_choice_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.018, 0.025, 0.74)
	style.border_color = Color(0.48, 0.68, 1.0, 0.58)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	mobility_choice_panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	mobility_choice_panel.add_child(row)
	var accept := Button.new()
	accept.text = accept_text
	accept.focus_mode = Control.FOCUS_NONE
	accept.custom_minimum_size = Vector2(150.0, 48.0)
	accept.pressed.connect(func(): mobility_choice_made.emit(true))
	row.add_child(accept)
	var decline := Button.new()
	decline.text = decline_text
	decline.focus_mode = Control.FOCUS_NONE
	decline.custom_minimum_size = Vector2(150.0, 48.0)
	decline.pressed.connect(func(): mobility_choice_made.emit(false))
	row.add_child(decline)
	$UI.add_child(mobility_choice_panel)
	var result: bool = await mobility_choice_made
	mobility_choice_panel.queue_free()
	mobility_choice_panel = null
	await hide_mobility_prompt()
	return result

func show_timed_mobility_message(message: String) -> void:
	await ability_controller.show_timed_mobility_message(message)


func resolve_vanish_when_targeted(slot: Node, card_data: CardData, player_defender: bool) -> bool:
	return await ability_controller.resolve_vanish_when_targeted(slot, card_data, player_defender)


func return_board_card_to_hand(slot: Node, card_data: CardData, owner_name: String) -> void:
	await ability_controller.return_board_card_to_hand(slot, card_data, owner_name)


func animate_gambit_activation(slot: Node, card_data: CardData, return_to_hand: bool, owner_name: String = "player") -> void:
	await ability_controller.animate_gambit_activation(slot, card_data, return_to_hand, owner_name)


func resolve_insight_abilities(card_data: CardData, trigger: StringName, extra_context: Dictionary = {}) -> bool:
	return await ability_controller.resolve_insight_abilities(card_data, trigger, extra_context)


func resolve_insight_with_presentation(ability: AbilityData, extra_context: Dictionary = {}) -> Dictionary:
	return await ability_controller.resolve_insight_with_presentation(ability, extra_context)


func present_insight_cards(cards: Array[CardData], config: Dictionary) -> Dictionary:
	return await ability_controller.present_insight_cards(cards, config)


func pop_ai_deck_top_cards(count: int) -> Array[CardData]:
	return ability_controller.pop_ai_deck_top_cards(count)


func pop_player_deck_top_cards(count: int) -> Array[CardData]:
	return ability_controller.pop_player_deck_top_cards(count)


func peek_player_deck_top_cards(count: int) -> Array[CardData]:
	return ability_controller.peek_player_deck_top_cards(count)


func get_insight_world_position(source_name: String) -> Vector3:
	return ability_controller.get_insight_world_position(source_name)


func present_intel(ability: AbilityData) -> Dictionary:
	return await ability_controller.present_intel(ability)


func present_ai_deck_choice(ability: AbilityData) -> Dictionary:
	return await ability_controller.present_ai_deck_choice(ability)


func present_intelligence(ability: AbilityData) -> Dictionary:
	return await ability_controller.present_intelligence(ability)


func present_secrecy(ability: AbilityData) -> Dictionary:
	return await ability_controller.present_secrecy(ability)


func present_vision(ability: AbilityData) -> Dictionary:
	return await ability_controller.present_vision(ability)


func present_hidden_enemy_gambit_choice(ability: AbilityData) -> Dictionary:
	return await ability_controller.present_hidden_enemy_gambit_choice(ability)


func build_ability_context(extra_context: Dictionary = {}) -> Dictionary:
	return ability_controller.build_ability_context(extra_context)


func ability_requires_choice(card_data: CardData) -> bool:
	return ability_controller.ability_requires_choice(card_data)


func get_card_control_ability(card_data: CardData, ability_id: StringName) -> AbilityData:
	return control_controller.get_card_control_ability(card_data, ability_id)


func slot_has_control_ability(slot: Node, ability_id: StringName, include_equipment: bool = true) -> AbilityData:
	return control_controller.slot_has_control_ability(slot, ability_id, include_equipment)


func is_ability_suppressed_by_lockdown(slot: Node, trigger_name: String) -> bool:
	return control_controller.is_ability_suppressed_by_lockdown(slot, trigger_name)


func is_equipment_suppressed(slot: Node) -> bool:
	return control_controller.is_equipment_suppressed(slot)


func get_control_halt_source_against(owner_name: String) -> Dictionary:
	return control_controller.get_halt_source_against(owner_name)


func is_unit_chained_down(slot: Node) -> bool:
	return control_controller.is_unit_chained_down(slot)


func control_unit_must_attack(slot: Node) -> bool:
	return control_controller.unit_must_attack(slot)


func control_lane_attack_is_disabled(owner_name: String, lane: String) -> bool:
	return control_controller.lane_attack_is_disabled(owner_name, lane)


func control_owner_has_handicap(owner_name: String) -> bool:
	return control_controller.owner_has_handicap(owner_name)


func show_control_trigger(ability: AbilityData, detail: String = "", include_description: bool = false) -> void:
	await control_controller.show_control_trigger(ability, detail, include_description)


func resolve_control_deployment(card_data: CardData, slot: Node, owner_name: String = "player") -> bool:
	return await control_controller.resolve_control_deployment(card_data, slot, owner_name)


func resolve_hidden_control_gambit(card_data: CardData, owner_name: String, lane: String) -> bool:
	return await control_controller.resolve_hidden_control_gambit(card_data, owner_name, lane)


func add_active_control_actions_to_board_menu(slot: Node) -> void:
	control_controller.add_active_control_actions_to_board_menu(slot)


func can_activate_control_ability(slot: Node, ability: AbilityData) -> bool:
	return control_controller.can_activate_control_ability(slot, ability)


func activate_control_ability(slot: Node, ability: AbilityData, ai_owner: bool = false) -> bool:
	return await control_controller.activate_control_ability(slot, ability, ai_owner)


func ai_try_activate_control(lane: String) -> bool:
	return await control_controller.ai_try_activate_control(lane)


func control_can_parry(attacker_slot: Node, defender_slot: Node, attacker_ap: int, defender_ap: int) -> bool:
	return await control_controller.control_can_parry(attacker_slot, defender_slot, attacker_ap, defender_ap)


func resolve_ambush_from_parry(parry_cards: Array[CardData], owner_name: String) -> bool:
	return await control_controller.resolve_ambush_from_parry(parry_cards, owner_name)


func set_combat_lane_order_from_left() -> void:
	combat_controller.set_combat_lane_order_from_left()


func set_combat_lane_order_from_right() -> void:
	combat_controller.set_combat_lane_order_from_right()


func resolve_lane_combat(lane: String, player_slot: Node, opponent_slot: Node) -> void:
	await combat_controller.resolve_lane_combat(lane, player_slot, opponent_slot)


func resolve_directed_clash(
	lane: String,
	_attacker_slot: Node,
	attacker_card: CardData,
	defender_slot: Node,
	defender_card: CardData,
	player_is_attacker: bool
) -> void:
	await combat_controller.resolve_directed_clash(lane, _attacker_slot, attacker_card, defender_slot, defender_card, player_is_attacker)


func resolve_ai_parry_attempt(
	attacker_card: CardData,
	defender_slot: Node,
	defender_card: CardData,
	attacker_ap: int = -1,
	defender_ap: int = -1,
	ignore_protection: bool = false
) -> void:
	await combat_controller.resolve_ai_parry_attempt(attacker_card, defender_slot, defender_card, attacker_ap, defender_ap, ignore_protection)


func resolve_ai_successful_parry_abilities(parry_cards: Array[CardData]) -> void:
	await combat_controller.resolve_ai_successful_parry_abilities(parry_cards)


func find_ai_parry_card_index(remaining_dp: int) -> int:
	return combat_controller.find_ai_parry_card_index(remaining_dp)


func get_slot_card_data(slot: Node) -> CardData:
	return combat_controller.get_slot_card_data(slot)


func get_slot_combat_ap(slot: Node, ignore_protection: bool = false) -> int:
	return combat_controller.get_slot_combat_ap(slot, ignore_protection)


func get_slot_combat_ap_with_protection_announcements(slot: Node, ignore_protection: bool = false) -> int:
	return await ability_controller.get_slot_combat_ap_with_protection_announcements(slot, ignore_protection)


func get_card_protection_ability(card_data: CardData, ability_id: StringName) -> AbilityData:
	return ability_controller.get_card_protection_ability(card_data, ability_id)


func get_gambit_attack_protection(attacker_slot: Node) -> AbilityData:
	return ability_controller.get_gambit_attack_protection(attacker_slot)


func slot_has_protection_ability(slot: Node, ability_id: StringName) -> AbilityData:
	return ability_controller.slot_has_protection_ability(slot, ability_id)


func count_frontline_units(owner_name: String) -> int:
	return combat_controller.count_frontline_units(owner_name)


func show_protection_trigger(ability: AbilityData, detail: String = "") -> void:
	await ability_controller.show_protection_trigger(ability, detail)


func find_slot_by_owner_row_lane(owner_name: String, row: String, lane: String) -> Node:
	return combat_controller.find_slot_by_owner_row_lane(owner_name, row, lane)


func lane_has_front_unit(owner_name: String, lane: String) -> bool:
	return combat_controller.lane_has_front_unit(owner_name, lane)


func lane_has_any_front_unit(lane: String) -> bool:
	return combat_controller.lane_has_any_front_unit(lane)


func get_slot_lane(slot: Node) -> String:
	return combat_controller.get_slot_lane(slot)


func promote_slot_unit_preserving_equipment(slot: Node, new_unit: CardData, slot_owner: String) -> bool:
	return combat_controller.promote_slot_unit_preserving_equipment(slot, new_unit, slot_owner)


func send_slot_card_to_discard(slot: Node) -> void:
	combat_controller.send_slot_card_to_discard(slot)


func destroy_unit_with_protection(
	slot: Node,
	opposing_slot: Node = null,
	from_clash: bool = false,
	ignore_protection: bool = false
) -> bool:
	return await ability_controller.destroy_unit_with_protection(slot, opposing_slot, from_clash, ignore_protection)


func discard_protection_equipment(slot: Node, ability_id: StringName) -> bool:
	return ability_controller.discard_protection_equipment(slot, ability_id)


func get_3d_node_under_screen_position(screen_position: Vector2) -> Node:
	return interaction_controller.get_3d_node_under_screen_position(screen_position)


func find_board_slot_from_node(node: Node) -> Node:
	return interaction_controller.find_board_slot_from_node(node)


func is_node_inside_target(node: Node, target: Node) -> bool:
	return interaction_controller.is_node_inside_target(node, target)


func _on_tribute_changed(_status_text: String) -> void:
	update_tribute_counter()
	# Let the active card-transfer call finish before changing phase/UI state.
	call_deferred("try_auto_advance_tribute_phase")


func try_auto_advance_tribute_phase() -> void:
	phase_controller.try_auto_advance_tribute_phase()


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
	return phase_controller.get_battle_plan_key(plan)


func is_battle_plan_used(plan: Dictionary) -> bool:
	return phase_controller.is_battle_plan_used(plan)


func mark_battle_plan_used(plan: Dictionary) -> void:
	phase_controller.mark_battle_plan_used(plan)


func get_unused_battle_plan_choices(amount: int) -> Array[Dictionary]:
	return phase_controller.get_unused_battle_plan_choices(amount)


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
	clear_deployment_slot_highlights_for_animation()

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

	await card_animation_manager.animate_card_between_nodes(
		card_data,
		source_node,
		target_node,
		false
	)


func discard_cards_with_animation(cards: Array, source_node: Node, slot_owner: String) -> void:
	for card_value in cards:
		var card_data := card_value as CardData
		if card_data == null:
			continue
		if slot_owner == "enemy":
			ai_discard.append(card_data)
		elif discard_pile != null:
			discard_pile.add_card(card_data, false)
	animate_cards_to_discard_and_reveal(cards, source_node, slot_owner)


func animate_cards_to_discard_and_reveal(cards: Array, source_node: Node, slot_owner: String) -> void:
	for card_value in cards:
		var card_data := card_value as CardData
		if card_data == null:
			continue
		await play_card_to_discard_animation(card_data, source_node, slot_owner)
	if slot_owner == "enemy":
		update_ai_visuals()
	elif discard_pile != null:
		discard_pile.build_stack()


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
	PrototypeMenu.skip_intro_once = true
	var tree := get_tree()
	if tree != null:
		tree.change_scene_to_file(MENU_SCENE_PATH)


func return_to_menu_without_intro() -> void:
	Cursors.use_normal()
	PrototypeMenu.skip_intro_once = true
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


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

		var is_player_slot := String(slot.get_meta("owner", "")) == "player"
		var is_face_down := bool(slot.get_meta("face_down", false))
		var entries: Array = slot.call("get_ability_visual_entries") if slot.has_method("get_ability_visual_entries") else []
		for entry in entries:
			var card_data := entry.get("card") as CardData
			var visual := entry.get("visual") as Node
			var usable_ids: Array[StringName] = []
			if is_player_slot and card_data != null and not is_face_down and not phase_transition_busy:
				var equipment_blocked := card_data != get_slot_card_data(slot) and is_equipment_suppressed(slot)
				if not equipment_blocked:
					for ability in card_data.get_abilities():
						if ability == null:
							continue
						var category := ability.category.to_lower()
						var handler_id := ability.get_handler_id()
						if category == "insight" and ability.trigger == "active" and can_activate_insight_ability(slot, ability):
							usable_ids.append(ability.ability_id)
						elif category == "mobility" and (ability.trigger == "active" or handler_id == &"tactic_flow" or handler_id == &"volley") and can_activate_mobility_ability(slot, ability):
							usable_ids.append(ability.ability_id)
						elif category == "control" and ability.trigger == "active" and can_activate_control_ability(slot, ability):
							usable_ids.append(ability.ability_id)
			if visual != null and visual.has_method("set_usable_ability_ids"):
				visual.call("set_usable_ability_ids", usable_ids)
			connect_card_ability_icon_signals(slot, visual)

func connect_card_ability_icon_signals(slot: Node, supplied_visual: Node = null) -> void:
	if slot == null:
		return
	var visual := supplied_visual
	if visual == null and slot.has_method("get_placed_card_visual"):
		visual = slot.call("get_placed_card_visual") as Node
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
	if visual.has_signal("ability_icon_unhovered"):
		var unhovered_callable := Callable(self, "_on_card_ability_icon_unhovered").bind(slot)
		if not visual.is_connected("ability_icon_unhovered", unhovered_callable):
			visual.connect("ability_icon_unhovered", unhovered_callable)


func _on_card_ability_icon_pressed(_card_visual: Node, ability: AbilityData, slot: Node) -> void:
	if ability != null and ability.category.to_lower() == "mobility":
		await activate_mobility_ability_from_slot(slot, ability)
	elif ability != null and ability.category.to_lower() == "control":
		if await activate_control_ability(slot, ability):
			var lane := get_slot_lane(slot)
			player_passed_current_lane = true
			set_lane_priority_to_ai(lane, ability.ability_name + " used instead of attacking.")
			await resolve_ai_current_priority_lane(lane)
	else:
		await activate_insight_ability_from_slot(slot, ability)


func _on_card_ability_icon_hovered(card_visual: Node, ability: AbilityData, _slot: Node) -> void:
	if ability == null or ability_tooltip_panel == null or ability_tooltip_label == null:
		return

	polish_card_visual_ability_icons(card_visual)

	ability_tooltip_label.text = ability.ability_name + "\n" + ability.rules_text

	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := ability_tooltip_panel.size
	if panel_size.x <= 1.0 or panel_size.y <= 1.0:
		panel_size = ability_tooltip_panel.custom_minimum_size
	if panel_size.x <= 1.0 or panel_size.y <= 1.0:
		panel_size = Vector2(340.0, 96.0)

	var mouse := get_viewport().get_mouse_position()
	var target_position := mouse + ABILITY_TOOLTIP_OFFSET

	# Prefer top-left of the cursor. If the cursor is too close to an edge, clamp safely onscreen.
	target_position.x = clampf(target_position.x, ABILITY_TOOLTIP_SCREEN_MARGIN, viewport_size.x - panel_size.x - ABILITY_TOOLTIP_SCREEN_MARGIN)
	target_position.y = clampf(target_position.y, ABILITY_TOOLTIP_SCREEN_MARGIN, viewport_size.y - panel_size.y - ABILITY_TOOLTIP_SCREEN_MARGIN)

	ability_tooltip_panel.position = target_position
	ability_tooltip_panel.visible = true

func _on_card_ability_icon_unhovered(_card_visual: Node, _ability: AbilityData, _slot: Node) -> void:
	if ability_tooltip_panel != null:
		ability_tooltip_panel.visible = false

func create_ability_tooltip_ui() -> void:
	ability_tooltip_panel = PanelContainer.new()
	ability_tooltip_panel.name = "AbilityTooltip"
	ability_tooltip_panel.visible = false
	ability_tooltip_panel.custom_minimum_size = Vector2(340.0, 96.0)
	ability_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_tooltip_panel.z_index = 220
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.018, 0.025, 0.94)
	style.border_color = Color(0.48, 0.68, 1.0, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	ability_tooltip_panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	ability_tooltip_panel.add_child(margin)
	ability_tooltip_label = Label.new()
	ability_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ability_tooltip_label.add_theme_font_size_override("font_size", 16)
	ability_tooltip_label.add_theme_color_override("font_color", Color.WHITE)
	ability_tooltip_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	ability_tooltip_label.add_theme_constant_override("shadow_offset_x", 1)
	ability_tooltip_label.add_theme_constant_override("shadow_offset_y", 2)
	margin.add_child(ability_tooltip_label)
	$UI.add_child(ability_tooltip_panel)


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
	await combat_controller.advance_combat_lane_after_resolution()


func skip_empty_combat_lanes_with_pause() -> void:
	await combat_controller.skip_empty_combat_lanes_with_pause()


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
	return deployment_controller.get_clean_card_type(card_data)


func is_gambit_card(card_data: CardData) -> bool:
	return deployment_controller.is_gambit_card(card_data)


func is_equipment_card(card_data: CardData) -> bool:
	return deployment_controller.is_equipment_card(card_data)


func is_spell_card(card_data: CardData) -> bool:
	return deployment_controller.is_spell_card(card_data)


func get_face_down_card_setup_cost(count_already_set_this_round: int) -> int:
	return deployment_controller.get_face_down_card_setup_cost(count_already_set_this_round)


func get_player_next_face_down_card_setup_cost() -> int:
	return deployment_controller.get_player_next_face_down_card_setup_cost()


func get_ai_next_face_down_card_setup_cost() -> int:
	return deployment_controller.get_ai_next_face_down_card_setup_cost()


func get_player_face_down_card_deployment_cost(card_data: CardData, place_face_down: bool) -> int:
	return deployment_controller.get_player_face_down_card_deployment_cost(card_data, place_face_down)


func get_ai_face_down_card_deployment_cost(card_data: CardData, place_face_down: bool) -> int:
	return deployment_controller.get_ai_face_down_card_deployment_cost(card_data, place_face_down)


func reset_face_down_gambit_setup_counters() -> void:
	deployment_controller.reset_face_down_gambit_setup_counters()


func return_card_to_hand_safely(card: CardUI) -> void:
	deployment_controller.return_card_to_hand_safely(card)


func is_unit_card(card_data: CardData) -> bool:
	return deployment_controller.is_unit_card(card_data)


func try_attach_selected_equipment_to_slot(slot: Node) -> bool:
	return deployment_controller.try_attach_selected_equipment_to_slot(slot)


func confirm_pending_spell_placement(place_face_down: bool) -> void:
	await deployment_controller.confirm_pending_spell_placement(place_face_down)


func clear_deployment_slot_highlights_for_animation() -> void:
	deployment_controller.clear_deployment_slot_highlights_for_animation()


func resolve_dominance_before_cleanup() -> void:
	phase_controller.resolve_dominance_before_cleanup()


func get_front_lane_ap_total(owner_name: String, lane: String) -> int:
	return phase_controller.get_front_lane_ap_total(owner_name, lane)


func cleanup_battlefield_spells() -> void:
	deployment_controller.cleanup_battlefield_spells()


func cleanup_face_up_gambits_before_combat() -> void:
	deployment_controller.cleanup_face_up_gambits_before_combat()


func setup_ai_deck() -> void:
	ai_deck.clear()
	ai_hand.clear()
	ai_discard.clear()
	ai_tribute.clear()

	ai_reset_memory()

	ai_perm_tp = 0
	ai_current_perm_tp = 0
	ai_temp_tp = 0
	ai_current_tp = 0
	ai_tribute_used_this_turn = false

	var selected_ai_cards := ai_build_selected_deck_cards()

	if selected_ai_cards.is_empty():
		var pool: Array[CardData] = CardDatabase.get_ai_test_deck()

		for i in range(40):
			ai_deck.append(pool[i % pool.size()])

		log_msg("AI deck source: prototype AI deck.")
	else:
		for card_data in selected_ai_cards:
			if card_data != null:
				ai_deck.append(card_data)

		match ai_deck_source_mode:
			AI_DECK_SOURCE_RANDOM_SYNERGY:
				log_msg("AI deck source: Random Synergy Deck.")
			AI_DECK_SOURCE_SAVED:
				log_msg("AI deck source: Saved Deck Slot " + str(ai_selected_saved_deck_slot + 1) + ".")

	ai_deck.shuffle()
	update_ai_visuals()


func ai_build_selected_deck_cards() -> Array[CardData]:
	return ai_controller.ai_build_selected_deck_cards()


func ai_draw_cards(amount: int) -> void:
	ai_controller.ai_draw_cards(amount)


func ai_start_tribute_phase() -> void:
	await ai_controller.ai_start_tribute_phase()


func ai_offer_one_card_to_tribute() -> void:
	await ai_controller.ai_offer_one_card_to_tribute()


func ai_choose_tribute_card_index() -> int:
	return ai_controller.ai_choose_tribute_card_index()


func ai_score_tribute_card(card_index: int, card_data: CardData) -> int:
	return ai_controller.ai_score_tribute_card(card_index, card_data)


func ai_count_matching_cards_in_hand(card_data: CardData) -> int:
	return ai_controller.ai_count_matching_cards_in_hand(card_data)


func ai_count_hand_units() -> int:
	return ai_controller.ai_count_hand_units()


func ai_reset_memory() -> void:
	ai_controller.ai_reset_memory()


func ai_memory_weight() -> float:
	return ai_controller.ai_memory_weight()


func ai_randomness_multiplier() -> float:
	return ai_controller.ai_randomness_multiplier()


func ai_apply_memory_bonus(base_score: int) -> int:
	return ai_controller.ai_apply_memory_bonus(base_score)


func ai_tactical_noise(max_amount: int) -> int:
	return ai_controller.ai_tactical_noise(max_amount)


func ai_memory_player_hidden_gambit_rate() -> float:
	return ai_controller.ai_memory_player_hidden_gambit_rate()


func ai_memory_player_check_success_rate() -> float:
	return ai_controller.ai_memory_player_check_success_rate()


func ai_memory_player_lane_pressure_score(lane: String) -> int:
	return ai_controller.ai_memory_player_lane_pressure_score(lane)


func ai_memory_add_lane_pressure(lane: String, amount: int) -> void:
	ai_controller.ai_memory_add_lane_pressure(lane, amount)


func ai_memory_add_backrow_pressure(lane: String, amount: int) -> void:
	ai_controller.ai_memory_add_backrow_pressure(lane, amount)


func ai_memory_note_player_deployment(card_data: CardData, slot: Node) -> void:
	ai_controller.ai_memory_note_player_deployment(card_data, slot)


func ai_memory_note_player_hidden_reveal(card_data: CardData, lane: String, _source: String = "") -> void:
	ai_controller.ai_memory_note_player_hidden_reveal(card_data, lane, _source)


func ai_memory_note_player_check_result(lane: String, successful: bool) -> void:
	ai_controller.ai_memory_note_player_check_result(lane, successful)


func ai_memory_note_player_attacked_hidden(lane: String, revealed_gambit: bool) -> void:
	ai_controller.ai_memory_note_player_attacked_hidden(lane, revealed_gambit)


func ai_lookahead_weight() -> float:
	return ai_controller.ai_lookahead_weight()


func ai_apply_lookahead_bonus(base_score: int) -> int:
	return ai_controller.ai_apply_lookahead_bonus(base_score)


func ai_card_has_ability_id(card_data: CardData, ability_id: StringName) -> bool:
	return ai_controller.ai_card_has_ability_id(card_data, ability_id)


func ai_estimate_card_value(card_data: CardData) -> int:
	return ai_controller.ai_estimate_card_value(card_data)


func ai_score_projected_lane_control(lane: String, projected_ai_ap: int, projected_ai_dp: int, ai_has_front_unit: bool) -> int:
	return ai_controller.ai_score_projected_lane_control(lane, projected_ai_ap, projected_ai_dp, ai_has_front_unit)


func ai_score_deployment_lookahead(card_data: CardData, slot: Node, action_type: String, face_down: bool) -> int:
	return ai_controller.ai_score_deployment_lookahead(card_data, slot, action_type, face_down)


func ai_score_combat_action_lookahead(lane: String, action_type: String) -> int:
	return ai_controller.ai_score_combat_action_lookahead(lane, action_type)


func ai_score_attack_lookahead(lane: String) -> int:
	return ai_controller.ai_score_attack_lookahead(lane)


func ai_score_check_lookahead(lane: String) -> int:
	return ai_controller.ai_score_check_lookahead(lane)


func ai_score_pass_lookahead(lane: String) -> int:
	return ai_controller.ai_score_pass_lookahead(lane)


func ai_ability_awareness_weight() -> float:
	return ai_controller.ai_ability_awareness_weight()


func ai_apply_ability_awareness_bonus(base_score: int) -> int:
	return ai_controller.ai_apply_ability_awareness_bonus(base_score)


func ai_slot_has_any_ability(slot: Node, ability_id: StringName) -> AbilityData:
	return ai_controller.ai_slot_has_any_ability(slot, ability_id)


func ai_count_player_front_units_at_or_below(max_ap: int) -> int:
	return ai_controller.ai_count_player_front_units_at_or_below(max_ap)


func ai_count_enemy_empty_adjacent_front_slots(lane: String) -> int:
	return ai_controller.ai_count_enemy_empty_adjacent_front_slots(lane)


func ai_count_player_hidden_backrow_cards() -> int:
	return ai_controller.ai_count_player_hidden_backrow_cards()


func ai_score_card_ability_value(card_data: CardData, slot: Node = null, context: String = "", face_down: bool = false) -> int:
	return ai_controller.ai_score_card_ability_value(card_data, slot, context, face_down)


func ai_score_protection_ability_value(ability: AbilityData, card_data: CardData, slot: Node, context: String, face_down: bool) -> int:
	return ai_controller.ai_score_protection_ability_value(ability, card_data, slot, context, face_down)


func ai_score_mobility_ability_value(ability: AbilityData, card_data: CardData, slot: Node, context: String, face_down: bool) -> int:
	return ai_controller.ai_score_mobility_ability_value(ability, card_data, slot, context, face_down)


func ai_score_insight_ability_value(ability: AbilityData, _card_data: CardData, slot: Node, context: String, face_down: bool) -> int:
	return ai_controller.ai_score_insight_ability_value(ability, _card_data, slot, context, face_down)


func ai_score_card_abilities_for_deployment(card_data: CardData, slot: Node, action_type: String, face_down: bool) -> int:
	return ai_controller.ai_score_card_abilities_for_deployment(card_data, slot, action_type, face_down)


func ai_score_tribute_ability_preservation(card_data: CardData) -> int:
	return ai_controller.ai_score_tribute_ability_preservation(card_data)


func ai_score_combat_ability_awareness(lane: String, action_type: String) -> int:
	return ai_controller.ai_score_combat_ability_awareness(lane, action_type)


func ai_take_combat_initiative() -> void:
	await ai_controller.ai_take_combat_initiative()


func ai_choose_combat_start_lane() -> String:
	return ai_controller.ai_choose_combat_start_lane()


func ai_score_combat_direction(lanes: Array[String]) -> int:
	return ai_controller.ai_score_combat_direction(lanes)


func ai_resolve_combat_sequence() -> void:
	await ai_controller.ai_resolve_combat_sequence()


func ai_count_front_units(owner_name: String) -> int:
	return ai_controller.ai_count_front_units(owner_name)


func ai_get_total_front_ap(owner_name: String) -> int:
	return ai_controller.ai_get_total_front_ap(owner_name)


func ai_take_deployment_turn() -> void:
	await ai_controller.ai_take_deployment_turn()


func ai_try_deploy_one_card() -> bool:
	return await ai_controller.ai_try_deploy_one_card()


func ai_choose_deployment_action() -> Dictionary:
	return ai_controller.ai_choose_deployment_action()


func ai_describe_deployment_action(action: Dictionary, score: int) -> String:
	return ai_controller.ai_describe_deployment_action(action, score)


func ai_make_deployment_action(card_index: int, slot: Node, action_type: String, face_down: bool) -> Dictionary:
	return ai_controller.ai_make_deployment_action(card_index, slot, action_type, face_down)


func ai_build_deployment_actions() -> Array[Dictionary]:
	return ai_controller.ai_build_deployment_actions()


func ai_add_unit_deployment_actions(actions: Array[Dictionary], card_index: int, card_data: CardData) -> void:
	ai_controller.ai_add_unit_deployment_actions(actions, card_index, card_data)


func ai_add_equipment_deployment_actions(actions: Array[Dictionary], card_index: int, card_data: CardData) -> void:
	ai_controller.ai_add_equipment_deployment_actions(actions, card_index, card_data)


func ai_add_gambit_deployment_actions(actions: Array[Dictionary], card_index: int, card_data: CardData) -> void:
	ai_controller.ai_add_gambit_deployment_actions(actions, card_index, card_data)


func ai_get_empty_enemy_slots(row: String) -> Array[Node]:
	return ai_controller.ai_get_empty_enemy_slots(row)


func ai_get_enemy_equipment_target_slots() -> Array[Node]:
	return ai_controller.ai_get_enemy_equipment_target_slots()


func ai_score_deployment_action(action: Dictionary) -> int:
	return ai_controller.ai_score_deployment_action(action)


func ai_score_promotion_deployment(card_data: CardData, slot: Node) -> int:
	return ai_controller.ai_score_promotion_deployment(card_data, slot)


func ai_score_unit_deployment(card_data: CardData, slot: Node, face_down: bool) -> int:
	return ai_controller.ai_score_unit_deployment(card_data, slot, face_down)


func ai_score_equipment_deployment(card_data: CardData, slot: Node) -> int:
	return ai_controller.ai_score_equipment_deployment(card_data, slot)


func ai_score_equipment_setup(card_data: CardData, slot: Node) -> int:
	return ai_controller.ai_score_equipment_setup(card_data, slot)


func ai_score_gambit_deployment(card_data: CardData, slot: Node, face_down: bool) -> int:
	return ai_controller.ai_score_gambit_deployment(card_data, slot, face_down)


func ai_can_promote_card_to_slot(new_unit: CardData, slot: Node) -> bool:
	return ai_controller.ai_can_promote_card_to_slot(new_unit, slot)


func ai_find_best_affordable_unit_index() -> int:
	return ai_controller.ai_find_best_affordable_unit_index()


func ai_find_affordable_gambit_index_for_visibility(face_down: bool) -> int:
	return ai_controller.ai_find_affordable_gambit_index_for_visibility(face_down)


func ai_find_enemy_unit_slot_that_can_take_equipment() -> Node:
	return ai_controller.ai_find_enemy_unit_slot_that_can_take_equipment()


func ai_find_empty_enemy_slot(row: String) -> Node:
	return ai_controller.ai_find_empty_enemy_slot(row)


func ai_choose_slot_for_card(card_data: CardData) -> Node:
	return ai_controller.ai_choose_slot_for_card(card_data)


func ai_choose_spell_like_slot(card_data: CardData) -> Node:
	return ai_controller.ai_choose_spell_like_slot(card_data)


func ai_choose_equipment_target_slot(_card_data: CardData) -> Node:
	return ai_controller.ai_choose_equipment_target_slot(_card_data)


func ai_choose_front_slot_for_card(card_data: CardData) -> Node:
	return ai_controller.ai_choose_front_slot_for_card(card_data)


func ai_get_empty_front_slots() -> Array[Node]:
	return ai_controller.ai_get_empty_front_slots()


func ai_score_front_slot_for_card(card_data: CardData, lane: String) -> int:
	return ai_controller.ai_score_front_slot_for_card(card_data, lane)


func ai_score_deploy_card(card_data: CardData) -> int:
	return ai_controller.ai_score_deploy_card(card_data)


func ai_spend_tp(cost: int) -> bool:
	return ai_controller.ai_spend_tp(cost)


func is_spell_like_card(card_data: CardData) -> bool:
	return CardRules.is_spell_like_card(card_data)


func cleanup_phase_one_board_cards() -> void:
	deployment_controller.cleanup_phase_one_board_cards()


func return_face_down_setup_card_to_owner_hand(slot: Node, card_data: CardData, slot_owner: String) -> void:
	deployment_controller.return_face_down_setup_card_to_owner_hand(slot, card_data, slot_owner)


func discard_slot_card_for_cleanup(slot: Node, card_data: CardData, slot_owner: String) -> void:
	deployment_controller.discard_slot_card_for_cleanup(slot, card_data, slot_owner)


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
		add_active_mobility_actions_to_board_menu(slot)
		add_active_control_actions_to_board_menu(slot)
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
		var ability := board_action_ability_map.get(action_id) as AbilityData
		if ability != null and ability.category.to_lower() == "mobility":
			await activate_mobility_ability_from_slot(board_action_target_slot, ability)
		elif ability != null and ability.category.to_lower() == "control":
			if await activate_control_ability(board_action_target_slot, ability):
				var lane := get_slot_lane(board_action_target_slot)
				player_passed_current_lane = true
				set_lane_priority_to_ai(lane, ability.ability_name + " used instead of attacking.")
				await resolve_ai_current_priority_lane(lane)
		else:
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
	ability_controller.add_active_insight_actions_to_board_menu(slot, card_data)


func add_active_mobility_actions_to_board_menu(slot: Node) -> void:
	ability_controller.add_active_mobility_actions_to_board_menu(slot)


func can_activate_insight_ability(slot: Node, ability: AbilityData) -> bool:
	return ability_controller.can_activate_insight_ability(slot, ability)


func activate_insight_from_board_action(action_id: int, slot: Node) -> void:
	await ability_controller.activate_insight_from_board_action(action_id, slot)


func activate_insight_ability_from_slot(slot: Node, ability: AbilityData) -> void:
	await ability_controller.activate_insight_ability_from_slot(slot, ability)


func get_active_insight_usage_key(slot: Node, ability: AbilityData) -> String:
	return ability_controller.get_active_insight_usage_key(slot, ability)


func get_mobility_usage_key(slot: Node, ability: AbilityData) -> String:
	return ability_controller.get_mobility_usage_key(slot, ability)


func get_card_mobility_ability(card_data: CardData, ability_id: StringName) -> AbilityData:
	return ability_controller.get_card_mobility_ability(card_data, ability_id)


func slot_has_mobility_ability(slot: Node, ability_id: StringName) -> AbilityData:
	return ability_controller.slot_has_mobility_ability(slot, ability_id)


func get_player_front_slots() -> Array[Node]:
	return ability_controller.get_player_front_slots()


func get_adjacent_lanes(lane: String) -> Array[String]:
	return ability_controller.get_adjacent_lanes(lane)


func can_activate_mobility_ability(slot: Node, ability: AbilityData) -> bool:
	return ability_controller.can_activate_mobility_ability(slot, ability)


func activate_mobility_ability_from_slot(slot: Node, ability: AbilityData) -> void:
	await ability_controller.activate_mobility_ability_from_slot(slot, ability)


func resolve_lane_shift(source_slot: Node, ability: AbilityData) -> bool:
	return await ability_controller.resolve_lane_shift(source_slot, ability)


func resolve_mobilize(source_slot: Node, ability: AbilityData) -> bool:
	return await ability_controller.resolve_mobilize(source_slot, ability)


func resolve_tactic_flow(source_slot: Node, ability: AbilityData) -> bool:
	return await ability_controller.resolve_tactic_flow(source_slot, ability)


func resolve_flank_swap(ability: AbilityData, owner_name: String = "player") -> bool:
	return await ability_controller.resolve_flank_swap(ability, owner_name)


func move_slot_contents(source: Node, target: Node) -> void:
	await ability_controller.move_slot_contents(source, target)


func swap_slot_contents(first: Node, second: Node) -> void:
	await ability_controller.swap_slot_contents(first, second)


func swap_owner_lanes(owner_name: String, first_lane: String, second_lane: String) -> void:
	await ability_controller.swap_owner_lanes(owner_name, first_lane, second_lane)


func animate_snapshot_between_slots(snapshot: Dictionary, source: Node, target: Node) -> void:
	await ability_controller.animate_snapshot_between_slots(snapshot, source, target)


func resolve_stealth_hidden_decoy(back_slot: Node, card_data: CardData, owner_name: String, lane: String) -> bool:
	return ability_controller.resolve_stealth_hidden_decoy(back_slot, card_data, owner_name, lane)


func get_card_insight_ability(card_data: CardData, ability_id: StringName) -> AbilityData:
	return ability_controller.get_card_insight_ability(card_data, ability_id)


func get_hidden_enemy_gambit_cards() -> Array[CardData]:
	return ability_controller.get_hidden_enemy_gambit_cards()


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

	register_inspection_fade(slot, inspect_panel)

	var source_position: Vector2 = get_viewport().get_mouse_position()
	inspect_panel.last_source_rect = Rect2(source_position, Vector2(130.0, 180.0))
	inspect_panel.show_card(null, card_data)

	log_msg("Inspecting board card: " + card_data.card_name)


func register_inspection_fade(slot: Node, inspect_panel: CardInspectPanel) -> void:
	clear_all_inspection_fades()

	if slot != null and slot.has_method("set_inspected_faded"):
		slot.call("set_inspected_faded", true)
		inspected_faded_slots.append(slot)

	if inspect_panel != null:
		var clear_callable := Callable(self, "_on_card_inspection_closed")
		if not inspect_panel.inspection_closed.is_connected(clear_callable):
			inspect_panel.inspection_closed.connect(clear_callable)


func _on_card_inspection_closed() -> void:
	clear_all_inspection_fades()


func clear_all_inspection_fades() -> void:
	for slot in inspected_faded_slots:
		if slot == null:
			continue
		if not is_instance_valid(slot):
			continue
		if slot.has_method("set_inspected_faded"):
			slot.call("set_inspected_faded", false)

	inspected_faded_slots.clear()


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
	return combat_controller.can_player_attack_lane_from_menu(lane)


func get_player_attackers_for_lane(target_lane: String) -> Array[Node]:
	return combat_controller.get_player_attackers_for_lane(target_lane)


func can_player_check_lane_from_menu(lane: String) -> bool:
	return combat_controller.can_player_check_lane_from_menu(lane)


func can_player_pass_lane_from_menu(lane: String) -> bool:
	return combat_controller.can_player_pass_lane_from_menu(lane)


func can_player_take_priority_action_in_lane(lane: String) -> bool:
	return combat_controller.can_player_take_priority_action_in_lane(lane)


func is_lane_current_or_valid_combat_start(lane: String) -> bool:
	return combat_controller.is_lane_current_or_valid_combat_start(lane)


func get_initiative_priority_owner() -> String:
	return combat_controller.get_initiative_priority_owner()


func reset_priority_for_current_lane() -> void:
	combat_controller.reset_priority_for_current_lane()


func current_combat_lane() -> String:
	return combat_controller.current_combat_lane()


func set_lane_priority_to_player(lane: String, reason: String = "") -> void:
	combat_controller.set_lane_priority_to_player(lane, reason)


func set_lane_priority_to_ai(lane: String, reason: String = "") -> void:
	combat_controller.set_lane_priority_to_ai(lane, reason)


func attack_from_board_action_menu(slot: Node) -> void:
	await combat_controller.attack_from_board_action_menu(slot)


func pass_from_board_action_menu(slot: Node) -> void:
	await combat_controller.pass_from_board_action_menu(slot)


func resolve_monarch_strike(lane: String, attacker_card: CardData) -> void:
	combat_controller.resolve_monarch_strike(lane, attacker_card)


func resolve_ai_monarch_strike(lane: String, attacker_card: CardData) -> void:
	combat_controller.resolve_ai_monarch_strike(lane, attacker_card)


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
	await combat_controller.resolve_player_attack_lane_with_visuals(lane)


func resolve_player_pass_lane_with_visuals(lane: String) -> void:
	await combat_controller.resolve_player_pass_lane_with_visuals(lane)


func resolve_ai_current_priority_lane(lane: String) -> void:
	await combat_controller.resolve_ai_current_priority_lane(lane)


func ai_active_ability_weight() -> float:
	return ai_controller.ai_active_ability_weight()


func ai_apply_active_ability_bonus(base_score: int) -> int:
	return ai_controller.ai_apply_active_ability_bonus(base_score)


func ai_try_use_active_ability_before_combat(lane: String) -> Dictionary:
	return await ai_controller.ai_try_use_active_ability_before_combat(lane)


func ai_describe_active_ability_action(action: Dictionary, score: int, threshold: int) -> String:
	return ai_controller.ai_describe_active_ability_action(action, score, threshold)


func ai_active_ability_use_threshold() -> int:
	return ai_controller.ai_active_ability_use_threshold()


func ai_build_active_ability_actions(current_lane_name: String) -> Array[Dictionary]:
	return ai_controller.ai_build_active_ability_actions(current_lane_name)


func ai_get_enemy_face_up_front_slots() -> Array[Node]:
	return ai_controller.ai_get_enemy_face_up_front_slots()


func ai_get_active_ability_entries_for_slot(slot: Node) -> Array[Dictionary]:
	return ai_controller.ai_get_active_ability_entries_for_slot(slot)


func ai_can_consider_active_ability(slot: Node, ability: AbilityData) -> bool:
	return ai_controller.ai_can_consider_active_ability(slot, ability)


func ai_add_active_mobility_actions(actions: Array[Dictionary], current_lane_name: String, source_slot: Node, ability: AbilityData) -> void:
	ai_controller.ai_add_active_mobility_actions(actions, current_lane_name, source_slot, ability)


func ai_add_active_insight_actions(actions: Array[Dictionary], current_lane_name: String, source_slot: Node, ability: AbilityData) -> void:
	ai_controller.ai_add_active_insight_actions(actions, current_lane_name, source_slot, ability)


func ai_score_active_ability_action(action: Dictionary, current_lane_name: String) -> int:
	return ai_controller.ai_score_active_ability_action(action, current_lane_name)


func ai_score_active_move_action(source_slot: Node, target_slot: Node, current_lane_name: String) -> int:
	return ai_controller.ai_score_active_move_action(source_slot, target_slot, current_lane_name)


func ai_score_active_swap_action(source_slot: Node, target_slot: Node) -> int:
	return ai_controller.ai_score_active_swap_action(source_slot, target_slot)


func ai_score_active_destroy_action(target_slot: Node) -> int:
	return ai_controller.ai_score_active_destroy_action(target_slot)


func ai_score_active_vortex_action(source_slot: Node) -> int:
	return ai_controller.ai_score_active_vortex_action(source_slot)


func ai_score_active_insight_peek_action(target_slot: Node, current_lane_name: String) -> int:
	return ai_controller.ai_score_active_insight_peek_action(target_slot, current_lane_name)


func ai_execute_active_ability_action(action: Dictionary, current_lane_name: String) -> Dictionary:
	return await ai_controller.ai_execute_active_ability_action(action, current_lane_name)


func ai_mark_active_mobility_used(slot: Node, ability: AbilityData) -> void:
	ai_controller.ai_mark_active_mobility_used(slot, ability)


func ai_mark_active_insight_used(slot: Node, ability: AbilityData) -> void:
	ai_controller.ai_mark_active_insight_used(slot, ability)


func ai_execute_active_move_action(source_slot: Node, target_slot: Node, ability: AbilityData) -> Dictionary:
	return await ai_controller.ai_execute_active_move_action(source_slot, target_slot, ability)


func ai_execute_active_swap_action(source_slot: Node, target_slot: Node, ability: AbilityData) -> Dictionary:
	return await ai_controller.ai_execute_active_swap_action(source_slot, target_slot, ability)


func ai_execute_active_destroy_action(source_slot: Node, target_slot: Node, ability: AbilityData) -> Dictionary:
	return await ai_controller.ai_execute_active_destroy_action(source_slot, target_slot, ability)


func ai_execute_active_vortex_action(source_slot: Node, ability: AbilityData) -> Dictionary:
	return await ai_controller.ai_execute_active_vortex_action(source_slot, ability)


func ai_execute_active_insight_peek_action(source_slot: Node, target_slot: Node, ability: AbilityData, current_lane_name: String) -> Dictionary:
	return await ai_controller.ai_execute_active_insight_peek_action(source_slot, target_slot, ability, current_lane_name)


func resolve_ai_pass_lane_with_visuals(lane: String) -> void:
	await combat_controller.resolve_ai_pass_lane_with_visuals(lane)


func ai_choose_combat_action(lane: String) -> String:
	return ai_controller.ai_choose_combat_action(lane)


func ai_score_combat_attack_action(lane: String) -> int:
	return ai_controller.ai_score_combat_attack_action(lane)


func ai_score_combat_check_action(lane: String) -> int:
	return ai_controller.ai_score_combat_check_action(lane)


func ai_score_combat_pass_action(lane: String) -> int:
	return ai_controller.ai_score_combat_pass_action(lane)


func resolve_ai_check_lane_with_visuals(lane: String) -> void:
	await combat_controller.resolve_ai_check_lane_with_visuals(lane)


func resolve_ai_attack_lane_with_visuals(lane: String) -> void:
	await combat_controller.resolve_ai_attack_lane_with_visuals(lane)


func set_active_combat_lane_highlight(lane: String) -> void:
	combat_controller.set_active_combat_lane_highlight(lane)


func clear_active_combat_lane_highlight() -> void:
	combat_controller.clear_active_combat_lane_highlight()


func check_from_board_action_menu(slot: Node) -> void:
	await combat_controller.check_from_board_action_menu(slot)


func resolve_player_check_lane_with_visuals(lane: String) -> void:
	await combat_controller.resolve_player_check_lane_with_visuals(lane)


func prepare_player_lane_action(lane: String) -> bool:
	return combat_controller.prepare_player_lane_action(lane)


func return_setup_card(slot: Node, card_data: CardData, owner_name: String) -> void:
	combat_controller.return_setup_card(slot, card_data, owner_name)


func resolve_immediate_hidden_gambit_cast(gambit_card: CardData, caster_owner: String, lane: String, slot: Node = null) -> bool:
	return await ability_controller.resolve_immediate_hidden_gambit_cast(gambit_card, caster_owner, lane, slot)


func resolve_attack_into_face_down_backrow(
	lane: String,
	_attacker_card: CardData,
	_enemy_front_slot: Node,
	enemy_back_slot: Node,
	enemy_back_card: CardData
) -> void:
	await combat_controller.resolve_attack_into_face_down_backrow(lane, _attacker_card, _enemy_front_slot, enemy_back_slot, enemy_back_card)


func activate_mobility_ability_from_slot_base(slot: Node, ability: AbilityData) -> void:
	await ability_controller.activate_mobility_ability_from_slot_base(slot, ability)


func can_activate_mobility_ability_base(slot: Node, ability: AbilityData) -> bool:
	return ability_controller.can_activate_mobility_ability_base(slot, ability)


func can_activate_lane_shift_to_empty(slot: Node, ability: AbilityData) -> bool:
	return ability_controller.can_activate_lane_shift_to_empty(slot, ability)


func get_empty_adjacent_player_front_slots(source_slot: Node) -> Array[Node]:
	return ability_controller.get_empty_adjacent_player_front_slots(source_slot)


func can_activate_volley_ability(slot: Node, ability: AbilityData) -> bool:
	return ability_controller.can_activate_volley_ability(slot, ability)


func get_volley_target_lanes_for_slot(source_slot: Node) -> Array[String]:
	return ability_controller.get_volley_target_lanes_for_slot(source_slot)


func get_volley_target_slots_for_slot(source_slot: Node) -> Array[Node]:
	return ability_controller.get_volley_target_slots_for_slot(source_slot)


func resolve_volley_from_slot(source_slot: Node, ability: AbilityData) -> bool:
	return await ability_controller.resolve_volley_from_slot(source_slot, ability)


func resolve_player_attack_lane_from_specific_attacker(lane: String, attacker_slot: Node, ability_name: String = "Volley") -> void:
	await ability_controller.resolve_player_attack_lane_from_specific_attacker(lane, attacker_slot, ability_name)


func prepare_player_volley_lane_action(source_lane: String, target_lane: String) -> bool:
	return ability_controller.prepare_player_volley_lane_action(source_lane, target_lane)


func resolve_volley_attack_into_face_down_backrow(lane: String, enemy_back_slot: Node, enemy_back_card: CardData, ability_name: String = "Volley") -> void:
	await ability_controller.resolve_volley_attack_into_face_down_backrow(lane, enemy_back_slot, enemy_back_card, ability_name)


func _mark_and_polish_tree(node: Node) -> void:
	if node == null:
		return
	if node.has_method("get_card_data") and node.has_method("set_usable_ability_ids"):
		if not node.is_in_group("card_ability_icon_polish"):
			node.add_to_group("card_ability_icon_polish")
		polish_card_visual_ability_icons(node)
	for child in node.get_children():
		_mark_and_polish_tree(child)

func polish_card_visual_ability_icons(card_visual: Node) -> void:
	if card_visual == null or not is_instance_valid(card_visual):
		return
	var root := card_visual.get_node_or_null("AbilityIconRoot") as Node3D
	if root == null:
		return
	for icon_root in root.get_children():
		if icon_root == null:
			continue

		# Remove the old tiny yellow 3D tooltip. The screen-space black tooltip is the only tooltip now.
		var yellow_tooltip := icon_root.get_node_or_null("Tooltip") as Label3D
		if yellow_tooltip != null and not yellow_tooltip.is_queued_for_deletion():
			yellow_tooltip.queue_free()

		var area := icon_root.get_node_or_null("ClickArea") as Area3D
		if area != null:
			var collision := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if collision != null and collision.shape is BoxShape3D:
				(collision.shape as BoxShape3D).size = ABILITY_HOVER_BOX_SIZE

		var icon := icon_root.get_node_or_null("Icon") as Sprite3D
		if icon != null:
			icon.pixel_size = maxf(icon.pixel_size, 0.0038)

		var glow := icon_root.get_node_or_null("Glow") as Sprite3D
		if glow != null:
			glow.pixel_size = maxf(glow.pixel_size, 0.0062)

func get_or_create_mobility_prompt_row() -> Control:
	var existing := get_node_or_null("UI/MobilityPromptRow") as Control
	if existing != null:
		return existing
	var root := Control.new()
	root.name = "MobilityPromptRow"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 121
	root.visible = false
	root.modulate.a = 0.0
	$UI.add_child(root)
	var center_row := HBoxContainer.new()
	center_row.name = "CenterRow"
	center_row.anchor_left = 0.0
	center_row.anchor_right = 1.0
	center_row.anchor_top = MOBILITY_PROMPT_CENTER_Y
	center_row.anchor_bottom = MOBILITY_PROMPT_CENTER_Y
	center_row.offset_top = -62.0
	center_row.offset_bottom = 62.0
	center_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center_row.add_theme_constant_override("separation", 18)
	root.add_child(center_row)
	var icon := TextureRect.new()
	icon.name = "PromptIcon"
	icon.custom_minimum_size = Vector2(58.0, 58.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(MOBILITY_PROMPT_ICON_PATH):
		icon.texture = load(MOBILITY_PROMPT_ICON_PATH) as Texture2D
	center_row.add_child(icon)
	var label := Label.new()
	label.name = "PromptLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(760.0, 0.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.98))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.035, 0.92))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_shadow_color", Color(0.10, 0.11, 0.14, 0.72))
	label.add_theme_constant_override("shadow_outline_size", 5)
	center_row.add_child(label)
	return root
