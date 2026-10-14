#! remote

const UConfig = preload("res://addons/_lib/brohd/src/alib_runtime/utils/u_config.gd")
const UFile = preload("uid://bqfy5cvhth0m1") #! resolve UtilR.Files.UFile
const GetFiles = preload("uid://2kt1rv8kqr3u") #! resolve UtilR.Files.GetFiles
const UString = preload("uid://dce8d0wuh35gs") #! resolve UtilR.Strings.UString
const UTree = preload("uid://1gwputufojp6") #! resolve UtilR.Nodes.Trees.UTree
const URegex = preload("uid://d0rbf4as6kpns") #! resolve UtilR.Strings.URegex
const UClassDetail = preload("uid://0a4i0eyxcij7") #! resolve UtilR.Objects.UClassDetail
const Confirmation = preload("uid://dwhlbgevd62gg") #! resolve Dialogs.Handlers.Confirmation
const FilePicker = preload("uid://bnhku17qy1buh") #! resolve Dialogs.Handlers.FilePicker

const UEditor = preload("uid://csg0d63aj8d0h") #! resolve UtilE.UEditor
const PopupHelper = preload("uid://ba5x2r7gyvmej") #! resolve UtilR.Nodes.PopupMenus.PathHelper
const FileSystem = preload("uid://ckkcgqmrbp57n") #! resolve EditorNodes.Refs.FileSystem
const UEditorTheme = preload("uid://skhivjtt6r3b") #! resolve UtilE.UEditorTheme
const TreeHelperBase = preload("uid://bma4204fvtvtx") #! resolve UtilR.Nodes.Trees.FileTreeHelperBase

const TabBarContainer = preload("uid://dhohyyr2xlven") #! resolve UIRuntime.Tabs.TabBarContainer
const EditorIcons = preload("uid://viocyrti6wce") #! resolve UIPlugin.EditorIcons

const Options = preload("uid://dxdxq2n3imf4q") #! resolve UtilR.Nodes.PopupMenus.Options

const SplitWrapper = preload("uid://ceuhswngaxtvo") #! resolve ALibRuntime.UICustom.SplitWrapper

const UControl = preload("uid://brio73mirr5e6") #! resolve ALibRuntime.Utils.UControl

const FSTreeClasses = preload("res://addons/_lib/editor_filesystem/src/components/tree/fs_tree_classes.gd")

const Dependencies = preload("uid://dbn0kmkxa7caq") #! resolve ALibRuntime.Utils.UResource.Dependencies
const GDScriptOptimizer = preload("res://addons/_lib/gdscript_optimizer/src/optimizer.gd")
const DepGraphPanel = preload("res://addons/_lib/brohd/src/alib_runtime/ui/dep_graph/dep_graph_panel.gd")

const JSONHighlighter = preload("uid://b1cjxhrucdnbo") #! resolve SyntaxHighlighters.Text.Json
const YAMLHighlighter = preload("uid://com2gj0t82d8f") #! resolve SyntaxHighlighters.Text.Yaml
