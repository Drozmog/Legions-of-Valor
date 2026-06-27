extends Node

const STYLE_NAMES := ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]
const BACK_BUTTON_SIZE := Vector2(58.0, 26.0)
const MENU_SCENE_PATH := "res://ui/Menu/prototype_menu.tscn"
const REPLACEMENT_META := "deck_builder_back_texture_replacement"
const ORIGINAL_HIDDEN_META := "deck_builder_framed_back_button_hidden"


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not is_instance_valid(scene):
		return
	_clean_back_buttons(scene)


func _clean_back_buttons(node: Node) -> void:
	if node is Button:
		var button := node as Button
		if _is_deck_builder_icon_back_button(button):
			_replace_with_texture_button(button)

	for child in node.get_children():
		_clean_back_buttons(child)


func _is_deck_builder_icon_back_button(button: Button) -> bool:
	if bool(button.get_meta(ORIGINAL_HIDDEN_META, false)):
		return false
	if not button.text.strip_edges().is_empty():
		return false
	if button.icon == null:
		return false
	return _find_deck_builder_owner(button) != null


func _replace_with_texture_button(button: Button) -> void:
	_make_button_borderless(button)
	var parent := button.get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child is TextureButton and bool(child.get_meta(REPLACEMENT_META, false)):
			button.visible = false
			button.custom_minimum_size = Vector2.ZERO
			return

	var replacement := TextureButton.new()
	replacement.name = "DeckBuilderBackTextureButton"
	replacement.set_meta(REPLACEMENT_META, true)
	replacement.texture_normal = button.icon
	replacement.texture_hover = button.icon
	replacement.texture_pressed = button.icon
	replacement.texture_disabled = button.icon
	replacement.ignore_texture_size = true
	replacement.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	replacement.custom_minimum_size = BACK_BUTTON_SIZE
	replacement.focus_mode = Control.FOCUS_NONE
	replacement.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var deck_builder := _find_deck_builder_owner(button)
	if deck_builder != null and deck_builder.has_method("request_scene_change"):
		replacement.pressed.connect(deck_builder.call.bind("request_scene_change", MENU_SCENE_PATH))

	var index := button.get_index()
	parent.add_child(replacement)
	parent.move_child(replacement, index)
	button.visible = false
	button.custom_minimum_size = Vector2.ZERO
	button.size = Vector2.ZERO
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.set_meta(ORIGINAL_HIDDEN_META, true)


func _make_button_borderless(button: Button) -> void:
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


func _find_deck_builder_owner(node: Node) -> Node:
	var current := node
	while current != null:
		if current is DeckBuilder:
			return current
		current = current.get_parent()
	return null
