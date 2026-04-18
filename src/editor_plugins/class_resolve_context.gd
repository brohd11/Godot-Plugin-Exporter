extends EditorContextMenuPlugin

const SLOT = EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR_CODE

const EditorGDScriptParser = preload("uid://t2dewmuth0sy") #! resolve ALibEditor.Singletons.EditorGDScriptParser
const UString = preload("uid://cwootkivqiwq1") #! resolve ALibRuntime.Utils.UString
const GDScriptParse = UString.GDScriptParse
const UFile = preload("uid://gs632l1nhxaf") #! resolve ALibRuntime.Utils.UFile
const UGDScript = preload("uid://dpa8eyss8m0xx") #! resolve ALibEditor.Utils.UGDScript
const Options = preload("uid://c61qxuau2v0pb") #! resolve ALibRuntime.Popups.Options
const NUCodeEdit = preload("uid://ionhj6gs6txf") #! resolve ALibRuntime.NodeUtils.NUCodeEdit
const StringParse = preload("uid://dy6347rrua78w") #! resolve NUCodeEdit.StringParse
const HLInfo = preload("uid://by8s8jfumbkwl").HLInfo #! resolve SyntaxPlusSingleton.HLInfo

const PREFIX = "#!"
const TAG = "resolve"

const POPUP_MENU = "Resolve Tag/"

const ADD_TAG_PATH = POPUP_MENU + "Add Tag"
const ADD_TAG_UID_PATH = ADD_TAG_PATH + " [UID]"
const RESOLVE_PATH = POPUP_MENU + "Resolve Tagged Class"
const RESOLVE_UID_PATH = RESOLVE_PATH + " [UID]"

var code_completion:EditorCodeCompletion


func _init() -> void:
	SyntaxPlusSingleton.register_highlight_callable(PREFIX, TAG, _syntax_callable, SyntaxPlusSingleton.CallableLocation.END)
	EditorCodeCompletion.register_tag_static(PREFIX, TAG, EditorCodeCompletion.TagLocation.END)
	code_completion = CodeCompletion.new()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		SyntaxPlusSingleton.unregister_highlight_callable(PREFIX, TAG)
		EditorCodeCompletion.unregister_tag_static(PREFIX, TAG, EditorCodeCompletion.TagLocation.END)
		if is_instance_valid(code_completion):
			code_completion.clean_up()


func _syntax_callable(_script_editor:CodeEdit, current_line_text:String, line_idx:int, comment_tag_idx:int):
	var current_script = ScriptEditorRef.get_current_script()
	if not current_script:
		return {}
	
	var hl_info = {}
	var comment = current_line_text.substr(comment_tag_idx)
	var tag_end_idx = HLInfo.get_tag_end_index(PREFIX, TAG, comment)
	if tag_end_idx == -1:
		return hl_info
	hl_info.merge(HLInfo.highlight_prefix(PREFIX, comment))
	hl_info.merge(HLInfo.highlight_tag(TAG, comment))
	
	var class_path_data = Utils.get_class_path_from_comment(comment)
	
	var class_start_idx = class_path_data.get(Keys.START_IDX)
	var class_path = class_path_data.get(Keys.TEXT)
	hl_info.merge(HLInfo.check_const_path(class_path, current_script, class_start_idx))
	return hl_info


func _popup_menu(paths: PackedStringArray) -> void:
	var script_editor:CodeEdit = Engine.get_main_loop().root.get_node(paths[0]);
	
	var sel = ContextMenuSingleton.get_script_editor_selection(script_editor)
	var line_data = sel.get_line_data()
	if line_data.is_empty():
		return
	
	var string_parse := StringParse.new(script_editor)
	
	var has_const:=false
	var has_valid:=false
	for line_idx in line_data.keys():
		var line_text_data = string_parse.get_line_data(line_idx)
		var code = line_text_data.get("code", "")
		var comment = line_text_data.get("comment", "")
		if comment != "":
			if Utils.comment_begins_with_tag(comment):
				has_valid = true
				continue # continue to not register const
		
		var code_stripped = code.strip_edges()
		if code_stripped.begins_with("const"):
			var const_info = GDScriptParse.get_var_or_const_info(code_stripped, false)
			if const_info != null:
				var const_val = const_info[1]
				if not const_val.begins_with("preload"):
					has_const = true
		
		if has_const and has_valid:
			break
	
	if not (has_valid or has_const):
		return
	
	var options = Options.new()
	if has_valid:
		options.add_option(RESOLVE_PATH, null)
		options.add_option(RESOLVE_UID_PATH, null)
	if has_const:
		options.add_option(ADD_TAG_PATH, null)
		options.add_option(ADD_TAG_UID_PATH, null)
	
	var final_options = options.get_options()
	if not final_options.is_empty():
		PopupWrapper.create_context_plugin_items(self, script_editor, final_options, _callback.bind(line_data))


func _callback(script_editor:CodeEdit, option_path:String, line_data:Dictionary):
	if option_path.begins_with(RESOLVE_PATH):
		_resolve_tag(script_editor, line_data, option_path.ends_with("[UID]"))
	elif option_path.begins_with(ADD_TAG_PATH):
		_add_tag(script_editor, line_data, option_path.ends_with("[UID]"))


func _resolve_tag(script_editor:CodeEdit, line_data:Dictionary, uid:bool):
	var current_parser = EditorGDScriptParser.get_parser()
	var action_started = false
	var string_parse := StringParse.new(script_editor)
	for line_idx in line_data.keys():
		var line_text_data = string_parse.get_line_data(line_idx)
		var comment = line_text_data.get("comment", "")
		if comment == "":
			continue
		if not Utils.comment_begins_with_tag(comment):
			continue
		var class_path_data = Utils.get_class_path_from_comment(comment)
		if class_path_data.is_empty():
			continue
		
		var code = line_text_data.get("code")
		var eq_idx = code.find("=")
		if eq_idx == -1:
			continue
		
		var class_path = class_path_data.get(Keys.TEXT)
		var resolved_class_path = current_parser.resolve_expression(class_path, line_idx)
		if not GDScriptParse.is_absolute_path(resolved_class_path):
			continue
		
		var preload_str = _get_preload_string(resolved_class_path, uid)
		
		var declaration_symbol = code.substr(0, eq_idx).strip_edges(false)
		var new_text = declaration_symbol + " = " + preload_str + " " + comment
		if not action_started:
			action_started = true
			script_editor.start_action(TextEdit.ACTION_TYPING)
		
		script_editor.set_line(line_idx, new_text)
	
	if action_started:
		script_editor.end_action()


func _add_tag(script_editor:CodeEdit, line_data:Dictionary, uid:bool):
	var current_parser = EditorGDScriptParser.get_parser()
	var string_parse := StringParse.new(script_editor)
	var action_started = false
	for line_idx in line_data.keys():
		var line_text_data = string_parse.get_line_data(line_idx)
		var comment = line_text_data.get("comment", "")
		if Utils.comment_begins_with_tag(comment):
			continue
		
		var code = line_text_data.get("code")
		var indent_str = code.substr(0, code.find("const "))
		var code_stripped = code.strip_edges() as String
		
		var const_info = GDScriptParse.get_var_or_const_info(code_stripped, false)
		if const_info == null:
			continue
		var const_name = const_info[0]
		var const_dec_text = const_info[1]
		var resolved_val = current_parser.resolve_expression(const_name, line_idx)
		if not GDScriptParse.is_absolute_path(resolved_val):
			continue
		
		var preload_str = _get_preload_string(resolved_val, uid)
		var new_text = indent_str + "const " + const_name + " = " + preload_str
		new_text = new_text + " " + " ".join([PREFIX, TAG, const_dec_text, comment]).strip_edges(false)
		
		if not action_started:
			action_started = true
			script_editor.start_action(TextEdit.ACTION_TYPING)
		
		script_editor.set_line(line_idx, new_text)
	
	if action_started:
		script_editor.end_action()


func _get_preload_string(full_script_path:String, uid:bool):
	var script_path_data = UString.get_script_path_and_suffix(full_script_path)
	var main_script = script_path_data[0]
	if uid:
		main_script = UFile.path_to_uid(main_script)
	var class_access = script_path_data[1]
	var preload_str = 'preload("%s")' % main_script
	if class_access != "":
		preload_str += "." + class_access
	return preload_str


class CodeCompletion extends EditorCodeCompletion:
	func _on_code_completion_requested(_script_editor:CodeEdit) -> bool:
		var caret_context = get_caret_context()
		if not caret_context.token_state == TokenState.COMMENT:
			return false
		var comment = caret_context.get_comment()
		var class_path_data = Utils.get_class_path_from_comment(comment)
		if class_path_data.is_empty():
			return false
		
		var class_path = class_path_data.get(Keys.TEXT)
		Helpers.class_completion(self, class_path)
		return true


class Utils:
	static func comment_begins_with_tag(comment:String):
		return HLInfo.get_tag_end_index(PREFIX, TAG, comment) > -1
	
	static func get_class_path_from_comment(comment:String):
		var tag_end_idx = HLInfo.get_tag_end_index(PREFIX, TAG, comment)
		if tag_end_idx == -1:
			return {}
		var class_start_idx = tag_end_idx
		while class_start_idx < comment.length() - 1:
			var _char = comment[class_start_idx]
			if _char in UString.INDENTIFIER_CHARS:
				break
			class_start_idx += 1
		var class_path_text = comment.substr(class_start_idx).get_slice(" ", 0).strip_edges(false)
		return {Keys.START_IDX: class_start_idx, Keys.TEXT: class_path_text}


class Keys:
	const START_IDX = &"start_idx"
	const TEXT = &"text"
