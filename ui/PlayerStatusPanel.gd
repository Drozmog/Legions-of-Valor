class_name PlayerStatusPanel
extends PanelContainer

@export var hand: HandUI
@export var player_deck: PlayerDeck
@export var tribute_manager: TributeManager

@export var refresh_interval: float = 0.15

var title_label: Label = null
var status_label: Label = null
var refresh_timer: float = 0.0


func _ready() -> void:
	setup_position()
	setup_visuals()
	build_ui()
	auto_find_missing_references()
	connect_signals()
	update_status()
	set_process(true)


func setup_position() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0

	offset_left = -280.0
	offset_right = -20.0
	offset_top = 20.0
	offset_bottom = 165.0


func setup_visuals() -> void:
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
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
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	title_label = Label.new()
	title_label.text = "PLAYER STATUS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title_label)

	status_label = Label.new()
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_label)


func auto_find_missing_references() -> void:
	var root := get_tree().current_scene

	if root == null:
		root = get_tree().root

	if hand == null:
		hand = find_hand(root)

	if player_deck == null:
		player_deck = find_player_deck(root)

	if tribute_manager == null:
		tribute_manager = find_tribute_manager(root)


func find_hand(node: Node) -> HandUI:
	if node is HandUI:
		return node

	for child in node.get_children():
		var found := find_hand(child)

		if found != null:
			return found

	return null


func find_player_deck(node: Node) -> PlayerDeck:
	if node is PlayerDeck:
		return node

	for child in node.get_children():
		var found := find_player_deck(child)

		if found != null:
			return found

	return null


func find_tribute_manager(node: Node) -> TributeManager:
	if node is TributeManager:
		return node

	for child in node.get_children():
		var found := find_tribute_manager(child)

		if found != null:
			return found

	return null


func connect_signals() -> void:
	if player_deck != null:
		if not player_deck.deck_changed.is_connected(_on_deck_changed):
			player_deck.deck_changed.connect(_on_deck_changed)

	if tribute_manager != null:
		if not tribute_manager.tribute_changed.is_connected(_on_tribute_changed):
			tribute_manager.tribute_changed.connect(_on_tribute_changed)


func _process(delta: float) -> void:
	refresh_timer += delta

	if refresh_timer >= refresh_interval:
		refresh_timer = 0.0
		update_status()


func _on_deck_changed(_cards_remaining: int) -> void:
	update_status()


func _on_tribute_changed(_status_text: String) -> void:
	update_status()


func update_status() -> void:
	if status_label == null:
		return

	var deck_count: int = 0
	var hand_count: int = 0
	var hand_limit: int = 0
	var tp_text: String = "TP 0/0"
	var temp_text: String = "Temp +0"
	var factions_text: String = "None"

	if player_deck != null:
		deck_count = player_deck.cards_remaining()

	if hand != null:
		hand_count = hand.cards.size()
		hand_limit = hand.max_hand_size

	if tribute_manager != null:
		tp_text = "TP " + str(tribute_manager.current_tribute_points) + "/" + str(tribute_manager.permanent_tp)
		temp_text = "Temp +" + str(tribute_manager.temporary_tp)
		factions_text = format_factions(tribute_manager.get_unlocked_factions())

	status_label.text = (
		"Deck: " + str(deck_count) + "\n" +
		"Hand: " + str(hand_count) + "/" + str(hand_limit) + "\n" +
		tp_text + "\n" +
		temp_text + "\n" +
		"Factions: " + factions_text
	)


func format_factions(factions: Array[String]) -> String:
	if factions.is_empty():
		return "None"

	var text: String = ""

	for i in range(factions.size()):
		text += factions[i]

		if i < factions.size() - 1:
			text += ", "

	return text
