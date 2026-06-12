extends Control

const CARD_UI_SCENE: PackedScene = preload("res://Scenes/Cards/CardUI.tscn")

@export var fan_radius: float = 500.0          # bigger = flatter fan, smaller = more curved
@export var fan_spread_degrees: float = 50.0 # total fan rotation
@export var hover_lift: float = 40.0

var cards: Array[Control] = []
var selected_card: Control = null
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in range(5):
		var card : Control = CARD_UI_SCENE.instantiate()
		add_child(card)
		cards.append(card)
		card.mouse_entered.connect(_on_card_hovered.bind(card))
		card.mouse_exited.connect(_on_card_unhovered.bind(card))
		card.gui_input.connect(_on_card_gui_input.bind(card))
	arrange_fan()

func arrange_fan() -> void:
	var count := cards.size()
	var center_x := size.x/2.0
	var bottom_y := size.y - 50.0	#40px margin off from bottom
	var mid := (count-1)/2.0 	#middle index of fan
	
#	Center of imaginary circle
	var circle_center := Vector2(center_x, bottom_y + fan_radius)
	
	var step_deg := 0.0
	if count > 1:
		step_deg = fan_spread_degrees / (count-1) #Angle between cards
	 
	for i in range(count):
		var card = cards[i]
		var offset := i-mid
		var angle_deg := offset * step_deg
		var angle_rad := deg_to_rad(angle_deg)
		
		var point := circle_center + Vector2(sin(angle_rad), -cos(angle_rad)) * fan_radius
		
		card.pivot_offset = Vector2(card.size.x/2.0, card.size.y) #Bottom center pivot
		card.position = point - card.pivot_offset
		card.rotation_degrees = angle_deg
		
		card.set_meta("home_position", card.position)


func _on_card_hovered(card: Control) -> void:
	if card == selected_card:
		return            
	card.move_to_front()
	_move_card_to(card, card.get_meta("home_position") + Vector2(0, -hover_lift))

func _on_card_unhovered(card: Control) -> void:
	if card == selected_card:
		return
	_move_card_to(card, card.get_meta("home_position"))
			

func _on_card_gui_input(event: InputEvent, card: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		select_card(card)

func select_card(card: Control) -> void:
	if selected_card == card:
		_move_card_to(card, card.get_meta("home_position"))
		selected_card = null
		return
	if selected_card != null:        # something else was selected: drop it back down
		_move_card_to(selected_card, selected_card.get_meta("home_position"))
	selected_card = card             # remember the new choice
	card.move_to_front()
	_move_card_to(card, card.get_meta("home_position") + Vector2(0, -hover_lift))  # raise it

func _move_card_to(card: Control, target: Vector2) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", target, 0.12)
