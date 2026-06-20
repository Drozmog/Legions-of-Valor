class_name BattlefieldBottomHud3D
extends Node3D

signal phase_action_pressed

const GOLD := Color(0.94, 0.68, 0.19, 1.0)
const PALE_GOLD := Color(1.0, 0.91, 0.66, 1.0)
const PANEL_BG := Color(0.055, 0.023, 0.010, 0.94)

var camera_3d: Camera3D
var surfaces: Array[Dictionary] = []
var active_viewport: SubViewport

var main_surface: MeshInstance3D
var log_surface: MeshInstance3D
var plan_surface: MeshInstance3D
var log_viewport: SubViewport
var plan_viewport: SubViewport

var phase_label: Label
var turn_label: Label
var score_label: Label
var instruction_label: Label
var phase_button: Button
var log_text: RichTextLabel
var player_plan_box: PanelContainer
var opponent_plan_box: PanelContainer

var log_open := false
var plans_open := false
var last_info_signature := ""
var last_plan_signature := ""


func _ready() -> void:
	camera_3d = get_viewport().get_camera_3d()
	build_main_bar()
	build_log_foldout()
	build_plan_foldout()
	set_process_input(true)


func build_main_bar() -> void:
	var entry := create_surface("BattleHud", Vector2i(1800, 110), Vector3(0.0, 0.075, 3.87), Vector2(9.0, 0.42), true)
	main_surface = entry["surface"]
	var root: Control = entry["control"]

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 5.0
	panel.offset_top = 5.0
	panel.offset_right = -5.0
	panel.offset_bottom = -5.0
	panel.add_theme_stylebox_override("panel", panel_style())
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	var log_button := make_button("▲ LOG", Vector2(82, 42))
	log_button.pressed.connect(toggle_log)
	row.add_child(log_button)

	var portrait := Label.new()
	portrait.text = "P"
	portrait.custom_minimum_size = Vector2(46, 46)
	portrait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait.add_theme_font_size_override("font_size", 23)
	portrait.add_theme_color_override("font_color", PALE_GOLD)
	portrait.add_theme_stylebox_override("normal", portrait_style())
	row.add_child(portrait)

	var identity := VBoxContainer.new()
	identity.custom_minimum_size = Vector2(142, 0)
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(identity)
	var player_name := Label.new()
	player_name.text = "PLAYER"
	player_name.add_theme_font_size_override("font_size", 16)
	player_name.add_theme_color_override("font_color", PALE_GOLD)
	identity.add_child(player_name)
	var role := Label.new()
	role.text = "LEGIONS COMMANDER"
	role.add_theme_font_size_override("font_size", 11)
	role.add_theme_color_override("font_color", Color(0.72, 0.57, 0.34, 1.0))
	identity.add_child(role)

	var plans_button := make_button("BATTLEPLANS", Vector2(150, 42))
	plans_button.pressed.connect(toggle_plans)
	row.add_child(plans_button)

	var divider := VSeparator.new()
	row.add_child(divider)

	var phase_info := VBoxContainer.new()
	phase_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_info.alignment = BoxContainer.ALIGNMENT_CENTER
	phase_info.add_theme_constant_override("separation", 0)
	row.add_child(phase_info)
	var heading := HBoxContainer.new()
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 16)
	phase_info.add_child(heading)
	phase_label = Label.new()
	phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 18)
	phase_label.add_theme_color_override("font_color", PALE_GOLD)
	heading.add_child(phase_label)
	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 14)
	turn_label.add_theme_color_override("font_color", GOLD)
	turn_label.visible = false
	heading.add_child(turn_label)
	score_label = Label.new()
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 14)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	phase_info.add_child(score_label)
	instruction_label = Label.new()
	instruction_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_size_override("font_size", 13)
	instruction_label.add_theme_color_override("font_color", Color(0.84, 0.75, 0.61, 1.0))
	phase_info.add_child(instruction_label)

	phase_button = make_button("CONTINUE", Vector2(170, 46), true)
	phase_button.pressed.connect(func(): phase_action_pressed.emit())
	row.add_child(phase_button)


func build_log_foldout() -> void:
	var entry := create_surface("BattleLog", Vector2i(900, 430), Vector3(-2.35, 0.115, 2.18), Vector2(4.45, 2.05), false)
	log_surface = entry["surface"]
	log_viewport = entry["viewport"]
	var root: Control = entry["control"]
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", panel_style())
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	log_text = RichTextLabel.new()
	log_text.bbcode_enabled = false
	log_text.scroll_active = true
	log_text.scroll_following = true
	log_text.fit_content = false
	log_text.add_theme_font_size_override("normal_font_size", 17)
	log_text.add_theme_color_override("default_color", Color(0.92, 0.84, 0.68, 1.0))
	margin.add_child(log_text)
	log_surface.visible = false


func build_plan_foldout() -> void:
	var entry := create_surface("BattlePlans", Vector2i(1240, 560), Vector3(0.0, 0.118, 1.75), Vector2(6.25, 2.75), false)
	plan_surface = entry["surface"]
	plan_viewport = entry["viewport"]
	var root: Control = entry["control"]
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", panel_style())
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)
	player_plan_box = make_plan_card("YOUR BATTLEPLAN")
	opponent_plan_box = make_plan_card("OPPONENT BATTLEPLAN")
	row.add_child(player_plan_box)
	row.add_child(opponent_plan_box)
	plan_surface.visible = false


func create_surface(surface_name: String, viewport_size: Vector2i, world_position: Vector3, world_size: Vector2, interactive: bool) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = surface_name + "Viewport"
	viewport.size = viewport_size
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_embed_subwindows = true
	add_child(viewport)
	var control := Control.new()
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	viewport.add_child(control)
	var surface := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = world_size
	surface.mesh = quad
	surface.position = world_position
	surface.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_texture = viewport.get_texture()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.no_depth_test = true
	material.render_priority = 127
	surface.material_override = material
	add_child(surface)
	var entry := {"viewport": viewport, "control": control, "surface": surface, "viewport_size": viewport_size, "world_size": world_size, "interactive": interactive}
	surfaces.append(entry)
	return entry


func update_info(phase_text: String, turn_text: String, score_text: String, instruction: String, action_text: String, disabled: bool, ready: bool) -> void:
	var signature := "%s|%s|%s|%s|%s|%s|%s" % [phase_text, turn_text, score_text, instruction, action_text, disabled, ready]
	if signature == last_info_signature:
		return
	last_info_signature = signature
	phase_label.text = phase_text + "   •   " + turn_text
	turn_label.text = turn_text
	score_label.text = score_text
	instruction_label.text = instruction.replace("\n", "  •  ")
	phase_button.text = action_text
	phase_button.disabled = disabled
	var style_name := "normal"
	phase_button.add_theme_stylebox_override(style_name, button_style(Color(0.48, 0.29, 0.045, 0.98), Color(1.0, 0.82, 0.24, 1.0), 3, 12) if ready else button_style(Color(0.13, 0.07, 0.025, 0.96), Color(0.54, 0.38, 0.12, 0.9), 2, 0))


func set_log_output(value: String) -> void:
	if log_text != null and log_text.text != value:
		log_text.text = value


func set_battleplans(player_plan: Dictionary, enemy_plan: Dictionary) -> void:
	var signature := str(player_plan) + "|" + str(enemy_plan)
	if signature == last_plan_signature:
		return
	last_plan_signature = signature
	fill_plan_card(player_plan_box, player_plan, "YOUR BATTLEPLAN")
	fill_plan_card(opponent_plan_box, enemy_plan, "OPPONENT BATTLEPLAN")


func toggle_log() -> void:
	log_open = not log_open
	log_surface.visible = log_open
	if log_open:
		plans_open = false
		plan_surface.visible = false


func toggle_plans() -> void:
	plans_open = not plans_open
	plan_surface.visible = plans_open
	if plans_open:
		log_open = false
		log_surface.visible = false


func make_plan_card(caption: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", button_style(Color(0.085, 0.035, 0.015, 0.97), GOLD, 3, 8))
	var box := VBoxContainer.new()
	box.name = "Content"
	box.add_theme_constant_override("separation", 9)
	card.add_child(box)
	var title := Label.new()
	title.name = "Title"
	title.text = caption
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", PALE_GOLD)
	box.add_child(title)
	for child_name in ["Name", "Stats", "Objective"]:
		var label := Label.new()
		label.name = child_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 20 if child_name == "Name" else 16)
		label.add_theme_color_override("font_color", Color.WHITE if child_name != "Objective" else Color(0.86, 0.78, 0.64, 1.0))
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL if child_name == "Objective" else Control.SIZE_SHRINK_CENTER
		box.add_child(label)
	return card


func fill_plan_card(card: PanelContainer, plan: Dictionary, caption: String) -> void:
	if card == null:
		return
	(card.get_node("Content/Title") as Label).text = caption
	(card.get_node("Content/Name") as Label).text = str(plan.get("name", "Not selected"))
	(card.get_node("Content/Stats") as Label).text = "INIT %s   •   DRAW %s   •   HAND %s   •   REWARD +%s" % [plan.get("initiative_mark", "-"), plan.get("draw_amount", "-"), plan.get("max_hand_size", "-"), plan.get("aurion_reward", "-")]
	(card.get_node("Content/Objective") as Label).text = str(plan.get("objective", "Choose a battleplan to reveal its objective."))


func _input(event: InputEvent) -> void:
	if not event is InputEventMouse or camera_3d == null:
		return
	var mouse_event := event as InputEventMouse
	for entry in surfaces:
		if not bool(entry["interactive"]):
			continue
		var surface: MeshInstance3D = entry["surface"]
		var origin := camera_3d.project_ray_origin(mouse_event.position)
		var direction := camera_3d.project_ray_normal(mouse_event.position)
		if absf(direction.y) < 0.0001:
			continue
		var distance := (surface.global_position.y - origin.y) / direction.y
		if distance < 0.0:
			continue
		var local := surface.to_local(origin + direction * distance)
		var world_size: Vector2 = entry["world_size"]
		if absf(local.x) > world_size.x * 0.5 or absf(local.y) > world_size.y * 0.5:
			continue
		var size: Vector2i = entry["viewport_size"]
		var mapped := Vector2((local.x / world_size.x + 0.5) * size.x, (0.5 - local.y / world_size.y) * size.y)
		var forwarded := event.duplicate() as InputEventMouse
		forwarded.position = mapped
		forwarded.global_position = mapped
		(entry["viewport"] as SubViewport).push_input(forwarded, true)
		get_viewport().set_input_as_handled()
		return


func make_button(text_value: String, minimum: Vector2, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = minimum
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var bg := Color(0.30, 0.17, 0.045, 0.98) if primary else Color(0.13, 0.07, 0.025, 0.96)
	button.add_theme_stylebox_override("normal", button_style(bg, Color(0.64, 0.44, 0.12, 1.0), 2, 0))
	button.add_theme_stylebox_override("hover", button_style(bg.lightened(0.12), GOLD, 2, 5))
	button.add_theme_stylebox_override("pressed", button_style(Color(0.42, 0.26, 0.06, 1.0), PALE_GOLD, 2, 0))
	button.add_theme_stylebox_override("disabled", button_style(Color(0.055, 0.03, 0.015, 0.78), Color(0.28, 0.20, 0.08, 0.55), 1, 0))
	button.add_theme_color_override("font_color", PALE_GOLD)
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.36, 0.28, 0.75))
	button.add_theme_font_size_override("font_size", 14)
	return button


func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(11)
	# A flat tabletop plaque avoids the square shadow corner produced by
	# StyleBoxFlat shadows around rounded panels.
	style.shadow_size = 0
	return style


func portrait_style() -> StyleBoxFlat:
	var style := button_style(Color(0.20, 0.095, 0.025, 1.0), GOLD, 3, 4)
	style.set_corner_radius_all(23)
	return style


func button_style(bg: Color, border: Color, width: int, shadow: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	if shadow > 0:
		style.shadow_color = Color(1.0, 0.55, 0.06, 0.55)
		style.shadow_size = shadow
	return style
