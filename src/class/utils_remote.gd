#! remote

const UConfig = preload("res://addons/addon_lib/brohd/alib_runtime/utils/u_config.gd")
const UFile = preload("uid://bqfy5cvhth0m1") #! resolve UtilR.Files.URFile
const GetFiles = preload("uid://2kt1rv8kqr3u") #! resolve UtilR.Files.GetFiles
const UString = preload("res://addons/addon_lib/brohd/alib_runtime/utils/u_string.gd")
const UTree = preload("res://addons/addon_lib/brohd/alib_runtime/utils/u_tree.gd")
const URegex = preload("res://addons/addon_lib/brohd/alib_runtime/utils/u_regex.gd")
const UClassDetail = preload("res://addons/addon_lib/brohd/alib_editor/utils/src/u_class_detail.gd")
const ConfirmationDialogHandler = preload("uid://bccd38qwc47vu").Handlers.Confirmation # dialog.gd
const Conf = preload("uid://b4rwv7tgks0b5") #! resolve ALibRuntime.Dialog.Handlers.Confirmation

const UEditor = preload("res://addons/addon_lib/brohd/alib_editor/utils/src/u_editor.gd")
const PopupHelper = preload("res://addons/addon_lib/brohd/alib_runtime/popup_menu/popup_menu_path_helper.gd")
const FileSystem = preload("res://addons/addon_lib/brohd/alib_editor/utils/src/editor_nodes/filesystem.gd")
const UEditorTheme = preload("res://addons/addon_lib/brohd/alib_editor/utils/src/u_editor_theme.gd")
const TreeHelperBase = preload("res://addons/addon_lib/brohd/alib_runtime/tree_helper/tree_helper_base.gd")

const TabBarContainer = preload("uid://b7cxw711vl1jd") #! resolve ALibEditor.UIHelpers.Tab.TabBarContainer
const EditorIcons = preload("uid://viocyrti6wce") #! resolve ALibEditor.Singleton.EditorIcons

const Options = preload("uid://c61qxuau2v0pb") #! resolve ALibRuntime.Popups.Options

const SplitWrapper = preload("uid://ceuhswngaxtvo") #! resolve ALibRuntime.UICustom.SplitWrapper

const UControl = preload("uid://brio73mirr5e6") #! resolve ALibRuntime.Utils.UControl

const FSTreeClasses = preload("res://addons/addon_lib/brohd/alib_editor/file_system/components/tree/fs_tree_classes.gd")

const Dependencies = preload("uid://dbn0kmkxa7caq") #! resolve ALibRuntime.Utils.UResource.Dependencies
const GDScriptOptimizer = preload("res://addons/addon_lib/gdscript_optimizer/optimizer.gd")
const DepGraphPanel = preload("res://addons/addon_lib/brohd/alib_runtime/ui/dep_graph/dep_graph_panel.gd")

const JSONHighlighter = preload("res://addons/addon_lib/brohd/alib_runtime/misc/syntax_highlighters/text/types/json_highlighter.gd")
const YAMLHighlighter = preload("res://addons/addon_lib/brohd/alib_runtime/misc/syntax_highlighters/text/types/yaml_highlighter.gd")
