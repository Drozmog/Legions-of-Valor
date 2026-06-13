class_name CardUI
extends Panel

signal drag_started(card: CardUI)
signal drag_released(card: CardUI, screen_position: Vector2)

@onready var name_label: Label = $NameLabel

var card_data: CardData = null
var is_dragging: bool = false
var is_face_down: bool = false
var drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


func setup(data: CardData) -> void:
	card_data = data
	show_front()


func show_front() -> void:
	is_face_down = false

	if name_label != null:
		name_label.visible = true

		if card_data != null:
			name_label.text = card_data.card_name

	self_modulate = Color(1.0, 1.0, 1.0, 1.0)


func show_back() -> void:
	is_face_down = true

	if name_label != null:
		name_label.visible = false

	self_modulate = Color(0.08, 0.08, 0.08, 0.95)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			start_dragging()
			accept_event()


func start_dragging() -> void:
	is_dragging = true
	drag_offset = get_global_mouse_position() - global_position

	move_to_front()
	rotation_degrees = 0

	drag_started.emit(self)
	set_process(true)


func _process(_delta: float) -> void:
	if not is_dragging:
		return

	global_position = get_global_mouse_position() - drag_offset

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		stop_dragging()


func stop_dragging() -> void:
	if not is_dragging:
		return

	is_dragging = false
	set_process(false)

	drag_released.emit(self, get_viewport().get_mouse_position())
