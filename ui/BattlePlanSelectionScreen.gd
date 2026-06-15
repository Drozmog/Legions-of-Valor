class_name BattlePlanSelectionScreen
extends Control

signal battle_plan_selected(plan: Dictionary)

var options_container: HBoxContainer = null


func _ready() -> void:
	setup_screen()
	build_base_ui()
	hide_selection()


func setup_screen() -> void:
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100


func build_base_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1080, 580)
	center.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.025, 0.018, 0.94)
	style.border_color = Color(0.9, 0.72, 0.32, 1.0)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "CHOOSE YOUR BATTLE PLAN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Three battle plans are drawn at random. Select one before the round begins."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	vbox.add_child(subtitle)

	options_container = HBoxContainer.new()
	options_container.alignment = BoxContainer.ALIGNMENT_CENTER
	options_container.add_theme_constant_override("separation", 18)
	vbox.add_child(options_container)


func show_selection(plans: Array[Dictionary]) -> void:
	if options_container == null:
		return

	for child in options_container.get_children():
		child.queue_free()

	for plan in plans:
		options_container.add_child(create_plan_card(plan))

	visible = true


func hide_selection() -> void:
	visible = false


func create_plan_card(plan: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 390)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.065, 0.04, 1.0)
	style.border_color = Color(0.65, 0.48, 0.2, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var name := Label.new()
	name.text = str(plan.get("name", "Battle Plan"))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.add_theme_font_size_override("font_size", 21)
	vbox.add_child(name)

	var stats := Label.new()
	stats.text = "Initiative: " + str(plan.get("initiative_mark", 0)) + "   Draw: " + str(plan.get("draw_amount", 0)) + "   Max Hand: " + str(plan.get("max_hand_size", 0)) + "\nAurion Reward: +" + str(plan.get("aurion_reward", 0))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.add_theme_font_size_override("font_size", 14)
	vbox.add_child(stats)

	var desc := Label.new()
	desc.text = get_plan_description(plan)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(0, 190)
	desc.add_theme_font_size_override("font_size", 14)
	vbox.add_child(desc)

	var button := Button.new()
	button.text = "Select"
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(_on_select_pressed.bind(plan))
	vbox.add_child(button)

	return panel


func get_plan_description(plan: Dictionary) -> String:
	var description: String = str(plan.get("description", ""))
	if description.strip_edges() != "":
		return description

	return str(plan.get("objective", "No objective text found for this battle plan."))


func _on_select_pressed(plan: Dictionary) -> void:
	battle_plan_selected.emit(plan)
	hide_selection()
