class_name Card3DTestUiPatch
extends "res://cards/Card3D_Test.gd"

# Direct UI fix for ability icons.
# This is applied at the card scene level so it works no matter which battlefield scene is running.

const UI_ABILITY_ICON_PIXEL_SIZE := 0.0038
const UI_ABILITY_GLOW_PIXEL_SIZE := 0.0062
const UI_ABILITY_HITBOX_SIZE := Vector3(0.34, 0.22, 0.34)


func _ready() -> void:
	ability_icon_pixel_size = UI_ABILITY_ICON_PIXEL_SIZE
	ability_icon_spacing = maxf(ability_icon_spacing, 0.25)
	super._ready()


func create_ability_icon_3d(ability: AbilityData) -> Node3D:
	var ability_type := ability.category.to_lower().strip_edges() if ability != null else ""
	var icon_path: String = ABILITY_ICON_PATHS.get(ability_type, "")
	var root := Node3D.new()
	root.name = ability_type.capitalize() + "AbilityIcon"
	root.set_meta("ability", ability)

	if icon_path != "" and ResourceLoader.exists(icon_path):
		var glow := Sprite3D.new()
		glow.name = "Glow"
		glow.texture = load(icon_path) as Texture2D
		glow.pixel_size = UI_ABILITY_GLOW_PIXEL_SIZE
		glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		glow.no_depth_test = true
		glow.modulate = Color(1.0, 0.78, 0.22, 0.0)
		glow.visible = false
		root.add_child(glow)

		var sprite := Sprite3D.new()
		sprite.name = "Icon"
		sprite.texture = load(icon_path) as Texture2D
		sprite.pixel_size = UI_ABILITY_ICON_PIXEL_SIZE
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.no_depth_test = true
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.36)
		root.add_child(sprite)
	else:
		var label := Label3D.new()
		label.name = "IconFallback"
		label.text = ability_type.substr(0, 1).to_upper()
		label.pixel_size = 0.0048
		label.font_size = 34
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = Color(1.0, 0.92, 0.55, 0.36)
		label.outline_size = 8
		label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
		root.add_child(label)

	var area := Area3D.new()
	area.name = "ClickArea"
	area.collision_layer = 8
	area.collision_mask = 0
	area.input_ray_pickable = false
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = UI_ABILITY_HITBOX_SIZE
	collision.shape = shape
	area.add_child(collision)
	area.input_event.connect(_on_ability_icon_input_event.bind(root))
	area.mouse_entered.connect(_on_ability_icon_mouse_entered.bind(root))
	area.mouse_exited.connect(_on_ability_icon_mouse_exited.bind(root))
	root.add_child(area)

	return root


func _on_ability_icon_mouse_entered(icon_root: Node3D) -> void:
	# Do not show the old yellow Label3D tooltip. The battlefield manager shows the proper black panel.
	var ability := icon_root.get_meta("ability", null) as AbilityData
	if ability != null:
		ability_icon_hovered.emit(self, ability)
	Cursors.use_pointing()


func _on_ability_icon_mouse_exited(icon_root: Node3D) -> void:
	var ability := icon_root.get_meta("ability", null) as AbilityData
	if ability != null:
		ability_icon_unhovered.emit(self, ability)
	Cursors.use_normal()
