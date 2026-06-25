@tool
extends EditorScript

const ROOT := "res://abilities/definitions"
const WRONG_PATH := "res://abilities_backup/AbilityData.gd"
const RIGHT_PATH := "res://abilities/AbilityData.gd"

func _run() -> void:
	var files: Array[String] = []
	_collect_tres_files(ROOT, files)

	var checked := 0
	var fixed := 0
	var skipped := 0

	for path in files:
		checked += 1

		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			push_warning("Skipped empty file: " + path)
			skipped += 1
			continue

		if not text.contains(WRONG_PATH):
			skipped += 1
			continue

		_make_backup(path, text)

		var updated := text.replace(WRONG_PATH, RIGHT_PATH)

		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("Could not write file: " + path)
			continue

		file.store_string(updated)
		file.close()

		print("Fixed: ", path)
		fixed += 1

	print("--------------------------------")
	print("Checked: ", checked)
	print("Fixed: ", fixed)
	print("Skipped: ", skipped)
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


func _make_backup(path: String, original_text: String) -> void:
	var backup_path := path + ".bak"

	if FileAccess.file_exists(backup_path):
		return

	var file := FileAccess.open(backup_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not create backup for: " + path)
		return

	file.store_string(original_text)
	file.close()
