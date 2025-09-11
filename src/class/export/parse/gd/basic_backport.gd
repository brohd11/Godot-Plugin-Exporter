extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"


const EI_BACKPORT_PATH = "res://addons/plugin_exporter/src/class/export/backport/ei_backport.gd"
const EI_BACKPORT = "_EIBackport"


var _is_not_regex:= RegEx.new()
var _for_loop_type_regex:= RegEx.new()
var _ei_regex:= RegEx.new()
var _raw_string_regex := RegEx.new()

var _raw_string_regexes = []


var backport:= false

func _init() -> void:
	_string_regex = URegex.get_strings()
	
	var is_not_pattern = "(\\S+)\\s+is\\s+not\\s+(\\S+)"
	_is_not_regex.compile(is_not_pattern)
	
	var for_loop_pattern = "^(\\s*for\\s+)(\\S+)\\s*:\\s*.*?(\\s+in\\s+.*)"
	_for_loop_type_regex.compile(for_loop_pattern)
	
	var ei_pattern = "\\bEditorInterface\\b"
	_ei_regex.compile(ei_pattern)
	
	var raw_string_pattern = "(?s)r(\"\"\"|'''|\"|')(.*?)(\\1)"
	_raw_string_regex.compile(raw_string_pattern)
	
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
	
	
	line = replace_editor_interface(line)
	line = remove_for_loop_type_hint(line)
	line = convert_all_is_not_syntax(line)
	
	
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
	# 1. First, escape all backslashes.
	var escaped_content = raw_content.replace("\\", "\\\\")
	# 2. Second, escape all double-quotes that might be inside the string.
	escaped_content = escaped_content.replace("\"", "\\\"")
	# 3. Finally, wrap the result in double-quotes to make it a full string literal.
	return '"' + escaped_content + '"'



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
