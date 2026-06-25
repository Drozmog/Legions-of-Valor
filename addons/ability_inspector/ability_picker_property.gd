@tool
extends EditorProperty

var card: CardData
var rows: VBoxContainer
var rebuilding := false


func setup(target: CardData) -> void:
	card = target
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(rows)
	set_bottom_editor(rows)
	_rebuild()


func _update_property() -> void:
	_rebuild()


func _rebuild() -> void:
	if rows == null or rebuilding:
		return
	rebuilding = true
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()

	if card != null:
		for index in range(card.abilities.size()):
			_add_ability_row(index, card.abilities[index])
		if card.abilities.is_empty() and not card.get_abilities().is_empty():
			var migrate_button := Button.new()
			migrate_button.text = "Import Recognized Legacy Abilities"
			migrate_button.tooltip_text = "Convert names recognized in legacy ability text into AbilityData references."
			migrate_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			migrate_button.pressed.connect(func() -> void:
				_commit(card.get_abilities())
			)
			rows.add_child(migrate_button)

	var add_button := Button.new()
	add_button.text = "+ Add Ability"
	add_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_button.pressed.connect(_add_ability)
	rows.add_child(add_button)
	rebuilding = false


func _add_ability_row(index: int, current: AbilityData) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(row)

	var category_picker := OptionButton.new()
	category_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_picker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var selected_category: String = current.category if current != null else AbilityDatabase.CATEGORIES[0]
	for category in AbilityDatabase.CATEGORIES:
		category_picker.add_item(category.capitalize())
		category_picker.set_item_metadata(category_picker.item_count - 1, category)
		if category == selected_category:
			category_picker.select(category_picker.item_count - 1)
	row.add_child(category_picker)

	var ability_picker := OptionButton.new()
	ability_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ability_picker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_populate_ability_picker(ability_picker, selected_category, current)
	row.add_child(ability_picker)

	var remove_button := Button.new()
	remove_button.text = "-"
	remove_button.tooltip_text = "Remove ability"
	remove_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.add_child(remove_button)

	category_picker.item_selected.connect(func(selected: int) -> void:
		var category := String(category_picker.get_item_metadata(selected))
		_populate_ability_picker(ability_picker, category, null)
		if ability_picker.item_count > 0:
			_set_ability(index, ability_picker.get_item_metadata(0) as AbilityData)
	)
	ability_picker.item_selected.connect(func(selected: int) -> void:
		_set_ability(index, ability_picker.get_item_metadata(selected) as AbilityData)
	)
	remove_button.pressed.connect(func() -> void:
		_remove_ability(index)
	)


func _populate_ability_picker(picker: OptionButton, category: String, selected: AbilityData) -> void:
	picker.clear()
	for ability in AbilityDatabase.get_abilities_by_category(category):
		picker.add_item(ability.ability_name)
		var item_index := picker.item_count - 1
		picker.set_item_metadata(item_index, ability)
		if selected != null and ability.ability_id == selected.ability_id:
			picker.select(item_index)
	if picker.item_count == 0:
		picker.add_item("No abilities in category")
		picker.disabled = true
	else:
		picker.disabled = false


func _add_ability() -> void:
	var candidates := AbilityDatabase.get_all_abilities()
	if candidates.is_empty() or card == null:
		return
	var next: Array[AbilityData] = card.abilities.duplicate()
	next.append(candidates[0])
	_commit(next)


func _set_ability(index: int, ability: AbilityData) -> void:
	if card == null or ability == null or index < 0 or index >= card.abilities.size():
		return
	var next: Array[AbilityData] = card.abilities.duplicate()
	next[index] = ability
	_commit(next)


func _remove_ability(index: int) -> void:
	if card == null or index < 0 or index >= card.abilities.size():
		return
	var next: Array[AbilityData] = card.abilities.duplicate()
	next.remove_at(index)
	_commit(next)


func _commit(value: Array[AbilityData]) -> void:
	card.abilities = value
	card.emit_changed()
	emit_changed(get_edited_property(), value)
	_rebuild()
