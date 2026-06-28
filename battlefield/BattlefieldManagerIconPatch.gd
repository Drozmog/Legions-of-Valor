class_name BattlefieldManagerIconPatch
extends "res://battlefield/BattlefieldManagerVolleyPatch4.gd"

const ABILITY_ICON_POLISHED_META := "ability_icon_hover_polished"
const ABILITY_TOOLTIP_TOP_LEFT := Vector3(-0.34, 0.075, -0.30)
const ABILITY_HOVER_BOX_SIZE := Vector3(0.28, 0.18, 0.28)
const ABILITY_ICON_SCALE := Vector3(1.12, 1.12, 1.12)


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
		var tooltip := icon_root.get_node_or_null("Tooltip") as Label3D
		if tooltip != null:
			tooltip.position = ABILITY_TOOLTIP_TOP_LEFT
		var area := icon_root.get_node_or_null("ClickArea") as Area3D
		if area != null:
			var collision := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if collision != null and collision.shape is BoxShape3D:
				(collision.shape as BoxShape3D).size = ABILITY_HOVER_BOX_SIZE
		var icon := icon_root.get_node_or_null("Icon") as Sprite3D
		if icon != null:
			icon.pixel_size = maxf(icon.pixel_size, 0.0033)
		var glow := icon_root.get_node_or_null("Glow") as Sprite3D
		if glow != null:
			glow.pixel_size = maxf(glow.pixel_size, 0.0054)
