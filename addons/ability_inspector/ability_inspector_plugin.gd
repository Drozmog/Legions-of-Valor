@tool
extends EditorInspectorPlugin

const AbilityPickerProperty := preload("res://addons/ability_inspector/ability_picker_property.gd")


func _can_handle(object: Object) -> bool:
	return object is CardData


func _parse_property(
	object: Object,
	_type: Variant.Type,
	name: String,
	_hint_type: PropertyHint,
	_hint_string: String,
	_usage_flags: int,
	_wide: bool
) -> bool:
	if name != "abilities":
		return false
	var editor := AbilityPickerProperty.new()
	editor.setup(object as CardData)
	add_property_editor(name, editor)
	return true
