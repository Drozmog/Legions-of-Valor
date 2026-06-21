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

var sort_menu: MenuButton = null
var current_sort_id := SORT_NAME
var library_sort_ascending := true
var has_applied_library_sort := false
var attach_attempts := 0


func _ready() -> void:
	call_deferred("_attach_sort_dropdown")


func _attach_sort_dropdown() -> void:
	attach_attempts += 1
	var deck_builder := get_parent()
	if deck_builder == null:
		_retry_attach()
		return

	var viewport := deck_builder.get_node_or_null("LibraryTabletopUIViewport") as SubViewport
	if viewport == null:
		_retry_attach()
		return

	var root := viewport.get_node_or_null("LibraryTabletopUIControlRoot") as Control
	if root == null:
		_retry_attach()
		return

	var plaque := root.get_node_or_null("LibraryControlPlaque") as Control
	if plaque == null:
		_retry_attach()
		return

	var command_row := _find_first_hbox(plaque)
	if command_row == null:
		_retry_attach()
		return
	if command_row.get_node_or_null("LibrarySortMenuButton") != null:
		return

	sort_menu = MenuButton.new()
	sort_menu.name = "LibrarySortMenuButton"
	sort_menu.text = _sort_button_text()
	sort_menu.custom_minimum_size = Vector2(76, 32)
	sort_menu.focus_mode = Control.FOCUS_NONE
	sort_menu.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_button_style(sort_menu)

	var popup := sort_menu.get_popup()
	popup.clear()
	popup.add_radio_check_item("Name", SORT_NAME)
	popup.add_radio_check_item("TP", SORT_TP)
	popup.add_radio_check_item("AP", SORT_AP)
	popup.add_radio_check_item("DP", SORT_DP)
	popup.id_pressed.connect(_on_sort_option_selected)
	_update_sort_popup_checks()

	command_row.add_child(sort_menu)


func _retry_attach() -> void:
	if attach_attempts < 10:
		call_deferred("_attach_sort_dropdown")


func _find_first_hbox(node: Node) -> HBoxContainer:
	if node is HBoxContainer:
		return node as HBoxContainer
	for child in node.get_children():
		var found := _find_first_hbox(child)
		if found != null:
			return found
	return null


func _on_sort_option_selected(sort_id: int) -> void:
	if has_applied_library_sort and sort_id == current_sort_id:
		library_sort_ascending = not library_sort_ascending
	else:
		current_sort_id = sort_id
		library_sort_ascending = true
	has_applied_library_sort = true
	_apply_library_sort()
	_update_sort_menu_text()
	_update_sort_popup_checks()


func _apply_library_sort() -> void:
	var deck_builder := get_parent()
	if deck_builder == null:
		return

	var cards: Array = deck_builder.get("all_cards")
	cards.sort_custom(func(a: Variant, b: Variant) -> bool:
		var comparison := _compare_cards(a, b)
		return comparison < 0 if library_sort_ascending else comparison > 0
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


func _compare_cards(a: Variant, b: Variant) -> int:
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


func _card_string(card: Variant, property_name: String) -> String:
	if card == null:
		return ""
	var value = card.get(property_name)
	return "" if value == null else String(value).to_lower()


func _card_int(card: Variant, property_name: String) -> int:
	if card == null:
		return 0
	var value = card.get(property_name)
	return 0 if value == null else int(value)


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


func _update_sort_menu_text() -> void:
	if sort_menu != null:
		sort_menu.text = _sort_button_text()


func _update_sort_popup_checks() -> void:
	if sort_menu == null:
		return
	var popup := sort_menu.get_popup()
	for item_index in range(popup.get_item_count()):
		popup.set_item_checked(item_index, popup.get_item_id(item_index) == current_sort_id)


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
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style
