class_name AbilityPromptPanel
extends PanelContainer

signal ability_choice_made(use_ability: bool, card_data: CardData, ability_text: String)

const ABILITY_ICON_PATHS := {
	"assault": "res://ui/ability_icons/assault.png",
	"control": "res://ui/ability_icons/control.png",
	"attrition": "res://ui/ability_icons/attrition.png",
	"economy": "res://ui/ability_icons/economy.png",
	"protection": "res://ui/ability_icons/protection.png",
	"insight": "res://ui/ability_icons/insight.png",
	"mobility": "res://ui/ability_icons/mobility.png",
}

var current_card_data: CardData = null
var current_ability_text: String = ""

var icon_rect: TextureRect = null
var message_label: Label = null


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
	offset_left = -260.0
	offset_right = 260.0
	offset_top = -145.0
	offset_bottom = 145.0
	z_index = 200


func setup_visuals() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.84)
	style.border_color = Color(0.9, 0.75, 0.35, 1.0)
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
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(86, 86)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(icon_rect)

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(message_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	vbox.add_child(buttons)

	var use_button := Button.new()
	use_button.text = "Use Ability"
	use_button.pressed.connect(_on_use_pressed)
	buttons.add_child(use_button)

	var skip_button := Button.new()
	skip_button.text = "Skip"
	skip_button.pressed.connect(_on_skip_pressed)
	buttons.add_child(skip_button)


func show_for_card(card_data: CardData) -> void:
	current_card_data = card_data
	current_ability_text = ""

	if card_data != null:
		current_ability_text = card_data.get_ability_text()

	if message_label != null:
		message_label.text = "Use " + card_data.card_name + " ability?\n\n" + current_ability_text

	if icon_rect != null:
		icon_rect.texture = get_first_ability_icon(card_data)

	show()


func get_first_ability_icon(card_data: CardData) -> Texture2D:
	if card_data == null:
		return null

	var ability_categories := card_data.get_ability_categories()
	if ability_categories.is_empty():
		return null

	var ability_type: String = ability_categories[0].to_lower()
	var icon_path: String = ABILITY_ICON_PATHS.get(ability_type, "")

	if icon_path == "" or not ResourceLoader.exists(icon_path):
		return null

	return load(icon_path) as Texture2D


func _on_use_pressed() -> void:
	ability_choice_made.emit(true, current_card_data, current_ability_text)
	hide()


func _on_skip_pressed() -> void:
	ability_choice_made.emit(false, current_card_data, current_ability_text)
	hide()
