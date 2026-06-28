@tool
extends EditorScript

const APPLY_CHANGES := false # keep false first; change to true after preview looks correct

const PREVIEW_DIR := "res://_cleanup_preview"
const BACKUP_DIR := "res://_cleanup_backup"

const BASE_MANAGER := "res://battlefield/BattlefieldManager.gd"
const BASE_CARD := "res://cards/Card3D_Test.gd"
const CARD_SCENE := "res://cards/Card3D_Test.tscn"
const MENU_SCRIPT := "res://ui/PrototypeMenu.gd"

const MANAGER_PATCHES := [
	"res://battlefield/BattlefieldManagerVolleyPatch.gd",
	"res://battlefield/BattlefieldManagerVolleyPatch4.gd",
	"res://battlefield/BattlefieldManagerIconPatch.gd",
	"res://battlefield/BattlefieldManagerUiFollowup.gd",
]

const CARD_PATCH := "res://cards/Card3D_TestUiPatch.gd"

const MANAGER_FUNCS := [
	"ability_requires_choice",
	"activate_mobility_ability_from_slot",
	"_mark_and_polish_tree",
	"refresh_player_usable_ability_icons",
	"add_active_mobility_actions_to_board_menu",
	"can_activate_mobility_ability",
	"can_activate_lane_shift_to_empty",
	"get_empty_player_front_slots_excluding",
	"resolve_lane_shift",
	"can_activate_volley_ability",
	"get_volley_target_lanes_for_slot",
	"get_volley_target_slots_for_slot",
	"resolve_volley_from_slot",
	"prepare_player_volley_lane_action",
	"resolve_player_attack_lane_from_specific_attacker",
	"resolve_volley_attack_into_face_down_backrow",
	"resolve_vanish_when_targeted",
	"polish_card_ability_icons",
	"polish_card_visual_ability_icons",
	"_on_card_ability_icon_hovered",
	"_on_card_ability_icon_unhovered",
	"show_mobility_prompt",
	"hide_mobility_prompt",
	"prompt_mobility_choice",
	"get_or_create_mobility_prompt_row",
]

const CARD_FUNCS := [
	"create_ability_icon_3d",
	"_on_ability_icon_mouse_entered",
	"_on_ability_icon_mouse_exited",
]


func _run() -> void:
	print("=== Consolidating Mobility patches ===")

	_make_dir(PREVIEW_DIR)
	_make_dir(BACKUP_DIR)

	var manager_text := _read(BASE_MANAGER)
	var card_text := _read(BASE_CARD)
	var card_scene_text := _read(CARD_SCENE)
	var menu_text := _read(MENU_SCRIPT)

	if manager_text == "" or card_text == "":
		push_error("Missing base files. Aborting.")
		return

	var manager_constants := ""
	var manager_replacements := {}

	for patch_path in MANAGER_PATCHES:
		var patch_text := _read(patch_path)
		if patch_text == "":
			print("Skipping missing patch: ", patch_path)
			continue

		manager_constants += _extract_top_level_consts(patch_text)

		for fn_name in MANAGER_FUNCS:
			var block := _extract_func_block(patch_text, fn_name)
			if block != "":
				manager_replacements[fn_name] = block

	manager_text = _add_constants_once(manager_text, manager_constants, "MOBILITY CLEANUP CONSTANTS")

	for fn_name in manager_replacements.keys():
		var new_block: String = manager_replacements[fn_name]

		var super_call := "super." + String(fn_name) + "("
		if new_block.find(super_call) != -1:
			var base_func_name := String(fn_name) + "_base"
			var old_block := _extract_func_block(manager_text, String(fn_name))

			if old_block != "":
				var renamed_old_block := old_block.replace(
					"func " + String(fn_name) + "(",
					"func " + base_func_name + "("
				)

				if manager_text.find("func " + base_func_name + "(") == -1:
					manager_text = manager_text.strip_edges(false, true) + "\n\n\n" + renamed_old_block

				new_block = new_block.replace(super_call, base_func_name + "(")

		manager_text = _replace_or_append_func(manager_text, String(fn_name), new_block)

	manager_text = _ensure_process_calls_polish(manager_text)

	var card_patch_text := _read(CARD_PATCH)
	if card_patch_text != "":
		card_text = _add_constants_once(card_text, _extract_top_level_consts(card_patch_text), "CARD UI CLEANUP CONSTANTS")

		for fn_name in CARD_FUNCS:
			var block := _extract_func_block(card_patch_text, fn_name)
			if block != "":
				card_text = _replace_or_append_func(card_text, fn_name, block)

	card_scene_text = card_scene_text.replace("res://cards/Card3D_TestUiPatch.gd", "res://cards/Card3D_Test.gd")
	menu_text = menu_text.replace("res://battlefield/battlefield_3d_mobility_scene.tscn", "res://battlefield/battlefield_3d.tscn")

	_write(PREVIEW_DIR + "/BattlefieldManager.gd.txt", manager_text)
	_write(PREVIEW_DIR + "/Card3D_Test.gd.txt", card_text)
	_write(PREVIEW_DIR + "/Card3D_Test.tscn.txt", card_scene_text)
	_write(PREVIEW_DIR + "/PrototypeMenu.gd.txt", menu_text)

	if APPLY_CHANGES:
		_backup(BASE_MANAGER)
		_backup(BASE_CARD)
		_backup(CARD_SCENE)
		_backup(MENU_SCRIPT)

		_write(BASE_MANAGER, manager_text)
		_write(BASE_CARD, card_text)
		_write(CARD_SCENE, card_scene_text)
		_write(MENU_SCRIPT, menu_text)

		print("APPLIED. Backups written to ", BACKUP_DIR)
	else:
		print("Preview written to ", PREVIEW_DIR)
		print("No original files changed. Review preview first, then set APPLY_CHANGES := true.")


func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Could not write: " + path)
		return
	f.store_string(text)
	f.close()


func _make_dir(path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path)


func _backup(path: String) -> void:
	var backup_name := path.replace("res://", "").replace("/", "__") + ".txt"
	_write(BACKUP_DIR + "/" + backup_name, _read(path))


func _extract_top_level_consts(text: String) -> String:
	var out := ""
	for line in text.split("\n"):
		if line.begins_with("const "):
			out += line + "\n"
	return out


func _add_constants_once(base_text: String, constants_text: String, marker_name: String) -> String:
	if constants_text.strip_edges() == "":
		return base_text

	var marker := "# BEGIN " + marker_name
	if base_text.find(marker) != -1:
		return base_text

	var block := "\n" + marker + "\n" + constants_text + "# END " + marker_name + "\n"

	var insert_at := base_text.find("@onready")
	if insert_at == -1:
		insert_at = base_text.find("var ")
	if insert_at == -1:
		return base_text + block

	return base_text.substr(0, insert_at) + block + "\n" + base_text.substr(insert_at)


func _extract_func_block(text: String, fn_name: String) -> String:
	var pattern := "func " + fn_name + "("
	var start := text.find(pattern)
	if start == -1:
		return ""

	var next := text.find("\nfunc ", start + pattern.length())
	if next == -1:
		next = text.length()

	return text.substr(start, next - start).strip_edges(false, true) + "\n"


func _replace_or_append_func(base_text: String, fn_name: String, new_block: String) -> String:
	var pattern := "func " + fn_name + "("
	var start := base_text.find(pattern)

	if start == -1:
		return base_text.strip_edges(false, true) + "\n\n\n" + new_block

	var next := base_text.find("\nfunc ", start + pattern.length())
	if next == -1:
		next = base_text.length()

	return base_text.substr(0, start) + new_block + base_text.substr(next)


func _ensure_process_calls_polish(text: String) -> String:
	if text.find("polish_card_ability_icons()") != -1:
		return text

	var pattern := "func _process("
	var start := text.find(pattern)

	if start == -1:
		return text + "\n\nfunc _process(_delta: float) -> void:\n\tpolish_card_ability_icons()\n"

	var line_end := text.find("\n", start)
	if line_end == -1:
		return text

	return text.substr(0, line_end + 1) + "\tpolish_card_ability_icons()\n" + text.substr(line_end + 1)
