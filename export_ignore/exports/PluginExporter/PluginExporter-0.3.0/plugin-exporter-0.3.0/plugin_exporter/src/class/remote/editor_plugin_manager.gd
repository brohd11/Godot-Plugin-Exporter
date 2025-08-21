@tool
extends RefCounted

const PLUGIN_EXPORTED = true
const PLUGIN_EXPORT_FLAT = true

const UFile = preload("u_file.gd")

var plugin:EditorPlugin

#var _check_for_zyx:=false

var _code_completions_instances:Dictionary = {}
var _context_plugin_instances:Dictionary = {}
var _inspector_plugin_instances:Dictionary = {}
var _syntax_highlighter_instances:Dictionary = {}
var _editor_plugin_instances:Dictionary = {}

var code_completion_paths:Array = []
var context_menu_plugin_paths:Array = []
var inspector_plugin_paths:Array = []
var syntax_highlighter_paths:Array = []
var editor_plugin_paths:Array = []

func _init(_plugin:EditorPlugin, plugins_file_path:="", check_for_zyx:=false) -> void:
	plugin = _plugin
	#_check_for_zyx = check_for_zyx
	if plugins_file_path != "":
		load_paths_from_file(plugins_file_path)
		add_plugins()

func load_paths_from_file(path) -> void:
	
	var data = UFile.read_from_json(path)
	code_completion_paths = data.get("code_completion", [])
	context_menu_plugin_paths = data.get("context_menu", [])
	inspector_plugin_paths = data.get("inspector", [])
	syntax_highlighter_paths = data.get("syntax_highlighter", [])
	editor_plugin_paths = data.get("editor_plugin", [])

func add_plugins() -> void:
	add_code_completions()
	add_context_menu_plugins()
	add_inspector_plugins()
	add_syntax_highlighters()
	add_editor_plugins()

func remove_plugins() -> void:
	_remove_code_completions()
	_remove_context_menu_plugins()
	_remove_inspector_plugins()
	_remove_syntax_highlighters()
	_remove_editor_plugins()

#region Add/Remove Logic

#region Code Completions
func add_code_completions(code_completions=null) -> void:
	if code_completions == null:
		code_completions = code_completion_paths
	
	for path_or_script in code_completions:
		var script_data = _get_plugin_script(path_or_script)
		if script_data.is_empty():
			continue
		var path = script_data[0]
		var script:Script = script_data[1]
		
		var ins = script.new()
		#if ins is 
		plugin.add_child(ins)
		_code_completions_instances[path] = ins

func _remove_code_completions() -> void:
	for path in _code_completions_instances.keys():
		var ins = _code_completions_instances.get(path)
		ins.queue_free()
		_code_completions_instances.erase(path)

#endregion

#region Context Menu Plugins
func add_context_menu_plugins(context_menu_plugins=null) -> void:
	#if _check_for_zyx: # I THINK THIS CAN BE DEPRECATED
		#if PLUGIN_EXPORT_FLAT and UFile.plugin_exported_file_exists("zyx_popup_wrapper_plugin_logic.gd"):
			#return
		#if DirAccess.dir_exists_absolute("res://addons/zyx_popup_wrapper"):
			#return
	
	if context_menu_plugins == null:
		context_menu_plugins = context_menu_plugin_paths
	
	for path_or_script in context_menu_plugins:
		var script_data = _get_plugin_script(path_or_script)
		if script_data.is_empty():
			continue
		var path = script_data[0]
		var script:Script = script_data[1]
		if "SLOT" in script:
			var ins = script.new()
			if ins is EditorContextMenuPlugin:
				plugin.add_context_menu_plugin(ins.SLOT, ins)
				_context_plugin_instances[path] = ins
			else:
				ins.queue_free()

func _remove_context_menu_plugins() -> void:
	if not PLUGIN_EXPORTED:
		print(_context_plugin_instances)
	for instance_name in _context_plugin_instances.keys():
		var instance = _context_plugin_instances.get(instance_name)
		if is_instance_valid(instance):
			if not PLUGIN_EXPORTED:
				print("REMOVE", instance)
			plugin.remove_context_menu_plugin(instance)
		_context_plugin_instances.erase(instance_name)

#endregion

#region Inspector Plugins
func add_inspector_plugins(inspector_plugins=null) -> void:
	if inspector_plugins == null:
		inspector_plugins = inspector_plugin_paths
	
	for path_or_script in inspector_plugins:
		var script_data = _get_plugin_script(path_or_script)
		if script_data.is_empty():
			continue
		var path = script_data[0]
		var script:Script = script_data[1]
		
		var instance = script.new()
		plugin.add_inspector_plugin(instance)
		_inspector_plugin_instances[path] = instance

func _remove_inspector_plugins() -> void:
	for key in _inspector_plugin_instances.keys():
		var instance = _inspector_plugin_instances.get(key)
		plugin.remove_inspector_plugin(instance)
		_inspector_plugin_instances.erase(key)

#endregion


#region Syntax Highlighters
func add_syntax_highlighters(highlighters=null) -> void:
	if highlighters == null:
		highlighters = syntax_highlighter_paths
	
	for path_or_script in highlighters:
		var script_data = _get_plugin_script(path_or_script)
		if script_data.is_empty():
			continue
		var path = script_data[0]
		var script:Script = script_data[1]
		
		var highlighter = script.new()
		EditorInterface.get_script_editor().register_syntax_highlighter(highlighter)
		_syntax_highlighter_instances[path] = highlighter

func _remove_syntax_highlighters() -> void:
	for key in _syntax_highlighter_instances.keys():
		var highlighter = _syntax_highlighter_instances.get(key)
		EditorInterface.get_script_editor().unregister_syntax_highlighter(highlighter)
		_syntax_highlighter_instances.erase(key)

#endregion


#region Editor Plugins
func add_editor_plugins(editor_plugins=null) -> void:
	if editor_plugins == null:
		editor_plugins = editor_plugin_paths
	
	for path_or_script in editor_plugins:
		var script_data = _get_plugin_script(path_or_script)
		if script_data.is_empty():
			continue
		var path = script_data[0]
		var script:Script = script_data[1]
		
		var file_name = path.get_file()
		if file_name.find("_plugin_logic") > -1:
			var plugin_name = file_name.get_slice("_plugin_logic", 0)
			var plugin_dir = "res://addons/%s" % plugin_name
			if DirAccess.dir_exists_absolute(plugin_dir):
				print("Plugin exists, not enabling: %s" % plugin_name)
				continue
		
		var editor_plugin = script.new(plugin)
		plugin.add_child(editor_plugin)
		_editor_plugin_instances[path] = editor_plugin

func _remove_editor_plugins() -> void:
	for key in _editor_plugin_instances.keys():
		var editor_plugin = _editor_plugin_instances.get(key)
		editor_plugin.queue_free()
		_editor_plugin_instances.erase(key)

#endregion


#endregion


func _get_plugin_script(path) -> Array:
	var script:Script
	if path is Script:
		script = path
		path = script.resource_path
	elif path is String:
		if not FileAccess.file_exists(path):
			path = UFile.get_plugin_exported_path(path, false, PLUGIN_EXPORTED)
			if path == "":
				return []
		
		script = load(path)
	return [path, script]


