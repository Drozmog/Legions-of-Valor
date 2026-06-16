class_name BattlePlanPanel
extends PanelContainer

var player_title_label: Label = null
var player_name_label: Label = null
var player_description_label: Label = null

var opponent_title_label: Label = null
var opponent_name_label: Label = null
var opponent_description_label: Label = null


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
	offset_right = 100.0
	offset_top = 355.0
	offset_bottom = 470.0


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
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	margin.add_child(columns)

	var player_column := VBoxContainer.new()
	player_column.custom_minimum_size = Vector2(220.0, 0.0)
	player_column.add_theme_constant_override("separation", 5)
	columns.add_child(player_column)

	var divider := VSeparator.new()
	columns.add_child(divider)

	var opponent_column := VBoxContainer.new()
	opponent_column.custom_minimum_size = Vector2(220.0, 0.0)
	opponent_column.add_theme_constant_override("separation", 5)
	columns.add_child(opponent_column)

	player_title_label = Label.new()
	player_title_label.text = "PLAYER BATTLE PLAN"
	player_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_title_label.add_theme_font_size_override("font_size", 12)
	player_column.add_child(player_title_label)

	player_name_label = Label.new()
	player_name_label.text = ""
	player_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_name_label.add_theme_font_size_override("font_size", 14)
	player_column.add_child(player_name_label)

	player_description_label = Label.new()
	player_description_label.text = ""
	player_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_description_label.add_theme_font_size_override("font_size", 10)
	player_column.add_child(player_description_label)

	opponent_title_label = Label.new()
	opponent_title_label.text = "OPPONENT BATTLE PLAN"
	opponent_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opponent_title_label.add_theme_font_size_override("font_size", 12)
	opponent_column.add_child(opponent_title_label)

	opponent_name_label = Label.new()
	opponent_name_label.text = ""
	opponent_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opponent_name_label.add_theme_font_size_override("font_size", 14)
	opponent_column.add_child(opponent_name_label)

	opponent_description_label = Label.new()
	opponent_description_label.text = ""
	opponent_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	opponent_description_label.add_theme_font_size_override("font_size", 10)
	opponent_column.add_child(opponent_description_label)


func set_battle_plan(plan: Dictionary) -> void:
	if player_name_label == null or player_description_label == null:
		return

	player_name_label.text = str(plan.get("name", "Unknown Battle Plan"))
	player_description_label.text = get_battle_plan_description(plan)


func set_opponent_battle_plan(plan: Dictionary) -> void:
	if opponent_name_label == null or opponent_description_label == null:
		return

	if plan.is_empty():
		opponent_name_label.text = "None selected"
		opponent_description_label.text = "Opponent has no battle plan."
		return

	opponent_name_label.text = str(plan.get("name", "Unknown Battle Plan"))
	opponent_description_label.text = get_battle_plan_description(plan)


func get_battle_plan_description(plan: Dictionary) -> String:
	return (
		"Initiative: " + str(plan.get("initiative_mark", "-")) + "\n" +
		"Draw: " + str(plan.get("draw_amount", "-")) + "\n" +
		"Max Hand: " + str(plan.get("max_hand_size", "-")) + "\n" +
		"Aurion Reward: +" + str(plan.get("aurion_reward", "-")) + "\n\n" +
		str(plan.get("objective", ""))
	)


func clear_battle_plan() -> void:
	if player_name_label != null:
		player_name_label.text = "None selected"

	if player_description_label != null:
		player_description_label.text = "Choose a battle plan before the round begins."

	clear_opponent_battle_plan()


func clear_opponent_battle_plan() -> void:
	if opponent_name_label != null:
		opponent_name_label.text = "None selected"

	if opponent_description_label != null:
		opponent_description_label.text = "Opponent battle plan will appear after selection."
