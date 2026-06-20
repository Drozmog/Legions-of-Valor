class_name DeckSelectionScreen
extends Control

signal deck_selected(slot_index: int)

var options_grid: GridContainer

var selection_panel: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 110
	build_ui()
	get_viewport().size_changed.connect(_layout_to_viewport)
	call_deferred("_layout_to_viewport")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	selection_panel = PanelContainer.new()
	selection_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	selection_panel.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.028, 0.020, 0.010, 0.98)
	style.border_color = Color(0.92, 0.70, 0.25, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	selection_panel.add_theme_stylebox_override("panel", style)
	add_child(selection_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	selection_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "CHOOSE YOUR WAR DECK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42, 1.0))
	rows.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Select the saved deck you will bring into this battle."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	rows.add_child(subtitle)

	options_grid = GridContainer.new()
	options_grid.columns = 5
	options_grid.add_theme_constant_override("h_separation", 12)
	options_grid.add_theme_constant_override("v_separation", 12)
	rows.add_child(options_grid)
	_layout_to_viewport()


func _layout_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	position = Vector2.ZERO
	size = viewport_size
	if selection_panel == null:
		return
	var panel_size := Vector2(980.0, 430.0)
	selection_panel.position = (viewport_size - panel_size) * 0.5
	selection_panel.size = panel_size


func show_selection(deck_summaries: Array[Dictionary]) -> void:
	_layout_to_viewport()
	mouse_filter = Control.MOUSE_FILTER_STOP
	for child in options_grid.get_children():
		child.queue_free()
	var has_valid_deck := false
	for summary in deck_summaries:
		var slot_index := int(summary.get("slot_index", -1))
		var card_count := int(summary.get("card_count", 0))
		var valid := bool(summary.get("valid", false))
		has_valid_deck = has_valid_deck or valid
		var button := Button.new()
		button.text = (
			"SLOT " + str(slot_index + 1) + "\n"
			+ String(summary.get("deck_name", "Deck")) + "\n"
			+ str(card_count) + " / 40 CARDS"
		)
		button.custom_minimum_size = Vector2(170, 105)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = not valid
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_deck_pressed.bind(slot_index))
		options_grid.add_child(button)

	if not has_valid_deck:
		var fallback := Button.new()
		fallback.text = "PROTOTYPE DECK\n40 CARDS"
		fallback.custom_minimum_size = Vector2(170, 105)
		fallback.focus_mode = Control.FOCUS_NONE
		fallback.pressed.connect(_on_deck_pressed.bind(-1))
		options_grid.add_child(fallback)
	show()
	move_to_front()


func _on_deck_pressed(slot_index: int) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	deck_selected.emit(slot_index)
