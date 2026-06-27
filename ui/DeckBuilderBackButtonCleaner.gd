extends Node

const STYLE_NAMES := ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]
const BACK_BUTTON_SIZE := Vector2(58.0, 26.0)


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not is_instance_valid(scene):
		return
	if not (scene is DeckBuilder):
		return
	_clean_back_buttons(scene)


func _clean_back_buttons(node: Node) -> void:
	if node is Button:
		var button := node as Button
		if _is_deck_builder_icon_back_button(button):
			_make_button_borderless(button)

	for child in node.get_children():
		_clean_back_buttons(child)


func _is_deck_builder_icon_back_button(button: Button) -> bool:
	# The Deck Builder back control is the only textless icon button in the
	# tabletop HUD command row. Do not rely on resource_path because preloaded
	# textures can arrive without the exact path string after import/reload.
	if not button.text.strip_edges().is_empty():
		return false
	return button.icon != null


func _make_button_borderless(button: Button) -> void:
	button.set_meta("deck_builder_back_button_cleaned", true)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = BACK_BUTTON_SIZE
	button.size = BACK_BUTTON_SIZE
	button.expand_icon = true
	button.add_theme_constant_override("h_separation", 0)
	button.add_theme_constant_override("icon_max_width", int(BACK_BUTTON_SIZE.x))
	var empty_style := StyleBoxEmpty.new()
	for style_name in STYLE_NAMES:
		button.add_theme_stylebox_override(style_name, empty_style)
