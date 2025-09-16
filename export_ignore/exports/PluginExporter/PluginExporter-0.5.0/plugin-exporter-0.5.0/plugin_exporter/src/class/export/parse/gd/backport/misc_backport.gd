extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"

var backport_target:= 100

var _misc_string_replacement_regex:= RegEx.new()
const MISC_STRING_REPLACEMENTS = {
	"type_string": {
		"replace":"MiscBackport.type_string_compat",
		"min_ver":2
	},
	#"gd_term_instance.show": {
		#"replace":"googoo",
		#"min_ver":2
	#},
}

var no_strings:= false

func _compile_misc_strings():
	_string_regex = URegex.get_strings()
	
	var escaped_strings = []
	for string in MISC_STRING_REPLACEMENTS.keys():
		var replace_data = MISC_STRING_REPLACEMENTS.get(string)
		var min_ver = replace_data.get("min_ver", 0)
		if min_ver < backport_target:
			continue
		escaped_strings.append(URegex.escape_regex_meta_characters(string))
	
	if escaped_strings.is_empty():
		no_strings = true
		return
	
	var misc_list = "|".join(escaped_strings)
	#misc_list.trim_prefix("|").trim_suffix("|")
	var misc_string_pattern = "(?<![\\w.])(" + misc_list + ")\\b(\\s*\\((?:(?:[^()]|\\([^)]*\\))*)\\))?"
	_misc_string_replacement_regex.compile(misc_string_pattern)

# in parser_settings, create dictionary for extension of file,
# ie. if extension is foo, "parse_foo": {"my_setting": "value"}
func set_parse_settings(settings):
	backport_target = settings.get("backport_target", 100)
	_compile_misc_strings()

# logic to parse for files that are needed acts as a set, dependencies[my_dep_path] = {}
func get_direct_dependencies(file_path:String) -> Dictionary:
	var dependencies = {} 
	return dependencies

# runs right before export of files. Use for extension specific files.
func pre_export() -> void:
	pass

# first pass on post export, if the file ext is handle by default, file_lines will 
# contain modifies lines, for example, if you want to make a second pass on a gd file.
# If not handled by default, file_lines will be null. You can process and return the files lines
# or return the null value to default to the file's .
func post_export_edit_file(file_path:String, file_lines:Variant=null) -> Variant:
	return file_lines

# second pass of post export. If extension is handled by default, line will be 
# modified already. If changes were made in post_export_edit_file, these will be
# present here, else, it will be the unmodified line from the file.
func post_export_edit_line(line:String) -> String:
	line = replace_misc_methods(line)
	return line


func replace_misc_methods(line:String) -> String:
	return URegex.string_safe_regex_sub(line, _replace_misc_methods, _string_regex)

func _replace_misc_methods(line:String) -> String:
	if no_strings:
		return line
	
	var matches = _misc_string_replacement_regex.search_all(line)
	for i in range(matches.size() - 1, -1, -1):
		var _match: RegExMatch = matches[i]
		var _match_string = _match.get_string(1)
		var replace_data = MISC_STRING_REPLACEMENTS.get(_match_string, {})
		var replacement = _match_string
		if replace_data.is_empty():
			print("Could not replace string: %s" % _match_string)
		else:
			replacement = replace_data.get("replace")
		
		var args = _match.get_string(2)
		
		var new_call = replacement + args
		
		line = line.substr(0, _match.get_start(0)) \
			+ new_call \
			+ line.substr(_match.get_end(0))
	
	return line

