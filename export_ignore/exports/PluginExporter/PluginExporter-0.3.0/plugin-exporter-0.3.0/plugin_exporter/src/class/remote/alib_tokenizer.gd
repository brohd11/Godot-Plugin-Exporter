

static var _token_regex: RegEx
const pattern = "\"[^\"]*\"|'[^']*'|(\\[(?:[^\\[\\]]|(?1))*\\])|(\\{(?:[^{}]|(?2))*\\})|(\\((?:[^()]|(?3))*\\))|\\S+"


static func words_only(text):
	var separators = " \t\n\r:,.()[]{}<>=+-*/!\"'@"
	var code_only_text = text.get_slice("#", 0)
	var clean_text = code_only_text
	for separator in separators:
		clean_text = clean_text.replace(separator, " ")
	var words = clean_text.split(" ")
	
	return words

static func tokenize_string(text: String) -> Dictionary:
	if _token_regex == null:
		_token_regex = RegEx.new()
		_token_regex.compile(pattern)
	
	var tokens = PackedStringArray()
	if text.is_empty():
		return {"tokens":tokens}
	
	var matches = _token_regex.search_all(text)
	for _match in matches:
		var token = _match.get_string()
		# Check for and remove the surrounding quotes from the captured token
		if (token.begins_with("\"") and token.ends_with("\"")) or \
		   (token.begins_with("'") and token.ends_with("'")):
			# This removes the first and last character (the quote)
			token = token.substr(1, token.length() - 2)
		
		tokens.push_back(token)
	
	return {
		"tokens": tokens,
	}


