

#static var _token_regex: RegEx<- Backport Static Var
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
	if get__token_regex() == null:
		set__token_regex(RegEx.new())
		get__token_regex().compile(pattern)
	
	var tokens = PackedStringArray()
	if text.is_empty():
		return {"tokens":tokens}
	
	var matches = get__token_regex().search_all(text)
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

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_alib_tokenizer = "res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/tokens/alib_tokenizer.gd"

static func get__token_regex():
	return _BackportStaticVar.get_ins().get_var(_BPSV_PATH_alib_tokenizer, '_token_regex', null)
static func set__token_regex(value):
	return _BackportStaticVar.get_ins().set_var(_BPSV_PATH_alib_tokenizer, '_token_regex', value)
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
