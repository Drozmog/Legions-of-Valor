class_name BattlePlanPanel
extends PanelContainer

var title_label: Label = null
var name_label: Label = null
var description_label: Label = null


func _ready() -> void:
	setup_position()
	setup_visuals()
	build_ui()
	clear_battle_plan()


func setup_position() -> void:
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.0
	anchor_bottom = 0.0

	offset_left = 20.0
	offset_right = 285.0
	offset_top = 185.0
	offset_bottom = 300.0


func setup_visuals() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.015, 0.005, 0.74)
	panel_style.border_color = Color(1.0, 0.78, 0.22, 1.0)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2

	add_theme_stylebox_override("panel", panel_style)


func build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	title_label = Label.new()
	title_label.text = "BATTLE PLAN"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title_label)

	name_label = Label.new()
	name_label.text = ""
	name_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(name_label)

	description_label = Label.new()
	description_label.text = ""
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(description_label)


func set_battle_plan(plan: Dictionary) -> void:
	if name_label == null or description_label == null:
		return

	name_label.text = str(plan.get("name", "Unknown Battle Plan"))

	description_label.text = (
		"Initiative: " + str(plan.get("initiative_mark", "-")) + "\n" +
		"Draw: " + str(plan.get("draw_amount", "-")) + "\n" +
		"Max Hand: " + str(plan.get("max_hand_size", "-")) + "\n" +
		"Aurion Reward: +" + str(plan.get("aurion_reward", "-")) + "\n\n" +
		str(plan.get("objective", ""))
	)


func clear_battle_plan() -> void:
	if name_label != null:
		name_label.text = "None selected"

	if description_label != null:
		description_label.text = "Choose a battle plan before the round begins."
