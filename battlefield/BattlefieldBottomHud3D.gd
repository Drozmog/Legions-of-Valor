class_name BattlefieldBottomHud3D
extends Node3D

signal phase_action_pressed

const INSPECT_BUTTON_TEXTURE: Texture2D = preload("res://ui/combat_buttons/inspect_button.png")

const GOLD := Color(1.0, 1.0, 1.0, 0.92)
const PALE_GOLD := Color(1.0, 1.0, 1.0, 1.0)
const PANEL_BG := Color(0.025, 0.030, 0.040, 0.88)
const BATTLEPLAN_CARD_SIZE := Vector2(2.80, 1.70) # exact 3.5:2.5 landscape ratio
const BATTLEPLAN_CARD_CORNER_RADIUS_RATIO := 0.064
const BATTLEPLAN_CARD_CORNER_SEGMENTS := 8
const BATTLEPLAN_CARD_SURFACE_Z := 0.26
const BATTLEPLAN_LABEL_Z := 0.31
const BATTLEPLAN_SURFACE_RENDER_PRIORITY := 40
const BATTLEPLAN_CARD_RENDER_PRIORITY := 127
const BATTLEPLAN_INSPECT_BUTTON_SIZE := Vector2(0.5375, 0.25) # same 280x130-ish ratio, larger click target

var camera_3d: Camera3D
var surfaces: Array[Dictionary] = []
var active_viewport: SubViewport

var main_surface: MeshInstance3D
var right_surface: MeshInstance3D
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
var plan_card_root: Node3D
var player_plan_card_3d: MeshInstance3D
var opponent_plan_card_3d: MeshInstance3D
var player_plan_label_3d: Label3D
var opponent_plan_label_3d: Label3D
var player_plan_inspect_button_3d: Node3D
var opponent_plan_inspect_button_3d: Node3D
var battleplan_face_viewports: Array[SubViewport] = []

var log_open := false
var plans_open := false
var last_info_signature := ""
var last_plan_signature := ""
var card_drag_active := false
var modal_blocked := false
var log_open_position := Vector3.ZERO
var log_closed_position := Vector3.ZERO
var plan_open_position := Vector3.ZERO
var plan_closed_position := Vector3.ZERO
var log_slide_tween: Tween
var plan_slide_tween: Tween
var hud_cursor_active := false


func _ready() -> void:
	camera_3d = get_viewport().get_camera_3d()
	build_main_bar()
	build_log_foldout()
	build_plan_foldout()
	set_process_input(true)


func build_main_bar() -> void:
	# Equal left/right plaques. Their Y and Z match the previous single HUD exactly.
	# The viewport and mesh are both 10:1. Matching their aspect ratios keeps
	# the rendered controls from being stretched across the tabletop plaque.
	var left_entry := create_surface("BattleHudLeft", Vector2i(1600, 200), Vector3(-4, 0.075, 3.87), Vector2(3, 0.30), true)
	var right_entry := create_surface("BattleHudRight", Vector2i(1600, 200), Vector3(4, 0.075, 3.87), Vector2(3, 0.30), true)
	main_surface = left_entry["surface"]
	right_surface = right_entry["surface"]
	var left_row := make_main_panel_row(left_entry["control"] as Control, 0)
	var right_row := make_main_panel_row(right_entry["control"] as Control, 0)

	var log_button := make_button("▲ LOG", Vector2(0, 54))
	log_button.pressed.connect(toggle_log)
	add_hud_cell(left_row, log_button, 0.07)

	var portrait := TextureRect.new()
	portrait.texture = preload("res://ui/Profile Pictures/siegmere.png")
	portrait.custom_minimum_size = Vector2(140, 140)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_hud_cell(left_row, portrait, 0.05)

	var identity := VBoxContainer.new()
	identity.custom_minimum_size = Vector2(142, 20)
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	var player_name := Label.new()
	player_name.text = "DROZMOG"
	player_name.add_theme_font_size_override("font_size", 60)
	player_name.add_theme_color_override("font_color", PALE_GOLD)
	identity.add_child(player_name)
	var role := Label.new()
	role.text = "Grand Marshal"
	role.add_theme_font_size_override("font_size", 30)
	role.add_theme_color_override("font_color", Color.WHITE)
	identity.add_child(role)
	add_hud_cell(left_row, identity, 0.05)

	var plans_button := make_button("BATTLEPLANS", Vector2(0, 54))
	plans_button.pressed.connect(toggle_plans)
	add_hud_cell(left_row, plans_button, 0.10)

	var phase_info := VBoxContainer.new()
	phase_info.alignment = BoxContainer.ALIGNMENT_CENTER
	phase_info.add_theme_constant_override("separation", 0)
	score_label = Label.new()
	score_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 45)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	phase_info.add_child(score_label)
	instruction_label = Label.new()
	instruction_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_size_override("font_size", 30)
	instruction_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.78))
	instruction_label.visible = false
	phase_info.add_child(instruction_label)

	var phase_heading := HBoxContainer.new()
	phase_heading.custom_minimum_size = Vector2(205, 0)
	phase_heading.alignment = BoxContainer.ALIGNMENT_CENTER
	phase_heading.add_theme_constant_override("separation", 18)
	phase_label = Label.new()
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 50)
	phase_label.add_theme_color_override("font_color", PALE_GOLD)
	phase_heading.add_child(phase_label)
	turn_label = Label.new()
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 50)
	turn_label.add_theme_color_override("font_color", GOLD)
	phase_heading.add_child(turn_label)

	var status_stack := VBoxContainer.new()
	status_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	status_stack.add_theme_constant_override("separation", 0)
	status_stack.add_child(phase_heading)
	status_stack.add_child(phase_info)
	add_hud_cell(right_row, status_stack, 1)

	phase_button = make_button("CONTINUE", Vector2(0, 54), true)
	phase_button.pressed.connect(func(): phase_action_pressed.emit())
	add_hud_cell(right_row, phase_button, 0.70)


func make_main_panel_row(root: Control, separation: int) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 5.0
	panel.offset_top = 5.0
	panel.offset_right = -5.0
	panel.offset_bottom = -5.0
	panel.add_theme_stylebox_override("panel", panel_style())
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)
	return row


func add_hud_cell(row: HBoxContainer, content: Control, width_ratio: float) -> void:
	var cell := CenterContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.size_flags_stretch_ratio = width_ratio
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(cell)
	cell.add_child(content)


func build_log_foldout() -> void:
	log_open_position = Vector3(-3.22, 0.115, 2.6)
	log_closed_position = Vector3(-3.22, 0.115, 3.58)
	var entry := create_surface("BattleLog", Vector2i(900, 430), log_closed_position, Vector2(4.45, 2.05), true)
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
	log_text.mouse_filter = Control.MOUSE_FILTER_STOP
	log_text.add_theme_font_size_override("normal_font_size", 17)
	log_text.add_theme_color_override("default_color", Color(1.0, 1.0, 1.0, 0.88))
	margin.add_child(log_text)
	log_surface.scale = Vector3(1.0, 0.02, 1.0)
	log_surface.visible = false


func build_plan_foldout() -> void:
	plan_open_position = Vector3(0, 0.118, 2.42)
	plan_closed_position = Vector3(0, 0.118, 3.56)
	# Keep the dark panel close to the card width, while giving it more vertical
	# room at the bottom for the lower margins. Position constants below are the
	# main manual tuning points for this Battleplans popup.
	var entry := create_surface("BattlePlans", Vector2i(1410, 570), plan_closed_position, Vector2(7.05, 2.35), false)
	plan_surface = entry["surface"]
	plan_viewport = entry["viewport"]
	if plan_surface.material_override != null:
		plan_surface.material_override.render_priority = BATTLEPLAN_SURFACE_RENDER_PRIORITY
	var root: Control = entry["control"]
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", panel_style())
	root.add_child(panel)

	plan_card_root = Node3D.new()
	plan_card_root.name = "BattlePlan3DCards"
	plan_surface.add_child(plan_card_root)

	player_plan_card_3d = create_battleplan_card_mesh("PlayerBattleplanCard3D")
	player_plan_card_3d.position = Vector3(-1.74, -0.11, BATTLEPLAN_CARD_SURFACE_Z)
	plan_card_root.add_child(player_plan_card_3d)

	opponent_plan_card_3d = create_battleplan_card_mesh("OpponentBattleplanCard3D")
	opponent_plan_card_3d.position = Vector3(1.74, -0.11, BATTLEPLAN_CARD_SURFACE_Z)
	plan_card_root.add_child(opponent_plan_card_3d)

	player_plan_label_3d = create_battleplan_3d_label("YOUR BATTLEPLAN")
	player_plan_label_3d.position = Vector3(-2.24, 0.875, BATTLEPLAN_LABEL_Z)
	plan_card_root.add_child(player_plan_label_3d)

	opponent_plan_label_3d = create_battleplan_3d_label("OPPONENT BATTLEPLAN")
	opponent_plan_label_3d.position = Vector3(1.40, 0.875, BATTLEPLAN_LABEL_Z)
	plan_card_root.add_child(opponent_plan_label_3d)

	player_plan_inspect_button_3d = create_battleplan_inspect_button(true)
	player_plan_inspect_button_3d.position = Vector3(-0.63, 0.875, BATTLEPLAN_LABEL_Z + 0.035)
	player_plan_inspect_button_3d.rotation_degrees = Vector3(87, 0.0, 0.0)
	plan_card_root.add_child(player_plan_inspect_button_3d)

	opponent_plan_inspect_button_3d = create_battleplan_inspect_button(false)
	opponent_plan_inspect_button_3d.position = Vector3(2.8, 0.875, BATTLEPLAN_LABEL_Z + 0.035)
	opponent_plan_inspect_button_3d.rotation_degrees = Vector3(87, 0.0, 0.0)
	plan_card_root.add_child(opponent_plan_inspect_button_3d)

	plan_surface.scale = Vector3(0.88, 0.02, 0.88)
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
	var material := create_glass_surface_material(viewport.get_texture(), 127)
	surface.material_override = material
	add_child(surface)
	var entry := {"viewport": viewport, "control": control, "surface": surface, "viewport_size": viewport_size, "world_size": world_size, "interactive": interactive}
	surfaces.append(entry)
	return entry


func create_glass_surface_material(ui_texture: Texture2D, priority: int) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled;

uniform sampler2D ui_texture : source_color, repeat_disable, filter_linear_mipmap_anisotropic;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_lod = 3.8;

void fragment() {
	vec4 ui = texture(ui_texture, UV);
	vec3 blurred_world = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb;

	ALBEDO = mix(blurred_world, ui.rgb, clamp(ui.a * 0.95, 0.0, 1.0));
	ALPHA = ui.a;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("ui_texture", ui_texture)
	material.set_shader_parameter("blur_lod", 3.8)
	material.render_priority = priority
	return material


func update_info(phase_text: String, turn_text: String, score_text: String, instruction: String, action_text: String, disabled: bool, is_ready: bool) -> void:
	var signature := "%s|%s|%s|%s|%s|%s|%s" % [phase_text, turn_text, score_text, instruction, action_text, disabled, is_ready]
	if signature == last_info_signature:
		return
	last_info_signature = signature
	phase_label.text = phase_text
	turn_label.text = turn_text
	score_label.text = score_text
	instruction_label.text = instruction.replace("\n", "  •  ")
	phase_button.text = action_text
	phase_button.visible = not action_text.is_empty()
	phase_button.disabled = disabled or modal_blocked
	var style_name := "normal"
	phase_button.add_theme_stylebox_override(style_name, button_style(Color(0.16, 0.18, 0.22, 0.82), Color(1.0, 1.0, 1.0, 0.72), 2, 0) if is_ready else button_style(Color(0.07, 0.08, 0.10, 0.62), Color(1.0, 1.0, 1.0, 0.26), 1, 0))


func set_log_output(value: String) -> void:
	if log_text != null and log_text.text != value:
		log_text.text = value


func set_battleplans(player_plan: Dictionary, enemy_plan: Dictionary) -> void:
	var signature := str(player_plan) + "|" + str(enemy_plan)
	if signature == last_plan_signature:
		return
	last_plan_signature = signature
	cleanup_battleplan_face_viewports()
	apply_plan_to_3d_card(player_plan_card_3d, player_plan, "YOUR BATTLEPLAN")
	apply_plan_to_3d_card(opponent_plan_card_3d, enemy_plan, "OPPONENT BATTLEPLAN")


func toggle_log() -> void:
	if modal_blocked:
		return
	log_open = not log_open
	animate_foldout(log_surface, log_open, log_open_position, log_closed_position, true)
	if log_open:
		plans_open = false
		animate_foldout(plan_surface, false, plan_open_position, plan_closed_position, false)


func toggle_plans() -> void:
	if modal_blocked:
		return
	plans_open = not plans_open
	animate_foldout(plan_surface, plans_open, plan_open_position, plan_closed_position, false)
	if plans_open:
		log_open = false
		animate_foldout(log_surface, false, log_open_position, log_closed_position, true)


func animate_foldout(surface: MeshInstance3D, opening: bool, open_position: Vector3, closed_position: Vector3, is_log: bool) -> void:
	if surface == null:
		return
	var old_tween := log_slide_tween if is_log else plan_slide_tween
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	if opening:
		surface.visible = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if opening else Tween.EASE_IN)
	tween.tween_property(surface, "position", open_position if opening else closed_position, 0.28)
	tween.parallel().tween_property(surface, "scale", Vector3.ONE if opening else Vector3(1.0, 0.02, 1.0), 0.28)
	if not opening:
		tween.tween_callback(func(): surface.visible = false)
	if is_log:
		log_slide_tween = tween
	else:
		plan_slide_tween = tween


func set_card_drag_active(active: bool) -> void:
	card_drag_active = active


func set_modal_blocked(blocked: bool) -> void:
	modal_blocked = blocked
	last_info_signature = ""
	if phase_button != null:
		phase_button.disabled = blocked or phase_button.disabled
	for entry in surfaces:
		var viewport := entry.get("viewport") as SubViewport
		if viewport != null:
			viewport.gui_disable_input = blocked
	if blocked:
		if log_open:
			log_open = false
			animate_foldout(log_surface, false, log_open_position, log_closed_position, true)
		if plans_open:
			plans_open = false
			animate_foldout(plan_surface, false, plan_open_position, plan_closed_position, false)
		if hud_cursor_active:
			hud_cursor_active = false
			Cursors.use_normal()


func create_battleplan_card_mesh(card_name: String) -> MeshInstance3D:
	var card := MeshInstance3D.new()
	card.name = card_name
	card.mesh = create_rounded_battleplan_card_mesh(BATTLEPLAN_CARD_SIZE)
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.material_override = make_battleplan_card_material(create_battleplan_face_texture({}, "BATTLEPLAN"))
	return card


func create_battleplan_3d_label(label_text: String) -> Label3D:
	var label := Label3D.new()
	label.name = label_text.capitalize().replace(" ", "") + "Label3D"
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.font_size = 46
	label.pixel_size = 0.0038
	label.modulate = Color.WHITE
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.55)
	label.outline_size = 6
	label.no_depth_test = true
	label.render_priority = BATTLEPLAN_CARD_RENDER_PRIORITY
	return label


func create_battleplan_inspect_button(is_player_plan: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "PlayerBattleplanInspectButton" if is_player_plan else "OpponentBattleplanInspectButton"

	var surface := MeshInstance3D.new()
	surface.name = "InspectButtonSurface"
	var mesh := PlaneMesh.new()
	mesh.size = BATTLEPLAN_INSPECT_BUTTON_SIZE
	surface.mesh = mesh
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.material_override = make_inspect_button_material()
	root.add_child(surface)

	var area := Area3D.new()
	area.name = "ClickArea"
	area.collision_layer = 32
	area.collision_mask = 0
	area.input_ray_pickable = true
	root.add_child(area)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(BATTLEPLAN_INSPECT_BUTTON_SIZE.x * 1.15, BATTLEPLAN_INSPECT_BUTTON_SIZE.y * 1.25, 0.26)
	collision.shape = shape
	area.add_child(collision)
	area.input_event.connect(_on_battleplan_inspect_input_event.bind(is_player_plan))
	area.mouse_entered.connect(_on_battleplan_inspect_mouse_entered)
	area.mouse_exited.connect(_on_battleplan_inspect_mouse_exited)
	return root


func make_inspect_button_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = INSPECT_BUTTON_TEXTURE
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_repeat = false
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.no_depth_test = true
	material.render_priority = BATTLEPLAN_CARD_RENDER_PRIORITY
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_energy_multiplier = 0.95
	return material


func _on_battleplan_inspect_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_index: int,
	is_player_plan: bool
) -> void:
	if modal_blocked or card_drag_active or not plans_open:
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	inspect_battleplan(is_player_plan)
	get_viewport().set_input_as_handled()


func _on_battleplan_inspect_mouse_entered() -> void:
	hud_cursor_active = true
	Cursors.use_pointing()


func _on_battleplan_inspect_mouse_exited() -> void:
	hud_cursor_active = false
	Cursors.use_normal()


func inspect_battleplan(is_player_plan: bool) -> void:
	var card := player_plan_card_3d if is_player_plan else opponent_plan_card_3d
	if card == null or not is_instance_valid(card):
		return
	var inspector := find_card_inspect_panel()
	if inspector == null:
		return
	var texture := get_card_mesh_texture(card)
	if texture == null:
		return
	inspector.show_texture(texture, get_battleplan_card_source_rect(card), true)


func get_card_mesh_texture(card: MeshInstance3D) -> Texture2D:
	if card != null and card.material_override is StandardMaterial3D:
		return (card.material_override as StandardMaterial3D).albedo_texture
	return null


func get_battleplan_card_source_rect(card: MeshInstance3D) -> Rect2:
	if camera_3d == null or card == null:
		return Rect2()
	var center := camera_3d.unproject_position(card.global_position)
	var source_size := Vector2(430.0, 305.0)
	return Rect2(center - source_size * 0.5, source_size)


func find_card_inspect_panel() -> CardInspectPanel:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var direct := scene.get_node_or_null("UI/CardInspectPanel") as CardInspectPanel
	if direct != null:
		return direct
	return find_card_inspect_panel_recursive(scene)


func find_card_inspect_panel_recursive(node: Node) -> CardInspectPanel:
	if node is CardInspectPanel:
		return node as CardInspectPanel
	for child in node.get_children():
		var found := find_card_inspect_panel_recursive(child)
		if found != null:
			return found
	return null


func apply_plan_to_3d_card(card: MeshInstance3D, plan: Dictionary, caption: String) -> void:
	if card == null:
		return
	card.material_override = make_battleplan_card_material(create_battleplan_face_texture(plan, caption))


func create_battleplan_face_texture(plan: Dictionary, caption: String) -> Texture2D:
	var supplied_texture := get_supplied_plan_texture(plan)
	if supplied_texture != null:
		return supplied_texture

	var viewport := SubViewport.new()
	viewport.name = "BottomHudBattlePlanCardViewport"
	viewport.size = Vector2i(980, 700)
	viewport.transparent_bg = false
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	battleplan_face_viewports.append(viewport)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var battleplan_panel_style := StyleBoxFlat.new()
	battleplan_panel_style.bg_color = Color(0.055, 0.065, 0.085, 0.90)
	battleplan_panel_style.border_color = Color(1.0, 1.0, 1.0, 0.42)
	battleplan_panel_style.set_border_width_all(6)
	battleplan_panel_style.set_corner_radius_all(34)
	battleplan_panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	battleplan_panel_style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", battleplan_panel_style)
	viewport.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	margin.add_child(rows)

	var title_label := Label.new()
	title_label.text = caption
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 39)
	title_label.add_theme_color_override("font_color", PALE_GOLD)
	rows.add_child(title_label)

	var name_label := Label.new()
	name_label.text = str(plan.get("name", "Not selected"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 34)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	rows.add_child(name_label)

	var stat_label := Label.new()
	stat_label.text = "INIT %s  •  DRAW %s  •  HAND %s  •  REWARD +%s" % [plan.get("initiative_mark", "-"), plan.get("draw_amount", "-"), plan.get("max_hand_size", "-"), plan.get("aurion_reward", "-")]
	stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_label.add_theme_font_size_override("font_size", 24)
	stat_label.add_theme_color_override("font_color", PALE_GOLD)
	rows.add_child(stat_label)

	var objective := Label.new()
	objective.text = str(plan.get("objective", "Choose a battleplan to reveal its objective."))
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective.size_flags_vertical = Control.SIZE_EXPAND_FILL
	objective.add_theme_font_size_override("font_size", 27)
	objective.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.82))
	rows.add_child(objective)
	return viewport.get_texture()


func get_supplied_plan_texture(plan: Dictionary) -> Texture2D:
	for key in ["card_art", "battleplan_art", "texture", "art", "image", "card_texture", "texture_path"]:
		var value: Variant = plan.get(key, null)
		if value is Texture2D:
			return value as Texture2D
		if value is String and not String(value).is_empty() and ResourceLoader.exists(String(value)):
			return load(String(value)) as Texture2D
	return null


func cleanup_battleplan_face_viewports() -> void:
	for viewport in battleplan_face_viewports:
		if viewport != null and is_instance_valid(viewport):
			viewport.queue_free()
	battleplan_face_viewports.clear()


func make_battleplan_card_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.no_depth_test = true
	material.render_priority = BATTLEPLAN_CARD_RENDER_PRIORITY
	material.emission_enabled = true
	material.emission = Color(0.08, 0.09, 0.12, 1.0)
	material.emission_energy_multiplier = 0.35
	return material


func create_rounded_battleplan_card_mesh(card_size: Vector2) -> ArrayMesh:
	var half_size := card_size * 0.5
	var radius := minf(card_size.x, card_size.y) * BATTLEPLAN_CARD_CORNER_RADIUS_RATIO
	var outline: Array[Vector2] = []
	add_battleplan_card_corner(outline, Vector2(half_size.x - radius, half_size.y - radius), radius, 0.0, 90.0)
	add_battleplan_card_corner(outline, Vector2(-half_size.x + radius, half_size.y - radius), radius, 90.0, 180.0)
	add_battleplan_card_corner(outline, Vector2(-half_size.x + radius, -half_size.y + radius), radius, 180.0, 270.0)
	add_battleplan_card_corner(outline, Vector2(half_size.x - radius, -half_size.y + radius), radius, 270.0, 360.0)

	var vertices := PackedVector3Array([Vector3.ZERO])
	var normals := PackedVector3Array([Vector3.FORWARD])
	var uvs := PackedVector2Array([Vector2(0.5, 0.5)])
	var indices := PackedInt32Array()
	for point in outline:
		vertices.append(Vector3(point.x, point.y, 0.0))
		normals.append(Vector3.FORWARD)
		uvs.append(Vector2((point.x + half_size.x) / card_size.x, 1.0 - ((point.y + half_size.y) / card_size.y)))
	for index in range(1, outline.size() + 1):
		var next_index := index + 1 if index < outline.size() else 1
		indices.append(0)
		indices.append(index)
		indices.append(next_index)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func add_battleplan_card_corner(points: Array[Vector2], center: Vector2, radius: float, start_degrees: float, end_degrees: float) -> void:
	for segment in range(BATTLEPLAN_CARD_CORNER_SEGMENTS + 1):
		var weight := float(segment) / float(BATTLEPLAN_CARD_CORNER_SEGMENTS)
		var angle := deg_to_rad(lerpf(start_degrees, end_degrees, weight))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)


func _input(event: InputEvent) -> void:
	if modal_blocked or card_drag_active or not event is InputEventMouse or camera_3d == null:
		return
	var mouse_event := event as InputEventMouse
	for entry in surfaces:
		if not bool(entry["interactive"]):
			continue
		var surface: MeshInstance3D = entry["surface"]
		if surface == null or not surface.visible:
			continue
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
		var target_viewport := entry["viewport"] as SubViewport
		target_viewport.push_input(forwarded, true)
		if event is InputEventMouseMotion:
			var hovered := target_viewport.gui_get_hovered_control()
			var wants_pointing := (
				hovered != null
				and hovered.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND
			)
			if wants_pointing:
				hud_cursor_active = true
				Cursors.use_pointing()
			elif hud_cursor_active:
				hud_cursor_active = false
				Cursors.use_normal()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and hud_cursor_active:
		hud_cursor_active = false
		Cursors.use_normal()


func make_button(text_value: String, minimum: Vector2, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = minimum
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var bg := Color(0.14, 0.16, 0.20, 0.76) if primary else Color(0.07, 0.08, 0.10, 0.64)
	button.add_theme_stylebox_override("normal", button_style(bg, Color(1.0, 1.0, 1.0, 0.28), 1, 0))
	button.add_theme_stylebox_override("hover", button_style(Color(0.22, 0.24, 0.28, 0.86), Color.WHITE, 2, 7))
	button.add_theme_stylebox_override("pressed", button_style(Color(0.28, 0.30, 0.34, 0.92), Color.WHITE, 2, 2))
	button.add_theme_stylebox_override("disabled", button_style(Color(0.04, 0.05, 0.06, 0.48), Color(1.0, 1.0, 1.0, 0.12), 1, 0))
	button.add_theme_color_override("font_color", PALE_GOLD)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.34))
	button.add_theme_font_size_override("font_size", 50)
	return button


func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = GOLD
	style.border_color = Color(1.0, 1.0, 1.0, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	# A flat tabletop plaque avoids the square shadow corner produced by
	# StyleBoxFlat shadows around rounded panels.
	style.shadow_size = 0
	return style


func portrait_style() -> StyleBoxFlat:
	var style := button_style(Color(0.10, 0.11, 0.14, 0.82), Color(1.0, 1.0, 1.0, 0.45), 2, 3)
	style.set_corner_radius_all(23)
	return style


func button_style(bg: Color, border: Color, width: int, shadow: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(7)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	if shadow > 0:
		style.shadow_color = Color(1.0, 1.0, 1.0, 0.32)
		style.shadow_size = shadow
	return style
