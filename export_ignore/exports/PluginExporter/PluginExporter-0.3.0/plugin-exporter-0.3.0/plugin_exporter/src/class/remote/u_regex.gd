extends Node

static func get_preload_path():
	var regex = RegEx.new() # match.get_string(2) -> path
	regex.compile('preload\\((["\'])(.+?)\\1\\)')
	return regex

static func escape_regex_meta_characters(text: String) -> String:
	var output: PackedStringArray = []
	for char_str in text:
		match char_str:
			".", "+", "*", "?", "^", "$", "(", ")", "[", "]", "{", "}", "|", "\\":
				output.append("\\" + char_str)
			_:
				output.append(char_str)
	return "".join(output)



