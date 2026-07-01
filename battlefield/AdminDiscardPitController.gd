class_name AdminDiscardPitController
extends Node

@export_group("Enabled")
@export var show_debug_button: bool = true
@export var start_active: bool = false

@export_group("Scene Paths")
@export var ui_path: NodePath = NodePath("UI")
@export var pit_root_path: NodePath = NodePath("../AdminDiscardPit")
@export var pit_drop_area_path: NodePath = NodePath("ParryPitDropArea")

@export_group("Button Layout")
@export var button_text_on: String = "Pit: ON"
@export var button_text_off: String = "Pit: OFF"
@export var button_left: float = -150.0
@export var button_right: float = -20.0
@export var button_top: float = 315.0
@export var button_bottom: float = 359.0

@export_group("Animation")
@export var animation_time: float = 0.28
@export var hidden_y_offset: float = -0.75

var battlefield: BattlefieldManager = null
var button: Button = null
var pit_root: Node3D = null
var pit_drop_area: Area3D = null

var active := false
var home_position := Vector3.ZERO
var current_tween: Tween = null


func _ready() -> void:
	var parent_battlefield := get_parent() as BattlefieldManager
	if parent_battlefield != null:
		call_deferred("setup", parent_battlefield)


func setup(battlefield_manager: BattlefieldManager) -> void:
	battlefield = battlefield_manager
	find_nodes()
	create_button()

	active = start_active

	if pit_root != null:
		home_position = pit_root.position
		if active:
			pit_root.visible = true
			pit_root.position = home_position
		else:
			pit_root.visible = false
			pit_root.position = get_hidden_position()

	set_drop_enabled(active)
	refresh_button()

	print("ADMIN PIT READY. Root=", pit_root, " DropArea=", pit_drop_area, " Home=", home_position)


func _process(_delta: float) -> void:
	if button != null:
		button.visible = show_debug_button


func find_nodes() -> void:
	pit_root = get_node_or_null(pit_root_path) as Node3D

	if pit_root == null and battlefield != null:
		pit_root = battlefield.get_node_or_null("AdminDiscardPit") as Node3D

	if pit_root == null:
		push_error("AdminDiscardPitController: AdminDiscardPit not found.")
		return

	pit_drop_area = pit_root.get_node_or_null(pit_drop_area_path) as Area3D

	if pit_drop_area == null:
		pit_drop_area = find_child_recursive(pit_root, "ParryPitDropArea") as Area3D

	if pit_drop_area == null:
		push_warning("AdminDiscardPitController: ParryPitDropArea not found.")


func create_button() -> void:
	if battlefield == null:
		return

	var ui := battlefield.get_node_or_null(ui_path)

	if ui == null:
		ui = battlefield.get_node_or_null("UI")

	if ui == null:
		push_error("AdminDiscardPitController: UI not found.")
		return

	button = ui.get_node_or_null("DebugAdminDiscardPitButton") as Button

	if button == null:
		button = Button.new()
		button.name = "DebugAdminDiscardPitButton"
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(130.0, 44.0)
		button.anchor_left = 1.0
		button.anchor_right = 1.0
		button.anchor_top = 0.0
		button.anchor_bottom = 0.0
		button.z_index = 999
		ui.add_child(button)

	button.offset_left = button_left
	button.offset_right = button_right
	button.offset_top = button_top
	button.offset_bottom = button_bottom
	button.visible = show_debug_button
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	if not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	set_active(not active)


func set_active(next_active: bool) -> void:
	if pit_root == null:
		find_nodes()

	if pit_root == null:
		return

	active = next_active
	refresh_button()

	if current_tween != null and current_tween.is_valid():
		current_tween.kill()

	if active:
		show_pit()
	else:
		hide_pit()


func show_pit() -> void:
	if pit_root == null:
		return

	pit_root.visible = true
	pit_root.position = get_hidden_position()

	##restart_pit_animation_players()

	set_drop_enabled(true)

	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_CUBIC)
	current_tween.set_ease(Tween.EASE_OUT)
	current_tween.tween_property(pit_root, "position", home_position, animation_time)


func restart_pit_animation_players() -> void:
	if pit_root == null:
		return

	restart_animation_players_recursive(pit_root)


func restart_animation_players_recursive(root: Node) -> void:
	if root == null:
		return

	if root is AnimationPlayer:
		var animation_player := root as AnimationPlayer

		animation_player.active = true
		animation_player.process_mode = Node.PROCESS_MODE_INHERIT

		var animation_names := animation_player.get_animation_list()

		if animation_names.is_empty():
			return

		var animation_to_play := ""

		if animation_player.autoplay != "":
			animation_to_play = animation_player.autoplay
		else:
			animation_to_play = animation_names[0]

		if animation_player.has_animation(animation_to_play):
			animation_player.play(animation_to_play)
			print("ADMIN PIT playing animation: ", animation_to_play, " on ", animation_player.get_path())

	for child in root.get_children():
		restart_animation_players_recursive(child)


func hide_pit() -> void:
	if pit_root == null:
		return

	set_drop_enabled(false)

	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_CUBIC)
	current_tween.set_ease(Tween.EASE_IN)
	current_tween.tween_property(pit_root, "position", get_hidden_position(), animation_time)
	current_tween.tween_callback(func():
		if pit_root != null:
			pit_root.visible = false
	)


func refresh_button() -> void:
	if button != null:
		button.text = button_text_on if active else button_text_off


func get_hidden_position() -> Vector3:
	return home_position + Vector3(0.0, hidden_y_offset, 0.0)


func set_drop_enabled(enabled: bool) -> void:
	if pit_drop_area == null:
		return

	pit_drop_area.input_ray_pickable = enabled
	pit_drop_area.monitoring = enabled
	pit_drop_area.monitorable = enabled

	var collision := pit_drop_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.disabled = not enabled


func try_consume_hand_release(card: CardUI, screen_position: Vector2) -> bool:
	if not active:
		return false

	if card == null or card.card_data == null:
		return false

	if not is_screen_position_over_drop_area(screen_position):
		return false

	var card_data := card.card_data

	if battlefield != null and battlefield.has_method("finish_hand_drag_preview"):
		battlefield.finish_hand_drag_preview()

	if battlefield != null and battlefield.hand != null and battlefield.hand.has_method("consume_dragged_card"):
		battlefield.hand.consume_dragged_card(card)
	elif is_instance_valid(card):
		card.queue_free()

	if battlefield != null and battlefield.discard_pile != null and battlefield.discard_pile.has_method("add_card"):
		battlefield.discard_pile.add_card(card_data)

	if battlefield != null and battlefield.player_hand_3d != null:
		if battlefield.player_hand_3d.has_method("clear_hand_interaction_state"):
			battlefield.player_hand_3d.clear_hand_interaction_state()

	if battlefield != null and battlefield.has_method("log_msg"):
		battlefield.log_msg("Admin pit discarded " + card_data.card_name + ".")

	return true


func is_screen_position_over_drop_area(screen_position: Vector2) -> bool:
	if pit_drop_area == null:
		return false

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false

	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * 100.0

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit := get_viewport().world_3d.direct_space_state.intersect_ray(query)

	if hit.is_empty():
		return false

	var collider := hit.get("collider", null) as Node
	if collider == null:
		return false

	if collider == pit_drop_area:
		return true

	return is_node_inside_target(collider, pit_drop_area)


func is_node_inside_target(node: Node, target: Node) -> bool:
	var current := node

	while current != null:
		if current == target:
			return true

		current = current.get_parent()

	return false


func find_child_recursive(root: Node, target_name: String) -> Node:
	if root == null:
		return null

	if root.name == target_name:
		return root

	for child in root.get_children():
		var found := find_child_recursive(child, target_name)
		if found != null:
			return found

	return null
