extends Node

const BASE_MANAGER_SCRIPT_PATH := "res://battlefield/BattlefieldManager.gd"
const RULE_MANAGER_SCRIPT: Script = preload("res://battlefield/BattlefieldManagerVolleyPatch.gd")


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_refresh_existing_tree")


func _on_node_added(node: Node) -> void:
	_apply_rule_script_if_manager(node)


func _refresh_existing_tree() -> void:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		_apply_to_tree(current_scene)


func _apply_to_tree(node: Node) -> void:
	_apply_rule_script_if_manager(node)
	for child in node.get_children():
		_apply_to_tree(child)


func _apply_rule_script_if_manager(node: Node) -> void:
	if node == null:
		return
	var current_script := node.get_script() as Script
	if current_script == null:
		return
	if current_script.resource_path != BASE_MANAGER_SCRIPT_PATH:
		return
	node.set_script(RULE_MANAGER_SCRIPT)
