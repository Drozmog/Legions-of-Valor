class_name DeckBuilder
extends Node3D

const CARD_SCENE: PackedScene = preload("res://cards/Card3D_Test.tscn")
const BATTLE_SCENE_PATH := "res://battlefield/battlefield_3d.tscn"
const MENU_SCENE_PATH := "res://ui/prototype_menu.tscn"
const SAVE_PATH := "user://lov_player_deck.json"

const MIN_DECK_SIZE := 10
const MAX_DECK_SIZE := 50
const COPY_LIMIT := 2

const CARD_SCALE_LIBRARY := Vector3(1.4, 1.4, 1.4)
const CARD_SCALE_DRAG := Vector3(1.05, 1.05, 1.05)
const CARD_SCALE_RACK := Vector3(0.70, 0.70, 0.70)

const LIBRARY_Y := 0.085
const RACK_Y := 0.12
const DRAG_Y := 0.42

const LIBRARY_BASE_X := -5.15
const LIBRARY_BASE_Z := -0.1
const LIBRARY_COLUMNS_PER_GROUP := 5
const LIBRARY_ROWS_PER_GROUP := 2
const LIBRARY_GROUP_SIZE := 10
const LIBRARY_COLUMN_SPACING := 1.55
const LIBRARY_ROW_SPACING := 2.10
const LIBRARY_GROUP_SPACING := 7.80
const LIBRARY_SCROLL_SPEED := LIBRARY_GROUP_SPACING
const LIBRARY_MIN_X := -6.35
const LIBRARY_MAX_X := 1.25

const RACK_X := 5.15
const RACK_Z_TOP := -2.20
const RACK_Z_BOTTOM := 2.30
const RACK_MIN_X := 3.35
const RACK_MAX_X := 6.85
const RACK_MIN_Z := -2.75
const RACK_MAX_Z := 2.75

const TABLE_PLANE_Y := 0.0

var all_cards: Array[CardData] = []
var filtered_cards: Array[CardData] = []
var card_lookup: Dictionary = {}
var deck_cards: Array[CardData] = []
var deck_nodes: Array[Node3D] = []
var library_nodes: Array[Node3D] = []

var library_root: Node3D
var rack_root: Node3D
var dragging_node: Node3D = null
var dragging_card: CardData = null
var dragging_from_library := false
var dragging_deck_original_index := -1
var dragging_target_position := Vector3.ZERO
var drag_preview_insert_index := 0
var library_scroll := 0.0
var library_scroll_min := 0.0
var library_scroll_max := 0.0

var active_race_filter := ""
var active_type_filter := ""
var search_text := ""

var camera_3d: Camera3D
var ui_layer: CanvasLayer
var status_label: Label
var deck_count_label: Label
var deck_name_edit: LineEdit
var save_button: Button
var play_button: Button
var search_box: LineEdit
var card_detail_label: RichTextLabel
var race_buttons: Dictionary = {}
var type_buttons: Dictionary = {}

func _ready() -> void:
	all_cards = CardDatabase.get_all_test_cards()
	all_cards.sort_custom(func(a: CardData, b: CardData) -> bool:
		return get_card_sort_key(a) < get_card_sort_key(b)
	)
	build_card_lookup()
	build_3d_scene()
	build_overlay_ui()
	load_deck_from_disk()
	refresh_library()
	layout_deck_rack(true)
	update_deck_status()
	set_status("3D deck table ready. Drag cards from the left table into the right rack.")


func _process(delta: float) -> void:
	animate_collection(library_nodes, delta)
	animate_collection(deck_nodes, delta)

	if dragging_node != null and is_instance_valid(dragging_node):
		dragging_node.global_position = dragging_node.global_position.lerp(dragging_target_position, clampf(delta * 18.0, 0.0, 1.0))
		dragging_node.scale = dragging_node.scale.lerp(CARD_SCALE_DRAG, clampf(delta * 12.0, 0.0, 1.0))


func _input(event: InputEvent) -> void:
	# Mouse-wheel scrolling must work even when the overlay UI is present.
	# Only block it while the search field is actively being typed in.
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			if search_box == null or not search_box.has_focus():
				set_library_scroll(library_scroll - LIBRARY_SCROLL_SPEED)
				get_viewport().set_input_as_handled()
			return

		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			if search_box == null or not search_box.has_focus():
				set_library_scroll(library_scroll + LIBRARY_SCROLL_SPEED)
				get_viewport().set_input_as_handled()
			return

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if is_pointer_over_ui():
				return
			if mouse_event.pressed:
				begin_drag_from_mouse(mouse_event.position)
			else:
				finish_drag(mouse_event.position)
			return

	if event is InputEventMouseMotion:
		if dragging_node != null:
			update_drag_target((event as InputEventMouseMotion).position)
			if not dragging_from_library:
				drag_preview_insert_index = get_deck_insert_index_from_world(dragging_target_position)
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

	rack_root = get_node_or_null("DeckRackCards") as Node3D
	if rack_root == null:
		rack_root = Node3D.new()
		rack_root.name = "DeckRackCards"
		add_child(rack_root)

func create_table_mesh() -> void:
	var table := MeshInstance3D.new()
	table.name = "HeavyWoodenDeckBuilderTable"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(14.8, 0.18, 6.45)
	table.mesh = mesh
	table.position = Vector3(0.0, -0.12, 0.0)
	table.material_override = make_mat(Color(0.30, 0.17, 0.075, 1.0), 0.80, 0.0)
	add_child(table)

	var table_trim := MeshInstance3D.new()
	table_trim.name = "GoldTableTrim"
	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(14.95, 0.035, 6.60)
	table_trim.mesh = trim_mesh
	table_trim.position = Vector3(0.0, -0.005, 0.0)
	table_trim.material_override = make_mat(Color(0.48, 0.34, 0.10, 1.0), 0.52, 0.0)
	add_child(table_trim)


func create_left_library_surface() -> void:
	var surface := MeshInstance3D.new()
	surface.name = "LeftCollectionTableSurface"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(8.9, 0.04, 5.45)
	surface.mesh = mesh
	surface.position = Vector3(-2.05, 0.012, 0.10)
	surface.material_override = make_mat(Color(0.18, 0.105, 0.052, 1.0), 0.88, 0.0)
	add_child(surface)

	var title := Label3D.new()
	title.name = "LibraryTitle3D"
	title.text = "OWNED CARD LIBRARY"
	title.font_size = 34
	title.pixel_size = 0.010
	title.position = Vector3(-5.75, 0.075, -2.55)
	title.rotation_degrees = Vector3(-90, 0, 0)
	title.modulate = Color(0.96, 0.79, 0.34, 1.0)
	add_child(title)


func create_right_rack_surface() -> void:
	var rack_base := MeshInstance3D.new()
	rack_base.name = "RightPhysicalDeckRack"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.55, 0.12, 5.60)
	rack_base.mesh = mesh
	rack_base.position = Vector3(5.10, 0.035, 0.0)
	rack_base.material_override = make_mat(Color(0.16, 0.080, 0.038, 1.0), 0.82, 0.0)
	add_child(rack_base)

	var left_wall := make_rack_wall("RackLeftWall", Vector3(3.25, 0.22, 0), Vector3(0.08, 0.42, 5.72))
	add_child(left_wall)
	var right_wall := make_rack_wall("RackRightWall", Vector3(6.95, 0.22, 0), Vector3(0.08, 0.42, 5.72))
	add_child(right_wall)
	var top_wall := make_rack_wall("RackTopWall", Vector3(5.10, 0.22, -2.86), Vector3(3.70, 0.42, 0.08))
	add_child(top_wall)
	var bottom_wall := make_rack_wall("RackBottomWall", Vector3(5.10, 0.22, 2.86), Vector3(3.70, 0.42, 0.08))
	add_child(bottom_wall)

	var title := Label3D.new()
	title.name = "RackTitle3D"
	title.text = "DECK RACK"
	title.font_size = 44
	title.pixel_size = 0.010
	title.position = Vector3(4.10, 0.16, -2.55)
	title.rotation_degrees = Vector3(-90, 0, 0)
	title.modulate = Color(0.96, 0.79, 0.34, 1.0)
	add_child(title)


func make_rack_wall(node_name: String, wall_position: Vector3, wall_size: Vector3) -> MeshInstance3D:
	var wall := MeshInstance3D.new()
	wall.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = wall_size
	wall.mesh = mesh
	wall.position = wall_position
	wall.material_override = make_mat(Color(0.22, 0.115, 0.055, 1.0), 0.70, 0.0)
	return wall


func build_overlay_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "DeckBuilderOverlay"
	add_child(ui_layer)

	var root := Control.new()
	root.name = "OverlayRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	ui_layer.add_child(root)

	var top_panel := PanelContainer.new()
	top_panel.name = "TopCommandPanel"
	top_panel.anchor_left = 0.03
	top_panel.anchor_right = 0.97
	top_panel.anchor_top = 0.025
	top_panel.anchor_bottom = 0.16
	top_panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.025, 0.018, 0.012, 0.90), Color(0.70, 0.52, 0.18, 1.0), 2))
	root.add_child(top_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	top_panel.add_child(margin)

	var top_rows := VBoxContainer.new()
	top_rows.add_theme_constant_override("separation", 8)
	margin.add_child(top_rows)

	var first_row := HBoxContainer.new()
	first_row.add_theme_constant_override("separation", 10)
	top_rows.add_child(first_row)

	var back_button := make_button("Back to Menu", Vector2(145, 42))
	back_button.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE_PATH))
	first_row.add_child(back_button)

	var title := Label.new()
	title.text = "3D CARD TABLE  /  DECK RACK"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.96, 0.82, 0.38, 1.0))
	first_row.add_child(title)

	var name_label := Label.new()
	name_label.text = "Deck Name:"
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.80, 0.72, 0.56, 1.0))
	first_row.add_child(name_label)

	deck_name_edit = LineEdit.new()
	deck_name_edit.text = "Custom Warband"
	deck_name_edit.custom_minimum_size = Vector2(235, 38)
	first_row.add_child(deck_name_edit)

	save_button = make_button("Save Deck", Vector2(120, 38))
	save_button.pressed.connect(save_deck_to_disk)
	first_row.add_child(save_button)

	play_button = make_button("Save + Battle", Vector2(140, 38))
	play_button.pressed.connect(_on_save_and_battle_pressed)
	first_row.add_child(play_button)

	var second_row := HBoxContainer.new()
	second_row.add_theme_constant_override("separation", 8)
	top_rows.add_child(second_row)

	search_box = LineEdit.new()
	search_box.placeholder_text = "Search cards by name, race, type, ability, or lore..."
	search_box.custom_minimum_size = Vector2(360, 36)
	search_box.text_changed.connect(_on_search_changed)
	second_row.add_child(search_box)

	var race_label := Label.new()
	race_label.text = "Faction:"
	race_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	race_label.add_theme_color_override("font_color", Color(0.80, 0.72, 0.56, 1.0))
	second_row.add_child(race_label)
	add_filter_buttons(second_row, ["All", "Human", "Dwarf", "Orc", "Elf", "Neutral"], race_buttons, _on_race_filter_pressed)

	var type_label := Label.new()
	type_label.text = "Type:"
	type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	type_label.add_theme_color_override("font_color", Color(0.80, 0.72, 0.56, 1.0))
	second_row.add_child(type_label)
	add_filter_buttons(second_row, ["All", "Unit", "Gambit", "Equipment"], type_buttons, _on_type_filter_pressed)

	var bottom_panel := PanelContainer.new()
	bottom_panel.name = "BottomStatusPanel"
	bottom_panel.anchor_left = 0.03
	bottom_panel.anchor_right = 0.97
	bottom_panel.anchor_top = 0.88
	bottom_panel.anchor_bottom = 0.975
	bottom_panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.025, 0.018, 0.012, 0.78), Color(0.55, 0.40, 0.15, 1.0), 1))
	root.add_child(bottom_panel)

	var bottom_margin := MarginContainer.new()
	bottom_margin.add_theme_constant_override("margin_left", 14)
	bottom_margin.add_theme_constant_override("margin_right", 14)
	bottom_margin.add_theme_constant_override("margin_top", 8)
	bottom_margin.add_theme_constant_override("margin_bottom", 8)
	bottom_panel.add_child(bottom_margin)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 14)
	bottom_margin.add_child(bottom_row)

	deck_count_label = Label.new()
	deck_count_label.custom_minimum_size = Vector2(220, 1)
	deck_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	deck_count_label.add_theme_font_size_override("font_size", 20)
	deck_count_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.38, 1.0))
	bottom_row.add_child(deck_count_label)

	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.82, 0.76, 0.62, 1.0))
	bottom_row.add_child(status_label)

	var clear_button := make_button("Clear Rack", Vector2(120, 36))
	clear_button.pressed.connect(_on_clear_pressed)
	bottom_row.add_child(clear_button)

	var sort_button := make_button("Sort Rack", Vector2(120, 36))
	sort_button.pressed.connect(_on_sort_pressed)
	bottom_row.add_child(sort_button)

	card_detail_label = RichTextLabel.new()
	card_detail_label.name = "CardDetailLabel"
	card_detail_label.bbcode_enabled = true
	card_detail_label.fit_content = false
	card_detail_label.scroll_active = false
	card_detail_label.anchor_left = 0.03
	card_detail_label.anchor_right = 0.33
	card_detail_label.anchor_top = 0.17
	card_detail_label.anchor_bottom = 0.30
	card_detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_detail_label.add_theme_color_override("default_color", Color(0.86, 0.80, 0.66, 1.0))
	root.add_child(card_detail_label)

	refresh_filter_buttons()


func make_button(text: String, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	return button


func add_filter_buttons(parent: HBoxContainer, labels: Array[String], store: Dictionary, callback: Callable) -> void:
	for label_text in labels:
		var button := make_button(label_text, Vector2(78, 34))
		var filter_key := label_text.to_lower()
		button.toggle_mode = true
		button.pressed.connect(func(): callback.call(filter_key))
		store[filter_key] = button
		parent.add_child(button)


func refresh_filter_buttons() -> void:
	for key in race_buttons.keys():
		var b: Button = race_buttons[key]
		b.button_pressed = (key == "all" and active_race_filter == "") or key == active_race_filter

	for key in type_buttons.keys():
		var b: Button = type_buttons[key]
		b.button_pressed = (key == "all" and active_type_filter == "") or key == active_type_filter


func refresh_library() -> void:
	for node in library_nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()
	library_nodes.clear()
	filtered_cards.clear()

	for card in all_cards:
		if card_matches_filters(card):
			filtered_cards.append(card)

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
	library_scroll = clamp(library_scroll, library_scroll_min, library_scroll_max)
	layout_library(true)
	set_status("Showing " + str(filtered_cards.size()) + " owned card(s). Library shows 5 cards top / 5 bottom; mouse wheel scrolls horizontally by page.")


func layout_library(instant: bool = false) -> void:
	for i in range(library_nodes.size()):
		var node := library_nodes[i]
		if node == dragging_node:
			continue

		# Two-row horizontal table layout:
		# 1-5 on top row, 6-10 on bottom row, then next group scrolls in horizontally.
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
		var visible_in_window: bool = target.x >= LIBRARY_MIN_X and target.x <= LIBRARY_MAX_X
		node.visible = visible_in_window
		if instant:
			node.position = target
			node.scale = CARD_SCALE_LIBRARY


func layout_deck_rack(instant: bool = false, preview_insert_index: int = -1) -> void:
	var count_with_gap := deck_nodes.size()
	if dragging_node != null and not dragging_from_library and is_point_in_rack(dragging_target_position):
		count_with_gap += 1

	var available_span := RACK_Z_BOTTOM - RACK_Z_TOP
	var spacing := 0.205
	if count_with_gap > 1:
		spacing = min(0.205, available_span / float(max(1, count_with_gap - 1)))

	var visual_index := 0
	for i in range(deck_nodes.size()):
		if preview_insert_index >= 0 and visual_index == preview_insert_index:
			visual_index += 1
		var node := deck_nodes[i]
		if node == dragging_node:
			continue
		var target := Vector3(RACK_X, RACK_Y + float(visual_index) * 0.004, RACK_Z_TOP + float(visual_index) * spacing)
		node.set_meta("target_position", target)
		node.set_meta("target_scale", CARD_SCALE_RACK)
		node.set_meta("target_rotation", Vector3(0, 0, 0))
		if instant:
			node.position = target
			node.scale = CARD_SCALE_RACK
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
	add_pick_area(card_node)
	return card_node


func add_pick_area(card_node: Node3D) -> void:
	var area := Area3D.new()
	area.name = "DeckBuilderPickArea"
	area.collision_layer = 1
	area.collision_mask = 1
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
		return

	var card_data: CardData = picked.get_meta("card_data", null) as CardData
	if card_data == null:
		return

	dragging_node = picked
	dragging_card = card_data
	dragging_from_library = String(picked.get_meta("source_zone", "")) == "library"
	dragging_deck_original_index = -1

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
	update_drag_target(screen_position)


func update_drag_target(screen_position: Vector2) -> void:
	var hit := screen_to_table_point(screen_position)
	dragging_target_position = Vector3(hit.x, DRAG_Y, hit.z)


func finish_drag(screen_position: Vector2) -> void:
	if dragging_node == null or dragging_card == null:
		return

	update_drag_target(screen_position)
	var released_in_rack := is_point_in_rack(dragging_target_position)

	if dragging_from_library:
		if released_in_rack:
			try_add_library_card_to_deck(dragging_card)
		animate_library_card_home(dragging_node)
	else:
		if released_in_rack:
			var insert_index := get_deck_insert_index_from_world(dragging_target_position)
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
	drag_preview_insert_index = 0
	layout_library(false)
	layout_deck_rack(false)
	update_deck_status()


func try_add_library_card_to_deck(card_data: CardData) -> bool:
	if deck_cards.size() >= MAX_DECK_SIZE:
		set_status("Deck rack is full. Maximum " + str(MAX_DECK_SIZE) + " cards.")
		return false

	var copies := get_deck_copy_count(card_data)
	if copies >= COPY_LIMIT:
		set_status("Cannot add more than " + str(COPY_LIMIT) + " copies of " + card_data.card_name + ".")
		return false

	var new_node := create_card_node(card_data, "deck")
	new_node.name = "Deck_" + card_data.card_name.replace(" ", "_")
	new_node.scale = CARD_SCALE_DRAG
	new_node.position = dragging_target_position
	rack_root.add_child(new_node)

	var insert_index := get_deck_insert_index_from_world(dragging_target_position)
	insert_index = clamp(insert_index, 0, deck_cards.size())
	deck_cards.insert(insert_index, card_data)
	deck_nodes.insert(insert_index, new_node)
	set_status("Added " + card_data.card_name + " to deck rack. " + str(copies + 1) + "/" + str(COPY_LIMIT) + " copies.")
	show_card_detail(card_data)
	return true


func animate_library_card_home(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_as_top_level(false)
	if node.get_parent() != library_root:
		node.reparent(library_root)
	node.set_meta("source_zone", "library")
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


func set_library_scroll(value: float) -> void:
	library_scroll = clamp(value, library_scroll_min, library_scroll_max)
	layout_library(false)


func pick_card_node(screen_position: Vector2) -> Node3D:
	if camera_3d == null:
		return null
	var origin := camera_3d.project_ray_origin(screen_position)
	var end := origin + camera_3d.project_ray_normal(screen_position) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	var collider: Object = result.get("collider", null)
	if collider == null:
		return null
	if collider is Area3D and (collider as Area3D).has_meta("card_node"):
		return (collider as Area3D).get_meta("card_node") as Node3D
	return null


func screen_to_table_point(screen_position: Vector2) -> Vector3:
	if camera_3d == null:
		return Vector3.ZERO
	var origin := camera_3d.project_ray_origin(screen_position)
	var direction := camera_3d.project_ray_normal(screen_position)
	if abs(direction.y) < 0.0001:
		return origin
	var t := (TABLE_PLANE_Y - origin.y) / direction.y
	return origin + direction * t


func is_point_in_rack(point: Vector3) -> bool:
	return point.x >= RACK_MIN_X and point.x <= RACK_MAX_X and point.z >= RACK_MIN_Z and point.z <= RACK_MAX_Z


func get_deck_insert_index_from_world(point: Vector3) -> int:
	var t := inverse_lerp(RACK_Z_TOP, RACK_Z_BOTTOM, clamp(point.z, RACK_Z_TOP, RACK_Z_BOTTOM))
	var count: int = int(max(1, deck_cards.size() + 1))
	return clamp(int(round(t * float(count - 1))), 0, deck_cards.size())


func card_matches_filters(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var race := card_data.race.to_lower().strip_edges()
	var card_type := card_data.card_type.to_lower().strip_edges()

	if active_race_filter != "" and race != active_race_filter:
		return false
	if active_type_filter != "" and card_type != active_type_filter:
		return false

	if search_text != "":
		var haystack := (
			card_data.card_name + " " +
			card_data.race + " " +
			card_data.card_type + " " +
			card_data.rarity + " " +
			card_data.ability_text + " " +
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


func get_deck_copy_count(card_data: CardData) -> int:
	var key := get_card_key(card_data)
	var count := 0
	for card in deck_cards:
		if get_card_key(card) == key:
			count += 1
	return count


func update_deck_status() -> void:
	if deck_count_label != null:
		deck_count_label.text = "Deck " + str(deck_cards.size()) + "/" + str(MAX_DECK_SIZE)
	var valid := deck_cards.size() >= MIN_DECK_SIZE and deck_cards.size() <= MAX_DECK_SIZE
	if play_button != null:
		play_button.disabled = not valid
	if save_button != null:
		save_button.disabled = deck_cards.is_empty()


func save_deck_to_disk() -> void:
	if deck_cards.size() < MIN_DECK_SIZE:
		set_status("Deck needs at least " + str(MIN_DECK_SIZE) + " cards before saving for battle.")
		return
	if deck_cards.size() > MAX_DECK_SIZE:
		set_status("Deck cannot exceed " + str(MAX_DECK_SIZE) + " cards.")
		return

	var card_ids: Array[String] = []
	for card in deck_cards:
		card_ids.append(get_card_key(card))

	var data := {
		"deck_name": deck_name_edit.text.strip_edges(),
		"cards": card_ids,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		set_status("Could not save deck: " + SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	set_status("Saved deck: " + deck_name_edit.text + " (" + str(deck_cards.size()) + " cards).")


func load_deck_from_disk() -> void:
	deck_cards.clear()
	for node in deck_nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()
	deck_nodes.clear()

	if not FileAccess.file_exists(SAVE_PATH):
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
	deck_name_edit.text = String(data.get("deck_name", "Custom Warband"))
	var card_ids: Array = data.get("cards", [])

	for raw_id in card_ids:
		var key := String(raw_id)
		if not card_lookup.has(key):
			continue
		var card_data: CardData = card_lookup[key]
		if get_deck_copy_count(card_data) >= COPY_LIMIT:
			continue
		if deck_cards.size() >= MAX_DECK_SIZE:
			break
		deck_cards.append(card_data)
		var node := create_card_node(card_data, "deck")
		node.scale = CARD_SCALE_RACK
		rack_root.add_child(node)
		deck_nodes.append(node)


func show_card_detail(card_data: CardData) -> void:
	if card_detail_label == null or card_data == null:
		return
	card_detail_label.text = "[b]" + card_data.card_name + "[/b]  [color=#d7bd64]TP " + str(card_data.tribute_cost) + "[/color]\n" + card_data.race.capitalize() + "  |  " + card_data.card_type.capitalize() + "  |  AP " + str(card_data.ap) + " / DP " + str(card_data.dp)


func set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message


func _on_search_changed(new_text: String) -> void:
	search_text = new_text.to_lower().strip_edges()
	refresh_library()


func _on_race_filter_pressed(filter_value: String) -> void:
	active_race_filter = "" if filter_value == "all" else filter_value
	refresh_filter_buttons()
	refresh_library()


func _on_type_filter_pressed(filter_value: String) -> void:
	active_type_filter = "" if filter_value == "all" else filter_value
	refresh_filter_buttons()
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
		return get_card_sort_key(a["card"]) < get_card_sort_key(b["card"])
	)
	deck_cards.clear()
	deck_nodes.clear()
	for pair in pairs:
		deck_cards.append(pair["card"])
		deck_nodes.append(pair["node"])
	layout_deck_rack(false)
	set_status("Deck rack sorted smoothly by type, faction, and name.")


func _on_save_and_battle_pressed() -> void:
	save_deck_to_disk()
	if deck_cards.size() >= MIN_DECK_SIZE:
		get_tree().change_scene_to_file(BATTLE_SCENE_PATH)


func is_pointer_over_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	return hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE


func make_mat(albedo: Color, roughness: float = 0.75, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = roughness
	mat.metallic = metallic
	return mat


func make_panel_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.set_corner_radius_all(8)
	return style
