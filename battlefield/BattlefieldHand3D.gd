class_name BattlefieldHand3D
extends Node3D

const CARD_SCENE: PackedScene = preload("res://cards/Card3D_Test.tscn")
const CARD_PICK_LAYER: int = 8

@export var hand_plane_y: float = 0.58
@export var layout_lerp_speed: float = 9.5
@export var hover_height: float = 0.075
@export var hover_neighbor_spread: float = 0.21
@export var hover_return_clearance_time: float = 0.20
@export var drag_start_distance: float = 10.0

var hand_ui: HandUI
var camera_3d: Camera3D
var card_visuals: Dictionary = {}
var hidden_card_ids: Dictionary = {}
var hovered_card_id: int = 0
var returning_card_id: int = 0
var hover_return_time_left: float = 0.0
var pressed_card: CardUI
var pressed_screen_position := Vector2.ZERO
var press_became_drag := false
var next_spawn_position := Vector3.ZERO
var has_next_spawn_position := false
var deal_animation_states: Dictionary = {}
var draw_preview: Node3D
var draw_preview_target_position := Vector3.ZERO
var draw_preview_target_rotation := Vector3.ZERO
var draw_preview_target_scale := Vector3.ONE
var draw_preview_following: bool = false
var draw_preview_source_position := Vector3.ZERO
var draw_preview_source_rotation := Vector3.ZERO
var modal_blocked := false


func setup(source_hand: HandUI, source_camera: Camera3D) -> void:
	hand_ui = source_hand
	camera_3d = source_camera
	set_process(true)
	set_process_input(true)


func _process(delta: float) -> void:
	if hand_ui == null or camera_3d == null:
		return
	sync_card_visuals()
	update_card_layout(delta)
	if _is_modal_blocked():
		clear_hand_interaction_state()
		return
	update_pressed_card_drag()
	# A SubViewport or modal control may consume mouse-up before this node's
	# _input callback. Recover from the physical button state so a card can
	# never remain hidden or permanently held.
	if pressed_card != null and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		release_pressed_card(get_viewport().get_mouse_position())
	update_draw_preview(delta)


func sync_card_visuals() -> void:
	var live_ids: Dictionary = {}
	for proxy in hand_ui.cards:
		if proxy == null or not is_instance_valid(proxy) or proxy.card_data == null:
			continue
		var card_id: int = proxy.get_instance_id()
		live_ids[card_id] = true
		proxy.visible = false
		proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not card_visuals.has(card_id):
			card_visuals[card_id] = create_card_visual(proxy)

	for raw_id in card_visuals.keys():
		var card_id: int = int(raw_id)
		if live_ids.has(card_id):
			continue
		var old_visual := card_visuals[card_id] as Node3D
		if old_visual != null and is_instance_valid(old_visual):
			old_visual.queue_free()
		card_visuals.erase(card_id)
		hidden_card_ids.erase(card_id)
		deal_animation_states.erase(card_id)


func create_card_visual(proxy: CardUI) -> Node3D:
	var visual := CARD_SCENE.instantiate() as Node3D
	add_child(visual)
	visual.top_level = true
	visual.assign_card_data(proxy.card_data, false)
	visual.set_meta("hand_proxy", proxy)

	var pick_area := Area3D.new()
	pick_area.name = "HandCardPickArea"
	pick_area.collision_layer = CARD_PICK_LAYER
	pick_area.collision_mask = 0
	pick_area.input_ray_pickable = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.02, 0.20, 1.34)
	collision.shape = shape
	collision.position.y = 0.08
	pick_area.add_child(collision)
	visual.add_child(pick_area)
	pick_area.input_event.connect(_on_card_input_event.bind(proxy))
	pick_area.mouse_entered.connect(_on_card_mouse_entered.bind(proxy))
	pick_area.mouse_exited.connect(_on_card_mouse_exited.bind(proxy))

	if has_next_spawn_position:
		visual.global_position = next_spawn_position
		has_next_spawn_position = false
		deal_animation_states[proxy.get_instance_id()] = {
			"start": visual.global_position,
			"destination": Vector3.INF,
			"elapsed": 0.0,
			"duration": 0.78,
			"arc_height": 0.42,
		}
	else:
		visual.global_position = get_proxy_target_position(proxy)
	visual.scale = get_proxy_target_scale(proxy) * 0.92
	return visual


func update_card_layout(delta: float) -> void:
	var blocked := _is_modal_blocked()
	var viewport_size := get_viewport().get_visible_rect().size
	var clearance_card_id := 0
	if not blocked:
		clearance_card_id = hovered_card_id if hovered_card_id != 0 else returning_card_id
	var clearance_index := get_card_index_from_id(clearance_card_id)
	for index in range(hand_ui.cards.size()):
		var proxy: CardUI = hand_ui.cards[index]
		if proxy == null or not is_instance_valid(proxy):
			continue
		var card_id: int = proxy.get_instance_id()
		var visual := card_visuals.get(card_id) as Node3D
		if visual == null or not is_instance_valid(visual):
			continue
		var hidden := hidden_card_ids.has(card_id)
		var screen_center := get_proxy_screen_center(proxy)
		var onscreen := screen_center.y > -180.0 and screen_center.y < viewport_size.y + 100.0
		visual.visible = not hidden and onscreen
		set_visual_pickable(visual, not blocked and not hidden and onscreen)
		if hidden or not onscreen:
			continue
		var target_position := get_proxy_target_position(proxy)
		target_position.y += float(index) * 0.008
		if not blocked and clearance_index >= 0 and index != clearance_index:
			var index_distance := absi(index - clearance_index)
			if index_distance <= 2:
				var spread_weight := 1.0 if index_distance == 1 else 0.45
				var spread_direction := -1.0 if index < clearance_index else 1.0
				target_position.x += spread_direction * hover_neighbor_spread * spread_weight
		if not blocked and card_id == hovered_card_id:
			target_position.y += hover_height
		# Exponential smoothing remains consistent across frame rates and gives
		# dealt cards a gentle deceleration instead of a stepped linear chase.
		var weight := 1.0 - exp(-layout_lerp_speed * delta)
		visual.global_position = visual.global_position.lerp(target_position, weight)
		var target_rotation := Vector3(0.0, deg_to_rad(-proxy.rotation_degrees), 0.0)
		visual.global_rotation = visual.global_rotation.lerp(target_rotation, weight)
		var target_scale := get_proxy_target_scale(proxy)
		if not blocked and card_id == hovered_card_id:
			target_scale *= 1.025
		if deal_animation_states.has(card_id):
			_update_deal_animation(card_id, visual, target_position, target_rotation, target_scale, delta)
			continue
		visual.scale = visual.scale.lerp(target_scale, weight)
		if visual.has_method("set_ability_icons_visible"):
			visual.set_ability_icons_visible(hand_ui.showing_ability_icons and not blocked)

	if hovered_card_id == 0 and returning_card_id != 0:
		hover_return_time_left = maxf(hover_return_time_left - delta, 0.0)
		if hover_return_time_left <= 0.0:
			returning_card_id = 0


func _update_deal_animation(
	card_id: int,
	visual: Node3D,
	target_position: Vector3,
	target_rotation: Vector3,
	target_scale: Vector3,
	delta: float
) -> void:
	var state: Dictionary = deal_animation_states[card_id]
	state["elapsed"] = float(state["elapsed"]) + delta
	var duration := maxf(float(state["duration"]), 0.01)
	var t := clampf(float(state["elapsed"]) / duration, 0.0, 1.0)
	# Quintic smoothstep gives zero velocity and acceleration at both ends.
	# The sine lift creates a shallow ballistic arc without an artificial bounce.
	var travel := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	var start := state["start"] as Vector3
	var destination := state["destination"] as Vector3
	if not destination.is_finite():
		destination = target_position
	else:
		# New cards re-center the fan. Ease that changing landing point so a card
		# already in flight bends naturally instead of being yanked sideways.
		var destination_weight := 1.0 - exp(-8.0 * delta)
		destination = destination.lerp(target_position, destination_weight)
	state["destination"] = destination
	var position := start.lerp(destination, travel)
	position.y += sin(t * PI) * float(state["arc_height"])
	visual.global_position = position
	var bank := sin(t * PI) * deg_to_rad(-7.0 if destination.x < start.x else 7.0)
	visual.global_rotation = target_rotation + Vector3(0.0, 0.0, bank)
	var scale_weight := 0.90 + 0.10 * travel
	visual.scale = target_scale * scale_weight
	deal_animation_states[card_id] = state
	if t < 1.0:
		return
	visual.global_position = target_position
	visual.global_rotation = target_rotation
	visual.scale = target_scale
	deal_animation_states.erase(card_id)


func get_card_index_from_id(card_id: int) -> int:
	if card_id == 0 or hand_ui == null:
		return -1
	for index in range(hand_ui.cards.size()):
		var proxy: CardUI = hand_ui.cards[index]
		if proxy != null and proxy.get_instance_id() == card_id:
			return index
	return -1


func get_proxy_screen_center(proxy: CardUI) -> Vector2:
	return proxy.get_global_transform_with_canvas() * (proxy.size * 0.5)


func get_proxy_target_position(proxy: CardUI) -> Vector3:
	return screen_to_plane(get_proxy_screen_center(proxy), hand_plane_y)


func get_proxy_target_scale(proxy: CardUI) -> Vector3:
	var target_pixel_width := maxf(proxy.size.x * proxy.scale.x, 1.0)
	var center := get_proxy_target_position(proxy)
	var left_screen := camera_3d.unproject_position(center - Vector3(0.51, 0.0, 0.0))
	var right_screen := camera_3d.unproject_position(center + Vector3(0.51, 0.0, 0.0))
	var base_pixel_width := maxf(left_screen.distance_to(right_screen), 1.0)
	var scale_factor := target_pixel_width / base_pixel_width
	return Vector3.ONE * scale_factor


func screen_to_plane(screen_position: Vector2, plane_y: float) -> Vector3:
	var origin := camera_3d.project_ray_origin(screen_position)
	var direction := camera_3d.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return origin
	return origin + direction * ((plane_y - origin.y) / direction.y)


func _on_card_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_index: int,
	proxy: CardUI
) -> void:
	if _is_modal_blocked():
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			pressed_card = proxy
			pressed_screen_position = mouse_event.position
			press_became_drag = false
			get_viewport().set_input_as_handled()


func update_pressed_card_drag() -> void:
	if _is_modal_blocked():
		clear_hand_interaction_state()
		return
	if pressed_card == null or press_became_drag:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if pressed_screen_position.distance_to(get_viewport().get_mouse_position()) < drag_start_distance:
		return
	press_became_drag = true
	hand_ui._on_card_drag_started(pressed_card)
	hide_card_for_action(pressed_card)


func _input(event: InputEvent) -> void:
	if _is_modal_blocked():
		clear_hand_interaction_state()
		return
	if pressed_card == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or mouse_event.pressed:
			return
		release_pressed_card(mouse_event.position)
		get_viewport().set_input_as_handled()


func release_pressed_card(screen_position: Vector2) -> void:
	if _is_modal_blocked():
		clear_hand_interaction_state()
		return
	if pressed_card == null:
		return
	var released_card := pressed_card
	pressed_card = null
	if press_became_drag:
		released_card.global_position = (
			screen_position
			- released_card.size * released_card.scale * 0.5
		)
		released_card.rotation_degrees = 0.0
		hand_ui._on_card_drag_released(released_card, screen_position)
	else:
		hand_ui._on_card_clicked(released_card, screen_position)
	press_became_drag = false


func _on_card_mouse_entered(proxy: CardUI) -> void:
	if _is_modal_blocked():
		return
	if proxy != null:
		returning_card_id = 0
		hover_return_time_left = 0.0
		hovered_card_id = proxy.get_instance_id()
		Cursors.use_pointing()


func _on_card_mouse_exited(proxy: CardUI) -> void:
	if proxy != null and hovered_card_id == proxy.get_instance_id():
		returning_card_id = hovered_card_id
		hover_return_time_left = hover_return_clearance_time
		hovered_card_id = 0
		Cursors.use_normal()


func hide_card_for_action(proxy: CardUI) -> void:
	if proxy == null:
		return
	hidden_card_ids[proxy.get_instance_id()] = true


func restore_card(
	proxy: CardUI,
	from_world_position: Vector3 = Vector3.ZERO,
	use_world_position: bool = false
) -> void:
	if proxy == null:
		return
	if use_world_position:
		var visual := card_visuals.get(proxy.get_instance_id()) as Node3D
		if visual != null and is_instance_valid(visual):
			visual.global_position = from_world_position
	hidden_card_ids.erase(proxy.get_instance_id())


func get_card_global_position(proxy: CardUI) -> Vector3:
	if proxy == null:
		return Vector3.ZERO
	var visual := card_visuals.get(proxy.get_instance_id()) as Node3D
	if visual != null and is_instance_valid(visual):
		return visual.global_position
	return get_proxy_target_position(proxy)


func get_card_global_rotation(proxy: CardUI) -> Vector3:
	if proxy == null:
		return Vector3.ZERO
	var visual := card_visuals.get(proxy.get_instance_id()) as Node3D
	if visual != null and is_instance_valid(visual):
		return visual.global_rotation
	return Vector3(0.0, deg_to_rad(-proxy.rotation_degrees), 0.0)


func get_card_global_scale(proxy: CardUI) -> Vector3:
	if proxy == null:
		return Vector3.ONE
	var visual := card_visuals.get(proxy.get_instance_id()) as Node3D
	if visual != null and is_instance_valid(visual):
		return visual.scale
	return get_proxy_target_scale(proxy)


func get_card_position_for_data(card_data: CardData) -> Vector3:
	if hand_ui == null:
		return Vector3.ZERO
	for proxy in hand_ui.cards:
		if proxy != null and proxy.card_data == card_data:
			return get_card_global_position(proxy)
	return Vector3.ZERO


func queue_next_card_spawn(world_position: Vector3) -> void:
	next_spawn_position = world_position
	has_next_spawn_position = true


func start_draw_preview(card_data: CardData, source_node: Node3D) -> void:
	if _is_modal_blocked():
		return
	cancel_draw_preview(false)
	if card_data == null or source_node == null:
		return
	draw_preview = CARD_SCENE.instantiate() as Node3D
	add_child(draw_preview)
	draw_preview.top_level = true
	draw_preview.assign_card_data(card_data, true)
	var source_position := source_node.global_position
	if source_node.has_method("get_top_card_global_position"):
		source_position = source_node.get_top_card_global_position()
	draw_preview.global_position = source_position + Vector3(0.0, 0.035, 0.0)
	draw_preview.global_rotation = source_node.global_rotation
	draw_preview_source_position = draw_preview.global_position
	draw_preview_source_rotation = draw_preview.global_rotation
	draw_preview.scale = Vector3.ONE * 0.96
	draw_preview_target_position = draw_preview.global_position
	draw_preview_target_rotation = Vector3.ZERO
	draw_preview_target_scale = get_reference_hand_scale()
	draw_preview_following = true
	Cursors.use_grab()


func update_draw_preview_target(screen_position: Vector2) -> void:
	if _is_modal_blocked():
		return
	if draw_preview == null or not draw_preview_following:
		return
	var plane_position := screen_to_plane(screen_position, hand_plane_y + 0.10)
	draw_preview_target_position = plane_position
	draw_preview_target_rotation = Vector3.ZERO
	draw_preview_target_scale = get_reference_hand_scale() * 1.04


func update_draw_preview(delta: float) -> void:
	if draw_preview == null or not is_instance_valid(draw_preview) or not draw_preview_following:
		return
	var position_weight := clampf(delta * 12.0, 0.0, 1.0)
	var rotation_weight := clampf(delta * 9.0, 0.0, 1.0)
	draw_preview.global_position = draw_preview.global_position.lerp(
		draw_preview_target_position,
		position_weight
	)
	draw_preview.global_rotation = draw_preview.global_rotation.lerp(
		draw_preview_target_rotation,
		rotation_weight
	)
	draw_preview.scale = draw_preview.scale.lerp(draw_preview_target_scale, position_weight)


func finish_draw_preview_into_hand(proxy: CardUI) -> void:
	if draw_preview == null or proxy == null:
		cancel_draw_preview(false)
		return
	draw_preview_following = false
	# Transfer ownership to this animation immediately. A fast subsequent draw
	# may create a new active preview without cancelling/freeing this settling card.
	var held_card := draw_preview
	draw_preview = null
	var card_id := proxy.get_instance_id()
	hidden_card_ids[card_id] = true
	sync_card_visuals()
	var target_position := get_proxy_target_position(proxy)
	var target_index := hand_ui.cards.find(proxy)
	target_position.y += float(maxi(target_index, 0)) * 0.008
	var target_rotation := Vector3(0.0, deg_to_rad(-proxy.rotation_degrees), 0.0)
	var target_scale := get_proxy_target_scale(proxy)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(held_card, "global_position", target_position + Vector3(0.0, 0.24, 0.0), 0.18)
	# Turn around the card's vertical visual axis instead of rolling over its
	# horizontal edge.
	tween.parallel().tween_property(held_card, "global_rotation", Vector3(0.0, target_rotation.y, PI * 0.5), 0.18)
	await tween.finished
	if held_card == null or not is_instance_valid(held_card):
		hidden_card_ids.erase(card_id)
		sync_card_visuals()
		return
	held_card.show_front()
	held_card.global_rotation = Vector3(0.0, target_rotation.y, -PI * 0.5)
	var settle := create_tween()
	settle.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	settle.tween_property(held_card, "global_position", target_position, 0.23)
	settle.parallel().tween_property(held_card, "global_rotation", target_rotation, 0.23)
	settle.parallel().tween_property(held_card, "scale", target_scale, 0.23)
	await settle.finished
	if held_card == null or not is_instance_valid(held_card):
		hidden_card_ids.erase(card_id)
		sync_card_visuals()
		return
	var persistent := card_visuals.get(card_id) as Node3D
	if persistent != null and is_instance_valid(persistent):
		persistent.global_position = target_position
		persistent.global_rotation = target_rotation
		persistent.scale = target_scale
	hidden_card_ids.erase(card_id)
	_queue_free_safely(held_card)
	if draw_preview == null:
		Cursors.use_normal()


func cancel_draw_preview(animate_back: bool = true) -> void:
	if draw_preview == null or not is_instance_valid(draw_preview):
		draw_preview = null
		return
	draw_preview_following = false
	var old_preview := draw_preview
	draw_preview = null
	if animate_back:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(old_preview, "global_position", draw_preview_source_position, 0.20)
		tween.parallel().tween_property(old_preview, "global_rotation", draw_preview_source_rotation, 0.20)
		tween.parallel().tween_property(old_preview, "scale", Vector3.ONE * 0.96, 0.20)
		tween.tween_callback(_queue_free_safely.bind(old_preview))
	else:
		_queue_free_safely(old_preview)
	Cursors.use_normal()


func _queue_free_safely(node: Node) -> void:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	node.queue_free()


func set_modal_blocked(blocked: bool) -> void:
	modal_blocked = blocked
	if blocked:
		clear_hand_interaction_state()
	for raw_id in card_visuals.keys():
		var visual := card_visuals[raw_id] as Node3D
		if visual != null and is_instance_valid(visual):
			set_visual_pickable(visual, not blocked and visual.visible)


func _is_modal_blocked() -> bool:
	if modal_blocked:
		return true
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var depth: Variant = scene.get("blurred_modal_input_depth")
	return depth != null and int(depth) > 0


func clear_hand_interaction_state() -> void:
	pressed_card = null
	press_became_drag = false
	if hovered_card_id != 0 or returning_card_id != 0:
		hovered_card_id = 0
		returning_card_id = 0
		hover_return_time_left = 0.0
		Cursors.use_normal()
	if draw_preview != null:
		cancel_draw_preview(false)


func get_reference_hand_scale() -> Vector3:
	if hand_ui != null and not hand_ui.cards.is_empty():
		var proxy: CardUI = hand_ui.cards[0]
		if proxy != null:
			return get_proxy_target_scale(proxy)
	return Vector3.ONE


func set_visual_pickable(visual: Node3D, enabled: bool) -> void:
	var area := visual.get_node_or_null("HandCardPickArea") as Area3D
	if area != null:
		area.collision_layer = CARD_PICK_LAYER if enabled and not _is_modal_blocked() else 0
		area.input_ray_pickable = enabled and not _is_modal_blocked()
