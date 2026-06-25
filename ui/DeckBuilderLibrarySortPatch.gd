extends Node

const SORT_NAME := 0
const SORT_TP := 1
const SORT_AP := 2
const SORT_DP := 3

const SORT_LABELS := {
	SORT_NAME: "Name",
	SORT_TP: "TP",
	SORT_AP: "AP",
	SORT_DP: "DP",
}

var sort_button: Button = null
var sort_dropdown_panel: PanelContainer = null
var current_sort_id := SORT_NAME
var library_sort_ascending := true
var has_applied_library_sort := false


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	attach_sort_button()


func attach_sort_button() -> void:
	var deck_builder := get_parent()
	if deck_builder == null:
		return

	var viewport := deck_builder.get_node_or_null("LibraryTabletopUIViewport") as SubViewport
	if viewport == null:
		return

	var ui_root := viewport.get_node_or_null("LibraryTabletopUIControlRoot") as Control
	if ui_root == null:
		return

	if ui_root.get_node_or_null("LibrarySortButton") != null:
		return

	sort_button = Button.new()
	sort_button.name = "LibrarySortButton"
	sort_button.text = get_sort_button_text()
	sort_button.custom_minimum_size = Vector2(96, 34)
	sort_button.size = Vector2(96, 34)
	sort_button.position = Vector2(990, 48)
	sort_button.z_index = 500
	sort_button.focus_mode = Control.FOCUS_NONE
	sort_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sort_button.pressed.connect(toggle_sort_dropdown)
	apply_button_style(sort_button)
	ui_root.add_child(sort_button)

	build_sort_dropdown(ui_root)


func build_sort_dropdown(ui_root: Control) -> void:
	sort_dropdown_panel = PanelContainer.new()
	sort_dropdown_panel.name = "LibrarySortDropdown"
	sort_dropdown_panel.visible = false
	sort_dropdown_panel.position = Vector2(826, 48)
	sort_dropdown_panel.size = Vector2(160, 34)
	sort_dropdown_panel.custom_minimum_size = Vector2(160, 34)
	sort_dropdown_panel.z_index = 510
	sort_dropdown_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	sort_dropdown_panel.add_theme_stylebox_override("panel", make_dropdown_style())
	ui_root.add_child(sort_dropdown_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	sort_dropdown_panel.add_child(margin)

	var option_row := HBoxContainer.new()
	option_row.add_theme_constant_override("separation", 4)
	margin.add_child(option_row)

	add_sort_option(option_row, "Name", SORT_NAME, 48)
	add_sort_option(option_row, "TP", SORT_TP, 30)
	add_sort_option(option_row, "AP", SORT_AP, 30)
	add_sort_option(option_row, "DP", SORT_DP, 30)


func add_sort_option(parent: Control, label_text: String, sort_id: int, width: int) -> void:
	var option_button := Button.new()
	option_button.text = label_text
	option_button.custom_minimum_size = Vector2(width, 24)
	option_button.focus_mode = Control.FOCUS_NONE
	option_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	option_button.pressed.connect(on_sort_option_selected.bind(sort_id))
	apply_button_style(option_button)
	parent.add_child(option_button)


func toggle_sort_dropdown() -> void:
	if sort_dropdown_panel == null:
		return
	sort_dropdown_panel.visible = not sort_dropdown_panel.visible


func on_sort_option_selected(sort_id: int) -> void:
	if has_applied_library_sort and sort_id == current_sort_id:
		library_sort_ascending = not library_sort_ascending
	else:
		current_sort_id = sort_id
		library_sort_ascending = true
	has_applied_library_sort = true
	apply_library_sort()
	if sort_button != null:
		sort_button.text = get_sort_button_text()
	if sort_dropdown_panel != null:
		sort_dropdown_panel.visible = false


func apply_library_sort() -> void:
	var deck_builder := get_parent()
	if deck_builder == null:
		return

	var cards: Array = deck_builder.get("all_cards")
	cards.sort_custom(compare_card_sort)
	deck_builder.set("all_cards", cards)
	deck_builder.set("library_scroll", 0.0)
	deck_builder.set("library_scroll_target", 0.0)

	if deck_builder.has_method("refresh_library"):
		deck_builder.call("refresh_library")
	if deck_builder.has_method("set_status"):
		var direction := "ascending"
		if not library_sort_ascending:
			direction = "descending"
		deck_builder.call("set_status", "Owned library sorted by " + get_sort_label(current_sort_id) + " (" + direction + ").")


func compare_card_sort(a, b) -> bool:
	var result := compare_cards(a, b)
	if library_sort_ascending:
		return result < 0
	return result > 0


func compare_cards(a, b) -> int:
	if current_sort_id == SORT_TP:
		var tp_result := compare_int(get_card_int(a, "tribute_cost"), get_card_int(b, "tribute_cost"))
		if tp_result != 0:
			return tp_result
	elif current_sort_id == SORT_AP:
		var ap_result := compare_int(get_card_int(a, "ap"), get_card_int(b, "ap"))
		if ap_result != 0:
			return ap_result
	elif current_sort_id == SORT_DP:
		var dp_result := compare_int(get_card_int(a, "dp"), get_card_int(b, "dp"))
		if dp_result != 0:
			return dp_result

	var name_result := compare_string(get_card_string(a, "card_name"), get_card_string(b, "card_name"))
	if name_result != 0:
		return name_result

	var type_result := compare_string(get_card_string(a, "card_type"), get_card_string(b, "card_type"))
	if type_result != 0:
		return type_result

	return compare_string(get_card_string(a, "race"), get_card_string(b, "race"))


func get_card_string(card, property_name: String) -> String:
	if card == null:
		return ""
	var value = card.get(property_name)
	if value == null:
		return ""
	return String(value).to_lower()


func get_card_int(card, property_name: String) -> int:
	if card == null:
		return 0
	var value = card.get(property_name)
	if value == null:
		return 0
	return int(value)


func compare_string(left: String, right: String) -> int:
	if left == right:
		return 0
	if left < right:
		return -1
	return 1


func compare_int(left: int, right: int) -> int:
	if left == right:
		return 0
	if left < right:
		return -1
	return 1


func get_sort_label(sort_id: int) -> String:
	return String(SORT_LABELS.get(sort_id, "Name"))


func get_sort_button_text() -> String:
	if library_sort_ascending:
		return "SORT ▲"
	return "SORT ▼"


func apply_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", make_button_style(Color(0.10, 0.065, 0.032, 0.94), Color(0.48, 0.34, 0.10, 0.85)))
	button.add_theme_stylebox_override("hover", make_button_style(Color(0.20, 0.12, 0.045, 0.96), Color(0.82, 0.58, 0.18, 1.0)))
	button.add_theme_stylebox_override("pressed", make_button_style(Color(0.52, 0.36, 0.09, 1.0), Color(0.95, 0.74, 0.24, 1.0)))
	button.add_theme_color_override("font_color", Color(0.92, 0.84, 0.62, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.72, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.97, 0.85, 1.0))
	button.add_theme_font_size_override("font_size", 13)


func make_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.01, 0.005, 0.002, 0.70)
	style.shadow_size = 3
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	return style


func make_dropdown_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.026, 0.010, 0.98)
	style.border_color = Color(0.72, 0.49, 0.13, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.01, 0.005, 0.002, 0.82)
	style.shadow_size = 5
	return style
