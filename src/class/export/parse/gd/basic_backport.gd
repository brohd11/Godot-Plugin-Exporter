extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"


const EI_BACKPORT_PATH = "res://addons/plugin_exporter/src/class/export/backport/ei_backport.gd"
const EI_BACKPORT = "_EIBackport"

const VALID_4_0_WINDOW_POSITIONS = [
	"Window.WINDOW_INITIAL_POSITION_ABSOLUTE",
	"Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN",
	"Window.WINDOW_INITIAL_POSITION_CENTER_OTHER_SCREEN",
	"Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN"
]
const DEFAULT_POSITION = "Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN"

const VALID_4_0_EI_METHODS = [
	"edit_node", "edit_resource", "edit_script", "get_base_control",
	"get_command_palette", "get_current_directory", "get_current_path",
	"get_edited_scene_root", "get_editor_main_screen", "get_editor_paths",
	"get_editor_scale", "get_editor_settings", "get_file_system_dock",
	"get_inspector", "get_open_scenes", "get_playing_scene",
	"get_resource_filesystem", "get_resource_previewer", "get_script_editor", "get_selected_paths",
	"get_selection", "inspect_object", "is_movie_maker_enabled", "is_playing_scene",
	"is_plugin_enabled", "make_mesh_previews", "open_scene_from_path", "play_current_scene",
	"play_custom_scene", "play_main_scene", "reload_scene_from_path", "restart_editor", "save_scene", "save_scene_as",
	"select_file", "set_main_screen_editor", "set_movie_maker_enabled", "set_plugin_enabled", "stop_playing_scene"
]



var _indent_regex:= RegEx.new()
var _is_not_regex:= RegEx.new()
var _for_loop_type_regex:= RegEx.new()
var _ei_method_validate_regex:= RegEx.new()
var _ei_method_chain_regex:= RegEx.new()
var _ei_regex:= RegEx.new()


var _raw_string_regexes = []

var _window_regex:= RegEx.new()
var _is_part_of_edited_scene_regex:= RegEx.new()


var backport:= false

func _init() -> void:
	_string_regex = URegex.get_strings()
	
	var indent_pattern = "^(\\t*)( *)(.*)"
	_indent_regex.compile(indent_pattern)
	
	var is_not_pattern = "(\\S+)\\s+is\\s+not\\s+(\\S+)"
	_is_not_regex.compile(is_not_pattern)
	
	var for_loop_pattern = "^(\\s*for\\s+)(\\S+)\\s*:\\s*.*?(\\s+in\\s+.*)"
	_for_loop_type_regex.compile(for_loop_pattern)
	
	var ei_method_validate_pattern = "(\\bEditorInterface\\b)\\.(\\w+)"
	_ei_method_validate_regex.compile(ei_method_validate_pattern)
	
	var ei_method_chain_pattern = "(\\bEditorInterface\\b[\\w\\s\\.\\(\\)\\[\\]\"',]*)"
	_ei_method_chain_regex.compile(ei_method_chain_pattern)
	
	var ei_pattern = "\\bEditorInterface\\b"
	_ei_regex.compile(ei_pattern)
	
	var raw_string_patterns = [
	"(?s)(?<!\\w)r(\"\"\")(.*?)(\"\"\")", # 1. r"""..."""
	"(?s)(?<!\\w)r(''')(.*?)(''')",      # 2. r'''...'''
	"(?s)(?<!\\w)r(\")(.*?)(\")",        # 3. r"..."
	"(?s)(?<!\\w)r(')(.*?)(')",         # 4. r'...'
	]
	for pattern in raw_string_patterns:
		var regex = RegEx.new()
		regex.compile(pattern)
		_raw_string_regexes.append(regex)
	
	var window_pattern = "Window\\.WINDOW_INITIAL_POSITION_[A-Z_]+"
	_window_regex.compile(window_pattern)
	
	var is_part_pattern = "(?:(\\S+)\\.)?is_part_of_edited_scene\\(\\)"
	_is_part_of_edited_scene_regex.compile(is_part_pattern)
	
	#run_editor_interface_tests()
	#run_is_not_tests()
	#run_for_loop_tests()



# in parser_settings, create dictionary for extension of file,
# ie. if extension is foo, "parse_foo": {"my_setting": "value"}
func set_parse_settings(settings):
	backport = true

# logic to parse for files that are needed acts as a set, dependencies[my_dep_path] = {}
func get_direct_dependencies(file_path:String) -> Dictionary:
	var dependencies = {} 
	return dependencies
	

# first pass on post export, if the file ext is handled by default, file_lines will 
# contain modifies lines, for example, if you want to make a second pass on a gd file.
# If not handled by default, file_lines will be null. You can process and return the files lines
# or return the null value to default to the file's .
func post_export_edit_file(file_path:String, file_lines:Variant=null) -> Variant:
	if not backport:
		return file_lines
	
	var file_as_text = "\n".join(file_lines)
	var converted_file = backport_raw_strings(file_as_text)
	file_lines = converted_file.split("\n")
	
	
	var extends_class = file_extends_class(file_lines)
	if not extends_class:
		file_lines.append("### PLUGIN EXPORTER BASIC BACKPORT")
		var adj_path = export_obj.adjusted_remote_paths.get(EI_BACKPORT_PATH, EI_BACKPORT_PATH)
		file_lines.append(_construct_pre(EI_BACKPORT, adj_path))
		file_lines.append("### PLUGIN EXPORTER BASIC BACKPORT")
		file_lines.append("")
	
	return file_lines

# second pass of post export. If extension is handled by default, line will be 
# modified already. If changes were made in post_export_edit_file, these will be
# present here, else, it will be the unmodified line from the file.
func post_export_edit_line(line:String) -> String:
	if not backport:
		return line
	
	line = fix_mixed_indent(line)
	
	line = replace_ei_methods(line)
	validate_ei_methods(line)
	line = replace_editor_interface(line)
	line = remove_for_loop_type_hint(line)
	line = convert_all_is_not_syntax(line)
	line = check_window_line(line)
	line = replace_is_part_of_edited_scene(line)
	
	return line


func fix_mixed_indent(line: String) -> String:
	# The replacement string "$1$3" means:
	# - $1: the tabs
	# - $3: the code
	# deliberately leave out the spaces
	return _indent_regex.sub(line, "$1$3", true)

func validate_ei_methods(line: String):
	_string_safe_regex_sub(line, _validate_ei_methods)

func _validate_ei_methods(line: String):
	var matches = _ei_method_validate_regex.search_all(line)
	
	for _match in matches:
		var full_chain = _match.get_string(1).strip_edges()
		var method_name = _match.get_string(2) # Group 2 is the method name
		if not VALID_4_0_EI_METHODS.has(method_name):
			var file_path = export_obj.file_parser.current_file_path_parsing
			print("Found non valid 4.0 method 'EditorInterface.%s()' in: %s." % [method_name, file_path])
	
	return line

func replace_ei_methods(line: String) -> String:
	return _string_safe_regex_sub(line, _replace_ei_methods)

func _replace_ei_methods(line: String) -> String:
	var matches = _ei_method_chain_regex.search_all(line)
	
	for i in range(matches.size() - 1, -1, -1):
		var full_match: RegExMatch = matches[i]
		var chain_string = full_match.get_string(1)
		
		if "get_editor_theme" in chain_string:
			chain_string = chain_string.replace("get_editor_theme", "get_base_control")
			if "get_color" in chain_string:
				chain_string = chain_string.replace("get_color", "get_theme_color")
			if "get_icon" in chain_string:
				chain_string = chain_string.replace("get_icon", "get_theme_icon")
		
		
		var start_pos = full_match.get_start(1)
		var end_pos = full_match.get_end(1)
		line = line.substr(0, start_pos) + chain_string + line.substr(end_pos)
	
	
	
	return line

func replace_editor_interface(line: String) -> String:
	var replacement_text = "%s.get_ins().ei" % EI_BACKPORT
	var processor = func(code: String):
		return _ei_regex.sub(code, replacement_text, true)
	return _string_safe_regex_sub(line, processor)

func convert_all_is_not_syntax(line: String) -> String:
	var processor = func(code: String):
		return _is_not_regex.sub(code, "not $1 is $2", true)
	return _string_safe_regex_sub(line, processor)

func remove_for_loop_type_hint(line: String) -> String:
	var _match = _for_loop_type_regex.search(line)
	if _match:
		# $1 = "    for "
		# $2 = "i"
		# $3 = " in range(10):"
		return _for_loop_type_regex.sub(line, "$1$2$3", true)
	else:
		return line

func backport_raw_strings(script_content: String) -> String:
	for regex in _raw_string_regexes:
		while true:
			var _match = regex.search(script_content)
			if not _match:
				break
			# The capture groups are still the same: group 2 is the content.
			# The lookbehind (?<!...) is "zero-width" and doesn't count as a group.
			var raw_content = _match.get_string(2)
			var new_literal = _create_escaped_literal(raw_content)
			
			script_content = script_content.left(_match.get_start()) \
						+ new_literal \
						+ script_content.substr(_match.get_end())
	
	return script_content


func _create_escaped_literal(raw_content: String) -> String:
	var escaped_content = raw_content.replace("\\", "\\\\") # escape all backslashes.
	escaped_content = escaped_content.replace("\"", "\\\"") # escape all double-quotes
	return '"' + escaped_content + '"' # make string literal


func check_window_line(line):
	return _string_safe_regex_sub(line, _check_window)

func _check_window(line: String) -> String:
	var result: RegExMatch = _window_regex.search(line)
	if result:
		var found_constant: String = result.get_string(0)
		if not VALID_4_0_WINDOW_POSITIONS.has(found_constant):
			#print("Found invalid constant: '%s'" % found_constant)
			#print("Replacing with default: '%s'" % DEFAULT_POSITION)
			return line.replace(found_constant, DEFAULT_POSITION)
	
	return line

func replace_is_part_of_edited_scene(line: String) -> String:
	var matches = _is_part_of_edited_scene_regex.search_all(line)
	
	for i in range(matches.size() - 1, -1, -1):
		var _match: RegExMatch = matches[i]
		var subject_obj: String
		var replacement_text: String
		
		var captured_obj = _match.get_string(1)
		
		if captured_obj.is_empty():
			subject_obj = "self"
		else: # An object was captured. Use it.
			subject_obj = captured_obj
		
		# Build the new replacement string
		replacement_text = "%s.get_ins().ei.is_part_of_edited_scene_compat(%s)" % [EI_BACKPORT, subject_obj]
		
		line = line.substr(0, _match.get_start(0)) \
				+ replacement_text \
				+ line.substr(_match.get_end(0))
	
	return line



#region Tests


func run_raw_string_test():
	# Example 1: A typical Windows file path
	var raw_string_content1 = "C:\\Users\\MyUser\\Project"
	var godot4_0_compatible_string1 = _create_escaped_literal(raw_string_content1)
	print("Raw content: ", raw_string_content1)
	print("4.0 version: ", godot4_0_compatible_string1)
	# Expected output: "C:\\Users\\MyUser\\Project"

	print("---")

	# Example 2: A string containing quotes
	var raw_string_content2 = 'The command is: "run.exe" -path "C:\\data"'
	var godot4_0_compatible_string2 = _create_escaped_literal(raw_string_content2)
	print("Raw content: ", raw_string_content2)
	print("4.0 version: ", godot4_0_compatible_string2)
	# Expected output: "The command is: \"run.exe\" -path \"C:\\data\""



func run_editor_interface_tests():
	print("--- EditorInterface Examples ---")
	var line1 = "var ei = EditorInterface.get_editor_viewport()"
	print("Input:  %s" % line1)
	print("Output: %s\n" % replace_editor_interface(line1))
	# Output: var ei = EditorInterfaceBackport.get_ins().ei.get_editor_viewport()
	var line2 = "var x = 1 # We used to use EditorInterface here"
	print("Input:  %s" % line2)
	print("Output: %s\n" % replace_editor_interface(line2))
	# Output: var x = 1 # We used to use EditorInterface here
	var line3 = 'print("The old way was EditorInterface")'
	print("Input:  %s" % line3)
	print("Output: %s\n" % replace_editor_interface(line3))
	# Output: print("The old way was EditorInterface")
	var line4 = 'var custom_ei = MyCustomEditorInterface.new()'
	print("Input:  %s" % line4)
	print("Output: %s\n" % replace_editor_interface(line4))
	# Output: var custom_ei = MyCustomEditorInterface.new()


func run_is_not_tests():
	var line1 = "if x is not y and x is not z:"
	var line2 = "    var is_valid = get_node(\"Player\") is not null"
	var line3 = "while target is not null and target.name is not \"PlayerShip\":"
	var line4 = "# A comment: the variable is not initialized here." # Should NOT change
	var line5 = 'print("some_object is not MyCustomClass")'
	var line6 = "return current_state is not State.IDLE"
	
	print("--- Final Universal Tests ---")
	print("'%s' -> '%s'" % [line1, convert_all_is_not_syntax(line1)])
	print("'%s' -> '%s'" % [line2, convert_all_is_not_syntax(line2)])
	print("'%s' -> '%s'" % [line3, convert_all_is_not_syntax(line3)])
	print("'%s' -> '%s'" % [line4, convert_all_is_not_syntax(line4)])
	print("'%s' -> '%s'" % [line5, convert_all_is_not_syntax(line5)])
	print("'%s' -> '%s'" % [line6, convert_all_is_not_syntax(line6)])

func run_for_loop_tests():
	var line1 = "    for i: int in range(10):"
	var line2 = "for node:Node2D in get_children(): # With no space"
	var line3 = "	for key : String in my_dict.keys(): # With lots of space"
	var line4 = "for x in y:" # Should NOT change
	var line5 = "for i in range(10): # a comment with a colon" # Should NOT change
	var line6 = "for i:int in range(10): # a comment with a colon" # Should NOT change
	
	print("--- For-Loop Type Hint Removal Tests ---")
	print("'%s' -> '%s'" % [line1, remove_for_loop_type_hint(line1)])
	print("'%s' -> '%s'" % [line2, remove_for_loop_type_hint(line2)])
	print("'%s' -> '%s'" % [line3, remove_for_loop_type_hint(line3)])
	print("'%s' -> '%s'" % [line4, remove_for_loop_type_hint(line4)])
	print("'%s' -> '%s'" % [line5, remove_for_loop_type_hint(line5)])
	print("'%s' -> '%s'" % [line6, remove_for_loop_type_hint(line6)])
#endregion
