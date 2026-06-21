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

var ui_root: Control = null
var sort_button: Button = null
var sort_dropdown_panel: PanelContainer = null
var current_sort_id := SORT_NAME
var library_sort_ascending := true
var has_applied_library_sort := false
var attached := false


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	if attached:
		return
	_attach_sort_dropdown()


func _attach_sort_dropdown() -> void:
	var deck_builder := get_parent()
	if deck_builder == null:
		return

	var viewport := deck_builder.get_node_or_null("LibraryTabletopUIViewport") as SubViewport
	if viewport == null:
		return

	ui_root = viewport.get_node_or_null("LibraryTabletopUIControlRoot") as Control
	if ui_root == null:
		return

	if ui_root.get_node_or_null("LibrarySortButton") != null:
		attached = true
		return

	attached = true

	sort_button = Button.new()
	sort_button.name = "LibrarySortButton"
	sort_button.text = _sort_button_text()
	sort_button.custom_minimum_size = Vector2(86, 32)
	sort_button.size = Vector2(86, 32)
	sort_button.position = Vector2(998, 16)
	sort_button.z_index = 240
	sort_button.focus_mode = Control.FOCUS_NONE
	sort_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sort_button.pressed.connect(_toggle_sort_dropdown)
	_apply_button_style(sort_button)
	ui_root.add_child(sort_button)

	_build_sort_dropdown_panel()


func _build_sort_dropdown_panel() -> void:
	if ui_root == null:
		return

	sort_dropdown_panel = PanelContainer.new()
	sort_dropdown_panel.name = "LibrarySortDropdown"
	sort_dropdown_panel.visible = false
	sort_dropdown_panel.position = Vector2(952, 50)
	sort_dropdown_panel.size = Vector2(132, 42)
	sort_dropdown_panel.custom_minimum_size = Vector2(132, 42)
	sort_dropdown_panel.z_index = 260
	sort_dropdown_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	sort_dropdown_panel.add_theme_stylebox_override(
		"panel",
		_make_dropdown_style(Color(0.055, 0.026, 0.010, 0.98), Color(0.72, 0.49, 0.13, 1.0))
	)
	ui_root.add_child(sort_dropdown_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	sort_dropdown_panel.add_child(margin)

	var option_row := HBoxContainer.new()
	option_row.add_theme_constant_override("separation", 4)
	margin.add_child(option_row)

	_add_sort_option_button(option_row, "Name", SORT_NAME)
	_add_sort_option_button(option_row, "TP", SORT_TP)
	_add_sort_option_button(option_row, "AP", SORT_AP)
	_add_sort_option_button(option_row, "DP", SORT_DP)


func _add_sort_option_button(parent: Control, label: String, sort_id: int) -> void:
	var option_button := Button.new()
	option_button.text = label
	option_button.custom_minimum_size = Vector2(28 if label != "Name" else 42, 24)
	option_button.focus_mode = Control.FOCUS_NONE
	option_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	option_button.pressed.connect(_on_sort_option_selected.bind(sort_id))
	_apply_button_style(option_button)
	parent.add_child(option_button)


func _toggle_sort_dropdown() -> void:
	if sort_dropdown_panel == null:
		return
	sort_dropdown_panel.visible = not sort_dropdown_panel.visible


func _on_sort_option_selected(sort_id: int) -> void:
	if has_applied_library_sort and sort_id == current_sort_id:
		library_sort_ascending = not library_sort_ascending
	else:
		current_sort_id = sort_id
		library_sort_ascending = true
	has_applied_library_sort = true
	_apply_library_sort()
	_update_sort_button_text()
	if sort_dropdown_panel != null:
		sort_dropdown_panel.visible = false


func _apply_library_sort() -> void:
	var deck_builder := get_parent()
	if deck_builder == null:
		return

	var cards: Array = deck_builder.get("all_cards")
	cards.sort_custom(func(a, b) -> bool:
		var comparison := _compare_cards(a, b)
		if library_sort_ascending:
			return comparison < 0
		return comparison > 0
	)
	deck_builder.set("all_cards", cards)
	deck_builder.set("library_scroll", 0.0)
	deck_builder.set("library_scroll_target", 0.0)

	if deck_builder.has_method("refresh_library"):
		deck_builder.call("refresh_library")
	if deck_builder.has_method("set_status"):
		var direction := "ascending" if library_sort_ascending else "descending"
		deck_builder.call(
			"set_status",
			"Owned library sorted by " + _sort_label(current_sort_id) + " (" + direction + ")."
		)


func _compare_cards(a, b) -> int:
	match current_sort_id:
		SORT_TP:
			var tp_compare := _compare_int(_card_int(a, "tribute_cost"), _card_int(b, "tribute_cost"))
			if tp_compare != 0:
				return tp_compare
		SORT_AP:
			var ap_compare := _compare_int(_card_int(a, "ap"), _card_int(b, "ap"))
			if ap_compare != 0:
				return ap_compare
		SORT_DP:
			var dp_compare := _compare_int(_card_int(a, "dp"), _card_int(b, "dp"))
			if dp_compare != 0:
				return dp_compare

	var name_compare := _compare_string(_card_string(a, "card_name"), _card_string(b, "card_name"))
	if name_compare != 0:
		return name_compare

	var type_compare := _compare_string(_card_string(a, "card_type"), _card_string(b, "card_type"))
	if type_compare != 0:
		return type_compare

	return _compare_string(_card_string(a, "race"), _card_string(b, "race"))


func _card_string(card, property_name: String) -> String:
	if card == null:
		return ""
	var value = card.get(property_name)
	if value == null:
		return ""
	return String(value).to_lower()


func _card_int(card, property_name: String) -> int:
	if card == null:
		return 0
	var value = card.get(property_name)
	if value == null:
		return 0
	return int(value)


func _compare_string(left: String, right: String) -> int:
	if left == right:
		return 0
	return -1 if left < right else 1


func _compare_int(left: int, right: int) -> int:
	if left == right:
		return 0
	return -1 if left < right else 1


func _sort_label(sort_id: int) -> String:
	return String(SORT_LABELS.get(sort_id, "Name"))


func _sort_button_text() -> String:
	return "SORT ▲" if library_sort_ascending else "SORT ▼"


func _update_sort_button_text() -> void:
	if sort_button != null:
		sort_button.text = _sort_button_text()


func _apply_button_style(button: Button) -> void:
	var bg_normal := Color(0.10, 0.065, 0.032, 0.94)
	var border_normal := Color(0.48, 0.34, 0.10, 0.85)
	button.add_theme_stylebox_override("normal", _make_button_style(bg_normal, border_normal))
	button.add_theme_stylebox_override("hover", _make_button_style(bg_normal.lightened(0.12), border_normal.lightened(0.20)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.52, 0.36, 0.09, 1.0), Color(0.95, 0.74, 0.24, 1.0)))
	button.add_theme_color_override("font_color", Color(0.92, 0.84, 0.62, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.72, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.97, 0.85, 1.0))
	button.add_theme_font_size_override("font_size", 13)


func _make_button_style(bg: Color, border: Color) -> StyleBoxFlat:
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


func _make_dropdown_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.01, 0.005, 0.002, 0.82)
	style.shadow_size = 5
	return style
