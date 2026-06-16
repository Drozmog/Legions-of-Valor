@tool
class_name OpponentVisuals
extends Node3D

@export var card_width: float = 1.02
@export var card_height: float = 1.34
@export var card_thickness: float = 0.006

@export var hand_card_spacing: float = 0.42
@export var hand_fan_curve: float = 0.16
@export var hand_max_visible_cards: int = 10

@export var pile_max_visible_cards: int = 14
@export var pile_card_gap: float = 0.008

@export var editor_preview_hand_count: int = 5
@export var editor_preview_deck_count: int = 8
@export var editor_preview_tribute_count: int = 2
@export var editor_preview_discard_count: int = 2

@export var face_up_pile_card_scale: float = 1.0

@export var opponent_label_pixel_size: float = 0.0045
@export var opponent_pile_label_font_size: int = 22
@export var opponent_hand_label_font_size: int = 22
@export var show_enemy_hand_label: bool = true

var deck_count: int = 0
var tribute_count: int = 0
var discard_count: int = 0
var hand_count: int = 0

var tribute_cards_data: Array = []
var discard_cards_data: Array = []

var hand_root: Node3D = null
var deck_root: Node3D = null
var tribute_root: Node3D = null
var discard_root: Node3D = null
var parry_pit_root: Node3D = null



func _ready() -> void:
	find_roots()
	rebuild_all()


func find_roots() -> void:
	hand_root = get_node_or_null("EnemyHandFan") as Node3D
	deck_root = get_node_or_null("EnemyDrawPileVisual") as Node3D
	tribute_root = get_node_or_null("EnemyTributePileVisual") as Node3D
	discard_root = get_node_or_null("EnemyDiscardPileVisual") as Node3D
	parry_pit_root = get_node_or_null("EnemyParryPitVisual") as Node3D


func set_all_card_data(new_deck_count: int, new_hand_count: int, new_tribute_cards: Array, new_discard_cards: Array) -> void:
	deck_count = max(new_deck_count, 0)
	hand_count = max(new_hand_count, 0)

	tribute_cards_data = new_tribute_cards.duplicate()
	discard_cards_data = new_discard_cards.duplicate()

	tribute_count = tribute_cards_data.size()
	discard_count = discard_cards_data.size()

	rebuild_all()


func set_all_counts(new_deck_count: int, new_hand_count: int, new_tribute_count: int, new_discard_count: int) -> void:
	deck_count = max(new_deck_count, 0)
	hand_count = max(new_hand_count, 0)
	tribute_count = max(new_tribute_count, 0)
	discard_count = max(new_discard_count, 0)
	rebuild_all()


func rebuild_all() -> void:
	find_roots()
	rebuild_hand_fan()
	rebuild_deck_pile()
	rebuild_tribute_pile()
	rebuild_discard_pile()
	rebuild_parry_pit()


func get_visible_hand_count() -> int:
	if Engine.is_editor_hint():
		return editor_preview_hand_count

	return hand_count


func get_visible_deck_count() -> int:
	if Engine.is_editor_hint():
		return editor_preview_deck_count

	return deck_count


func get_visible_tribute_count() -> int:
	if Engine.is_editor_hint():
		return editor_preview_tribute_count

	return tribute_count


func get_visible_discard_count() -> int:
	if Engine.is_editor_hint():
		return editor_preview_discard_count

	return discard_count


func rebuild_hand_fan() -> void:
	if hand_root == null:
		return

	clear_children(hand_root)

	var visible_count: int = mini(get_visible_hand_count(), hand_max_visible_cards)

	if visible_count <= 0:
		return

	var total_width: float = hand_card_spacing * float(visible_count - 1)
	var start_x: float = -total_width / 2.0

	for i in range(visible_count):
		var normalized: float = 0.0

		if visible_count > 1:
			normalized = (float(i) / float(visible_count - 1)) * 2.0 - 1.0

		var x: float = start_x + hand_card_spacing * float(i)
		var z: float = absf(normalized) * hand_fan_curve
		var y: float = float(i) * 0.004
		var yaw: float = -normalized * 8.0

		var card := CardPileVisual.create_card_back_visual(card_width, card_height)
		card.position = Vector3(x, y, z)
		card.rotation_degrees = Vector3(0, yaw, 0)
		hand_root.add_child(card)

	if show_enemy_hand_label:
		create_label(
			hand_root,
			"Enemy Hand: " + str(get_visible_hand_count()),
			Vector3(0, 0.20, -0.62),
			opponent_hand_label_font_size
		)


func rebuild_deck_pile() -> void:
	rebuild_card_back_pile(deck_root, get_visible_deck_count(), "Enemy Deck")


func rebuild_tribute_pile() -> void:
	if Engine.is_editor_hint():
		rebuild_card_back_pile(tribute_root, get_visible_tribute_count(), "Enemy Tribute")
		return

	rebuild_face_up_pile(tribute_root, tribute_cards_data, "Enemy Tribute")


func rebuild_discard_pile() -> void:
	if Engine.is_editor_hint():
		rebuild_card_back_pile(discard_root, get_visible_discard_count(), "Enemy Discard")
		return

	rebuild_face_up_pile(discard_root, discard_cards_data, "Enemy Discard")
	
	
func rebuild_face_up_pile(root: Node3D, cards: Array, label_text: String) -> void:
	if root == null:
		return

	clear_children(root)

	root.add_child(CardPileVisual.create_pile_base())

	var start_index: int = max(0, cards.size() - pile_max_visible_cards)
	var visible_cards: Array = cards.slice(start_index, cards.size())

	for i in range(visible_cards.size()):
		var card_data: CardData = visible_cards[i] as CardData

		if card_data == null:
			continue

		var card_node := CardPileVisual.create_face_up_card_visual(card_data, face_up_pile_card_scale)

		card_node.position = Vector3(
			float(i) * 0.025,
			0.045 + float(i) * 0.014,
			float(i) * 0.018
		)

		card_node.rotation_degrees = Vector3(0.0, float(i) * 1.0, 0.0)

		root.add_child(card_node)

	create_label(
		root,
		label_text + ": " + str(cards.size()),
		Vector3(0, 0.28, -0.82),
		opponent_pile_label_font_size
	)
	


func rebuild_card_back_pile(root: Node3D, count: int, label_text: String) -> void:
	if root == null:
		return

	clear_children(root)

	root.add_child(CardPileVisual.create_pile_base())

	var visible_count: int = mini(count, pile_max_visible_cards)

	for i in range(visible_count):
		var card := CardPileVisual.create_card_back_visual(card_width, card_height)
		card.position = Vector3(0, 0.025 + float(i) * (card_thickness + pile_card_gap), 0)
		card.rotation_degrees = Vector3(0, float(i % 4) * 1.5, 0)
		root.add_child(card)

	create_label(
		root,
		label_text + ": " + str(count),
		Vector3(0, 0.28, -0.82),
		opponent_pile_label_font_size
	)


func rebuild_parry_pit() -> void:
	if parry_pit_root == null:
		return

	clear_children(parry_pit_root)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "EnemyParryPitGlow"

	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.62
	mesh.bottom_radius = 0.62
	mesh.height = 0.045
	mesh.radial_segments = 64
	mesh_instance.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.651, 0.078, 1.0, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(0.651, 0.078, 1.0, 0.0)
	mat.emission_energy_multiplier = 2.6
	mesh_instance.material_override = mat

	parry_pit_root.add_child(mesh_instance)
	create_label(parry_pit_root, "Enemy Parry", Vector3(0, 0.25, -0.70), opponent_pile_label_font_size)


func create_label(parent: Node3D, text: String, label_position: Vector3, font_size: int) -> void:
	var label := CardPileVisual.create_counter_label(
		"PileLabel",
		text,
		label_position,
		opponent_label_pixel_size,
		font_size
	)

	parent.add_child(label)


func clear_children(root: Node) -> void:
	for child in root.get_children():
		child.queue_free()
