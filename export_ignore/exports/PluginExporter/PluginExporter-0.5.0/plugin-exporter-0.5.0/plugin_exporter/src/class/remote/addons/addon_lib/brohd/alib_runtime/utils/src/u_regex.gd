extends Node


static func escape_regex_meta_characters(text: String) -> String:
	var output: PackedStringArray = []
	for char_str in text:
		match char_str:
			".", "+", "*", "?", "^", "$", "(", ")", "[", "]", "{", "}", "|", "\\":
				output.append("\\" + char_str)
			_:
				output.append(char_str)
	return "".join(output)


static func get_preload_path():
	var regex = RegEx.new() # match.get_string(2) -> path
	regex.compile('preload\\((["\'])(.+?)\\1\\)')
	return regex

static func get_const_name():
	var regex = RegEx.new()
	regex.compile("^\\s*const\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*(:=|=)")
	return regex

static func get_strings(): # for use with string_safe_regex_sub
	var regex = RegEx.new()
	regex.compile("\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'")
	return regex


static func string_safe_regex_sub(line: String, processor: Callable, string_regex:RegEx) -> String:
	var code_part = line
	var comment_part = ""
	var comment_pos = line.find("#")
	if comment_pos != -1:
		code_part = line.substr(0, comment_pos)
		comment_part = line.substr(comment_pos)
	
	# 1. Find all string matches and store both their values and positions
	var string_matches = string_regex.search_all(code_part)
	var string_literals = []
	for _match in string_matches:
		string_literals.append(_match.get_string())
	
	# 2. Replace strings with placeholders by POSITION, iterating BACKWARDS
	var sanitized_code = code_part
	for i in range(string_matches.size() - 1, -1, -1):
		var _match = string_matches[i]
		var placeholder = "__STRING_PLACEHOLDER_%d__" % i
		# Reconstruct the string using the match's start and end positions
		sanitized_code = sanitized_code.left(_match.get_start()) + placeholder + sanitized_code.substr(_match.get_end())
	
	# 3. Call the provided processor function on the sanitized code
	var converted_code = processor.call(sanitized_code)
	
	# 4. Restore strings (this part can remain the same)
	var final_code = converted_code
	for i in range(string_literals.size()):
		var placeholder = "__STRING_PLACEHOLDER_%d__" % i
		final_code = final_code.replace(placeholder, string_literals[i])
	
	return final_code + comment_part

