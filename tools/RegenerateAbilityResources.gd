@tool
extends EditorScript

const ROOT := "res://abilities/definitions"
const ICON_ROOT := "res://ui/ability_icons"


func _run() -> void:
	var files: Array[String] = []
	_collect_tres_files(ROOT, files)

	print("Found ability .tres files: ", files.size())

	var saved := 0
	var failed := 0

	for path in files:
		if path.ends_with("test_ability.tres"):
			continue

		var original_text := FileAccess.get_file_as_string(path)
		if original_text.strip_edges().is_empty():
			push_warning("Skipped empty file: " + path)
			failed += 1
			continue

		_make_backup(path, original_text)

		var props := _read_existing_properties(original_text)

		var ability := AbilityData.new()

		ability.ability_id = StringName(str(props.get("ability_id", _basename_without_ext(path))))
		ability.ability_name = str(props.get("ability_name", String(ability.ability_id).capitalize()))
		ability.category = str(props.get("category", _category_from_path(path)))
		ability.point_cost = float(props.get("point_cost", 0.0))
		ability.trigger = str(props.get("trigger", "passive"))
		ability.rules_text = str(props.get("rules_text", ""))

		var icon_path := "%s/%s.png" % [ICON_ROOT, ability.category]
		if ResourceLoader.exists(icon_path):
			ability.icon = load(icon_path) as Texture2D
		else:
			ability.icon = null
			push_warning("Missing icon for " + path + ": " + icon_path)

		ability.handler_id = StringName(str(props.get("handler_id", String(ability.ability_id))))

		var err := ResourceSaver.save(ability, path)

		if err == OK:
			print("Saved: ", path)
			saved += 1
		else:
			push_error("Failed to save %s | Error: %s" % [path, err])
			failed += 1

	print("--------------------------------")
	print("Ability resource regeneration done.")
	print("Saved: ", saved)
	print("Failed: ", failed)
	print("--------------------------------")

	get_editor_interface().get_resource_filesystem().scan()


func _collect_tres_files(folder_path: String, files: Array[String]) -> void:
	var dir := DirAccess.open(folder_path)
	if dir == null:
		push_error("Could not open folder: " + folder_path)
		return

	dir.list_dir_begin()

	while true:
		var item := dir.get_next()
		if item == "":
			break

		if item.begins_with("."):
			continue

		var full_path := folder_path.path_join(item)

		if dir.current_is_dir():
			_collect_tres_files(full_path, files)
		elif item.ends_with(".tres"):
			files.append(full_path)

	dir.list_dir_end()


func _read_existing_properties(text: String) -> Dictionary:
	var props := {}

	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()

		if line.is_empty():
			continue

		if line.begins_with("["):
			continue

		var equals_index := line.find("=")
		if equals_index == -1:
			continue

		var key := line.substr(0, equals_index).strip_edges()
		var value := line.substr(equals_index + 1).strip_edges()

		if key == "script":
			continue

		if key == "icon":
			continue

		props[key] = _parse_tres_value(value)

	return props


func _parse_tres_value(value: String) -> Variant:
	if value.begins_with("&\""):
		return _parse_quoted_string(value.substr(1))

	if value.begins_with("\""):
		return _parse_quoted_string(value)

	if value.is_valid_float():
		return value.to_float()

	if value.is_valid_int():
		return value.to_int()

	return value


func _parse_quoted_string(value: String) -> String:
	var parsed = JSON.parse_string(value)

	if typeof(parsed) == TYPE_STRING:
		return parsed

	if value.begins_with("\"") and value.ends_with("\""):
		value = value.substr(1, value.length() - 2)

	return value.replace("\\n", "\n").replace("\\\"", "\"").replace("\\\\", "\\")


func _make_backup(path: String, original_text: String) -> void:
	var backup_path := path + ".bak"

	if FileAccess.file_exists(backup_path):
		return

	var file := FileAccess.open(backup_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not make backup for: " + path)
		return

	file.store_string(original_text)
	file.close()


func _basename_without_ext(path: String) -> String:
	var file_name := path.get_file()
	return file_name.get_basename()


func _category_from_path(path: String) -> String:
	var parts := path.split("/")
	var index := parts.find("definitions")

	if index != -1 and index + 1 < parts.size():
		return parts[index + 1]

	return "assault"
