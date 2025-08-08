extends EditorContextMenuPlugin

const Slot = ContextMenuSlot.CONTEXT_SLOT_SCRIPT_EDITOR_CODE
const ExportFlatLogic = preload("res://addons/plugin_exporter/src/editor_plugins/pe_export_flat_context_logic.gd")
const ExportedLogic = preload("res://addons/plugin_exporter/src/editor_plugins/pe_exported_context_logic.gd")
const DepTagLogic = preload("res://addons/plugin_exporter/src/editor_plugins/pe_dep_tag_context_logic.gd")
const RemoteDepLogic = preload("res://addons/plugin_exporter/src/editor_plugins/pe_remote_dep_context_logic.gd")


func _popup_menu(paths: PackedStringArray) -> void:
	var se:CodeEdit = Engine.get_main_loop().root.get_node(paths[0]);
	
	var popup_data = ExportFlatLogic.get_popup_data(se)
	var exp_popup_data = ExportedLogic.get_popup_data(se)
	popup_data.merge(exp_popup_data)
	var dep_popup_data = DepTagLogic.get_popup_data(se)
	popup_data.merge(dep_popup_data)
	var rem_dep_data = RemoteDepLogic.get_popup_data(se)
	popup_data.merge(rem_dep_data)
	
	ExportFlatLogic.add_context_popups(self, se, popup_data, _on_popup_pressed)

func _on_popup_pressed(script_editor, item_name):
	if item_name == "Export Flat Flag":
		ExportFlatLogic.add_export_flat_flag(script_editor)
	elif item_name == "Exported Flag":
		ExportedLogic.add_exported_flag(script_editor)
	elif item_name == "Dependency":
		DepTagLogic.add_dep_tag(script_editor)
	elif item_name == "Remote Dep":
		RemoteDepLogic.add_remote_dep_tag(script_editor)
