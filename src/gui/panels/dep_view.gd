extends VBoxContainer

const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const UControl = UtilsRemote.UControl
const Options = UtilsRemote.Options
const DepGraphPanel = UtilsRemote.DepGraphPanel


var dep_graph:DepGraphPanel

var current_files:Array = []

func _init() -> void:
	name = "Dependency View"

func _ready() -> void:
	dep_graph = DepGraphPanel.new()
	add_child(dep_graph)
	UControl.expand(dep_graph)
	
	# create setting?
	dep_graph.set_edge_mode(DepGraphPanel.EdgeMode.TREE)

func set_current_file(path:String):
	show()
	current_files = [path]
	_create_graph()

func _create_graph():
	dep_graph.v_gap = 50 * EditorInterface.get_editor_scale()
	dep_graph.h_gap = 200 * EditorInterface.get_editor_scale()
	dep_graph.set_files(current_files)
	print(dep_graph.get_dep_graph().to_dict())

func get_options() -> Options:
	var options = Options.new()
	options.add_option("Change View", _change_view_mode)
	return options

func _change_view_mode():
	var next_mode = wrapi(dep_graph.edge_mode + 1, 0, dep_graph.EdgeMode.size())
	dep_graph.set_edge_mode(next_mode)
	_create_graph()
