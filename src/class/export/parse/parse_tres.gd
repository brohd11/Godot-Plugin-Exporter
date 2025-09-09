extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"

func set_parse_settings(settings):
	pass

func get_direct_dependencies(file_path:String) -> Dictionary:
	var dependencies = {}
	return dependencies

func post_export_edit_line(line:String) -> String:
	return line

func post_export_edit_file(file_path:String, file_lines:Variant=null) -> Variant:
	return

func _update_file_export_flags(line:String) -> String:
	return line
