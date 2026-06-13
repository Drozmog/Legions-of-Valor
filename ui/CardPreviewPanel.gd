class_name CardPreviewPanel
extends PanelContainer

@export var hand: HandUI

var name_label: Label = null
var info_label: Label = null


func _ready() -> void:
	setup_position()
	setup_visuals()
	build_ui()
	auto_find_missing_references()
	connect_signals()
	hide_preview()


func setup_position() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0

	offset_left = -360.0
	offset_right = -20.0
	offset_top = -430.0
	offset_bottom = -170.0


func setup_visuals() -> void:
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.68)
	panel_style.border_color = Color(0.9, 0.75, 0.35, 0.9)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8

	add_theme_stylebox_override("panel", panel_style)


func build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	name_label = Label.new()
	name_label.text = "Card Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)

	info_label = Label.new()
	info_label.text = ""
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)


func auto_find_missing_references() -> void:
	if hand != null:
		return

	var root: Node = get_tree().current_scene

	if root == null:
		root = get_tree().root

	hand = find_hand(root)


func find_hand(node: Node) -> HandUI:
	if node is HandUI:
		return node as HandUI

	for child: Node in node.get_children():
		var found: HandUI = find_hand(child)

		if found != null:
			return found

	return null


func connect_signals() -> void:
	if hand == null:
		return

	if not hand.card_preview_requested.is_connected(show_card):
		hand.card_preview_requested.connect(show_card)

	if not hand.card_preview_cleared.is_connected(hide_preview):
		hand.card_preview_cleared.connect(hide_preview)


func show_card(card_data: CardData) -> void:
	if card_data == null:
		hide_preview()
		return

	visible = true

	name_label.text = card_data.card_name

	var race_text: String = card_data.race.capitalize()
	var type_text: String = card_data.card_type.capitalize()
	var rarity_text: String = card_data.rarity.capitalize()

	if race_text == "":
		race_text = "Neutral"

	if type_text == "":
		type_text = "Unknown"

	if rarity_text == "":
		rarity_text = "Common"

	info_label.text = (
		"Race: " + race_text + "\n" +
		"Type: " + type_text + "\n" +
		"Rarity: " + rarity_text + "\n\n" +
		"TP: " + str(card_data.tribute_cost) + "    AP: " + str(card_data.ap) + "    DP: " + str(card_data.dp) + "\n\n" +
		"Ability:\n" + clean_text(card_data.ability_text) + "\n\n" +
		"Lore:\n" + clean_text(card_data.lore_text)
	)


func hide_preview() -> void:
	visible = false


func clean_text(text: String) -> String:
	if text.strip_edges() == "":
		return "-"

	return text.strip_edges()
