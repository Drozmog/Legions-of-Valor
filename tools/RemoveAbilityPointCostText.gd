@tool
extends EditorScript

const ROOT := "res://abilities/definitions"


func _run() -> void:
	var files: Array[String] = []
	_collect_tres_files(ROOT, files)

	var checked := 0
	var fixed := 0
	var skipped := 0
	var failed := 0

	for path in files:
		checked += 1

		var resource := ResourceLoader.load(path)
		if not resource is AbilityData:
			skipped += 1
			continue

		var ability := resource as AbilityData
		var original_text := ability.rules_text
		var cleaned_text := _remove_point_cost_lines(original_text)

		if cleaned_text == original_text:
			skipped += 1
			continue

		_make_backup(path)

		ability.rules_text = cleaned_text

		var err := ResourceSaver.save(ability, path)
		if err == OK:
			print("Removed Point Cost text from: ", path)
			fixed += 1
		else:
			push_error("Failed to save %s | Error: %s" % [path, err])
			failed += 1

	print("--------------------------------")
	print("Remove Point Cost text complete.")
	print("Checked: ", checked)
	print("Fixed: ", fixed)
	print("Skipped: ", skipped)
	print("Failed: ", failed)
	print("--------------------------------")

	get_editor_interface().get_resource_filesystem().scan()


func _remove_point_cost_lines(text: String) -> String:
	var output_lines: PackedStringArray = []

	for line in text.split("\n"):
		var trimmed := line.strip_edges()

		if trimmed.begins_with("Point Cost:"):
			continue

		output_lines.append(line)

	var cleaned := "\n".join(output_lines)

	while cleaned.contains("\n\n\n"):
		cleaned = cleaned.replace("\n\n\n", "\n\n")

	return cleaned.strip_edges()


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


func _make_backup(path: String) -> void:
	var backup_path := path + ".before_point_cost_cleanup.bak"

	if FileAccess.file_exists(backup_path):
		return

	var text := FileAccess.get_file_as_string(path)
	var file := FileAccess.open(backup_path, FileAccess.WRITE)

	if file == null:
		push_warning("Could not create backup for: " + path)
		return

	file.store_string(text)
	file.close()
