extends "res://addons/addon_lib/brohd/popup_wrapper/pw_context_logic_base.gd"

const Slot = EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR_CODE
const PostPopup = false

static func get_callable():
	return custom_item_pressed

static func get_popup_data(script_editor:CodeEdit) -> Dictionary:
	var line = script_editor.get_caret_line()
	var text = script_editor.get_line(line)
	if text== "":
		return {"Plugin Exporter/Export Flat Flag":{Params.CALLABLE_KEY: custom_item_pressed}}
	return {}

static func custom_item_pressed(id:int, popup:PopupMenu, script_editor:CodeEdit):
	add_export_flat_flag(script_editor)

static func add_export_flat_flag(script_editor):
	var line = script_editor.get_caret_line()
	var text = script_editor.get_line(line)
	script_editor.insert_text("const PLUGIN_EXPORT_FLAT = false", line, 0)
