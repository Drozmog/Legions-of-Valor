extends MeshInstance3D

signal slot_clicked(slot)
signal slot_right_clicked(slot)

@onready var click_area: Area3D = $ClickArea
@onready var card_point: Marker3D = $CardPoint

var occupied: bool = false
var placed_card: Node3D = null
var equipment_cards: Array[CardData] = []
var equipment_nodes: Array[Node3D] = []
var stacked_unit_cards: Array[CardData] = []
var stacked_unit_nodes: Array[Node3D] = []
var slot_material: StandardMaterial3D

var default_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var valid_color: Color = Color(0.35, 1.0, 0.35, 1.0)
var invalid_color: Color = Color(1.0, 0.25, 0.25, 1.0)
var promotion_color: Color = Color(1.0, 0.84, 0.12, 1.0)

var highlight_outline: Node3D
var glow_outline: Node3D

var outline_material: StandardMaterial3D
var glow_material: StandardMaterial3D
var mobility_pulse_tween: Tween

const SLOT_WIDTH: float = 1.02
const SLOT_HEIGHT: float = 1.34
const MAX_EQUIPMENT_PER_UNIT: int = 2

const OUTLINE_THICKNESS: float = 0.016
const GLOW_THICKNESS: float = 0.085

const OUTLINE_Y_OFFSET: float = 0.030
const GLOW_Y_OFFSET: float = 0.020
const INSPECT_FADE_ALPHA: float = 0.36


func _ready() -> void:
	occupied = get_meta("occupied", false)

	setup_highlight_outline()
	setup_slot_material()

	click_area.input_ray_pickable = true
	click_area.input_event.connect(_on_click_area_input_event)
	click_area.mouse_entered.connect(_on_click_area_mouse_entered)
	click_area.mouse_exited.connect(_on_click_area_mouse_exited)


func set_highlight(active: bool) -> void:
	if highlight_outline == null or glow_outline == null:
		return

	if active:
		set_outline_color(valid_color)
		highlight_outline.visible = true
		glow_outline.visible = true
	else:
		highlight_outline.visible = false
		glow_outline.visible = false


func set_invalid_highlight(active: bool) -> void:
	if highlight_outline == null or glow_outline == null:
		return

	if active:
		set_outline_color(invalid_color)
		highlight_outline.visible = true
		glow_outline.visible = true
	else:
		highlight_outline.visible = false
		glow_outline.visible = false


func set_promotion_highlight(active: bool) -> void:
	if highlight_outline == null or glow_outline == null:
		return

	if active:
		set_outline_color(promotion_color)
		highlight_outline.visible = true
		glow_outline.visible = true
	else:
		highlight_outline.visible = false
		glow_outline.visible = false


func set_insight_highlight(active: bool, color: Color = Color(0.18, 0.55, 1.0, 1.0)) -> void:
	set_meta("insight_selectable", active)
	if active:
		set_outline_color(color)
		highlight_outline.visible = true
		glow_outline.visible = true
	else:
		highlight_outline.visible = false
		glow_outline.visible = false
		_use_cursor(&"use_normal")


func set_mobility_highlight(active: bool) -> void:
	set_meta("mobility_selectable", active)
	if active:
		set_outline_color(Color(0.20, 0.62, 1.0, 1.0))
		highlight_outline.visible = true
		glow_outline.visible = true
		if mobility_pulse_tween != null and mobility_pulse_tween.is_valid():
			mobility_pulse_tween.kill()
		mobility_pulse_tween = create_tween().set_loops()
		mobility_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		mobility_pulse_tween.tween_property(glow_material, "emission_energy_multiplier", 3.4, 0.55)
		mobility_pulse_tween.tween_property(glow_material, "emission_energy_multiplier", 1.8, 0.55)
	else:
		if mobility_pulse_tween != null and mobility_pulse_tween.is_valid():
			mobility_pulse_tween.kill()
		mobility_pulse_tween = null
		if glow_material != null:
			glow_material.emission_energy_multiplier = 2.5
		highlight_outline.visible = false
		glow_outline.visible = false
		_use_cursor(&"use_normal")


func set_outline_color(color: Color) -> void:
	if outline_material != null:
		outline_material.albedo_color = color
		outline_material.emission = color

	if glow_material != null:
		glow_material.albedo_color = Color(color.r, color.g, color.b, 0.18)
		glow_material.emission = color


func _on_click_area_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			slot_clicked.emit(self)

		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			slot_right_clicked.emit(self)


func _clear_inspection_fade() -> void:
	set_inspected_faded(false)


func _find_card_inspect_panel(node: Node) -> CardInspectPanel:
	if node == null:
		return null
	if node is CardInspectPanel:
		return node as CardInspectPanel
	for child in node.get_children():
		var found := _find_card_inspect_panel(child)
		if found != null:
			return found
	return null


func set_inspected_faded(active: bool) -> void:
	if placed_card == null or not is_instance_valid(placed_card):
		return
	_set_visual_fade_recursive(placed_card, active)


func _set_visual_fade_recursive(node: Node, active: bool) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.material_override is StandardMaterial3D:
			var material := mesh_instance.material_override as StandardMaterial3D
			var next_material := material.duplicate() as StandardMaterial3D
			var color := next_material.albedo_color
			if active:
				if not mesh_instance.has_meta("inspect_original_alpha"):
					mesh_instance.set_meta("inspect_original_alpha", color.a)
				color.a = INSPECT_FADE_ALPHA
				next_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			else:
				color.a = float(mesh_instance.get_meta("inspect_original_alpha", 1.0))
				if color.a >= 0.999:
					next_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				if mesh_instance.has_meta("inspect_original_alpha"):
					mesh_instance.remove_meta("inspect_original_alpha")
			next_material.albedo_color = color
			mesh_instance.material_override = next_material
	elif node is Sprite3D:
		var sprite := node as Sprite3D
		var color := sprite.modulate
		if active:
			if not sprite.has_meta("inspect_original_alpha"):
				sprite.set_meta("inspect_original_alpha", color.a)
			color.a = INSPECT_FADE_ALPHA
		else:
			color.a = float(sprite.get_meta("inspect_original_alpha", 1.0))
			if sprite.has_meta("inspect_original_alpha"):
				sprite.remove_meta("inspect_original_alpha")
		sprite.modulate = color
	elif node is Label3D:
		var label := node as Label3D
		var color := label.modulate
		if active:
			if not label.has_meta("inspect_original_alpha"):
				label.set_meta("inspect_original_alpha", color.a)
			color.a = INSPECT_FADE_ALPHA
		else:
			color.a = float(label.get_meta("inspect_original_alpha", 1.0))
			if label.has_meta("inspect_original_alpha"):
				label.remove_meta("inspect_original_alpha")
		label.modulate = color
	for child in node.get_children():
		_set_visual_fade_recursive(child, active)


func _on_click_area_mouse_entered() -> void:
	if bool(get_meta("insight_selectable", false)) or bool(get_meta("mobility_selectable", false)):
		_use_cursor(&"use_pointing")


func _on_click_area_mouse_exited() -> void:
	if bool(get_meta("insight_selectable", false)) or bool(get_meta("mobility_selectable", false)):
		_use_cursor(&"use_normal")


func _use_cursor(method_name: StringName) -> void:
	var cursors := get_node_or_null("/root/Cursors")
	if cursors != null and cursors.has_method(method_name):
		cursors.call(method_name)


func place_card(card_scene: PackedScene, card_data: CardData, place_face_down: bool = false) -> bool:
	if occupied:
		print(get_meta("slot_id"), " is already occupied.")
		return false

	placed_card = card_scene.instantiate()
	card_point.add_child(placed_card)

	placed_card.position = Vector3.ZERO
	placed_card.rotation = Vector3.ZERO

	if placed_card.has_method("assign_card_data"):
		placed_card.assign_card_data(card_data, place_face_down)

	occupied = true
	set_meta("occupied", true)
	set_meta("face_down", place_face_down)

	print("Placed card on: ", get_meta("slot_id"))
	return true


func can_attach_equipment() -> bool:
	if not occupied:
		return false

	if placed_card == null:
		return false

	if bool(get_meta("face_down", false)):
		return false

	return equipment_cards.size() < MAX_EQUIPMENT_PER_UNIT


func attach_equipment(card_scene: PackedScene, card_data: CardData, force: bool = false) -> bool:
	if not force and not can_attach_equipment():
		return false
	if force and (not occupied or placed_card == null or bool(get_meta("face_down", false))):
		return false

	var equipment_node := card_scene.instantiate() as Node3D
	card_point.add_child(equipment_node)
	equipment_cards.append(card_data)
	equipment_nodes.append(equipment_node)

	var index := equipment_nodes.size() - 1
	equipment_node.position = Vector3(-0.23 + float(index) * 0.46, 0.055 + float(index) * 0.004, 0.36)
	equipment_node.rotation_degrees = Vector3(0, 0, -6 + 12 * index)
	equipment_node.scale = Vector3(0.46, 0.46, 0.46)

	if equipment_node.has_method("assign_card_data"):
		equipment_node.assign_card_data(card_data, false)

	return true


func get_equipment_count() -> int:
	return equipment_cards.size()


func get_equipment_cards() -> Array[CardData]:
	return equipment_cards.duplicate()


func discard_equipment_with_ability(ability_id: StringName) -> CardData:
	for index in range(equipment_cards.size()):
		var equipment := equipment_cards[index]
		if equipment == null:
			continue
		for ability in equipment.get_abilities():
			if ability != null and ability.category.to_lower() == "protection" and ability.ability_id == ability_id:
				equipment_cards.remove_at(index)
				var visual := equipment_nodes[index]
				equipment_nodes.remove_at(index)
				if visual != null and is_instance_valid(visual):
					visual.queue_free()
				return equipment
	return null


func add_stacked_unit(card_scene: PackedScene, card_data: CardData) -> bool:
	if card_data == null or placed_card == null:
		return false
	var stacked_node := card_scene.instantiate() as Node3D
	card_point.add_child(stacked_node)
	stacked_node.position = Vector3(0.22, -0.012 - stacked_unit_nodes.size() * 0.006, 0.20)
	stacked_node.rotation_degrees = Vector3(0.0, 0.0, 7.0)
	stacked_node.scale = Vector3.ONE * 0.88
	stacked_node.call("assign_card_data", card_data, false)
	stacked_unit_cards.append(card_data)
	stacked_unit_nodes.append(stacked_node)
	return true


func get_stacked_unit_cards() -> Array[CardData]:
	return stacked_unit_cards.duplicate()


func take_slot_snapshot() -> Dictionary:
	var snapshot := {
		"card": get_placed_card_data(),
		"face_down": bool(get_meta("face_down", false)),
		"equipment": equipment_cards.duplicate(),
		"stacked_units": stacked_unit_cards.duplicate(),
		"vortex_bonus_turn": int(get_meta("vortex_bonus_turn", -1)),
		"used_mobility_turns": get_meta("used_mobility_turns", {}).duplicate(),
	}
	clear_slot()
	return snapshot


func restore_slot_snapshot(card_scene: PackedScene, snapshot: Dictionary) -> bool:
	var card := snapshot.get("card") as CardData
	if card == null:
		return true
	if not place_card(card_scene, card, bool(snapshot.get("face_down", false))):
		return false
	for equipment in snapshot.get("equipment", []):
		attach_equipment(card_scene, equipment as CardData)
	for stacked in snapshot.get("stacked_units", []):
		add_stacked_unit(card_scene, stacked as CardData)
	set_meta("vortex_bonus_turn", int(snapshot.get("vortex_bonus_turn", -1)))
	set_meta("used_mobility_turns", snapshot.get("used_mobility_turns", {}).duplicate())
	return true


func clear_slot() -> void:
	for stacked_node in stacked_unit_nodes:
		if is_instance_valid(stacked_node):
			stacked_node.queue_free()
	stacked_unit_nodes.clear()
	stacked_unit_cards.clear()
	for equipment_node in equipment_nodes:
		if is_instance_valid(equipment_node):
			equipment_node.queue_free()

	equipment_nodes.clear()
	equipment_cards.clear()

	if placed_card == null:
		occupied = false
		set_meta("occupied", false)
		return

	placed_card.queue_free()
	placed_card = null

	occupied = false
	set_meta("occupied", false)
	set_meta("face_down", false)
	set_meta("vortex_bonus_turn", -1)
	set_meta("used_mobility_turns", {})

	print("Cleared slot: ", get_meta("slot_id"))


func get_placed_card_data() -> CardData:
	if placed_card == null:
		return null

	if placed_card.has_method("get_card_data"):
		return placed_card.get_card_data()

	return null


func get_placed_card_visual() -> Node3D:
	return placed_card


func set_slot_usable_ability_ids(ability_ids: Array[StringName]) -> void:
	if placed_card != null and is_instance_valid(placed_card):
		if placed_card.has_method("set_usable_ability_ids"):
			placed_card.set_usable_ability_ids(ability_ids)


func get_ability_visual_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if placed_card != null and is_instance_valid(placed_card):
		entries.append({"card": get_placed_card_data(), "visual": placed_card})
	for index in range(mini(equipment_cards.size(), equipment_nodes.size())):
		var visual := equipment_nodes[index]
		if visual != null and is_instance_valid(visual):
			entries.append({"card": equipment_cards[index], "visual": visual})
	return entries


func reveal_card() -> void:
	if placed_card == null:
		return

	if placed_card.has_method("reveal_card"):
		placed_card.reveal_card()

	set_meta("face_down", false)


func set_slot_ability_icons_visible(show_icons: bool) -> void:
	if placed_card != null and is_instance_valid(placed_card):
		if placed_card.has_method("set_ability_icons_visible"):
			placed_card.set_ability_icons_visible(show_icons)

	for equipment_node in equipment_nodes:
		if equipment_node == null:
			continue

		if not is_instance_valid(equipment_node):
			continue

		if equipment_node.has_method("set_ability_icons_visible"):
			equipment_node.set_ability_icons_visible(show_icons)


func setup_slot_material() -> void:
	var existing_material := get_active_material(0) as StandardMaterial3D

	if existing_material != null:
		slot_material = existing_material.duplicate()
		material_override = slot_material
		default_color = slot_material.albedo_color
	else:
		slot_material = StandardMaterial3D.new()
		slot_material.albedo_color = default_color
		material_override = slot_material


func setup_highlight_outline() -> void:
	highlight_outline = Node3D.new()
	highlight_outline.name = "HighlightOutline"
	add_child(highlight_outline)

	outline_material = StandardMaterial3D.new()
	outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_material.albedo_color = valid_color
	outline_material.emission_enabled = false
	outline_material.emission = valid_color
	outline_material.emission_energy_multiplier = 1.2
	outline_material.no_depth_test = false

	glow_outline = Node3D.new()
	glow_outline.name = "GlowOutline"
	add_child(glow_outline)

	glow_material = StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_material.albedo_color = Color(0.35, 1.0, 0.35, 0.18)
	glow_material.emission_enabled = false
	glow_material.emission = valid_color
	glow_material.emission_energy_multiplier = 2.5
	glow_material.no_depth_test = false
	glow_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY

	create_outline_bar(
		highlight_outline,
		"TopBar",
		Vector3(SLOT_WIDTH + OUTLINE_THICKNESS, 0.01, OUTLINE_THICKNESS),
		Vector3(0, OUTLINE_Y_OFFSET, -SLOT_HEIGHT / 2.0),
		outline_material
	)

	create_outline_bar(
		highlight_outline,
		"BottomBar",
		Vector3(SLOT_WIDTH + OUTLINE_THICKNESS, 0.01, OUTLINE_THICKNESS),
		Vector3(0, OUTLINE_Y_OFFSET, SLOT_HEIGHT / 2.0),
		outline_material
	)

	create_outline_bar(
		highlight_outline,
		"LeftBar",
		Vector3(OUTLINE_THICKNESS, 0.01, SLOT_HEIGHT + OUTLINE_THICKNESS),
		Vector3(-SLOT_WIDTH / 2.0, OUTLINE_Y_OFFSET, 0),
		outline_material
	)

	create_outline_bar(
		highlight_outline,
		"RightBar",
		Vector3(OUTLINE_THICKNESS, 0.01, SLOT_HEIGHT + OUTLINE_THICKNESS),
		Vector3(SLOT_WIDTH / 2.0, OUTLINE_Y_OFFSET, 0),
		outline_material
	)

	create_outline_bar(
		glow_outline,
		"GlowTop",
		Vector3(SLOT_WIDTH + GLOW_THICKNESS, 0.01, GLOW_THICKNESS),
		Vector3(0, GLOW_Y_OFFSET, -SLOT_HEIGHT / 2.0),
		glow_material
	)

	create_outline_bar(
		glow_outline,
		"GlowBottom",
		Vector3(SLOT_WIDTH + GLOW_THICKNESS, 0.01, GLOW_THICKNESS),
		Vector3(0, GLOW_Y_OFFSET, SLOT_HEIGHT / 2.0),
		glow_material
	)

	create_outline_bar(
		glow_outline,
		"GlowLeft",
		Vector3(GLOW_THICKNESS, 0.01, SLOT_HEIGHT + GLOW_THICKNESS),
		Vector3(-SLOT_WIDTH / 2.0, GLOW_Y_OFFSET, 0),
		glow_material
	)

	create_outline_bar(
		glow_outline,
		"GlowRight",
		Vector3(GLOW_THICKNESS, 0.01, SLOT_HEIGHT + GLOW_THICKNESS),
		Vector3(SLOT_WIDTH / 2.0, GLOW_Y_OFFSET, 0),
		glow_material
	)

	highlight_outline.visible = false
	glow_outline.visible = false


func create_outline_bar(
	parent_node: Node3D,
	bar_name: String,
	bar_size: Vector3,
	bar_position: Vector3,
	material: StandardMaterial3D
) -> MeshInstance3D:
	var bar := MeshInstance3D.new()
	bar.name = bar_name

	var bar_mesh := BoxMesh.new()
	bar_mesh.size = bar_size

	bar.mesh = bar_mesh
	bar.position = bar_position
	bar.material_override = material

	parent_node.add_child(bar)

	return bar
