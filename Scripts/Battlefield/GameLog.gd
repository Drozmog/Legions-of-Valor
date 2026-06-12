extends CanvasLayer

@onready var log_text: RichTextLabel = $PanelContainer/MarginContainer/LogText

@export var max_lines: int = 8

var lines: Array[String] = []


func _ready() -> void:
	clear_log()
	add_log("Battlefield log ready.")


func add_log(message: String) -> void:
	lines.append(message)

	if lines.size() > max_lines:
		lines.pop_front()

	var output := ""

	for line in lines:
		output += line + "\n"

	log_text.text = output

	# Still print to Godot Output as backup.
	print(message)


func clear_log() -> void:
	lines.clear()
	log_text.text = ""
