extends Node

const PLAYER_BUTTON_NAME := "PlayerBattleplanInspectButton"
const OPPONENT_BUTTON_NAME := "OpponentBattleplanInspectButton"
const INSPECT_COLLISION_SIZE := Vector3(1.65, 0.95, 0.90)
const MANUAL_HIT_HALF_EXTENTS := Vector2(0.82, 0.48)

var cursor_owned := false


func _ready() -> void:
	set_process(true)
	set_process_input(true)


func _process(_delta: float) -> void:
	var hud := _find_bottom_hud()
	if hud != null:
		_patch_inspect_button_clickboxes(hud)


func _input(event: InputEvent) -> void:
	if not event is InputEventMouse:
		return

	var hud := _find_bottom_hud()
	if hud == null or not bool(hud.get("plans_open")):
		_clear_cursor_if_owned()
		return

	_patch_inspect_button_clickboxes(hud)

	var mouse_event := event as InputEventMouse
	var hovered_target := _get_inspect_button_under_mouse(hud, mouse_event.position)

	if event is InputEventMouseMotion:
		if hovered_target != "":
			cursor_owned = true
			_use_cursor("use_pointing")
		elif cursor_owned:
			_clear_cursor_if_owned()

	if not event is InputEventMouseButton:
		return

	var button_event := event as InputEventMouseButton
	if button_event.button_index != MOUSE_BUTTON_LEFT or not button_event.pressed:
		return
	if hovered_target == "":
		return

	if hud.has_method("inspect_battleplan"):
		hud.call("inspect_battleplan", hovered_target == PLAYER_BUTTON_NAME)
		get_viewport().set_input_as_handled()


func _patch_inspect_button_clickboxes(hud: Node) -> void:
	for button_name in [PLAYER_BUTTON_NAME, OPPONENT_BUTTON_NAME]:
		var button_root := hud.find_child(button_name, true, false) as Node3D
		if button_root == null:
			continue

		var area := button_root.get_node_or_null("ClickArea") as Area3D
		if area == null:
			continue

		area.input_ray_pickable = true
		area.collision_layer = 32
		area.collision_mask = 0

		var collision := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision == null or not collision.shape is BoxShape3D:
			continue

		var shape := collision.shape as BoxShape3D
		shape.size = Vector3(
			maxf(shape.size.x, INSPECT_COLLISION_SIZE.x),
			maxf(shape.size.y, INSPECT_COLLISION_SIZE.y),
			maxf(shape.size.z, INSPECT_COLLISION_SIZE.z)
		)


func _get_inspect_button_under_mouse(hud: Node, screen_position: Vector2) -> String:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return ""

	for button_name in [PLAYER_BUTTON_NAME, OPPONENT_BUTTON_NAME]:
		var button_root := hud.find_child(button_name, true, false) as Node3D
		if button_root == null or not button_root.visible:
			continue
		if _mouse_hits_button(camera, screen_position, button_root):
			return button_name

	return ""


func _mouse_hits_button(camera: Camera3D, screen_position: Vector2, button_root: Node3D) -> bool:
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var plane_normal := button_root.global_transform.basis.z.normalized()
	var denominator := plane_normal.dot(ray_direction)
	if absf(denominator) < 0.0001:
		return false

	var distance := plane_normal.dot(button_root.global_position - ray_origin) / denominator
	if distance < 0.0:
		return false

	var local_hit := button_root.to_local(ray_origin + ray_direction * distance)
	return absf(local_hit.x) <= MANUAL_HIT_HALF_EXTENTS.x and absf(local_hit.y) <= MANUAL_HIT_HALF_EXTENTS.y


func _find_bottom_hud() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return _find_bottom_hud_recursive(scene)


func _find_bottom_hud_recursive(node: Node) -> Node:
	if node == null:
		return null

	var script := node.get_script()
	if script is Script and String((script as Script).resource_path).ends_with("battlefield/BattlefieldBottomHud3D.gd"):
		return node

	for child in node.get_children():
		var found := _find_bottom_hud_recursive(child)
		if found != null:
			return found

	return null


func _clear_cursor_if_owned() -> void:
	if not cursor_owned:
		return
	cursor_owned = false
	_use_cursor("use_normal")


func _use_cursor(method_name: StringName) -> void:
	var cursors := get_node_or_null("/root/Cursors")
	if cursors != null and cursors.has_method(method_name):
		cursors.call(method_name)
