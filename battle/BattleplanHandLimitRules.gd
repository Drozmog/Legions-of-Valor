extends Node

const BATTLEPLAN_PHASE := 0
const HAND_CLEANUP_SECONDS := 20.0

var overlay_canvas: CanvasLayer = null
var overlay_root: Control = null
var overlay_panel: PanelContainer = null
var overlay_title: Label = null
var overlay_body: Label = null
var overlay_timer: Label = null
var overlay_tween: Tween = null
var overlay_visible := false
var last_manager: Node = null


func _ready() -> void:
	set_process(true)
	_create_overlay()


func _process(_delta: float) -> void:
	var manager := _find_battlefield_manager()
	if manager == null:
		_hide_overlay()
		last_manager = null
		return

	if manager != last_manager:
		_hide_overlay(true)
		last_manager = manager

	_enforce_battleplan_draw_limit(manager)
	_update_discard_overlay(manager)


func _find_battlefield_manager() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return _find_battlefield_manager_recursive(scene)


func _find_battlefield_manager_recursive(node: Node) -> Node:
	if node == null:
		return null
	if node.has_method("begin_battleplan_hand_cleanup_or_tribute") and node.has_method("draw_battleplan_cards"):
		return node
	for child in node.get_children():
		var found := _find_battlefield_manager_recursive(child)
		if found != null:
			return found
	return null


func _enforce_battleplan_draw_limit(manager: Node) -> void:
	if manager == null:
		return
	if int(manager.get("current_phase")) != BATTLEPLAN_PHASE:
		return

	var pending := int(manager.get("pending_battleplan_draws"))
	if pending <= 0:
		return

	var hand := manager.get("hand") as Node
	if hand == null:
		return

	var current_hand_size := _get_hand_card_count(hand)
	var max_hand_size := int(hand.get("max_hand_size"))
	var available_hand_space := maxi(max_hand_size - current_hand_size, 0)

	var deck_remaining := pending
	var player_deck := manager.get("player_deck") as Node
	if player_deck != null and player_deck.has_method("cards_remaining"):
		deck_remaining = int(player_deck.call("cards_remaining"))

	var allowed_draws := mini(pending, available_hand_space)
	allowed_draws = mini(allowed_draws, deck_remaining)

	if allowed_draws >= pending:
		return

	manager.set("pending_battleplan_draws", allowed_draws)

	if allowed_draws > 0:
		_log_once(
			manager,
			"Battleplan draw limited to " + str(allowed_draws) + " card(s) by max hand size " + str(max_hand_size) + "."
		)
		_call_if_available(manager, "update_phase_ui")
		return

	if current_hand_size > max_hand_size:
		_start_hand_cleanup(manager, current_hand_size, max_hand_size)
		return

	_log_once(manager, "Battleplan draw skipped. Hand is already at the max hand size of " + str(max_hand_size) + ".")
	_call_if_available(manager, "begin_battleplan_hand_cleanup_or_tribute")


func _start_hand_cleanup(manager: Node, current_hand_size: int, max_hand_size: int) -> void:
	manager.set("pending_battleplan_draws", 0)
	manager.set("battleplan_hand_cleanup_active", true)
	manager.set("battleplan_discard_time_left", HAND_CLEANUP_SECONDS)
	_log_once(
		manager,
		"Hand limit exceeded. Discard "
		+ str(maxi(current_hand_size - max_hand_size, 0))
		+ " card(s) within "
		+ str(int(HAND_CLEANUP_SECONDS))
		+ " seconds."
	)
	_call_if_available(manager, "update_phase_ui")


func _update_discard_overlay(manager: Node) -> void:
	if manager == null:
		_hide_overlay()
		return

	var active := bool(manager.get("battleplan_hand_cleanup_active"))
	var hand := manager.get("hand") as Node
	if not active or hand == null:
		_hide_overlay()
		return

	var current_hand_size := _get_hand_card_count(hand)
	var max_hand_size := int(hand.get("max_hand_size"))
	var excess := maxi(current_hand_size - max_hand_size, 0)
	if excess <= 0:
		_hide_overlay()
		return

	_show_overlay(manager, excess, max_hand_size)


func _create_overlay() -> void:
	if overlay_canvas != null:
		return

	overlay_canvas = CanvasLayer.new()
	overlay_canvas.name = "BattleplanHandLimitOverlay"
	overlay_canvas.layer = 260
	add_child(overlay_canvas)

	overlay_root = Control.new()
	overlay_root.name = "DiscardWarningRoot"
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_root.visible = false
	overlay_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	overlay_canvas.add_child(overlay_root)

	overlay_panel = PanelContainer.new()
	overlay_panel.name = "DiscardWarningPanel"
	overlay_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	overlay_panel.offset_left = -470.0
	overlay_panel.offset_right = 470.0
	overlay_panel.offset_top = 105.0
	overlay_panel.offset_bottom = 255.0
	overlay_root.add_child(overlay_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.52)
	style.border_color = Color(1.0, 1.0, 1.0, 0.96)
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(1.0, 1.0, 1.0, 0.82)
	style.shadow_size = 22
	overlay_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	overlay_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 6)
	margin.add_child(rows)

	overlay_title = Label.new()
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override("font_size", 38)
	overlay_title.add_theme_color_override("font_color", Color.WHITE)
	overlay_title.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.55))
	overlay_title.add_theme_constant_override("shadow_offset_x", 0)
	overlay_title.add_theme_constant_override("shadow_offset_y", 0)
	rows.add_child(overlay_title)

	overlay_body = Label.new()
	overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay_body.add_theme_font_size_override("font_size", 23)
	overlay_body.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.96))
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(overlay_body)

	overlay_timer = Label.new()
	overlay_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay_timer.add_theme_font_size_override("font_size", 31)
	overlay_timer.add_theme_color_override("font_color", Color.WHITE)
	rows.add_child(overlay_timer)


func _show_overlay(manager: Node, excess: int, max_hand_size: int) -> void:
	if overlay_root == null:
		_create_overlay()

	var time_left := int(ceil(float(manager.get("battleplan_discard_time_left"))))
	overlay_title.text = "DISCARD " + str(excess) + " CARD" + ("" if excess == 1 else "S")
	overlay_body.text = "Your selected Battleplan max hand size is " + str(max_hand_size) + ". Drag excess cards into the Discard Pile."
	overlay_timer.text = "TIME LEFT: " + str(time_left) + "s"

	if overlay_visible:
		return

	overlay_visible = true
	overlay_root.visible = true
	if overlay_tween != null and overlay_tween.is_valid():
		overlay_tween.kill()
	overlay_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	overlay_tween = create_tween()
	overlay_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	overlay_tween.tween_property(overlay_root, "modulate:a", 1.0, 0.28)


func _hide_overlay(immediate: bool = false) -> void:
	if overlay_root == null or not overlay_visible:
		return

	overlay_visible = false
	if overlay_tween != null and overlay_tween.is_valid():
		overlay_tween.kill()

	if immediate:
		overlay_root.visible = false
		overlay_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
		return

	overlay_tween = create_tween()
	overlay_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	overlay_tween.tween_property(overlay_root, "modulate:a", 0.0, 0.20)
	overlay_tween.tween_callback(func() -> void:
		if overlay_root != null:
			overlay_root.visible = false
	)


func _get_hand_card_count(hand: Node) -> int:
	var value: Variant = hand.get("cards")
	if value is Array:
		return (value as Array).size()
	return 0


func _call_if_available(target: Object, method_name: StringName) -> void:
	if target != null and target.has_method(method_name):
		target.call(method_name)


func _log_once(manager: Node, message: String) -> void:
	if manager != null and manager.has_method("log_msg"):
		manager.call("log_msg", message)
