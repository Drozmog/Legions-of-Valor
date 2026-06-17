extends CanvasLayer

@onready var panel: PanelContainer = $PanelContainer
@onready var margin: MarginContainer = $PanelContainer/MarginContainer
@onready var log_text: RichTextLabel = $PanelContainer/MarginContainer/LogText

@export var max_lines: int = 6
@export var log_font_size: int = 11

var lines: Array[String] = []


func _ready() -> void:
	setup_log_panel()
	clear_log()
	add_log("Battlefield log ready.")


func setup_log_panel() -> void:
	if panel != null:
		panel.anchor_left = 0.0
		panel.anchor_right = 0.0
		panel.anchor_top = 0.0
		panel.anchor_bottom = 0.0

		# Gray box size.
		panel.offset_left = 20.0
		panel.offset_right = 285.0
		panel.offset_top = 22.0
		panel.offset_bottom = 155.0

		# Explicit size keeps the panel predictable.
		panel.custom_minimum_size = Vector2(265.0, 133.0)

	if margin != null:
		margin.custom_minimum_size = Vector2(245.0, 115.0)
		margin.add_theme_constant_override("margin_left", 7)
		margin.add_theme_constant_override("margin_right", 7)
		margin.add_theme_constant_override("margin_top", 5)
		margin.add_theme_constant_override("margin_bottom", 5)

	if log_text != null:
		# This must NOT be Vector2.ZERO, or the text can disappear.
		log_text.custom_minimum_size = Vector2(235.0, 105.0)

		log_text.add_theme_font_size_override("normal_font_size", log_font_size)
		log_text.scroll_active = false
		log_text.fit_content = false
		log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		log_text.clip_contents = true


func add_log(message: String) -> void:
	lines.append(message)

	if lines.size() > max_lines:
		lines.pop_front()

	var output := ""

	for line in lines:
		output += line + "\n"

	if log_text != null:
		log_text.text = output

	print(message)


func clear_log() -> void:
	lines.clear()

	if log_text != null:
		log_text.text = ""
