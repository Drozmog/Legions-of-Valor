class_name CardInspectPanel
extends PanelContainer

@export var hand: HandUI

var card_image: TextureRect = null
var current_tween: Tween = null


func _ready() -> void:
	setup_position()
	setup_visuals()
	build_ui()
	auto_find_missing_references()
	connect_signals()

	visible = false
	modulate.a = 0.0
	z_index = 50


func setup_position() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0

	offset_left = -340.0
	offset_right = -35.0
	offset_top = -510.0
	offset_bottom = -45.0


func setup_visuals() -> void:
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	panel_style.border_width_left = 0
	panel_style.border_width_right = 0
	panel_style.border_width_top = 0
	panel_style.border_width_bottom = 0

	add_theme_stylebox_override("panel", panel_style)


func build_ui() -> void:
	card_image = TextureRect.new()
	card_image.name = "InspectedCardImage"

	card_image.mouse_filter = Control.MOUSE_FILTER_IGNORE

	card_image.anchor_left = 0.0
	card_image.anchor_top = 0.0
	card_image.anchor_right = 1.0
	card_image.anchor_bottom = 1.0

	card_image.offset_left = 0.0
	card_image.offset_top = 0.0
	card_image.offset_right = 0.0
	card_image.offset_bottom = 0.0

	card_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	add_child(card_image)


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

	if not hand.card_inspect_requested.is_connected(show_card):
		hand.card_inspect_requested.connect(show_card)


func show_card(card_data: CardData) -> void:
	if card_data == null:
		hide_card()
		return

	if card_data.card_art == null:
		hide_card()
		return

	card_image.texture = card_data.card_art

	visible = true
	pivot_offset = size / 2.0
	scale = Vector2(0.82, 0.82)
	modulate.a = 0.0

	if current_tween != null:
		current_tween.kill()

	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	current_tween.tween_property(self, "modulate:a", 1.0, 0.12)
	current_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.22)


func hide_card() -> void:
	if current_tween != null:
		current_tween.kill()

	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	current_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	current_tween.tween_callback(_finish_hide)


func _finish_hide() -> void:
	visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			hide_card()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			hide_card()
