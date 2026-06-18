extends CanvasLayer

@onready var panel: PanelContainer = $PanelContainer
@onready var margin: MarginContainer = $PanelContainer/MarginContainer
@onready var log_text: RichTextLabel = $PanelContainer/MarginContainer/LogText

@export var max_lines: int = 240
@export var log_font_size: int = 12
@export var panel_width: float = 650.0
@export var panel_height: float = 250.0

var lines: Array[String] = []
var last_lane_header: String = ""


func _ready() -> void:
	setup_log_panel()
	clear_log()
	add_section("Battlefield Log")
	add_log("Battlefield log ready.")


func setup_log_panel() -> void:
	if panel != null:
		panel.anchor_left = 0.0
		panel.anchor_right = 0.0
		panel.anchor_top = 0.0
		panel.anchor_bottom = 0.0

		panel.offset_left = 20.0
		panel.offset_right = 20.0 + panel_width
		panel.offset_top = 20.0
		panel.offset_bottom = 20.0 + panel_height
		panel.custom_minimum_size = Vector2(panel_width, panel_height)

	if margin != null:
		margin.custom_minimum_size = Vector2(panel_width - 20.0, panel_height - 20.0)
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)

	if log_text != null:
		log_text.custom_minimum_size = Vector2(panel_width - 36.0, panel_height - 32.0)
		log_text.add_theme_font_size_override("normal_font_size", log_font_size)
		log_text.scroll_active = true
		log_text.scroll_following = true
		log_text.fit_content = false
		log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		log_text.clip_contents = true
		log_text.mouse_filter = Control.MOUSE_FILTER_STOP


func add_log(message: String) -> void:
	var formatted_lines: Array[String] = format_battle_report_message(message)

	for line in formatted_lines:
		_push_line(line)

	_refresh_output()
	print(message)



func add_report_lines(report_lines: Array[String]) -> void:
	for report_line in report_lines:
		_push_line(str(report_line))

	_refresh_output()

	for report_line in report_lines:
		print(report_line)


func add_blank_line() -> void:
	if lines.is_empty():
		return

	if lines[lines.size() - 1] == "":
		return

	_push_line("")
	_refresh_output()


func add_section(title: String) -> void:
	var clean_title: String = title.strip_edges()

	if clean_title == "":
		return

	var section_lines: Array[String] = []
	section_lines.append("")
	section_lines.append("==============================")
	section_lines.append(clean_title.to_upper())
	section_lines.append("==============================")

	for line in section_lines:
		_push_line(line)

	_refresh_output()
	print(clean_title.to_upper())


func add_lane_header(lane: String) -> void:
	var clean_lane: String = lane.strip_edges()

	if clean_lane == "":
		return

	last_lane_header = clean_lane.to_lower()
	var header_lines: Array[String] = []
	_append_lane_header(header_lines, clean_lane)

	for line in header_lines:
		_push_line(line)

	_refresh_output()


func add_event(title: String, details: Array = []) -> void:
	var event_lines: Array[String] = _make_event(title, details)

	for line in event_lines:
		_push_line(line)

	_refresh_output()
	print(title)


func add_combat_report(title: String, report_lines: Array = []) -> void:
	add_event(title, report_lines)


func clear_log() -> void:
	lines.clear()
	last_lane_header = ""

	if log_text != null:
		log_text.text = ""


func format_battle_report_message(message: String) -> Array[String]:
	var clean_message: String = message.strip_edges()
	var output: Array[String] = []

	if clean_message == "":
		return output

	var lane: String = _extract_lane(clean_message)

	if lane != "" and lane != last_lane_header:
		_append_lane_header(output, lane)
		last_lane_header = lane

	var lower: String = clean_message.to_lower()

	if lower.begins_with("phase:"):
		output.append("")
		output.append("*** " + clean_message.to_upper() + " ***")
		return output

	if lower.contains("combat direction selected"):
		output.append_array(_make_event("Combat Direction", [clean_message]))
		return output

	if lower.begins_with("next lane:"):
		output.append_array(_make_event("Next Lane", [_remove_lane_prefix(clean_message)]))
		return output

	if lower.contains("resolving player attack"):
		output.append_array(_make_event("Player Attack", [_remove_lane_prefix(clean_message)]))
		return output

	if lower.contains("checks your hidden") or lower.contains("checking hidden"):
		output.append_array(_make_event("Check", [_remove_lane_prefix(clean_message)]))
		return output

	if lower.contains("check successful") or lower.contains("successful check"):
		output.append_array(_make_event("Check Succeeds", [_remove_lane_prefix(clean_message)]))
		return output

	if lower.contains("check failed") or lower.contains("failed check"):
		output.append_array(_make_event("Check Fails", [_remove_lane_prefix(clean_message)]))
		return output

	if lower.contains("attack read correctly") or lower.contains("successful attack read"):
		output.append_array(_make_event("Attack Read Correct", [_remove_lane_prefix(clean_message)]))
		return output

	if lower.contains("attack failed"):
		output.append_array(_make_event("Attack Fails", [_remove_lane_prefix(clean_message)]))
		return output

	if lower.contains("hidden back") or lower.contains("back row") or lower.contains("back-row"):
		output.append_array(_make_event("Hidden Back Row", [_remove_lane_prefix(clean_message)]))
		return output

	if lower.contains("monarch strike"):
		output.append_array(_make_event("Monarch Strike", [_remove_lane_prefix(clean_message)]))
		return output

	if lower.contains("gains +") and lower.contains("aurion"):
		output.append_array(_make_event("Aurion Gained", [clean_message]))
		return output

	if lower.contains("passes priority") or lower.contains("passes in") or lower.contains("both players passed") or lower.contains("priority passes"):
		output.append_array(_make_event("Pass / Priority", [_remove_lane_prefix(clean_message)]))
		return output

	if lower.contains("has priority") or lower.contains("initiative returns") or lower.contains("ai considers action"):
		output.append_array(_make_event("Priority", [_remove_lane_prefix(clean_message)]))
		return output

	if lower.contains("parry"):
		output.append_array(_make_event("Parry", [_remove_lane_prefix(clean_message)]))
		return output

	if lower.contains("no front-row units") or lower.contains("skipping") or lower.contains("all combat lanes resolved"):
		output.append_array(_make_event("Lane State", [_remove_lane_prefix(clean_message)]))
		return output

	if lower.contains("discarded") or lower.contains("decoy") or lower.contains("destroyed") or lower.contains("returns to"):
		output.append_array(_make_event("Result", [_remove_lane_prefix(clean_message)]))
		return output

	output.append("• " + clean_message)
	return output


func _append_lane_header(output: Array[String], lane: String) -> void:
	var clean_lane: String = lane.strip_edges()

	if clean_lane == "":
		return

	output.append("")
	output.append("------------------------------")
	output.append(clean_lane.to_upper() + " LANE")
	output.append("------------------------------")


func _make_event(title: String, details: Array = []) -> Array[String]:
	var output: Array[String] = []
	var clean_title: String = title.strip_edges()

	if clean_title == "":
		return output

	output.append("")
	output.append("> " + clean_title)

	for detail in details:
		var detail_text: String = str(detail).strip_edges()

		if detail_text == "":
			continue

		output.append("  - " + detail_text)

	return output


func _extract_lane(message: String) -> String:
	var lower: String = message.to_lower()

	if lower.contains("left lane") or lower.begins_with("next lane: left"):
		return "left"

	if lower.contains("middle lane") or lower.begins_with("next lane: middle") or lower.contains("center lane"):
		return "middle"

	if lower.contains("right lane") or lower.begins_with("next lane: right"):
		return "right"

	return ""


func _remove_lane_prefix(message: String) -> String:
	var clean_message: String = message.strip_edges()
	var lower: String = clean_message.to_lower()

	if lower.begins_with("left lane: "):
		return clean_message.substr(11).strip_edges()

	if lower.begins_with("middle lane: "):
		return clean_message.substr(13).strip_edges()

	if lower.begins_with("center lane: "):
		return clean_message.substr(13).strip_edges()

	if lower.begins_with("right lane: "):
		return clean_message.substr(12).strip_edges()

	return clean_message


func _push_line(line: String) -> void:
	lines.append(line)

	while lines.size() > max_lines:
		lines.pop_front()


func _refresh_output() -> void:
	var output := ""

	for line in lines:
		output += line + "\n"

	if log_text != null:
		log_text.text = output
