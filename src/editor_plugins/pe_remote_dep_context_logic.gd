extends "res://addons/addon_lib/brohd/popup_wrapper/pw_context_logic_base.gd"

const Slot = EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR_CODE
const PostPopup = false

const DEP_TAGS = ["#! remote-dep", "#! dependency"]

static func get_callable():
	return custom_item_pressed

static func get_popup_data(script_editor:CodeEdit) -> Dictionary:
	var first_line = script_editor.get_line(0)
	if first_line.find("#! remote") == -1:
		return {}
	var line = script_editor.get_caret_line()
	var text = script_editor.get_line(line)
	if text.count('"') == 2:
		for tag in DEP_TAGS:
			if text.find(tag) > -1:
				return {}
		var file_path = text.get_slice('"', 1)
		file_path = file_path.get_slice('"', 0)
		if not FileAccess.file_exists(file_path):
			return {}
		return {"Plugin Exporter/Remote Dep":{}}
	return {}

static func custom_item_pressed(id:int, popup:PopupMenu, script_editor:CodeEdit):
	add_remote_dep_tag(script_editor)

static func add_remote_dep_tag(script_editor):
	var line = script_editor.get_caret_line()
	var text = script_editor.get_line(line)
	script_editor.insert_text(" #! remote-dep", line, text.length())
