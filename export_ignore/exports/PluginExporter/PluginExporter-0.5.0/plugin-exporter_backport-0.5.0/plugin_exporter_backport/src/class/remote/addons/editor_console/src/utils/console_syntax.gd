extends SyntaxHighlighter

var default_text_color = _EIBackport.get_ins().ei.get_editor_settings().get("text_editor/theme/highlighting/text_color")

var var_names = []
var var_color = Color.html("96f442")

var scope_names = []
var scope_color = Color.SKY_BLUE
var hidden_scope_names = []

var os_mode:bool

func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var text_edit = get_text_edit()
	var line_text = text_edit.get_line(line)
	if os_mode:
		return check_keyword(line_text, ["os"], scope_color)
	
	var hl_info = {}
	var scope_hl = check_keyword(line_text, scope_names, scope_color)
	hl_info.merge(scope_hl)
	var hidden_scope_hl = check_keyword(line_text, hidden_scope_names, scope_color)
	hl_info.merge(hidden_scope_hl)
	var var_name_hl = check_keyword(line_text, var_names, var_color)
	hl_info.merge(var_name_hl)
	
	
	var hl_info_keys = hl_info.keys()
	hl_info_keys.sort()
	var sorted = {}
	for idx in hl_info_keys: 
		sorted[idx] = hl_info[idx]
	return sorted

func check_keyword(line_text, keywords, color):
	var hl_info = {}
	for keyword in keywords:
		var key_idx = line_text.find(keyword)
		while key_idx > -1:
			
			var end_idx = key_idx + keyword.length()
			var valid_hl = false
			if line_text.length() == end_idx:
				valid_hl = true
			if line_text.length() > end_idx:
				if line_text[end_idx] == " ":
					valid_hl = true
			if key_idx - 1 > -1:
				if line_text[key_idx - 1] != " ":
					valid_hl = false
			if valid_hl:
				hl_info[key_idx] = {"color":color}
				hl_info[end_idx] = {"color":default_text_color}
			key_idx = line_text.find(keyword, end_idx)
	
	return hl_info

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_console_syntax = "res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/utils/console_syntax.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
