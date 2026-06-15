class_name ParryPromptPanel
extends PanelContainer

signal parry_resolved(saved: bool, discarded_cards: Array[CardData], defender_slot: Node)

var attacker_card: CardData = null
var defender_card: CardData = null
var defender_slot_ref: Node = null
var available_cards: Array[CardData] = []
var chosen_cards: Array[CardData] = []
var required_dp: int = 0
var accumulated_dp: int = 0

var title_label: Label = null
var detail_label: Label = null
var cards_box: VBoxContainer = null


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
	offset_left = -310.0
	offset_right = 310.0
	offset_top = -210.0
	offset_bottom = 210.0
	z_index = 210


func setup_visuals() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.86)
	style.border_color = Color(0.35, 0.55, 1.0, 1.0)
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
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	title_label = Label.new()
	title_label.text = "PARRY CHAIN"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title_label)

	detail_label = Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(detail_label)

	cards_box = VBoxContainer.new()
	cards_box.add_theme_constant_override("separation", 6)
	vbox.add_child(cards_box)

	var let_die_button := Button.new()
	let_die_button.text = "Let Unit Fall"
	let_die_button.pressed.connect(_on_let_die_pressed)
	vbox.add_child(let_die_button)


func show_prompt(new_attacker_card: CardData, new_defender_card: CardData, new_defender_slot: Node, hand_cards: Array[CardData]) -> void:
	attacker_card = new_attacker_card
	defender_card = new_defender_card
	defender_slot_ref = new_defender_slot
	available_cards = hand_cards.duplicate()
	chosen_cards.clear()
	accumulated_dp = 0
	required_dp = 0

	if attacker_card != null:
		required_dp = max(attacker_card.ap, 0)

	rebuild_card_buttons()
	update_detail_text()
	show()


func rebuild_card_buttons() -> void:
	if cards_box == null:
		return

	for child in cards_box.get_children():
		child.queue_free()

	if available_cards.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No hand cards available to parry with."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cards_box.add_child(empty_label)
		return

	for card_data in available_cards:
		var button := Button.new()
		button.text = card_data.card_name + "  | DP " + str(card_data.dp)
		button.pressed.connect(_on_parry_card_pressed.bind(card_data, button))
		cards_box.add_child(button)


func update_detail_text() -> void:
	if detail_label == null:
		return

	var attacker_name := "Attacker"
	var defender_name := "Defender"

	if attacker_card != null:
		attacker_name = attacker_card.card_name

	if defender_card != null:
		defender_name = defender_card.card_name

	detail_label.text = attacker_name + " is attacking " + defender_name + " with AP " + str(required_dp) + ".\nDiscard hand cards until parry DP reaches " + str(required_dp) + ".\nCurrent parry DP: " + str(accumulated_dp)


func _on_parry_card_pressed(card_data: CardData, button: Button) -> void:
	if card_data == null:
		return

	if chosen_cards.has(card_data):
		return

	chosen_cards.append(card_data)
	accumulated_dp += max(card_data.dp, 0)
	button.disabled = true
	button.text = button.text + "  [chosen]"
	update_detail_text()

	if accumulated_dp >= required_dp:
		parry_resolved.emit(true, chosen_cards.duplicate(), defender_slot_ref)
		hide()


func _on_let_die_pressed() -> void:
	parry_resolved.emit(false, [], defender_slot_ref)
	hide()
