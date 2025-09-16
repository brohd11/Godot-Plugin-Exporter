@tool
extends Control

const ScriptEd = preload("res://addons/plugin_exporter/src/class/remote/addons/addon_lib/brohd/alib_editor/utils/src/editor_nodes/script_editor.gd")

@onready var output_text_edit: TextEdit = %Output
@onready var input: LineEdit = %Input

@onready var dock_button: Button = %DockButton

const COMMANDS = {
	"script":{
		"run":""
	}
}

func _ready() -> void:
	input.text_submitted.connect(_on_text_submitted)

func _on_text_submitted(new_text:String) -> void:
	var words = new_text.split(" ", false)
	if words.is_empty():
		return
	var first_word = words[0]
	var second_word = words[1]
	var third_word = words[2]
	if first_word == "script":
		if second_word == "run":
			var output = ScriptEd.get_current_script().call(third_word)
			output_text_edit.text += output
			pass
		pass
	pass

static func test():
	print("TESTING")
	return "YES"

