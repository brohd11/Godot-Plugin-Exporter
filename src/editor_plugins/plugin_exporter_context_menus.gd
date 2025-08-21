extends EditorContextMenuPlugin

const SLOT = EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR_CODE

const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const PopupWrapper = UtilsRemote.PopupWrapper

const DEPENDENCY_TAGS = ["#! remote-dep", "#! dependency"]

const DEPENDENCY = "Plugin Exporter/Dependency"
const REMOTE_DEP = "Plugin Exporter/Remote Dep"
const EXPORTED_FLAG = "Plugin Exporter/Exported Flag"
const EXPORTED_FLAT_FLAG = "Plugin Exporter/Export Flat Flag"


func _popup_menu(paths: PackedStringArray) -> void:
	var script_editor:CodeEdit = Engine.get_main_loop().root.get_node(paths[0]);
	
	var valid_items = get_valid_items(script_editor)
	PopupWrapper.create_context_plugin_items(self, script_editor, valid_items, _on_popup_pressed)


func _on_popup_pressed(script_editor, item_name):
	if item_name == EXPORTED_FLAT_FLAG:
		add_export_flat_flag(script_editor)
	elif item_name == EXPORTED_FLAG:
		add_exported_flag(script_editor)
	elif item_name == DEPENDENCY:
		add_dep_tag(script_editor)
	elif item_name == REMOTE_DEP:
		add_remote_dep_tag(script_editor)

static func get_valid_items(script_editor:CodeEdit) -> Dictionary:
	var valid_items = {}
	var first_line = script_editor.get_line(0)
	var line = script_editor.get_caret_line()
	var text = script_editor.get_line(line)
	if text == "":
		valid_items[EXPORTED_FLAG] = {}
		valid_items[EXPORTED_FLAT_FLAG] = {}
	
	if text.count('"') == 2:
		var valid_dep = true
		for tag in DEPENDENCY_TAGS:
			if text.find(tag) > -1:
				valid_dep = false
		var file_path = text.get_slice('"', 1)
		file_path = file_path.get_slice('"', 0)
		if not FileAccess.file_exists(file_path):
			valid_dep = false
		if valid_dep:
			if first_line.find("#! remote") == -1:
				valid_items[DEPENDENCY] = {}
			else:
				valid_items[REMOTE_DEP] = {}
	
	return valid_items


static func add_dep_tag(script_editor):
	var line = script_editor.get_caret_line()
	var text = script_editor.get_line(line)
	script_editor.insert_text(" #! dependency", line, text.length())


static func add_remote_dep_tag(script_editor):
	var line = script_editor.get_caret_line()
	var text = script_editor.get_line(line)
	script_editor.insert_text(" #! remote-dep", line, text.length())


static func add_exported_flag(script_editor):
	var line = script_editor.get_caret_line()
	var text = script_editor.get_line(line)
	script_editor.insert_text("const PLUGIN_EXPORTED = false", line, 0)


static func add_export_flat_flag(script_editor):
	var line = script_editor.get_caret_line()
	var text = script_editor.get_line(line)
	script_editor.insert_text("const PLUGIN_EXPORT_FLAT = false", line, 0)
