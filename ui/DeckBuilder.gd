class_name DeckBuilder
extends Node3D

const CARD_SCENE: PackedScene = preload("res://cards/Card3D_Test.tscn")
const BATTLE_SCENE_PATH := "res://battlefield/battlefield_3d.tscn"
const MENU_SCENE_PATH := "res://ui/Menu/prototype_menu.tscn"
const SAVE_PATH := "user://lov_player_deck.json"

const MIN_DECK_SIZE := 10
const MAX_DECK_SIZE := 40
const DECK_SLOT_COUNT := 10
const DECK_CHIP_WALL_X := 2.40
const DECK_CHIP_TOTAL_WIDTH := 3.40
const DECK_CHIP_SLOT_PITCH := 0.34
const DECK_CHIP_HIDDEN_POSITION := Vector3(5.98, 0.09, -2.20)
const DECK_CHIP_SHOWN_POSITION := Vector3(2.40, 0.09, -2.20)
const DECK_RACK_EXIT_OFFSET := Vector3(0.0, 0.0, 6.0)
const DECK_RACK_ENTRY_OFFSET := Vector3(0.0, 0.0, -6.0)

# Card sizing and library layout.
# The library is a continuous horizontal strip made of 5x2 card groups.
const CARD_SCALE_LIBRARY := Vector3(1.35, 1.35, 1.35)
const CARD_SCALE_LIBRARY_HOVER := Vector3(1.60, 1.60, 1.60)
const CARD_SCALE_RACK_HOVER := Vector3(1.24, 1.24, 1.24)
const CARD_SCALE_RACK := Vector3(1.12, 1.12, 1.12)

const LIBRARY_Y := 0.085
const RACK_Y := 0.42
const LIBRARY_HOVER_Y := 0.50
const RACK_HOVER_Y := 0.80
const RACK_CARD_TILT_DEGREES := 23.0
const RACK_CARD_REVEAL_SPACING := 0.215

const LIBRARY_BASE_X := -4.90
const LIBRARY_BASE_Z := -0.20
const LIBRARY_COLUMNS_PER_GROUP := 5
const LIBRARY_ROWS_PER_GROUP := 2
const LIBRARY_GROUP_SIZE := 10
const LIBRARY_COLUMN_SPACING := 1.55
const LIBRARY_ROW_SPACING := 2.10
const LIBRARY_GROUP_SPACING := 7.75

# Continuous wheel scroll. This is intentionally much smaller than one group.
const LIBRARY_SCROLL_WHEEL_STEP := 0.62
const LIBRARY_SCROLL_LERP_SPEED := 9.0

# Card-center bounds inside the red cloth. The right boundary deliberately ends
# before the rack wall so even a wide card is gone before entering the rack.
const LIBRARY_VISIBLE_MIN_X := -6.42
const LIBRARY_VISIBLE_MAX_X := 2.20

# CardBody shader clipping window.
# This clips the card texture at the carpet edges without creating black mask blocks.
const LIBRARY_CARD_CLIP_SHADER_PATH := "res://ui/shaders/deck_builder_card_window_clip.gdshader"
const LIBRARY_CARD_CLIP_FADE_WIDTH := 0.24
const LIBRARY_CARD_INTERACTION_INSET := 0.58
const LIBRARY_RENDER_SIDE_BUFFER := 1.20

# Copy-count labels (like "2x") should disappear a bit before the card reaches the clip edge,
# so they feel like they are going behind the library border too.
const LIBRARY_COUNT_LABEL_INSET := 0.92

const CARD_PICK_LAYER_LIBRARY := 1
const CARD_PICK_LAYER_DECK := 2
const DECK_SLOT_PICK_LAYER := 4
const CARD_ACTION_INSPECT := 1
const CARD_ACTION_CANCEL := 99
const ABILITY_FILTERS := ["Assault", "Control", "Attrition", "Economy", "Protection", "Insight", "Mobility"]
const ABILITY_ICON_PATHS := {
	"assault": "res://ui/ability_icons/assault.png",
	"control": "res://ui/ability_icons/control.png",
	"attrition": "res://ui/ability_icons/attrition.png",
	"economy": "res://ui/ability_icons/economy.png",
	"protection": "res://ui/ability_icons/protection.png",
	"insight": "res://ui/ability_icons/insight.png",
	"mobility": "res://ui/ability_icons/mobility.png",
}

enum LibrarySortMode {
	NAME,
	TP,
	AP,
	DP,
}

# Rack bounds from deck_builder.tscn (scene-accurate).
# Inner left wall X=2.496, inner right wall X=5.496, center X=3.996.
# Z range inner: -2.33 to 3.31, center Z=0.49.
const RACK_COL_LEFT  := 3.25
const RACK_COL_RIGHT := 4.54
const RACK_MAX_PER_COL := 20
const RACK_STACK_START_Z := -1.56
const RACK_Z_TOP    := -2.28   # just inside top wall
const RACK_Z_BOTTOM :=  3.26   # just inside bottom wall
const RACK_MIN_X := 2.52
const RACK_MAX_X := 5.45
const RACK_MIN_Z := -2.50
const RACK_MAX_Z :=  3.50
# Cards lean toward the camera and can be approached from well above the rack's
# top wall onscreen. This expanded top edge is used only while dragging.
const RACK_DROP_MIN_Z := -4.25
const RACK_DROP_MAX_X := 6.75

const TABLE_PLANE_Y := 0.0

var all_cards: Array[CardData] = []
var filtered_cards: Array[CardData] = []
var card_lookup: Dictionary = {}
var deck_cards: Array[CardData] = []
var deck_nodes: Array[Node3D] = []
var library_nodes: Array[Node3D] = []

var library_root: Node3D
var rack_root: Node3D
var rack_assembly_root: Node3D
var rack_assembly_home_position := Vector3.ZERO
var dragging_node: Node3D = null
var dragging_card: CardData = null
var dragging_from_library := false
var dragging_deck_original_index := -1
var dragging_target_position := Vector3.ZERO
var drag_pointer_offset := Vector3.ZERO
var drag_pointer_screen_position := Vector2.ZERO
var drag_card_center_screen_offset := Vector2.ZERO
var dragging_over_rack := false
var drag_rack_blend := 0.0
var drag_preview_insert_index := 0
var library_scroll := 0.0
var library_scroll_target := 0.0
var library_scroll_min := 0.0
var library_scroll_max := 0.0

var active_race_filters: Dictionary = {}
var active_type_filters: Dictionary = {}
var active_ability_filters: Dictionary = {}
var search_text := ""
var library_sort_mode: LibrarySortMode = LibrarySortMode.NAME
var library_sort_ascending := true

var camera_3d: Camera3D
var ui_layer: CanvasLayer
var status_label: Label
var deck_count_label: Label
var deck_name_edit: LineEdit
var save_button: Button
var play_button: Button
var search_box: LineEdit
var library_sort_button: MenuButton
var library_scroll_slider: HSlider
var library_scroll_slider_hitbox: Control
var library_scroll_slider_surface: MeshInstance3D
var library_scroll_slider_viewport: SubViewport
var library_scroll_slider_world_size := Vector2.ZERO
var library_scroll_slider_internal_update := false
var library_scroll_slider_dragging := false
var library_scroll_slider_hovered := false
var library_scroll_slider_drag_offset_x := 0.0
var card_detail_label: RichTextLabel
var card_detail_name_3d: Label3D
var card_detail_stats_3d: Label3D
var library_controls_label_3d: Label3D
var deck_ledger_label_3d: Label3D
var tabletop_ui_surfaces: Array[Dictionary] = []
var active_tabletop_viewport: SubViewport
var saved_decks: Array[Dictionary] = []
var active_deck_slot := 0
var deck_slot_roots: Array[Node3D] = []
var deck_slot_number_labels: Array[Label3D] = []
var deck_slot_count_labels: Array[Label3D] = []
var deck_slot_fill_meshes: Array[MeshInstance3D] = []
var deck_chip_root: Node3D
var deck_chip_tween: Tween
var deck_chip_is_out := false
var deck_switch_in_progress := false
var scene_transition_requested: bool = false
var card_action_menu: PopupMenu
var card_action_target: Node3D
var card_inspect_panel: CardInspectPanel
var race_buttons: Dictionary = {}
var type_buttons: Dictionary = {}
var ability_buttons: Dictionary = {}
var ability_filter_button: Button
var ability_filter_panel: PanelContainer


func _ready() -> void:
	all_cards = CardDatabase.get_all_test_cards()
	all_cards.sort_custom(func(a: CardData, b: CardData) -> bool:
		return get_card_sort_key(a) < get_card_sort_key(b)
	)
	build_card_lookup()
	initialize_deck_slots()
	build_3d_scene()
	build_overlay_ui()
	load_deck_from_disk()
	refresh_library()
	layout_deck_rack(true)
	update_deck_status()
	set_status("3D deck table ready. Drag cards from the left table into the right rack.")


func _process(delta: float) -> void:
	if library_scroll_slider_dragging:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			set_library_scroll_from_slider_screen_position(get_viewport().get_mouse_position())
			Cursors.use_grab()
		else:
			end_library_scroll_slider_drag()

	if absf(library_scroll - library_scroll_target) > 0.001:
		var scroll_weight: float = clampf(delta * LIBRARY_SCROLL_LERP_SPEED, 0.0, 1.0)
		library_scroll = lerpf(library_scroll, library_scroll_target, scroll_weight)
		layout_library(false)

	animate_collection(library_nodes, delta)
	animate_collection(deck_nodes, delta)
	update_deck_chip_wall_clipping()

	if dragging_node != null and is_instance_valid(dragging_node):
		drag_rack_blend = lerpf(
			drag_rack_blend,
			1.0 if dragging_over_rack else 0.0,
			clampf(delta * 9.0, 0.0, 1.0)
		)
		refresh_drag_target_position()
		var hover_scale := CARD_SCALE_LIBRARY_HOVER.lerp(CARD_SCALE_RACK_HOVER, drag_rack_blend)
		var hover_rotation := Vector3(
			lerpf(0.0, RACK_CARD_TILT_DEGREES, drag_rack_blend),
			0.0,
			0.0
		)
		dragging_node.global_position = dragging_node.global_position.lerp(
			dragging_target_position,
			clampf(delta * 16.0, 0.0, 1.0)
		)
		dragging_node.scale = dragging_node.scale.lerp(hover_scale, clampf(delta * 10.0, 0.0, 1.0))
		dragging_node.rotation_degrees = dragging_node.rotation_degrees.lerp(
			hover_rotation,
			clampf(delta * 10.0, 0.0, 1.0)
		)
		set_card_alpha(dragging_node, 1.0)


func _input(event: InputEvent) -> void:
	if scene_transition_requested or not is_inside_tree():
		return
	if deck_switch_in_progress:
		var current_viewport := get_viewport()
		if current_viewport != null:
			current_viewport.set_input_as_handled()
		return

	if handle_library_scroll_slider_manual_input(event):
		var current_viewport := get_viewport()
		if current_viewport != null and is_inside_tree():
			current_viewport.set_input_as_handled()
		return

	if event is InputEventMouseMotion and dragging_node == null:
		var mouse_position := (event as InputEventMouseMotion).position

		if not update_library_slider_cursor_for_screen_position(mouse_position):
			update_cursor_for_screen_position(mouse_position)

	if route_tabletop_ui_input(event):
		var current_viewport := get_viewport()
		if current_viewport != null and is_inside_tree():
			current_viewport.set_input_as_handled()
		return

	# Mouse-wheel scrolling must work even when the overlay UI is present.
	# Only block it while the search field is actively being typed in.
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			if search_box == null or not search_box.has_focus():
				set_library_scroll(library_scroll_target - LIBRARY_SCROLL_WHEEL_STEP)
				get_viewport().set_input_as_handled()
			return

		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			if search_box == null or not search_box.has_focus():
				set_library_scroll(library_scroll_target + LIBRARY_SCROLL_WHEEL_STEP)
				get_viewport().set_input_as_handled()
			return

		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			if card_inspect_panel != null and card_inspect_panel.visible:
				card_inspect_panel.hide_card()
				get_viewport().set_input_as_handled()
				return
			if not is_pointer_over_ui():
				show_card_action_menu(mouse_event.position)
				get_viewport().set_input_as_handled()
			return

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if is_pointer_over_ui():
				return
			if mouse_event.pressed:
				var slot_index := pick_deck_slot_index(mouse_event.position)
				if slot_index >= 0:
					_on_deck_slot_pressed(slot_index)
					get_viewport().set_input_as_handled()
					return
				begin_drag_from_mouse(mouse_event.position)
			else:
				finish_drag(mouse_event.position)
			return

	if event is InputEventMouseMotion:
		if dragging_node != null:
			update_drag_target((event as InputEventMouseMotion).position)
			if not dragging_from_library:
				drag_preview_insert_index = get_deck_insert_index_from_screen(
					(event as InputEventMouseMotion).position
				)
				layout_deck_rack(false, drag_preview_insert_index)


func build_3d_scene() -> void:
	# Use the editor-built 3D scene. Do not create duplicate table/rack meshes here.
	# Camera position/rotation/FOV are controlled in deck_builder.tscn.
	camera_3d = get_node_or_null("DeckBuilderCamera") as Camera3D
	if camera_3d != null:
		camera_3d.current = true
	else:
		push_warning("DeckBuilderCamera is missing from deck_builder.tscn.")

	var world_environment: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment != null and world_environment.environment == null:
		world_environment.environment = Environment.new()
		world_environment.environment.background_mode = Environment.BG_COLOR
		world_environment.environment.background_color = Color(0.015, 0.012, 0.010, 1.0)
		world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world_environment.environment.ambient_light_color = Color(0.70, 0.58, 0.42, 1.0)
		world_environment.environment.ambient_light_energy = 0.45

	library_root = get_node_or_null("LibraryCards") as Node3D
	if library_root == null:
		library_root = Node3D.new()
		library_root.name = "LibraryCards"
		add_child(library_root)

	setup_rack_assembly()

	build_tabletop_ui_labels()


func setup_rack_assembly() -> void:
	# The authored scene owns one mover containing both the imported tray and
	# its cards. Keeping this hierarchy intact makes deck swaps move as a unit.
	rack_assembly_root = get_node_or_null("DeckRackMover") as Node3D
	if rack_assembly_root == null:
		rack_assembly_root = Node3D.new()
		rack_assembly_root.name = "DeckRackMover"
		add_child(rack_assembly_root)

	rack_root = rack_assembly_root.get_node_or_null("DeckRackCards") as Node3D
	if rack_root == null:
		# Migrate an older root-level card container without changing its world pose.
		rack_root = get_node_or_null("DeckRackCards") as Node3D
		if rack_root == null:
			rack_root = Node3D.new()
			rack_root.name = "DeckRackCards"
		if rack_root.get_parent() == null:
			rack_assembly_root.add_child(rack_root)
		else:
			rack_root.reparent(rack_assembly_root, true)

	# Legacy scenes kept the rack light at the scene root. It belongs to the
	# moving assembly, while the authored WoodenTray is already its child.
	var rack_glow := get_node_or_null("RackWarmGlow") as Node3D
	if rack_glow != null and rack_glow.get_parent() != rack_assembly_root:
		rack_glow.reparent(rack_assembly_root, true)

	rack_assembly_home_position = rack_assembly_root.position


func build_tabletop_ui_labels() -> void:
	card_detail_name_3d = make_tabletop_label(
		"CardDetailName3D",
		"",
		Vector3(0.2, 0.095, -2.20),
		26,
		0.0075,
		Color(1.0, 0.83, 0.35, 1.0)
	)
	card_detail_stats_3d = make_tabletop_label(
		"CardDetailStats3D",
		"",
		Vector3(0.2, 0.094, -1.90),
		18,
		0.0070,
		Color(0.96, 0.88, 0.69, 1.0)
	)
	card_detail_name_3d.visible = false
	card_detail_stats_3d.visible = false



func make_tabletop_label(
	node_name: String,
	label_text: String,
	world_position: Vector3,
	label_font_size: int,
	label_pixel_size: float,
	label_color: Color
) -> Label3D:
	var label := get_node_or_null(node_name) as Label3D
	if label == null:
		label = Label3D.new()
		label.name = node_name
		add_child(label)
	label.text = label_text
	label.position = world_position
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	label.font_size = label_font_size
	label.pixel_size = label_pixel_size
	label.modulate = label_color
	label.outline_size = 8
	label.outline_modulate = Color(0.035, 0.012, 0.004, 0.95)
	label.no_depth_test = false
	return label


func build_overlay_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "DeckBuilderOverlay"
	add_child(ui_layer)

	var root := Control.new()
	root.name = "OverlayRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	ui_layer.add_child(root)

	card_inspect_panel = CardInspectPanel.new()
	card_inspect_panel.name = "CardInspectPanel"
	card_inspect_panel.center_on_screen = true
	card_inspect_panel.centered_display_size = Vector2(760.0, 1000.0)
	card_inspect_panel.preview_render_scale = 3.0
	root.add_child(card_inspect_panel)

	card_action_menu = PopupMenu.new()
	card_action_menu.name = "CardActionMenu"
	card_action_menu.exclusive = false
	card_action_menu.id_pressed.connect(_on_card_action_selected)
	root.add_child(card_action_menu)

	tabletop_ui_surfaces.clear()

	var library_ui := create_tabletop_ui_surface(
		"LibraryTabletopUI",
		Vector2i(1100, 100),
		Vector3(-1.9, 0.105, 3.48),
		Vector2(6.50, 0.555)
	)
	var library_ui_root: Control = library_ui["control"]

	var library_slider_ui := create_tabletop_ui_surface(
		"LibraryScrollSliderUI",
		Vector2i(1200, 54),
		Vector3(-2.05, 0.118, 2.6),
		Vector2(7.80, 0.255)
	)
	var library_slider_root: Control = library_slider_ui["control"]
	library_scroll_slider_surface = library_slider_ui["surface"]
	library_scroll_slider_viewport = library_slider_ui["viewport"]
	library_scroll_slider_world_size = library_slider_ui["world_size"]
	build_library_scroll_slider(library_slider_root)

	var deck_ui := create_tabletop_ui_surface(
		"DeckTabletopUI",
		Vector2i(520, 100),
		Vector3(4.10, 0.105, 3.48),
		Vector2(3.20, 0.555)
	)
	var deck_ui_root: Control = deck_ui["control"]

	var ability_popup_ui := create_tabletop_ui_surface(
		"AbilityFilterPopupUI",
		Vector2i(390, 60),
		Vector3(0, 0.135, 3.05),
		Vector2(2.35, 0.36)
	)
	var ability_popup_root: Control = ability_popup_ui["control"]

	# Put the popup surface first so it receives mouse input before the lower HUD.
	var ability_surface_entry: Dictionary = tabletop_ui_surfaces.pop_back()
	tabletop_ui_surfaces.push_front(ability_surface_entry)

	var plaque_style := make_panel_style(
		Color(0.18, 0.115, 0.065, 0.62),
		Color(0.0, 0.0, 0.0, 0.0),
		0
	)

	# A floating wooden plaque over the lower-left table, not a screen-wide bar.
	var library_plaque := PanelContainer.new()
	library_plaque.name = "LibraryControlPlaque"
	library_plaque.set_anchors_preset(Control.PRESET_FULL_RECT)
	library_plaque.offset_left = 10.0
	library_plaque.offset_top = 10.0
	library_plaque.offset_right = -10.0
	library_plaque.offset_bottom = -10.0
	library_plaque.add_theme_stylebox_override("panel", plaque_style)
	library_ui_root.add_child(library_plaque)

	var library_margin := MarginContainer.new()
	library_margin.add_theme_constant_override("margin_left", 12)
	library_margin.add_theme_constant_override("margin_right", 12)
	library_margin.add_theme_constant_override("margin_top", 6)
	library_margin.add_theme_constant_override("margin_bottom", 6)
	library_plaque.add_child(library_margin)

	var library_rows := VBoxContainer.new()
	library_rows.add_theme_constant_override("separation", 5)
	library_margin.add_child(library_rows)

	var command_row := HBoxContainer.new()
	command_row.add_theme_constant_override("separation", 8)
	library_rows.add_child(command_row)

	var back_button := TextureButton.new()
	back_button.texture_normal = preload("res://ui/combat_buttons/pass_button.png")
	back_button.texture_hover = preload("res://ui/combat_buttons/pass_button.png")
	back_button.texture_pressed = preload("res://ui/combat_buttons/pass_button.png")
	back_button.ignore_texture_size = true
	back_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	back_button.custom_minimum_size = Vector2(58, 26)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_button.pressed.connect(request_scene_change.bind(MENU_SCENE_PATH, "back_button"))
	command_row.add_child(back_button)

	var title_label := Label.new()
	title_label.text = "DECK BUILDER"
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	command_row.add_child(title_label)

	search_box = LineEdit.new()
	search_box.placeholder_text = "Search the card archives..."
	search_box.custom_minimum_size = Vector2(250, 32)
	search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_box.add_theme_font_size_override("font_size", 12)
	style_text_field(search_box)
	search_box.text_changed.connect(_on_search_changed)
	command_row.add_child(search_box)

	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 5)
	library_rows.add_child(filter_row)
	add_filter_caption(filter_row, "FACTION")
	add_filter_buttons(filter_row, ["All", "Human", "Dwarf", "Orc", "Elf", "Neutral"], race_buttons, _on_race_filter_pressed)
	add_filter_caption(filter_row, "CARD")
	add_filter_buttons(filter_row, ["All", "Unit", "Gambit", "Equipment"], type_buttons, _on_type_filter_pressed)

	ability_filter_button = make_button("Abilities", Vector2(88, 26))
	ability_filter_button.toggle_mode = true
	ability_filter_button.pressed.connect(_on_ability_filter_toggle_pressed)
	filter_row.add_child(ability_filter_button)

	library_sort_button = make_library_sort_button()
	filter_row.add_child(library_sort_button)

	# Keep free viewport space to the right so the embedded popup can open
	# beside this button instead of being forced above it.
	var filter_spacer := Control.new()
	filter_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filter_row.add_child(filter_spacer)
	create_ability_filter_panel(ability_popup_root)

	# A separate deck ledger over the lower-right table leaves open space between.
	var deck_plaque := PanelContainer.new()
	deck_plaque.name = "DeckLedgerPlaque"
	deck_plaque.set_anchors_preset(Control.PRESET_FULL_RECT)
	deck_plaque.offset_left = 10.0
	deck_plaque.offset_top = 10.0
	deck_plaque.offset_right = -10.0
	deck_plaque.offset_bottom = -10.0
	deck_plaque.add_theme_stylebox_override("panel", plaque_style)
	deck_ui_root.add_child(deck_plaque)

	var deck_margin := MarginContainer.new()
	deck_margin.add_theme_constant_override("margin_left", 12)
	deck_margin.add_theme_constant_override("margin_right", 12)
	deck_margin.add_theme_constant_override("margin_top", 6)
	deck_margin.add_theme_constant_override("margin_bottom", 6)
	deck_plaque.add_child(deck_margin)

	var deck_rows := VBoxContainer.new()
	deck_rows.add_theme_constant_override("separation", 5)
	deck_margin.add_child(deck_rows)

	var ledger_header := HBoxContainer.new()
	ledger_header.add_theme_constant_override("separation", 6)
	deck_rows.add_child(ledger_header)

	var ledger_label := Label.new()
	ledger_label.text = "WAR DECK LEDGER"
	ledger_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ledger_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ledger_label.add_theme_font_size_override("font_size", 14)
	ledger_label.add_theme_color_override("font_color", Color.WHITE)
	ledger_header.add_child(ledger_label)

	deck_count_label = Label.new()
	deck_count_label.custom_minimum_size = Vector2(76, 28)
	deck_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	deck_count_label.add_theme_font_size_override("font_size", 13)
	deck_count_label.add_theme_color_override("font_color", Color.WHITE)
	ledger_header.add_child(deck_count_label)

	var slots_button := make_button("SLOTS", Vector2(58, 28))
	slots_button.pressed.connect(toggle_deck_chip)
	ledger_header.add_child(slots_button)

	var clear_button := make_button("CLEAR", Vector2(62, 28))
	clear_button.pressed.connect(_on_clear_pressed)
	ledger_header.add_child(clear_button)

	var sort_button := make_button("SORT", Vector2(62, 28))
	sort_button.pressed.connect(_on_sort_pressed)
	ledger_header.add_child(sort_button)

	var deck_row := HBoxContainer.new()
	deck_row.add_theme_constant_override("separation", 7)
	deck_rows.add_child(deck_row)

	deck_name_edit = LineEdit.new()
	deck_name_edit.text = "Custom Warband"
	deck_name_edit.custom_minimum_size = Vector2(170, 34)
	deck_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_name_edit.add_theme_font_size_override("font_size", 12)
	style_text_field(deck_name_edit)
	deck_row.add_child(deck_name_edit)

	var delete_button := make_button("DELETE", Vector2(72, 34))
	delete_button.pressed.connect(delete_active_deck_slot)
	deck_row.add_child(delete_button)

	save_button = make_button("SAVE", Vector2(72, 34))
	save_button.pressed.connect(save_deck_to_disk)
	deck_row.add_child(save_button)

	play_button = make_button("TO BATTLE", Vector2(102, 34), true)
	play_button.pressed.connect(_on_save_and_battle_pressed)
	deck_row.add_child(play_button)

	status_label = Label.new()
	status_label.visible = false
	root.add_child(status_label)

	build_deck_slot_chip()
	refresh_filter_buttons()


func build_library_scroll_slider(parent: Control) -> void:
	if parent == null:
		return

	parent.mouse_filter = Control.MOUSE_FILTER_PASS

	var outer := PanelContainer.new()
	outer.name = "LibraryScrollSliderGlass"
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 28.0
	outer.offset_right = -28.0
	outer.offset_top = 8.0
	outer.offset_bottom = -8.0
	outer.mouse_filter = Control.MOUSE_FILTER_PASS
	outer.add_theme_stylebox_override(
		"panel",
		make_library_scroll_glass_panel_style()
	)
	parent.add_child(outer)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	outer.add_child(margin)

	var slider_layer := Control.new()
	slider_layer.name = "LibraryScrollSliderLayer"
	slider_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	slider_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(slider_layer)

	library_scroll_slider = HSlider.new()
	library_scroll_slider.name = "LibraryScrollSlider"
	library_scroll_slider.set_anchors_preset(Control.PRESET_FULL_RECT)
	library_scroll_slider.min_value = library_scroll_min
	library_scroll_slider.max_value = maxf(library_scroll_max, 0.001)
	library_scroll_slider.step = 0.001
	library_scroll_slider.value = library_scroll_target
	library_scroll_slider.focus_mode = Control.FOCUS_NONE

	# Important: the real HSlider is visual-only.
	# It must not receive clicks, track clicks, hover drags, or Godot's default slider behavior.
	library_scroll_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE

	style_library_scroll_slider(library_scroll_slider)
	slider_layer.add_child(library_scroll_slider)

	library_scroll_slider_hitbox = Control.new()
	library_scroll_slider_hitbox.name = "LibraryScrollSliderKnobHitbox"
	library_scroll_slider_hitbox.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Important:
	# This hitbox is only used for size/position math.
	# It must NOT receive Godot GUI input, otherwise the whole track starts acting like a slider.
	library_scroll_slider_hitbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	slider_layer.add_child(library_scroll_slider_hitbox)

	refresh_library_scroll_slider()


func make_library_scroll_glass_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.020, 0.025, 0.035, 0.42)
	style.border_color = Color(1.0, 1.0, 1.0, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 6
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func style_library_scroll_slider(slider: HSlider) -> void:
	if slider == null:
		return

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.0, 0.0, 0.0, 0.42)
	track.border_color = Color(1.0, 1.0, 1.0, 0.16)
	track.set_border_width_all(1)
	track.set_corner_radius_all(8)
	track.content_margin_top = 6.0
	track.content_margin_bottom = 6.0

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.82, 0.36, 0.54)
	fill.border_color = Color(1.0, 0.94, 0.70, 0.45)
	fill.set_border_width_all(1)
	fill.set_corner_radius_all(8)
	fill.content_margin_top = 6.0
	fill.content_margin_bottom = 6.0

	var fill_hover := fill.duplicate() as StyleBoxFlat
	fill_hover.bg_color = Color(1.0, 0.88, 0.48, 0.72)
	fill_hover.border_color = Color(1.0, 1.0, 1.0, 0.62)

	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_hover)

	slider.add_theme_icon_override(
		"grabber",
		make_library_scroll_knob_texture(
			26,
			Color(1.0, 0.86, 0.42, 0.95),
			Color(1.0, 1.0, 1.0, 0.72)
		)
	)

	slider.add_theme_icon_override(
		"grabber_highlight",
		make_library_scroll_knob_texture(
			28,
			Color(1.0, 0.92, 0.55, 1.0),
			Color(1.0, 1.0, 1.0, 0.92)
		)
	)

	slider.add_theme_icon_override(
		"grabber_disabled",
		make_library_scroll_knob_texture(
			22,
			Color(0.65, 0.62, 0.55, 0.36),
			Color(1.0, 1.0, 1.0, 0.20)
		)
	)


func make_library_scroll_knob_texture(diameter: int, fill_color: Color, border_color: Color) -> Texture2D:
	var image := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var center := Vector2(float(diameter - 1) * 0.5, float(diameter - 1) * 0.5)
	var radius := float(diameter) * 0.44
	var border_radius := radius
	var fill_radius := radius - 2.0

	for y in range(diameter):
		for x in range(diameter):
			var distance := Vector2(float(x), float(y)).distance_to(center)

			if distance <= fill_radius:
				image.set_pixel(x, y, fill_color)
			elif distance <= border_radius:
				image.set_pixel(x, y, border_color)

	return ImageTexture.create_from_image(image)
	

func handle_library_scroll_slider_manual_input(event: InputEvent) -> bool:
	if library_scroll_slider == null:
		return false

	if library_scroll_slider_hitbox == null:
		return false

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return false

		if not mouse_event.pressed:
			if library_scroll_slider_dragging:
				end_library_scroll_slider_drag()
				return true

			return false

		var local_point := get_library_scroll_slider_hitbox_local_from_screen(mouse_event.position)

		if not is_library_scroll_slider_local_point_valid(local_point):
			return false

		# Clicking the track should do nothing, but it should still consume the click
		# so it does not accidentally trigger other deck-builder interactions.
		if not is_library_scroll_slider_local_point_on_knob(local_point):
			Cursors.use_normal()
			return true

		var knob_rect := get_library_scroll_slider_knob_rect()
		library_scroll_slider_drag_offset_x = local_point.x - knob_rect.get_center().x
		begin_library_scroll_slider_drag()
		return true

	if event is InputEventMouseMotion and library_scroll_slider_dragging:
		var mouse_motion := event as InputEventMouseMotion
		set_library_scroll_from_slider_screen_position(mouse_motion.position)
		Cursors.use_grab()
		return true

	return false


func update_library_slider_cursor_for_screen_position(screen_position: Vector2) -> bool:
	if library_scroll_slider_dragging:
		Cursors.use_grab()
		return true

	var local_point := get_library_scroll_slider_hitbox_local_from_screen(screen_position)

	if not is_library_scroll_slider_local_point_valid(local_point):
		return false

	if is_library_scroll_slider_local_point_on_knob(local_point):
		Cursors.use_pointing()
	else:
		Cursors.use_normal()

	return true


func begin_library_scroll_slider_drag() -> void:
	library_scroll_slider_dragging = true
	Cursors.use_grab()


func end_library_scroll_slider_drag() -> void:
	if not library_scroll_slider_dragging:
		return

	library_scroll_slider_dragging = false
	library_scroll_slider_drag_offset_x = 0.0

	var local_point := get_library_scroll_slider_hitbox_local_from_screen(get_viewport().get_mouse_position())

	if is_library_scroll_slider_local_point_valid(local_point) and is_library_scroll_slider_local_point_on_knob(local_point):
		Cursors.use_pointing()
	else:
		Cursors.use_normal()


func set_library_scroll_from_slider_screen_position(screen_position: Vector2) -> void:
	var local_point := get_library_scroll_slider_hitbox_local_from_screen(screen_position)

	if not is_library_scroll_slider_local_point_valid(local_point):
		# While dragging, allow off-surface mouse movement to clamp to the edge.
		local_point = get_library_scroll_slider_unclamped_hitbox_local_from_screen(screen_position)

	if not is_library_scroll_slider_local_point_valid(local_point):
		return

	set_library_scroll_from_slider_local_x(local_point.x)


func set_library_scroll_from_slider_local_x(local_x: float) -> void:
	if library_scroll_slider_hitbox == null:
		return

	var hitbox_width := library_scroll_slider_hitbox.size.x

	if hitbox_width <= 0.001:
		return

	var knob_radius := get_library_scroll_slider_knob_radius()
	var usable_width := maxf(hitbox_width - knob_radius * 2.0, 1.0)

	var knob_center_x := clampf(
		local_x - library_scroll_slider_drag_offset_x,
		knob_radius,
		hitbox_width - knob_radius
	)

	var slider_ratio := clampf(
		(knob_center_x - knob_radius) / usable_width,
		0.0,
		1.0
	)

	var next_scroll := lerpf(library_scroll_min, library_scroll_max, slider_ratio)
	set_library_scroll(next_scroll)


func get_library_scroll_slider_hitbox_local_from_screen(screen_position: Vector2) -> Vector2:
	if library_scroll_slider_surface == null:
		return Vector2(INF, INF)

	if library_scroll_slider_viewport == null:
		return Vector2(INF, INF)

	if library_scroll_slider_world_size.x <= 0.001 or library_scroll_slider_world_size.y <= 0.001:
		return Vector2(INF, INF)

	if library_scroll_slider_hitbox == null:
		return Vector2(INF, INF)

	var hit: Vector3 = screen_to_horizontal_plane(screen_position, library_scroll_slider_surface.global_position.y)
	var local_hit: Vector3 = library_scroll_slider_surface.to_local(hit)
	var half_size := library_scroll_slider_world_size * 0.5

	if absf(local_hit.x) > half_size.x:
		return Vector2(INF, INF)

	if absf(local_hit.y) > half_size.y:
		return Vector2(INF, INF)

	return get_library_scroll_slider_hitbox_local_from_surface_local(local_hit)


func get_library_scroll_slider_unclamped_hitbox_local_from_screen(screen_position: Vector2) -> Vector2:
	if library_scroll_slider_surface == null:
		return Vector2(INF, INF)

	if library_scroll_slider_viewport == null:
		return Vector2(INF, INF)

	if library_scroll_slider_world_size.x <= 0.001:
		return Vector2(INF, INF)

	if library_scroll_slider_hitbox == null:
		return Vector2(INF, INF)

	var hit: Vector3 = screen_to_horizontal_plane(screen_position, library_scroll_slider_surface.global_position.y)
	var local_hit: Vector3 = library_scroll_slider_surface.to_local(hit)

	return get_library_scroll_slider_hitbox_local_from_surface_local(local_hit)


func get_library_scroll_slider_hitbox_local_from_surface_local(local_hit: Vector3) -> Vector2:
	var surface_ratio_x := clampf(
		(local_hit.x / library_scroll_slider_world_size.x) + 0.5,
		0.0,
		1.0
	)

	var viewport_x := surface_ratio_x * float(library_scroll_slider_viewport.size.x)
	var hitbox_rect := library_scroll_slider_hitbox.get_global_rect()

	if hitbox_rect.size.x <= 0.001:
		return Vector2(INF, INF)

	var local_x := viewport_x - hitbox_rect.position.x

	# We intentionally lock Y to the knob center.
	# The physical slider strip is already tiny, so X is the only important grab test.
	return Vector2(local_x, library_scroll_slider_hitbox.size.y * 0.5)


func is_library_scroll_slider_local_point_valid(local_point: Vector2) -> bool:
	return is_finite(local_point.x) and is_finite(local_point.y)


func is_library_scroll_slider_local_point_on_knob(local_position: Vector2) -> bool:
	var knob_rect := get_library_scroll_slider_knob_rect()

	# Larger grab zone around the dot so it is not annoyingly hard to pick up.
	return knob_rect.grow(16.0).has_point(local_position)


func get_library_scroll_slider_knob_rect() -> Rect2:
	if library_scroll_slider_hitbox == null:
		return Rect2()

	var hitbox_width := library_scroll_slider_hitbox.size.x
	var hitbox_height := library_scroll_slider_hitbox.size.y
	var knob_radius := get_library_scroll_slider_knob_radius()
	var usable_width := maxf(hitbox_width - knob_radius * 2.0, 1.0)
	var scroll_ratio := 0.0

	if library_scroll_max > library_scroll_min:
		scroll_ratio = inverse_lerp(library_scroll_min, library_scroll_max, library_scroll_target)

	scroll_ratio = clampf(scroll_ratio, 0.0, 1.0)

	var center_x := knob_radius + usable_width * scroll_ratio
	var center_y := hitbox_height * 0.5
	var diameter := knob_radius * 2.0

	return Rect2(
		Vector2(center_x - knob_radius, center_y - knob_radius),
		Vector2(diameter, diameter)
	)


func get_library_scroll_slider_knob_radius() -> float:
	return 18.0


func _on_library_scroll_slider_changed(value: float) -> void:
	if library_scroll_slider_internal_update:
		return

	set_library_scroll(float(value))


func refresh_library_scroll_slider() -> void:
	if library_scroll_slider == null:
		return

	var can_scroll := library_scroll_max > 0.001

	library_scroll_slider_internal_update = true
	library_scroll_slider.min_value = library_scroll_min
	library_scroll_slider.max_value = maxf(library_scroll_max, 0.001)
	library_scroll_slider.value = clampf(library_scroll_target, library_scroll_min, library_scroll_max)
	library_scroll_slider.editable = false
	library_scroll_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	library_scroll_slider_internal_update = false

	if library_scroll_slider_hitbox != null:
		library_scroll_slider_hitbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if library_scroll_slider_surface != null:
		library_scroll_slider_surface.visible = can_scroll


func create_tabletop_ui_surface(
	surface_name: String,
	viewport_size: Vector2i,
	world_position: Vector3,
	world_size: Vector2
) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = surface_name + "Viewport"
	viewport.size = viewport_size
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_embed_subwindows = true
	add_child(viewport)

	var control_root := Control.new()
	control_root.name = surface_name + "ControlRoot"
	control_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	control_root.mouse_filter = Control.MOUSE_FILTER_PASS
	viewport.add_child(control_root)

	var surface := MeshInstance3D.new()
	surface.name = surface_name + "Surface"
	var quad := QuadMesh.new()
	quad.size = world_size
	surface.mesh = quad
	surface.position = world_position
	surface.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := create_tabletop_glass_material(viewport.get_texture())
	surface.material_override = material
	add_child(surface)

	var entry := {
		"viewport": viewport,
		"control": control_root,
		"surface": surface,
		"viewport_size": viewport_size,
		"world_size": world_size,
		"interactive": true,
	}
	tabletop_ui_surfaces.append(entry)
	return entry


func create_tabletop_glass_material(ui_texture: Texture2D) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform sampler2D ui_texture : source_color, repeat_disable, filter_linear_mipmap;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_lod = 2.8;
void fragment() {
	vec4 ui = texture(ui_texture, UV);
	vec3 blurred_world = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb;

	float ui_weight = clamp(ui.a, 0.0, 1.0);

	ALBEDO = mix(blurred_world, ui.rgb, ui_weight);
	ALPHA = ui.a;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("ui_texture", ui_texture)
	material.set_shader_parameter("blur_lod", 2.8)
	material.render_priority = 120
	return material


func initialize_deck_slots() -> void:
	saved_decks.clear()
	for index in range(DECK_SLOT_COUNT):
		saved_decks.append({
			"deck_name": "Deck " + str(index + 1),
			"cards": [],
		})


func build_deck_slot_chip() -> void:
	deck_chip_root = Node3D.new()
	deck_chip_root.name = "PhysicalDeckSlotCartridge"
	deck_chip_root.position = DECK_CHIP_HIDDEN_POSITION
	add_child(deck_chip_root)
	build_deck_chip_shell(deck_chip_root)
	deck_chip_root.visible = false

	refresh_deck_slot_chip()


func build_deck_chip_shell(parent: Node3D) -> void:
	deck_slot_roots.clear()
	deck_slot_number_labels.clear()
	deck_slot_count_labels.clear()
	deck_slot_fill_meshes.clear()

	for slot_index in range(DECK_SLOT_COUNT):
		var slot := Node3D.new()
		slot.name = "DeckSlot" + str(slot_index + 1)
		slot.position.x = (
			-DECK_CHIP_TOTAL_WIDTH
			+ (float(slot_index) + 0.5) * DECK_CHIP_SLOT_PITCH
		)
		parent.add_child(slot)
		deck_slot_roots.append(slot)

		# A slightly oversized dark plate sits beneath each compartment. Adjacent
		# plates overlap by a few millimetres, producing one continuous contact
		# shadow that blocks tabletop labels from showing through the slot gaps.
		var shadow_backing := make_deck_slot_box(
			"SlotShadowBacking",
			Vector3(0.345, 0.020, 0.70),
			Vector3(0.0, 0.006, 0.008),
			Color(0.010, 0.005, 0.002, 1.0),
			0.92,
			0.0
		)
		slot.add_child(shadow_backing)

		var body := make_deck_slot_box(
			"SlotBody",
			Vector3(0.315, 0.12, 0.66),
			Vector3.ZERO,
			Color(0.18, 0.085, 0.022, 1.0),
			0.42,
			0.35
		)
		slot.add_child(body)

		var left_bevel := make_deck_slot_box(
			"SlotLeftBevel",
			Vector3(0.030, 0.128, 0.64),
			Vector3(-0.145, 0.010, 0.0),
			Color(0.27, 0.135, 0.035, 1.0),
			0.38,
			0.42
		)
		slot.add_child(left_bevel)

		var right_bevel := make_deck_slot_box(
			"SlotRightBevel",
			Vector3(0.030, 0.128, 0.64),
			Vector3(0.145, 0.010, 0.0),
			Color(0.07, 0.030, 0.012, 1.0),
			0.55,
			0.20
		)
		slot.add_child(right_bevel)

		var inset := make_deck_slot_box(
			"SlotInset",
			Vector3(0.255, 0.020, 0.49),
			Vector3(0.0, 0.071, 0.0),
			Color(0.025, 0.021, 0.018, 1.0),
			0.70,
			0.08
		)
		slot.add_child(inset)

		var inner_top_trim := make_deck_slot_box(
			"SlotInnerTopTrim",
			Vector3(0.250, 0.012, 0.018),
			Vector3(0.0, 0.086, -0.235),
			Color(0.76, 0.53, 0.16, 1.0),
			0.28,
			0.55
		)
		slot.add_child(inner_top_trim)

		var inner_bottom_trim := make_deck_slot_box(
			"SlotInnerBottomTrim",
			Vector3(0.250, 0.012, 0.018),
			Vector3(0.0, 0.086, 0.235),
			Color(0.40, 0.25, 0.075, 1.0),
			0.34,
			0.42
		)
		slot.add_child(inner_bottom_trim)

		var vertical_trim_left := make_deck_slot_box(
			"SlotInnerLeftTrim",
			Vector3(0.014, 0.012, 0.47),
			Vector3(-0.128, 0.087, 0.0),
			Color(0.58, 0.40, 0.12, 1.0),
			0.34,
			0.45
		)
		slot.add_child(vertical_trim_left)

		var vertical_trim_right := make_deck_slot_box(
			"SlotInnerRightTrim",
			Vector3(0.014, 0.012, 0.47),
			Vector3(0.128, 0.087, 0.0),
			Color(0.28, 0.17, 0.055, 1.0),
			0.42,
			0.35
		)
		slot.add_child(vertical_trim_right)

		var fill := make_deck_slot_box(
			"SlotFill",
			Vector3(0.235, 0.025, 0.018),
			Vector3(0.0, 0.093, 0.205),
			Color(0.92, 0.58, 0.08, 1.0),
			0.30,
			0.46
		)
		slot.add_child(fill)
		deck_slot_fill_meshes.append(fill)

		for rivet_position in [
			Vector3(-0.102, 0.100, -0.188),
			Vector3(0.102, 0.100, -0.188),
			Vector3(-0.102, 0.100, 0.188),
			Vector3(0.102, 0.100, 0.188),
		]:
			var rivet := make_deck_slot_rivet(rivet_position)
			slot.add_child(rivet)

		var number_label := make_deck_slot_label(
			"Deck " + str(slot_index + 1),
			Vector3(0.0, 0.111, -0.082),
			19
		)
		slot.add_child(number_label)
		deck_slot_number_labels.append(number_label)

		var count_label := make_deck_slot_label(
			"0 / " + str(MAX_DECK_SIZE),
			Vector3(0.0, 0.110, 0.105),
			16
		)
		slot.add_child(count_label)
		deck_slot_count_labels.append(count_label)

		var front_lip := make_deck_slot_box(
			"SlotFrontLip",
			Vector3(0.335, 0.16, 0.055),
			Vector3(0.0, 0.045, 0.325),
			Color(0.34, 0.17, 0.040, 1.0),
			0.34,
			0.42
		)
		slot.add_child(front_lip)

		var lip_highlight := make_deck_slot_box(
			"SlotFrontLipHighlight",
			Vector3(0.300, 0.018, 0.012),
			Vector3(0.0, 0.133, 0.302),
			Color(0.76, 0.46, 0.12, 1.0),
			0.28,
			0.50
		)
		slot.add_child(lip_highlight)

		var pick_area := Area3D.new()
		pick_area.name = "SlotPickArea"
		pick_area.collision_layer = DECK_SLOT_PICK_LAYER
		pick_area.collision_mask = 0
		pick_area.set_meta("deck_slot_index", slot_index)
		slot.add_child(pick_area)
		var pick_shape := CollisionShape3D.new()
		var pick_box := BoxShape3D.new()
		pick_box.size = Vector3(0.315, 0.24, 0.66)
		pick_shape.shape = pick_box
		pick_shape.position.y = 0.08
		pick_area.add_child(pick_shape)

	# A pull tab belongs to slot one so it is swallowed by the same wall clipping.
		var handle := MeshInstance3D.new()
		handle.name = "CartridgePullTab"
		var handle_mesh := BoxMesh.new()
		handle_mesh.size = Vector3(0.065, 0.125, 0.34)
		handle.mesh = handle_mesh
		handle.position = Vector3(-0.175, 0.038, 0.0)
		handle.material_override = make_mat(Color(0.36, 0.18, 0.045, 1.0), 0.34, 0.42)
		deck_slot_roots[0].add_child(handle)

		var handle_cap := MeshInstance3D.new()
		handle_cap.name = "CartridgePullTabCap"
		var handle_cap_mesh := BoxMesh.new()
		handle_cap_mesh.size = Vector3(0.016, 0.090, 0.26)
		handle_cap.mesh = handle_cap_mesh
		handle_cap.position = Vector3(-0.208, 0.052, 0.0)
		handle_cap.material_override = make_mat(Color(0.72, 0.48, 0.15, 1.0), 0.28, 0.55)
		deck_slot_roots[0].add_child(handle_cap)


func make_deck_slot_box(
	node_name: String,
	box_size: Vector3,
	local_position: Vector3,
	color: Color,
	roughness: float,
	metallic: float
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.material_override = make_mat(color, roughness, metallic)
	return mesh_instance


func make_deck_slot_rivet(local_position: Vector3) -> MeshInstance3D:
	var rivet := MeshInstance3D.new()
	rivet.name = "SlotCornerRivet"
	var mesh := SphereMesh.new()
	mesh.radius = 0.010
	mesh.height = 0.018
	rivet.mesh = mesh
	rivet.position = local_position
	rivet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rivet.material_override = make_mat(Color(0.78, 0.56, 0.18, 1.0), 0.25, 0.65)
	return rivet


func make_deck_slot_label(label_text: String, local_position: Vector3, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = label_text
	label.position = local_position
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	label.font_size = font_size
	label.pixel_size = 0.0031
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = Color(1.0, 0.88, 0.57, 1.0)
	label.outline_size = 7
	label.outline_modulate = Color(0.010, 0.004, 0.001, 1.0)
	label.no_depth_test = false
	return label


func refresh_deck_slot_chip() -> void:
	for slot_index in range(mini(DECK_SLOT_COUNT, deck_slot_count_labels.size())):
		var data: Dictionary = saved_decks[slot_index]
		var card_ids: Array = data.get("cards", [])
		var card_count := card_ids.size()
		deck_slot_count_labels[slot_index].text = str(card_count) + " / " + str(MAX_DECK_SIZE)
		var selected := slot_index == active_deck_slot
		deck_slot_number_labels[slot_index].modulate = (
			Color(1.0, 0.76, 0.18, 1.0)
			if selected
			else Color(1.0, 0.88, 0.57, 1.0)
		)
		deck_slot_count_labels[slot_index].modulate = (
			Color(1.0, 0.86, 0.46, 1.0)
			if selected
			else Color(0.90, 0.74, 0.42, 1.0)
		)

		var inset := deck_slot_roots[slot_index].get_node_or_null("SlotInset") as MeshInstance3D
		if inset != null:
			inset.material_override = make_mat(
				Color(0.62, 0.39, 0.070, 1.0) if selected else Color(0.025, 0.021, 0.018, 1.0),
				0.58,
				0.18 if selected else 0.08
			)
		var fill := deck_slot_fill_meshes[slot_index]
		var fill_box := fill.mesh as BoxMesh
		var fill_ratio := clampf(float(card_count) / float(MAX_DECK_SIZE), 0.0, 1.0)
		var fill_length := maxf(0.018, 0.42 * fill_ratio)
		fill_box.size = Vector3(0.245, 0.024, fill_length)
		fill.position.z = 0.205 - fill_length * 0.5
		fill.visible = card_count > 0


func toggle_deck_chip() -> void:
	if deck_switch_in_progress:
		return
	if deck_chip_is_out:
		retract_deck_chip()
	else:
		extend_deck_chip()


func extend_deck_chip() -> void:
	if deck_chip_root == null or deck_chip_is_out:
		return
	if deck_chip_tween != null:
		deck_chip_tween.kill()
	deck_chip_root.visible = true
	deck_chip_root.position = DECK_CHIP_HIDDEN_POSITION
	update_deck_chip_wall_clipping()
	deck_chip_tween = create_tween()
	deck_chip_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	deck_chip_tween.tween_property(deck_chip_root, "position", DECK_CHIP_SHOWN_POSITION, 0.38)
	await deck_chip_tween.finished
	deck_chip_is_out = true
	update_deck_chip_wall_clipping()


func retract_deck_chip() -> void:
	if deck_chip_root == null or not deck_chip_root.visible:
		deck_chip_is_out = false
		return
	if deck_chip_tween != null:
		deck_chip_tween.kill()
	deck_chip_tween = create_tween()
	deck_chip_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	deck_chip_tween.tween_property(deck_chip_root, "position", DECK_CHIP_HIDDEN_POSITION, 0.30)
	await deck_chip_tween.finished
	deck_chip_root.visible = false
	deck_chip_is_out = false


func update_deck_chip_wall_clipping() -> void:
	if deck_chip_root == null or not deck_chip_root.visible:
		return
	for slot in deck_slot_roots:
		if slot == null:
			continue
		# Each compartment only becomes visible after clearing the rack's left
		# wall. On retraction the wall swallows them one by one; nothing travels
		# visibly across the rack interior.
		var slot_right_edge := slot.global_position.x + 0.158
		slot.visible = slot_right_edge <= DECK_CHIP_WALL_X + 0.012


func pick_deck_slot_index(screen_position: Vector2) -> int:
	if not deck_chip_is_out or camera_3d == null:
		return -1
	var origin := camera_3d.project_ray_origin(screen_position)
	var end := origin + camera_3d.project_ray_normal(screen_position) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = DECK_SLOT_PICK_LAYER
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return -1
	var collider := result.get("collider") as Area3D
	if collider == null or not collider.has_meta("deck_slot_index"):
		return -1
	return int(collider.get_meta("deck_slot_index"))


func route_tabletop_ui_input(event: InputEvent) -> bool:
	if scene_transition_requested or not is_inside_tree():
		return false
	if event is InputEventKey:
		if active_tabletop_viewport != null and active_tabletop_viewport.gui_get_focus_owner() != null:
			active_tabletop_viewport.push_input(event)
			return true
		return false

	if not (event is InputEventMouse):
		return false

	var mouse_event := event as InputEventMouse
	var mapped := map_screen_to_tabletop_ui(mouse_event.position)
	if mapped.is_empty():
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			active_tabletop_viewport = null
		return false

	var viewport: SubViewport = mapped["viewport"]
	if viewport == null or not is_instance_valid(viewport) or not viewport.is_inside_tree():
		return false
	active_tabletop_viewport = viewport
	var forwarded := event.duplicate() as InputEventMouse
	forwarded.position = mapped["position"]
	forwarded.global_position = mapped["position"]
	viewport.push_input(forwarded, true)
	return true


func map_screen_to_tabletop_ui(screen_position: Vector2) -> Dictionary:
	if camera_3d == null:
		return {}
	for entry in tabletop_ui_surfaces:
		if not bool(entry.get("interactive", true)):
			continue
		var surface: MeshInstance3D = entry["surface"]
		var world_size: Vector2 = entry["world_size"]
		var hit := screen_to_horizontal_plane(screen_position, surface.global_position.y)
		var local := surface.to_local(hit)
		if absf(local.x) > world_size.x * 0.5 or absf(local.y) > world_size.y * 0.5:
			continue
		var viewport_size: Vector2i = entry["viewport_size"]
		var pixel_position := Vector2(
			(local.x / world_size.x + 0.5) * float(viewport_size.x),
			(0.5 - local.y / world_size.y) * float(viewport_size.y)
		)
		return {
			"viewport": entry["viewport"],
			"position": pixel_position,
		}
	return {}


func make_button(text: String, min_size: Vector2, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var bg_normal := Color(0.06, 0.07, 0.09, 0.66) if not primary else Color(0.14, 0.16, 0.20, 0.80)
	var border_normal := Color(1.0, 1.0, 1.0, 0.25) if not primary else Color(1.0, 1.0, 1.0, 0.48)

	var s_normal := _make_btn_style(bg_normal, border_normal)
	var s_hover := _make_btn_style(
		Color(0.22, 0.24, 0.28, 0.88),
		Color.WHITE
	)
	var s_pressed := _make_btn_style(Color(0.28, 0.30, 0.34, 0.92), Color.WHITE)
	var s_disabled := _make_btn_style(Color(0.04, 0.05, 0.06, 0.46), Color(1.0, 1.0, 1.0, 0.12))

	button.add_theme_stylebox_override("normal", s_normal)
	button.add_theme_stylebox_override("hover", s_hover)
	button.add_theme_stylebox_override("pressed", s_pressed)
	button.add_theme_stylebox_override("disabled", s_disabled)
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.90))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.32))
	button.add_theme_font_size_override("font_size", 13)
	return button


func make_library_sort_button() -> MenuButton:
	var button := MenuButton.new()
	button.name = "LibrarySortButton"
	button.text = "SORT ↕"
	button.custom_minimum_size = Vector2(76, 28)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var bg_normal := Color(0.06, 0.07, 0.09, 0.66)
	var border_normal := Color(1.0, 1.0, 1.0, 0.25)
	button.add_theme_stylebox_override("normal", _make_btn_style(bg_normal, border_normal))
	button.add_theme_stylebox_override("hover", _make_btn_style(Color(0.22, 0.24, 0.28, 0.88), Color.WHITE))
	button.add_theme_stylebox_override("pressed", _make_btn_style(Color(0.28, 0.30, 0.34, 0.92), Color.WHITE))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 13)

	var popup := button.get_popup()
	popup.transparent_bg = true
	popup.add_theme_stylebox_override(
		"panel",
		make_panel_style(Color(0.045, 0.055, 0.075, 0.70), Color(1.0, 1.0, 1.0, 0.24), 1)
	)
	popup.add_theme_stylebox_override("hover", _make_btn_style(Color(0.22, 0.24, 0.28, 0.90), Color.WHITE))
	popup.add_theme_color_override("font_color", Color.WHITE)
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_color_override("font_accelerator_color", Color(1.0, 1.0, 1.0, 0.55))
	popup.add_theme_font_size_override("font_size", 13)
	popup.add_item("Name", LibrarySortMode.NAME)
	popup.add_item("TP", LibrarySortMode.TP)
	popup.add_item("AP", LibrarySortMode.AP)
	popup.add_item("DP", LibrarySortMode.DP)
	for item_index in range(popup.item_count):
		popup.set_item_as_radio_checkable(item_index, true)
	popup.id_pressed.connect(_on_library_sort_selected)
	popup.about_to_popup.connect(_queue_library_sort_popup_position.bind(button, popup))
	update_library_sort_button()
	return button


func _queue_library_sort_popup_position(button: MenuButton, popup: PopupMenu) -> void:
	call_deferred("_position_library_sort_popup", button, popup)


func _position_library_sort_popup(button: MenuButton, popup: PopupMenu) -> void:
	if button == null or popup == null or not is_instance_valid(button) or not is_instance_valid(popup):
		return
	var button_rect := button.get_global_rect()
	var viewport_size := Vector2i(button.get_viewport_rect().size)
	var desired := Vector2i(
		int(ceil(button_rect.end.x + 8.0)),
		int(round(button_rect.position.y + (button_rect.size.y - float(popup.size.y)) * 0.5))
	)
	desired.x = clampi(desired.x, 4, maxi(4, viewport_size.x - popup.size.x - 4))
	desired.y = clampi(desired.y, 4, maxi(4, viewport_size.y - popup.size.y - 4))
	popup.position = desired


func _make_btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.shadow_color = Color(1.0, 1.0, 1.0, 0.16) if border.a > 0.7 else Color(0.0, 0.0, 0.0, 0.42)
	s.shadow_size = 3
	s.content_margin_left = 8.0
	s.content_margin_right = 8.0
	s.content_margin_top = 4.0
	s.content_margin_bottom = 4.0
	return s


func style_text_field(field: LineEdit) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.045, 0.055, 0.075, 0.70)
	normal.border_color = Color(1.0, 1.0, 1.0, 0.24)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.10, 0.12, 0.15, 0.86)
	focus.border_color = Color.WHITE
	field.add_theme_stylebox_override("normal", normal)
	field.add_theme_stylebox_override("focus", focus)
	field.add_theme_color_override("font_color", Color.WHITE)
	field.add_theme_color_override("font_placeholder_color", Color(1.0, 1.0, 1.0, 0.48))
	field.add_theme_color_override("caret_color", Color.WHITE)


func add_filter_caption(parent: HBoxContainer, caption: String) -> void:
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(66, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.WHITE)
	parent.add_child(label)


func add_filter_buttons(parent: HBoxContainer, labels: Array[String], store: Dictionary, callback: Callable) -> void:
	for label_text in labels:
		var button := make_button(label_text, Vector2(58, 26))
		var s_active := _make_btn_style(Color(0.28, 0.30, 0.34, 0.92), Color.WHITE)
		button.add_theme_stylebox_override("pressed", s_active)
		var filter_key := label_text.to_lower()
		button.toggle_mode = true
		button.pressed.connect(func(): callback.call(filter_key))
		store[filter_key] = button
		parent.add_child(button)


func create_ability_filter_panel(parent: Control) -> void:
	ability_filter_panel = PanelContainer.new()
	ability_filter_panel.name = "AbilityFilterPanel"
	ability_filter_panel.visible = false
	ability_filter_panel.position = Vector2(23.0, 6.0)
	ability_filter_panel.custom_minimum_size = Vector2(344.0, 48.0)
	ability_filter_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ability_filter_panel.z_index = 20
	ability_filter_panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(Color(0.18, 0.115, 0.065, 0.62), Color(0.0, 0.0, 0.0, 0.0), 0)
	)
	parent.add_child(ability_filter_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	ability_filter_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	margin.add_child(row)

	for raw_label_text in ABILITY_FILTERS:
		var label_text: String = String(raw_label_text)
		var filter_key: String = label_text.to_lower()
		var button := make_ability_filter_button(filter_key, label_text)
		button.pressed.connect(_on_ability_filter_pressed.bind(filter_key))
		ability_buttons[filter_key] = button
		row.add_child(button)


func make_ability_filter_button(filter_key: String, label_text: String) -> Button:
	var button := make_button("", Vector2(44, 40))
	button.name = label_text + "AbilityFilter"
	button.toggle_mode = true
	button.tooltip_text = label_text
	button.add_theme_stylebox_override("pressed", _make_btn_style(Color(0.28, 0.30, 0.34, 0.92), Color.WHITE))

	var icon_path: String = ABILITY_ICON_PATHS.get(filter_key, "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		button.icon = load(icon_path) as Texture2D
		button.expand_icon = true
	else:
		button.text = label_text.substr(0, 1).to_upper()

	return button


func refresh_filter_buttons() -> void:
	for key in race_buttons.keys():
		var b: Button = race_buttons[key]
		b.button_pressed = (key == "all" and active_race_filters.is_empty()) or active_race_filters.has(key)

	for key in type_buttons.keys():
		var b: Button = type_buttons[key]
		b.button_pressed = (key == "all" and active_type_filters.is_empty()) or active_type_filters.has(key)

	refresh_ability_filter_buttons()


func refresh_ability_filter_buttons() -> void:
	for key in ability_buttons.keys():
		var b: Button = ability_buttons[key]
		var is_active := active_ability_filters.has(key)
		b.button_pressed = is_active
		b.modulate = Color.WHITE if is_active else Color(1.0, 1.0, 1.0, 0.72)


func refresh_library() -> void:
	for node in library_nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()
	library_nodes.clear()
	filtered_cards.clear()

	for card in all_cards:
		if card_matches_filters(card):
			filtered_cards.append(card)
	filtered_cards.sort_custom(compare_library_cards)

	for i in range(filtered_cards.size()):
		var card_data: CardData = filtered_cards[i]
		var card_node := create_card_node(card_data, "library")
		card_node.name = "Library_" + card_data.card_name.replace(" ", "_")
		card_node.scale = CARD_SCALE_LIBRARY
		card_node.rotation_degrees = Vector3(0, 0, 0)
		library_root.add_child(card_node)
		library_nodes.append(card_node)

	var group_count: int = int(ceil(float(filtered_cards.size()) / float(LIBRARY_GROUP_SIZE)))
	library_scroll_max = max(0.0, float(max(0, group_count - 1)) * LIBRARY_GROUP_SPACING)
	library_scroll_target = clampf(library_scroll_target, library_scroll_min, library_scroll_max)
	library_scroll = clampf(library_scroll, library_scroll_min, library_scroll_max)

	refresh_library_scroll_slider()
	layout_library(true)
	set_status("Showing " + str(filtered_cards.size()) + " owned card(s). Continuous horizontal scroll is active.")


func layout_library(instant: bool = false) -> void:
	for i in range(library_nodes.size()):
		var node := library_nodes[i]

		if node == dragging_node:
			continue

		var group_index: int = int(i / LIBRARY_GROUP_SIZE)
		var local_index: int = i % LIBRARY_GROUP_SIZE
		var row_index: int = int(local_index / LIBRARY_COLUMNS_PER_GROUP)
		var column_index: int = local_index % LIBRARY_COLUMNS_PER_GROUP

		var target_x: float = LIBRARY_BASE_X + float(group_index) * LIBRARY_GROUP_SPACING + float(column_index) * LIBRARY_COLUMN_SPACING - library_scroll
		var target_z: float = LIBRARY_BASE_Z + float(row_index) * LIBRARY_ROW_SPACING
		var target := Vector3(target_x, LIBRARY_Y, target_z)

		node.set_meta("target_position", target)
		node.set_meta("target_scale", CARD_SCALE_LIBRARY)
		node.set_meta("target_rotation", Vector3(0, 0, 0))

		apply_library_card_window_clip(node, true)

		var copy_limit_reached := is_library_card_at_copy_limit(node)
		var card_alpha := 0.28 if copy_limit_reached else 1.0

		node.set_meta("target_alpha", card_alpha)

		set_card_pickable(
			node,
			is_library_card_inside_interaction_window(target.x) and not copy_limit_reached
		)
		
		if instant:
			node.position = target
			node.scale = CARD_SCALE_LIBRARY
			node.rotation_degrees = Vector3(0, 0, 0)
			node.visible = is_library_card_inside_render_window(target.x)
			node.set_meta("current_alpha", card_alpha)

			if node.visible:
				set_card_alpha(node, card_alpha)

			update_library_card_count_label_visibility(node)


func layout_deck_rack(instant: bool = false, preview_insert_index: int = -1) -> void:
	var count_with_gap := deck_nodes.size()
	if dragging_node != null and not dragging_from_library and dragging_over_rack:
		count_with_gap += 1

	var visual_index := 0
	for i in range(deck_nodes.size()):
		if preview_insert_index >= 0 and visual_index == preview_insert_index:
			visual_index += 1
		var node := deck_nodes[i]
		if node == dragging_node:
			continue

		var target := get_rack_slot_position(visual_index, count_with_gap)
		target.y += float(visual_index) * 0.002
		node.set_meta("target_position", target)
		node.set_meta("target_scale", CARD_SCALE_RACK)
		var target_rotation := Vector3(RACK_CARD_TILT_DEGREES, 0, 0)
		node.set_meta("target_rotation", target_rotation)
		if instant:
			node.position = target
			node.scale = CARD_SCALE_RACK
			node.rotation_degrees = target_rotation
		visual_index += 1


func create_card_node(card_data: CardData, source_zone: String) -> Node3D:
	var card_node := CARD_SCENE.instantiate() as Node3D
	if card_node.has_method("assign_card_data"):
		card_node.assign_card_data(card_data, false)
	card_node.set_meta("card_data", card_data)
	card_node.set_meta("source_zone", source_zone)
	card_node.set_meta("target_position", Vector3.ZERO)
	card_node.set_meta("target_scale", CARD_SCALE_LIBRARY)
	card_node.set_meta("target_rotation", Vector3.ZERO)
	card_node.set_meta("target_alpha", 1.0)
	card_node.set_meta("current_alpha", 1.0)
	add_pick_area(card_node)
	if source_zone == "library":
		add_library_copy_badge(card_node)
	return card_node


func add_library_copy_badge(card_node: Node3D) -> void:
	var badge := Label3D.new()
	badge.name = "DeckCopyBadge"
	badge.text = ""
	badge.position = Vector3(0.45, 0.075, -0.73)
	badge.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	badge.pixel_size = 0.0036
	badge.font_size = 30
	badge.modulate = Color.WHITE
	badge.outline_modulate = Color(0.0, 0.0, 0.0, 0.86)
	badge.outline_size = 10
	badge.no_depth_test = true
	badge.render_priority = 20
	badge.visible = false
	card_node.add_child(badge)


func add_pick_area(card_node: Node3D) -> void:
	var area := Area3D.new()
	area.name = "DeckBuilderPickArea"
	var source_zone := String(card_node.get_meta("source_zone", ""))
	area.collision_layer = CARD_PICK_LAYER_DECK if source_zone == "deck" else CARD_PICK_LAYER_LIBRARY
	area.collision_mask = 0
	area.set_meta("card_node", card_node)
	card_node.add_child(area)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.05, 0.16, 1.38)
	shape.shape = box
	shape.position = Vector3(0, 0.05, 0)
	area.add_child(shape)


func begin_drag_from_mouse(screen_position: Vector2) -> void:
	var picked := pick_card_node(screen_position)
	if picked == null:
		update_cursor_for_screen_position(screen_position)
		return

	var card_data: CardData = picked.get_meta("card_data", null) as CardData
	if card_data == null:
		return

	dragging_node = picked
	dragging_card = card_data
	dragging_from_library = String(picked.get_meta("source_zone", "")) == "library"
	
	if dragging_from_library:
		apply_library_card_window_clip(dragging_node, false)
	drag_rack_blend = 0.0 if dragging_from_library else 1.0
	dragging_deck_original_index = -1
	var grab_hit := screen_to_horizontal_plane(screen_position, picked.global_position.y)
	drag_pointer_offset = Vector3(
		picked.global_position.x - grab_hit.x,
		0.0,
		picked.global_position.z - grab_hit.z
	)
	if camera_3d != null:
		drag_card_center_screen_offset = (
			camera_3d.unproject_position(picked.global_position) - screen_position
		)

	if dragging_from_library:
		set_status("Dragging " + card_data.card_name + " toward the deck rack.")
		show_card_detail(card_data)
	else:
		dragging_deck_original_index = deck_nodes.find(picked)
		if dragging_deck_original_index >= 0:
			deck_nodes.remove_at(dragging_deck_original_index)
			deck_cards.remove_at(dragging_deck_original_index)
			set_status("Reordering " + card_data.card_name + ". Release inside the rack to place it, or outside to remove it.")
			update_deck_status()

	dragging_node.visible = true
	dragging_node.set_as_top_level(true)
	Cursors.use_grab()
	update_drag_target(screen_position)


func update_drag_target(screen_position: Vector2) -> void:
	drag_pointer_screen_position = screen_position
	var table_hit := screen_to_table_point(screen_position)
	dragging_over_rack = is_point_in_rack_drop_zone(table_hit)
	refresh_drag_target_position()


func refresh_drag_target_position() -> void:
	var hover_y := lerpf(LIBRARY_HOVER_Y, RACK_HOVER_Y, drag_rack_blend)
	var hit := screen_to_horizontal_plane(drag_pointer_screen_position, hover_y)
	dragging_target_position = Vector3(
		hit.x + drag_pointer_offset.x,
		hover_y,
		hit.z + drag_pointer_offset.z
	)


func finish_drag(screen_position: Vector2) -> void:
	if dragging_node == null or dragging_card == null:
		update_cursor_for_screen_position(screen_position)
		return

	update_drag_target(screen_position)
	var released_in_rack := dragging_over_rack

	if dragging_from_library:
		if released_in_rack:
			try_add_library_card_to_deck(dragging_card)
		animate_library_card_home(dragging_node)
	else:
		if released_in_rack:
			var insert_index := get_deck_insert_index_from_screen(screen_position)
			insert_index = clamp(insert_index, 0, deck_cards.size())
			deck_cards.insert(insert_index, dragging_card)
			deck_nodes.insert(insert_index, dragging_node)
			dragging_node.set_as_top_level(false)
			if dragging_node.get_parent() != rack_root:
				dragging_node.reparent(rack_root)
			dragging_node.set_meta("source_zone", "deck")
			set_status("Placed " + dragging_card.card_name + " in deck position " + str(insert_index + 1) + ".")
		else:
			set_status("Removed " + dragging_card.card_name + " from the deck rack.")
			dragging_node.queue_free()

	dragging_node = null
	dragging_card = null
	dragging_from_library = false
	dragging_deck_original_index = -1
	drag_pointer_offset = Vector3.ZERO
	drag_pointer_screen_position = Vector2.ZERO
	drag_card_center_screen_offset = Vector2.ZERO
	dragging_over_rack = false
	drag_rack_blend = 0.0
	drag_preview_insert_index = 0
	layout_library(false)
	layout_deck_rack(false)
	update_deck_status()
	Cursors.use_normal()


func update_cursor_for_screen_position(screen_position: Vector2) -> void:
	if dragging_node != null:
		Cursors.use_grab()
		return
	if (
		pick_deck_slot_index(screen_position) >= 0
		or pick_card_node(screen_position) != null
		or not map_screen_to_tabletop_ui(screen_position).is_empty()
		or is_pointer_over_ui()
	):
		Cursors.use_pointing()
	else:
		Cursors.use_normal()


func try_add_library_card_to_deck(card_data: CardData) -> bool:
	if deck_cards.size() >= MAX_DECK_SIZE:
		set_status("Deck rack is full. Maximum " + str(MAX_DECK_SIZE) + " cards.")
		return false

	var copies := get_deck_copy_count(card_data)
	var copy_limit := get_card_copy_limit(card_data)
	if copies >= copy_limit:
		set_status("Cannot add more than " + str(copy_limit) + " copies of " + card_data.card_name + ".")
		return false

	var new_node := create_card_node(card_data, "deck")
	new_node.name = "Deck_" + card_data.card_name.replace(" ", "_")
	new_node.scale = CARD_SCALE_RACK_HOVER
	new_node.position = dragging_target_position
	new_node.rotation_degrees = Vector3(RACK_CARD_TILT_DEGREES, 0.0, 0.0)
	rack_root.add_child(new_node)

	var insert_index := get_deck_insert_index_from_screen(drag_pointer_screen_position)
	insert_index = clamp(insert_index, 0, deck_cards.size())
	deck_cards.insert(insert_index, card_data)
	deck_nodes.insert(insert_index, new_node)
	set_status("Added " + card_data.card_name + " to deck rack. " + str(copies + 1) + "/" + str(copy_limit) + " copies.")
	show_card_detail(card_data)
	return true


func animate_library_card_home(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_as_top_level(false)
	if node.get_parent() != library_root:
		node.reparent(library_root)
	node.set_meta("source_zone", "library")
	apply_library_card_window_clip(node, true)
	layout_library(false)


func animate_collection(nodes: Array[Node3D], delta: float) -> void:
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue

		if node == dragging_node:
			continue

		var target_position: Vector3 = node.get_meta("target_position", node.position)
		var target_scale: Vector3 = node.get_meta("target_scale", node.scale)
		var target_rotation: Vector3 = node.get_meta("target_rotation", node.rotation_degrees)
		var weight: float = clampf(delta * 10.0, 0.0, 1.0)

		node.position = node.position.lerp(target_position, weight)
		node.scale = node.scale.lerp(target_scale, weight)
		node.rotation_degrees = node.rotation_degrees.lerp(target_rotation, weight)

		var source_zone := String(node.get_meta("source_zone", ""))

		if source_zone == "library":
			apply_library_card_window_clip(node, true)

			var copy_limit_reached := is_library_card_at_copy_limit(node)
			var card_alpha := 0.28 if copy_limit_reached else 1.0

			node.visible = is_library_card_inside_render_window(node.position.x)
			node.set_meta("current_alpha", card_alpha)

			set_card_pickable(
				node,
				is_library_card_inside_interaction_window(node.position.x) and not copy_limit_reached
			)

			if node.visible:
				set_card_alpha(node, card_alpha)

			update_library_card_count_label_visibility(node)

		else:
			apply_library_card_window_clip(node, false)

			node.visible = true
			node.set_meta("current_alpha", 1.0)
			set_card_pickable(node, true)
			set_card_alpha(node, 1.0)


func set_library_scroll(value: float) -> void:
	library_scroll_target = clampf(value, library_scroll_min, library_scroll_max)
	refresh_library_scroll_slider()


func is_library_card_inside_interaction_window(x_position: float) -> bool:
	return (
		x_position >= LIBRARY_VISIBLE_MIN_X + LIBRARY_CARD_INTERACTION_INSET
		and x_position <= LIBRARY_VISIBLE_MAX_X - LIBRARY_CARD_INTERACTION_INSET
	)


func is_library_card_inside_render_window(x_position: float) -> bool:
	return (
		x_position >= LIBRARY_VISIBLE_MIN_X - LIBRARY_RENDER_SIDE_BUFFER
		and x_position <= LIBRARY_VISIBLE_MAX_X + LIBRARY_RENDER_SIDE_BUFFER
	)


func get_library_edge_alpha(x_position: float) -> float:
	# Kept only so any old code path does not break.
	# Visual edge clipping is handled by the CardBody shader now.
	return 1.0


func get_library_card_count_label(card_node: Node) -> Label3D:
	if card_node == null:
		return null

	var badge := card_node.get_node_or_null("DeckCopyBadge") as Label3D

	if badge != null:
		return badge

	for child in card_node.get_children():
		if child is Label3D:
			var label := child as Label3D

			if label.text.strip_edges().ends_with("x"):
				return label

	return null


func get_library_count_label_edge_alpha(label_world_x: float) -> float:
	var left_alpha := smoothstep(
		LIBRARY_VISIBLE_MIN_X,
		LIBRARY_VISIBLE_MIN_X + LIBRARY_CARD_CLIP_FADE_WIDTH,
		label_world_x
	)

	var right_alpha := 1.0 - smoothstep(
		LIBRARY_VISIBLE_MAX_X - LIBRARY_CARD_CLIP_FADE_WIDTH,
		LIBRARY_VISIBLE_MAX_X,
		label_world_x
	)

	return clampf(minf(left_alpha, right_alpha), 0.0, 1.0)


func update_library_card_count_label_visibility(card_node: Node3D) -> void:
	var count_label := get_library_card_count_label(card_node)

	if count_label == null:
		return

	var card_data := card_node.get_meta("card_data", null) as CardData

	if card_data == null:
		count_label.visible = false
		return

	var copy_count := get_deck_copy_count(card_data)

	if copy_count <= 0:
		count_label.visible = false
		return

	count_label.text = str(copy_count) + "x"

	var edge_alpha := get_library_count_label_edge_alpha(count_label.global_position.x)

	if edge_alpha <= 0.01:
		count_label.visible = false
		return

	count_label.visible = true

	var label_color := count_label.modulate
	label_color.a = edge_alpha
	count_label.modulate = label_color

	var outline_color := count_label.outline_modulate
	outline_color.a = edge_alpha
	count_label.outline_modulate = outline_color


func apply_library_card_window_clip(card_node: Node3D, enabled: bool) -> void:
	if card_node == null or not is_instance_valid(card_node):
		return

	var card_body := card_node.get_node_or_null("CardBody") as MeshInstance3D

	if card_body == null:
		return

	var material := card_body.material_override

	if material is ShaderMaterial and bool(card_body.get_meta("deck_builder_window_clip_material", false)):
		var shader_material := material as ShaderMaterial
		shader_material.set_shader_parameter("clip_enabled", enabled)
		shader_material.set_shader_parameter("clip_min_x", LIBRARY_VISIBLE_MIN_X)
		shader_material.set_shader_parameter("clip_max_x", LIBRARY_VISIBLE_MAX_X)
		shader_material.set_shader_parameter("fade_width", LIBRARY_CARD_CLIP_FADE_WIDTH)
		return

	if not enabled:
		return

	var source_texture: Texture2D = null
	var source_color := Color.WHITE

	if material is BaseMaterial3D:
		var base_material := material as BaseMaterial3D
		source_texture = base_material.albedo_texture
		source_color = base_material.albedo_color

	var shader := load(LIBRARY_CARD_CLIP_SHADER_PATH) as Shader

	if shader == null:
		push_error("Missing library card clip shader: " + LIBRARY_CARD_CLIP_SHADER_PATH)
		return

	var clip_material := ShaderMaterial.new()
	clip_material.shader = shader
	clip_material.set_shader_parameter("card_texture", source_texture)
	clip_material.set_shader_parameter("card_color", source_color)
	clip_material.set_shader_parameter("clip_min_x", LIBRARY_VISIBLE_MIN_X)
	clip_material.set_shader_parameter("clip_max_x", LIBRARY_VISIBLE_MAX_X)
	clip_material.set_shader_parameter("fade_width", LIBRARY_CARD_CLIP_FADE_WIDTH)
	clip_material.set_shader_parameter("clip_enabled", true)
	clip_material.render_priority = 40

	card_body.material_override = clip_material
	card_body.set_meta("deck_builder_window_clip_material", true)


func set_card_pickable(card_node: Node3D, pickable: bool) -> void:
	var area := card_node.get_node_or_null("DeckBuilderPickArea") as Area3D
	if area != null:
		var source_zone := String(card_node.get_meta("source_zone", ""))
		var base_layer := CARD_PICK_LAYER_DECK if source_zone == "deck" else CARD_PICK_LAYER_LIBRARY
		area.collision_layer = base_layer if pickable else 0


func set_card_alpha(card_node: Node, alpha: float) -> void:
	if card_node == null:
		return
		
	if card_node is Label3D and String(card_node.name) == "DeckCopyBadge":
		return

	card_node.set_meta("current_alpha", alpha)

	if card_node is Sprite3D:
		var sprite := card_node as Sprite3D
		var sprite_color := sprite.modulate
		sprite_color.a = alpha
		sprite.modulate = sprite_color
	elif card_node is Label3D:
		var label := card_node as Label3D
		var label_color := label.modulate
		label_color.a = alpha
		label.modulate = label_color
	elif card_node is MeshInstance3D:
		apply_mesh_alpha(card_node as MeshInstance3D, alpha)

	for child in card_node.get_children():
		set_card_alpha(child, alpha)


func apply_mesh_alpha(mesh_instance: MeshInstance3D, alpha: float) -> void:
	var material: Material = mesh_instance.material_override

	if material is ShaderMaterial and bool(mesh_instance.get_meta("deck_builder_window_clip_material", false)):
		var shader_material := material as ShaderMaterial
		var color: Color = shader_material.get_shader_parameter("card_color")
		color.a = alpha
		shader_material.set_shader_parameter("card_color", color)
		return

	if mesh_instance.has_meta("deck_builder_alpha_material"):
		material = mesh_instance.get_meta("deck_builder_alpha_material") as Material

	if material == null:
		var source_material: Material = mesh_instance.material_override

		if source_material == null:
			source_material = mesh_instance.get_active_material(0)

		if source_material != null:
			material = source_material.duplicate()
			mesh_instance.material_override = material
			mesh_instance.set_meta("deck_builder_alpha_material", material)

	if material is BaseMaterial3D:
		var base_material := material as BaseMaterial3D
		base_material.transparency = (
			BaseMaterial3D.TRANSPARENCY_DISABLED
			if alpha >= 0.999
			else BaseMaterial3D.TRANSPARENCY_ALPHA
		)

		var material_color := base_material.albedo_color
		material_color.a = alpha
		base_material.albedo_color = material_color


func pick_card_node(screen_position: Vector2) -> Node3D:
	if camera_3d == null:
		return null
	var origin := camera_3d.project_ray_origin(screen_position)
	var end := origin + camera_3d.project_ray_normal(screen_position) * 1000.0

	# Rack cards lean toward the camera, so their visible upper halves can project
	# outside the rack's floor rectangle. Always test the deck layer first instead
	# of choosing a layer from the table-plane hit position.
	var deck_card := ray_pick_card_on_layer(origin, end, CARD_PICK_LAYER_DECK)
	if deck_card != null:
		return deck_card

	# Empty rack space must never pick a library card behind or beneath the rack.
	var table_point := screen_to_table_point(screen_position)
	if is_point_in_rack(table_point):
		return null
	return ray_pick_card_on_layer(origin, end, CARD_PICK_LAYER_LIBRARY)


func ray_pick_card_on_layer(origin: Vector3, end: Vector3, collision_layer: int) -> Node3D:
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = collision_layer
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	var collider: Object = result.get("collider", null)
	if collider == null:
		return null
	if collider is Area3D and (collider as Area3D).has_meta("card_node"):
		return (collider as Area3D).get_meta("card_node") as Node3D
	return null


func show_card_action_menu(screen_position: Vector2) -> void:
	if card_action_menu == null:
		return
	var picked := pick_card_node(screen_position)
	if picked == null:
		card_action_target = null
		card_action_menu.hide()
		return

	card_action_target = picked
	card_action_menu.clear()
	card_action_menu.add_item("Inspect", CARD_ACTION_INSPECT)
	card_action_menu.add_separator()
	card_action_menu.add_item("Cancel", CARD_ACTION_CANCEL)
	card_action_menu.position = Vector2i(int(screen_position.x), int(screen_position.y))
	card_action_menu.popup()


func _on_card_action_selected(action_id: int) -> void:
	if action_id == CARD_ACTION_INSPECT:
		inspect_card_node(card_action_target)
	card_action_target = null
	if card_action_menu != null:
		card_action_menu.hide()


func inspect_card_node(card_node: Node3D) -> void:
	if card_node == null or not is_instance_valid(card_node) or card_inspect_panel == null:
		return
	var card_data := card_node.get_meta("card_data", null) as CardData
	if card_data == null:
		return
	var source_position := get_viewport().get_mouse_position()
	card_inspect_panel.last_source_rect = Rect2(source_position, Vector2(130.0, 180.0))
	card_inspect_panel.show_card(null, card_data)
	set_status("Inspecting " + card_data.card_name + ". Right-click or press Escape to close.")


func screen_to_table_point(screen_position: Vector2) -> Vector3:
	return screen_to_horizontal_plane(screen_position, TABLE_PLANE_Y)


func screen_to_horizontal_plane(screen_position: Vector2, plane_y: float) -> Vector3:
	if camera_3d == null:
		return Vector3.ZERO
	var origin := camera_3d.project_ray_origin(screen_position)
	var direction := camera_3d.project_ray_normal(screen_position)
	if abs(direction.y) < 0.0001:
		return origin
	var t := (plane_y - origin.y) / direction.y
	return origin + direction * t


func is_point_in_rack(point: Vector3) -> bool:
	return point.x >= RACK_MIN_X and point.x <= RACK_MAX_X and point.z >= RACK_MIN_Z and point.z <= RACK_MAX_Z


func is_point_in_rack_drop_zone(point: Vector3) -> bool:
	return (
		point.x >= RACK_MIN_X
		and point.x <= RACK_DROP_MAX_X
		and point.z >= RACK_DROP_MIN_Z
		and point.z <= RACK_MAX_Z
	)


func get_deck_insert_index_from_screen(screen_position: Vector2) -> int:
	if camera_3d == null:
		return get_deck_insert_index_from_world(dragging_target_position)
	var intended_card_center := screen_position + drag_card_center_screen_offset
	var prospective_count := deck_cards.size() + 1
	var nearest_index := 0
	var nearest_distance := INF
	for index in range(prospective_count):
		var local_slot := get_rack_slot_position(index, prospective_count)
		var slot_screen := camera_3d.unproject_position(rack_root.to_global(local_slot))
		var distance := intended_card_center.distance_squared_to(slot_screen)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return nearest_index


func get_deck_insert_index_from_world(point: Vector3) -> int:
	var prospective_count := deck_cards.size() + 1
	var nearest_index := 0
	var nearest_distance := INF
	for index in range(prospective_count):
		var slot := get_rack_slot_position(index, prospective_count)
		var distance := Vector2(point.x - slot.x, point.z - slot.z).length_squared()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return nearest_index


func get_rack_slot_position(index: int, total_count: int) -> Vector3:
	var safe_count := maxi(total_count, 1)
	var left_count := (safe_count + 1) / 2
	var in_right_column := index >= left_count
	var column_count := safe_count / 2 if in_right_column else left_count
	var column_index := index - left_count if in_right_column else index
	# Fable-style stack: expose primarily the title strip of each card. The final
	# card in a column remains unobstructed, giving the stack a clear visual end.
	var spacing := RACK_CARD_REVEAL_SPACING
	if column_count > 1:
		spacing = minf(spacing, (RACK_Z_BOTTOM - RACK_STACK_START_Z) / float(column_count - 1))
	var x := RACK_COL_RIGHT if in_right_column else RACK_COL_LEFT
	return Vector3(x, RACK_Y, RACK_STACK_START_Z + float(column_index) * spacing)


func card_matches_filters(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var race := card_data.race.to_lower().strip_edges()
	var card_type := card_data.card_type.to_lower().strip_edges()

	if not active_race_filters.is_empty() and not active_race_filters.has(race):
		return false
	if not active_type_filters.is_empty() and not active_type_filters.has(card_type):
		return false
	if not active_ability_filters.is_empty():
		var card_ability_categories: Dictionary = {}
		for category in card_data.get_ability_categories():
			var clean_category := String(category).to_lower().strip_edges()
			if clean_category != "":
				card_ability_categories[clean_category] = true
		for filter_key in active_ability_filters.keys():
			if not card_ability_categories.has(filter_key):
				return false

	if search_text != "":
		var haystack := (
			card_data.card_name + " " +
			card_data.race + " " +
			card_data.card_type + " " +
			card_data.rarity + " " +
			card_data.get_ability_text() + " " +
			card_data.lore_text
		).to_lower()
		if not haystack.contains(search_text):
			return false

	return true


func build_card_lookup() -> void:
	card_lookup.clear()
	for card in all_cards:
		var key := get_card_key(card)
		if key != "":
			card_lookup[key] = card


func get_card_key(card_data: CardData) -> String:
	if card_data == null:
		return ""
	if card_data.card_id.strip_edges() != "":
		return card_data.card_id.strip_edges()
	return card_data.card_name.to_lower().strip_edges().replace(" ", "_")


func get_card_sort_key(card_data: CardData) -> String:
	if card_data == null:
		return "zzzz"
	return card_data.card_type.to_lower() + ":" + card_data.race.to_lower() + ":" + card_data.card_name.to_lower()


func _on_library_sort_selected(sort_id: int) -> void:
	var selected_mode := sort_id as LibrarySortMode
	if selected_mode == library_sort_mode:
		library_sort_ascending = not library_sort_ascending
	else:
		library_sort_mode = selected_mode
		library_sort_ascending = true
	update_library_sort_button()
	refresh_library()


func update_library_sort_button() -> void:
	if library_sort_button == null:
		return
	library_sort_button.text = "SORT " + ("↑" if library_sort_ascending else "↓")
	var popup := library_sort_button.get_popup()
	for item_index in range(popup.item_count):
		popup.set_item_checked(item_index, popup.get_item_id(item_index) == int(library_sort_mode))


func compare_library_cards(a: CardData, b: CardData) -> bool:
	if a == null:
		return false
	if b == null:
		return true

	var comparison := 0
	match library_sort_mode:
		LibrarySortMode.TP:
			comparison = _compare_card_numbers(a.tribute_cost, b.tribute_cost)
		LibrarySortMode.AP:
			comparison = _compare_card_numbers(a.ap, b.ap)
		LibrarySortMode.DP:
			comparison = _compare_card_numbers(a.dp, b.dp)
		_:
			comparison = a.card_name.naturalnocasecmp_to(b.card_name)

	if comparison == 0:
		comparison = a.card_name.naturalnocasecmp_to(b.card_name)
	return comparison < 0 if library_sort_ascending else comparison > 0


func _compare_card_numbers(a: int, b: int) -> int:
	if a < b:
		return -1
	if a > b:
		return 1
	return 0


func get_deck_copy_count(card_data: CardData) -> int:
	var key := get_card_key(card_data)
	var count := 0
	for card in deck_cards:
		if get_card_key(card) == key:
			count += 1
	return count


func get_card_copy_limit(card_data: CardData) -> int:
	return CardRules.get_deck_copy_limit(card_data)


func is_library_card_at_copy_limit(card_node: Node3D) -> bool:
	if card_node == null:
		return false
	var card_data := card_node.get_meta("card_data", null) as CardData
	if card_data == null:
		return false
	return get_deck_copy_count(card_data) >= get_card_copy_limit(card_data)


func refresh_library_copy_indicators() -> void:
	for card_node in library_nodes:
		if card_node == null or not is_instance_valid(card_node):
			continue
		var card_data := card_node.get_meta("card_data", null) as CardData
		if card_data == null:
			continue
		var copies := get_deck_copy_count(card_data)
		var badge := card_node.get_node_or_null("DeckCopyBadge") as Label3D
		if badge != null:
			badge.text = str(copies) + "x"
			badge.visible = copies > 0


func update_deck_status() -> void:
	refresh_library_copy_indicators()
	if deck_count_label != null:
		deck_count_label.text = "Deck " + str(deck_cards.size()) + "/" + str(MAX_DECK_SIZE)
	if deck_ledger_label_3d != null:
		deck_ledger_label_3d.text = (
			"WAR DECK LEDGER  •  DECK "
			+ str(deck_cards.size())
			+ "/"
			+ str(MAX_DECK_SIZE)
		)
	var valid := deck_cards.size() >= MIN_DECK_SIZE and deck_cards.size() <= MAX_DECK_SIZE
	if play_button != null:
		play_button.disabled = not valid
	if save_button != null:
		save_button.disabled = deck_cards.is_empty()


func save_deck_to_disk() -> void:
	if deck_cards.size() > MAX_DECK_SIZE:
		set_status("Deck cannot exceed " + str(MAX_DECK_SIZE) + " cards.")
		return

	var card_ids: Array[String] = []
	for card in deck_cards:
		card_ids.append(get_card_key(card))

	var deck_name := deck_name_edit.text.strip_edges()
	if deck_name == "":
		deck_name = "Deck " + str(active_deck_slot + 1)
		deck_name_edit.text = deck_name
	saved_decks[active_deck_slot] = {
		"deck_name": deck_name,
		"cards": card_ids,
	}
	write_deck_slots_to_disk()
	refresh_deck_slot_chip()
	set_status(
		"Saved slot " + str(active_deck_slot + 1) + ": "
		+ deck_name + " (" + str(deck_cards.size()) + "/" + str(MAX_DECK_SIZE) + " cards)."
	)
	extend_deck_chip()


func delete_active_deck_slot() -> void:
	if deck_switch_in_progress:
		return
	var deleted_slot := active_deck_slot
	saved_decks[deleted_slot] = {
		"deck_name": "Deck " + str(deleted_slot + 1),
		"cards": [],
	}
	write_deck_slots_to_disk()
	load_deck_slot_into_rack(deleted_slot)
	refresh_deck_slot_chip()
	extend_deck_chip()
	set_status("Deleted saved deck slot " + str(deleted_slot + 1) + ".")


func write_deck_slots_to_disk() -> void:
	var data := {
		"version": 2,
		"active_slot": active_deck_slot,
		"decks": saved_decks,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		set_status("Could not save deck: " + SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func load_deck_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		load_deck_slot_into_rack(active_deck_slot)
		refresh_deck_slot_chip()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return

	var data: Dictionary = parsed
	if data.has("decks") and data["decks"] is Array:
		var raw_decks: Array = data["decks"]
		for slot_index in range(mini(DECK_SLOT_COUNT, raw_decks.size())):
			if raw_decks[slot_index] is Dictionary:
				saved_decks[slot_index] = sanitize_saved_deck(raw_decks[slot_index], slot_index)
		active_deck_slot = clampi(int(data.get("active_slot", 0)), 0, DECK_SLOT_COUNT - 1)
	else:
		# Migrate the original single-deck save into slot 1.
		saved_decks[0] = sanitize_saved_deck(data, 0)
		active_deck_slot = 0
		write_deck_slots_to_disk()

	load_deck_slot_into_rack(active_deck_slot)
	refresh_deck_slot_chip()


func sanitize_saved_deck(raw_data: Dictionary, slot_index: int) -> Dictionary:
	var clean_cards: Array[String] = []
	var raw_cards: Array = raw_data.get("cards", [])
	for raw_id in raw_cards:
		if clean_cards.size() >= MAX_DECK_SIZE:
			break
		clean_cards.append(String(raw_id))
	var deck_name := String(raw_data.get("deck_name", "Deck " + str(slot_index + 1))).strip_edges()
	if deck_name == "":
		deck_name = "Deck " + str(slot_index + 1)
	return {
		"deck_name": deck_name,
		"cards": clean_cards,
	}


func clear_current_deck() -> void:
	deck_cards.clear()
	for node in deck_nodes:
		if node != null and is_instance_valid(node):
			node.visible = false
			node.queue_free()
	deck_nodes.clear()


func load_deck_slot_into_rack(slot_index: int) -> void:
	clear_current_deck()
	var data: Dictionary = saved_decks[slot_index]
	deck_name_edit.text = String(data.get("deck_name", "Deck " + str(slot_index + 1)))
	var card_ids: Array = data.get("cards", [])
	for raw_id in card_ids:
		var key := String(raw_id)
		if not card_lookup.has(key):
			continue
		var card_data: CardData = card_lookup[key]
		if get_deck_copy_count(card_data) >= get_card_copy_limit(card_data):
			continue
		if deck_cards.size() >= MAX_DECK_SIZE:
			break
		deck_cards.append(card_data)
		var node := create_card_node(card_data, "deck")
		node.scale = CARD_SCALE_RACK
		rack_root.add_child(node)
		deck_nodes.append(node)
	layout_deck_rack(true)
	update_deck_status()


func _on_deck_slot_pressed(slot_index: int) -> void:
	if deck_switch_in_progress or slot_index == active_deck_slot:
		return
	switch_to_deck_slot(slot_index)


func switch_to_deck_slot(slot_index: int) -> void:
	deck_switch_in_progress = true
	await retract_deck_chip()

	var exit_tween := create_tween()
	exit_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(
		rack_assembly_root,
		"position",
		rack_assembly_home_position + DECK_RACK_EXIT_OFFSET,
		0.38
	)
	await exit_tween.finished

	active_deck_slot = clampi(slot_index, 0, DECK_SLOT_COUNT - 1)
	rack_assembly_root.position = rack_assembly_home_position + DECK_RACK_ENTRY_OFFSET
	load_deck_slot_into_rack(active_deck_slot)
	write_deck_slots_to_disk()
	refresh_deck_slot_chip()

	var entry_tween := create_tween()
	entry_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	entry_tween.tween_property(
		rack_assembly_root,
		"position",
		rack_assembly_home_position,
		0.52
	)
	await entry_tween.finished

	deck_switch_in_progress = false
	extend_deck_chip()
	set_status(
		"Loaded deck slot " + str(active_deck_slot + 1) + ": "
		+ String(saved_decks[active_deck_slot].get("deck_name", "Deck")) + "."
	)


func show_card_detail(card_data: CardData) -> void:
	if card_data == null:
		return
	if card_detail_name_3d != null:
		card_detail_name_3d.text = card_data.card_name + "  •  TP " + str(card_data.tribute_cost)
		card_detail_name_3d.visible = true
	if card_detail_stats_3d != null:
		card_detail_stats_3d.text = (
			card_data.race.capitalize()
			+ "  •  "
			+ card_data.card_type.capitalize()
			+ "  •  AP "
			+ str(card_data.ap)
			+ " / DP "
			+ str(card_data.dp)
		)
		card_detail_stats_3d.visible = true


func set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message


func _on_search_changed(new_text: String) -> void:
	search_text = new_text.to_lower().strip_edges()
	refresh_library()


func _on_race_filter_pressed(filter_value: String) -> void:
	if filter_value == "all":
		active_race_filters.clear()
	elif active_race_filters.has(filter_value):
		active_race_filters.erase(filter_value)
	else:
		active_race_filters[filter_value] = true
	refresh_filter_buttons()
	refresh_library()


func _on_type_filter_pressed(filter_value: String) -> void:
	if filter_value == "all":
		active_type_filters.clear()
	elif active_type_filters.has(filter_value):
		active_type_filters.erase(filter_value)
	else:
		active_type_filters[filter_value] = true
	refresh_filter_buttons()
	refresh_library()


func _on_ability_filter_toggle_pressed() -> void:
	if ability_filter_panel != null:
		ability_filter_panel.visible = ability_filter_button != null and ability_filter_button.button_pressed


func _on_ability_filter_pressed(filter_value: String) -> void:
	if active_ability_filters.has(filter_value):
		active_ability_filters.erase(filter_value)
	elif active_ability_filters.size() < 2:
		active_ability_filters[filter_value] = true
	else:
		refresh_ability_filter_buttons()
		return

	refresh_ability_filter_buttons()
	refresh_library()


func _on_clear_pressed() -> void:
	deck_cards.clear()
	for node in deck_nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()
	deck_nodes.clear()
	update_deck_status()
	set_status("Deck rack cleared.")


func _on_sort_pressed() -> void:
	var pairs: Array[Dictionary] = []
	for i in range(deck_cards.size()):
		pairs.append({"card": deck_cards[i], "node": deck_nodes[i]})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return get_deck_sort_key(a["card"]) < get_deck_sort_key(b["card"])
	)
	deck_cards.clear()
	deck_nodes.clear()
	for pair in pairs:
		deck_cards.append(pair["card"])
		deck_nodes.append(pair["node"])
	layout_deck_rack(false)
	set_status("Deck rack sorted by tribute cost, then type and name.")


func get_deck_sort_key(card_data: CardData) -> String:
	if card_data == null:
		return "999:zzzz"
	return "%03d:%s:%s" % [
		card_data.tribute_cost,
		card_data.card_type.to_lower(),
		card_data.card_name.to_lower(),
	]


func _on_save_and_battle_pressed() -> void:
	save_deck_to_disk()
	if deck_cards.size() >= MIN_DECK_SIZE:
		request_scene_change(BATTLE_SCENE_PATH)


func request_scene_change(scene_path: String, sfx_name: String = "menu_button") -> void:
	if scene_transition_requested:
		return

	scene_transition_requested = true

	if scene_path == MENU_SCENE_PATH:
		PrototypeMenu.skip_intro_once = true

	active_tabletop_viewport = null

	for entry in tabletop_ui_surfaces:
		entry["interactive"] = false

	call_deferred("_perform_scene_change", scene_path, sfx_name)


func _perform_scene_change(scene_path: String, sfx_name: String = "menu_button") -> void:
	if SceneLoader != null and SceneLoader.has_method("go_to_scene"):
		SceneLoader.go_to_scene(scene_path, sfx_name)
		return

	var tree := get_tree()
	if tree != null:
		tree.change_scene_to_file(scene_path)


func is_pointer_over_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	# Only block 3D input when a STOP-filter control is under the cursor.
	# PASS controls (e.g. the full-screen root overlay) must not swallow clicks.
	return hovered.mouse_filter == Control.MOUSE_FILTER_STOP


func make_mat(albedo: Color, roughness: float = 0.75, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = roughness
	mat.metallic = metallic
	return mat


func _build_library_fog(root: Control) -> void:
	# Two gradient bands positioned as screen-fraction anchors so they scale
	# with any resolution. Cards are binary visible/hidden; these bands provide
	# the smooth visual fade at the cloth boundaries.
	# Color matches the dark-brown wooden table surrounding the cloth.
	var fog := Control.new()
	fog.name = "LibraryFogBands"
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fog)

	var fog_color := Color(0.23, 0.11, 0.05, 1.0)   # warm dark wood, not black

	# Left band: 0% → 13% of screen width.
	# Solid at left (matching wood frame), fades right into the cloth interior.
	var left_band := TextureRect.new()
	left_band.name = "FogLeft"
	left_band.texture = _make_fog_image(fog_color, 55, 110)
	left_band.stretch_mode = TextureRect.STRETCH_SCALE
	left_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_band.anchor_left   = 0.0
	left_band.anchor_right  = 0.13
	left_band.anchor_top    = 0.10
	left_band.anchor_bottom = 1.0
	fog.add_child(left_band)

	# Right band: 55% → 66.5% of screen width.
	# Fades left-to-right from transparent into solid wood, ending at the rack wall.
	var right_band := TextureRect.new()
	right_band.name = "FogRight"
	right_band.texture = _make_fog_image_right(fog_color, 110, 40)
	right_band.stretch_mode = TextureRect.STRETCH_SCALE
	right_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_band.anchor_left   = 0.55
	right_band.anchor_right  = 0.665
	right_band.anchor_top    = 0.10
	right_band.anchor_bottom = 1.0
	fog.add_child(right_band)


# Left-side fog: [solid_px] columns of fog_color, then [fade_px] fading to transparent.
func _make_fog_image(fog_color: Color, solid_px: int, fade_px: int) -> ImageTexture:
	var w := solid_px + fade_px
	var img := Image.create(w, 2, false, Image.FORMAT_RGBA8)
	for x in range(w):
		var c: Color
		if x < solid_px:
			c = fog_color
		else:
			var t := float(x - solid_px) / float(max(1, fade_px - 1))
			c = fog_color.lerp(Color(fog_color.r, fog_color.g, fog_color.b, 0.0), t)
		img.set_pixel(x, 0, c)
		img.set_pixel(x, 1, c)
	return ImageTexture.create_from_image(img)


# Right-side fog: [fade_px] fading from transparent → fog_color, then [solid_px] solid.
func _make_fog_image_right(fog_color: Color, fade_px: int, solid_px: int) -> ImageTexture:
	var w := fade_px + solid_px
	var img := Image.create(w, 2, false, Image.FORMAT_RGBA8)
	for x in range(w):
		var c: Color
		if x < fade_px:
			var t := float(x) / float(max(1, fade_px - 1))
			c = Color(fog_color.r, fog_color.g, fog_color.b, 0.0).lerp(fog_color, t)
		else:
			c = fog_color
		img.set_pixel(x, 0, c)
		img.set_pixel(x, 1, c)
	return ImageTexture.create_from_image(img)


func make_panel_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 8
	return style
