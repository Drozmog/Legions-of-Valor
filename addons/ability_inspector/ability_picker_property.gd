@tool
extends EditorProperty

var card: CardData
var root: VBoxContainer
var result_picker: OptionButton
var search_box: LineEdit
var add_button: Button
var status_label: Label

var query := ""
var rebuilding := false
var search_results: Array[AbilityData] = []


func setup(target: CardData) -> void:
	card = target

	root = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(root)
	set_bottom_editor(root)

	AbilityDatabase.reload()
	_rebuild()


func _update_property() -> void:
	_rebuild()


func _rebuild() -> void:
	if root == null or rebuilding:
		return

	rebuilding = true

	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()

	_add_current_abilities_section()
	_add_search_section()

	rebuilding = false
	_refresh_search_results()


func _add_current_abilities_section() -> void:
	var title := Label.new()
	title.text = "Assigned Abilities"
	root.add_child(title)

	if card == null:
		return

	if card.abilities.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No abilities assigned yet."
		empty_label.modulate = Color(0.75, 0.75, 0.75)
		root.add_child(empty_label)
		return

	for index in range(card.abilities.size()):
		_add_ability_row(index, card.abilities[index])


func _add_ability_row(index: int, ability: AbilityData) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(row)

	if ability != null and ability.icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = ability.icon
		icon_rect.custom_minimum_size = Vector2(22, 22)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon_rect)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if ability == null:
		label.text = "[Empty Ability]"
	else:
		label.text = "%s  —  %s" % [ability.ability_name, ability.category.capitalize()]
		label.tooltip_text = ability.rules_text

	row.add_child(label)

	var remove_button := Button.new()
	remove_button.text = "Remove"
	remove_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	remove_button.pressed.connect(func() -> void:
		_remove_ability(index)
	)
	row.add_child(remove_button)


func _add_search_section() -> void:
	var spacer := HSeparator.new()
	root.add_child(spacer)

	var title := Label.new()
	title.text = "Add Ability by Name"
	root.add_child(title)

	search_box = LineEdit.new()
	search_box.placeholder_text = "Type ability name, e.g. Banish, Pierce, Loyalty..."
	search_box.text = query
	search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_box.text_changed.connect(func(new_text: String) -> void:
		query = new_text
		_refresh_search_results()
	)
	search_box.text_submitted.connect(func(_submitted_text: String) -> void:
		_add_selected_or_best_result()
	)
	root.add_child(search_box)

	result_picker = OptionButton.new()
	result_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_picker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	root.add_child(result_picker)

	add_button = Button.new()
	add_button.text = "Add Selected Ability"
	add_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_button.pressed.connect(_add_selected_or_best_result)
	root.add_child(add_button)

	var reload_button := Button.new()
	reload_button.text = "Reload Ability List"
	reload_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	reload_button.pressed.connect(func() -> void:
		AbilityDatabase.reload()
		_refresh_search_results()
	)
	root.add_child(reload_button)

	status_label = Label.new()
	status_label.modulate = Color(0.75, 0.75, 0.75)
	root.add_child(status_label)


func _refresh_search_results() -> void:
	if result_picker == null or add_button == null:
		return

	result_picker.clear()
	search_results.clear()

	var clean_query := _normalize(query)

	if clean_query.is_empty():
		result_picker.add_item("Type an ability name above")
		result_picker.disabled = true
		add_button.disabled = true
		if status_label != null:
			status_label.text = ""
		return

	var scored_results: Array[Dictionary] = []

	for ability in AbilityDatabase.get_all_abilities():
		if ability == null:
			continue

		var score := _get_search_score(ability, clean_query)

		if score > 0:
			scored_results.append({
				"score": score,
				"ability": ability
			})

	scored_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["score"]) == int(b["score"]):
			var ability_a := a["ability"] as AbilityData
			var ability_b := b["ability"] as AbilityData
			return ability_a.ability_name.naturalnocasecmp_to(ability_b.ability_name) < 0

		return int(a["score"]) > int(b["score"])
	)

	var max_results := min(scored_results.size(), 12)

	for i in range(max_results):
		var ability := scored_results[i]["ability"] as AbilityData
		search_results.append(ability)

		var label := "%s  —  %s  /  %s" % [
			ability.ability_name,
			ability.category.capitalize(),
			ability.trigger
		]

		result_picker.add_item(label)
		result_picker.set_item_metadata(result_picker.item_count - 1, ability)

	if search_results.is_empty():
		result_picker.add_item("No matching abilities found")
		result_picker.disabled = true
		add_button.disabled = true
		if status_label != null:
			status_label.text = "No ability matched: " + query
	else:
		result_picker.disabled = false
		add_button.disabled = false
		result_picker.select(0)
		if status_label != null:
			status_label.text = "Matches found: " + str(search_results.size())


func _get_search_score(ability: AbilityData, clean_query: String) -> int:
	var ability_name := _normalize(ability.ability_name)
	var ability_id := _normalize(String(ability.ability_id))
	var ability_id_spaced := _normalize(String(ability.ability_id).replace("_", " "))
	var category := _normalize(ability.category)
	var trigger := _normalize(ability.trigger)

	var combined := "%s %s %s %s %s" % [
		ability_name,
		ability_id,
		ability_id_spaced,
		category,
		trigger
	]

	if ability_name == clean_query:
		return 100

	if ability_id == clean_query:
		return 100

	if ability_id_spaced == clean_query:
		return 95

	if ability_name.begins_with(clean_query):
		return 85

	if ability_id_spaced.begins_with(clean_query):
		return 80

	if ability_name.contains(clean_query):
		return 65

	if ability_id_spaced.contains(clean_query):
		return 60

	var words := clean_query.split(" ", false)
	var all_words_found := true

	for word in words:
		if not combined.contains(word):
			all_words_found = false
			break

	if all_words_found:
		return 45

	return 0


func _add_selected_or_best_result() -> void:
	if result_picker == null or result_picker.disabled:
		return

	var selected_index := result_picker.selected

	if selected_index < 0:
		selected_index = 0

	var ability := result_picker.get_item_metadata(selected_index) as AbilityData

	if ability == null:
		return

	_add_ability(ability)


func _add_ability(ability: AbilityData) -> void:
	if card == null or ability == null:
		return

	for existing in card.abilities:
		if existing != null and existing.ability_id == ability.ability_id:
			if status_label != null:
				status_label.text = "Already added: " + ability.ability_name
			return

	var next: Array[AbilityData] = card.abilities.duplicate()
	next.append(ability)

	_commit(next)

	query = ""
	_rebuild()


func _remove_ability(index: int) -> void:
	if card == null:
		return

	if index < 0 or index >= card.abilities.size():
		return

	var next: Array[AbilityData] = card.abilities.duplicate()
	next.remove_at(index)

	_commit(next)


func _commit(value: Array[AbilityData]) -> void:
	if card == null:
		return

	card.abilities = value
	card.emit_changed()
	emit_changed(get_edited_property(), value)
	_rebuild()


func _normalize(value: String) -> String:
	return value.strip_edges().to_lower().replace("_", " ")
