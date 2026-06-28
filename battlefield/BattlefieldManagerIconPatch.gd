class_name BattlefieldManagerIconPatch
extends "res://battlefield/BattlefieldManagerVolleyPatch4.gd"

const ABILITY_ICON_POLISHED_META := "ability_icon_hover_polished"
const ABILITY_HOVER_BOX_SIZE := Vector3(0.34, 0.22, 0.34)
const ABILITY_TOOLTIP_OFFSET := Vector2(-370.0, -122.0)
const ABILITY_TOOLTIP_SCREEN_MARGIN := 12.0


func _process(delta: float) -> void:
	super._process(delta)
	polish_card_ability_icons()


func polish_card_ability_icons() -> void:
	for card_visual in get_tree().get_nodes_in_group("card_ability_icon_polish"):
		polish_card_visual_ability_icons(card_visual)
	_mark_and_polish_tree(self)


func _mark_and_polish_tree(node: Node) -> void:
	if node == null:
		return
	if node.has_method("get_card_data") and node.has_method("set_usable_ability_ids"):
		if not node.is_in_group("card_ability_icon_polish"):
			node.add_to_group("card_ability_icon_polish")
		polish_card_visual_ability_icons(node)
	for child in node.get_children():
		_mark_and_polish_tree(child)


func polish_card_visual_ability_icons(card_visual: Node) -> void:
	if card_visual == null or not is_instance_valid(card_visual):
		return
	var root := card_visual.get_node_or_null("AbilityIconRoot") as Node3D
	if root == null:
		return
	for icon_root in root.get_children():
		if icon_root == null:
			continue

		# Remove the old tiny yellow 3D tooltip. The screen-space black tooltip is the only tooltip now.
		var yellow_tooltip := icon_root.get_node_or_null("Tooltip") as Label3D
		if yellow_tooltip != null and not yellow_tooltip.is_queued_for_deletion():
			yellow_tooltip.queue_free()

		var area := icon_root.get_node_or_null("ClickArea") as Area3D
		if area != null:
			var collision := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if collision != null and collision.shape is BoxShape3D:
				(collision.shape as BoxShape3D).size = ABILITY_HOVER_BOX_SIZE

		var icon := icon_root.get_node_or_null("Icon") as Sprite3D
		if icon != null:
			icon.pixel_size = maxf(icon.pixel_size, 0.0038)

		var glow := icon_root.get_node_or_null("Glow") as Sprite3D
		if glow != null:
			glow.pixel_size = maxf(glow.pixel_size, 0.0062)


func _on_card_ability_icon_hovered(card_visual: Node, ability: AbilityData, _slot: Node) -> void:
	if ability == null or ability_tooltip_panel == null or ability_tooltip_label == null:
		return

	polish_card_visual_ability_icons(card_visual)

	ability_tooltip_label.text = ability.ability_name + "\n" + ability.rules_text

	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := ability_tooltip_panel.size
	if panel_size.x <= 1.0 or panel_size.y <= 1.0:
		panel_size = ability_tooltip_panel.custom_minimum_size
	if panel_size.x <= 1.0 or panel_size.y <= 1.0:
		panel_size = Vector2(340.0, 96.0)

	var mouse := get_viewport().get_mouse_position()
	var target_position := mouse + ABILITY_TOOLTIP_OFFSET

	# Prefer top-left of the cursor. If the cursor is too close to an edge, clamp safely onscreen.
	target_position.x = clampf(target_position.x, ABILITY_TOOLTIP_SCREEN_MARGIN, viewport_size.x - panel_size.x - ABILITY_TOOLTIP_SCREEN_MARGIN)
	target_position.y = clampf(target_position.y, ABILITY_TOOLTIP_SCREEN_MARGIN, viewport_size.y - panel_size.y - ABILITY_TOOLTIP_SCREEN_MARGIN)

	ability_tooltip_panel.position = target_position
	ability_tooltip_panel.visible = true


func _on_card_ability_icon_unhovered(_card_visual: Node, _ability: AbilityData, _slot: Node) -> void:
	if ability_tooltip_panel != null:
		ability_tooltip_panel.visible = false
