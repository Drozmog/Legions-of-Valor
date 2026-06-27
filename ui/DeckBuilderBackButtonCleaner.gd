extends Node

const BACK_BUTTON_TEXTURE_PATH := "res://ui/combat_buttons/pass_button.png"
const STYLE_NAMES := ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not is_instance_valid(scene):
		return
	if not scene is DeckBuilder:
		return
	_clean_back_buttons(scene)


func _clean_back_buttons(node: Node) -> void:
	if node is Button:
		var button := node as Button
		if _is_deck_builder_back_button(button):
			_make_button_borderless(button)

	for child in node.get_children():
		_clean_back_buttons(child)


func _is_deck_builder_back_button(button: Button) -> bool:
	if bool(button.get_meta("deck_builder_back_button_cleaned", false)):
		return false
	if not button.text.strip_edges().is_empty():
		return false
	if button.icon == null:
		return false
	return button.icon.resource_path == BACK_BUTTON_TEXTURE_PATH


func _make_button_borderless(button: Button) -> void:
	button.set_meta("deck_builder_back_button_cleaned", true)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	var empty_style := StyleBoxEmpty.new()
	for style_name in STYLE_NAMES:
		button.add_theme_stylebox_override(style_name, empty_style)
	button.add_theme_constant_override("h_separation", 0)
