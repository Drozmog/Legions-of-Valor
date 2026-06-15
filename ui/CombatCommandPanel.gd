class_name CombatCommandPanel
extends PanelContainer

signal combat_command_selected(command: String, lane: String)

var current_lane: String = ""
var title_label: Label = null
var detail_label: Label = null


func _ready() -> void:
	setup_position()
	setup_visuals()
	build_ui()
	hide()


func setup_position() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -240.0
	offset_right = 240.0
	offset_top = -120.0
	offset_bottom = 120.0
	z_index = 205


func setup_visuals() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.84)
	style.border_color = Color(0.9, 0.75, 0.35, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	add_theme_stylebox_override("panel", style)


func build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	title_label = Label.new()
	title_label.text = "COMBAT COMMAND"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title_label)

	detail_label = Label.new()
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(detail_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(buttons)

	var pass_button := Button.new()
	pass_button.text = "Pass"
	pass_button.pressed.connect(_on_command_pressed.bind("pass"))
	buttons.add_child(pass_button)

	var commit_button := Button.new()
	commit_button.text = "Commit Strike"
	commit_button.pressed.connect(_on_command_pressed.bind("commit"))
	buttons.add_child(commit_button)

	var cautious_button := Button.new()
	cautious_button.text = "Cautious Strike"
	cautious_button.pressed.connect(_on_command_pressed.bind("cautious"))
	buttons.add_child(cautious_button)


func show_for_lane(lane: String, active_side: String) -> void:
	current_lane = lane

	if detail_label != null:
		detail_label.text = active_side + " acts in the " + lane.capitalize() + " lane."

	show()


func _on_command_pressed(command: String) -> void:
	combat_command_selected.emit(command, current_lane)
	hide()
