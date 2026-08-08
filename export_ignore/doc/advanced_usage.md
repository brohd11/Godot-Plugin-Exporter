

### Global Class

Global classes can just be used as normal.

### Remote Class

You can get a single un-named script from outside of the plugin like this:

``` gdscript
#! remote
extends "res://some_other/folder/my_class.gd"
```

On export, this file will be replaced with the extended class, and all dependencies copied to plugin.

"#! remote" must be within the first 10 lines of the file.

Because the file is replaced any changes will not be present in the copied file. I would use this if I want this file to be in a specific spot, or if I created another script to extend it and make changes there.

This was an earlier workflow in the production of this plugin. I would suggest using the next method for most things, though there are scenarios where this is needed.

**Note**: because this is extending the class, it is not the same as the class. It could have identical functionality, but if you need to type check, this class is not the same as the extended class. If you need to type check, use the plugin preload file method.

### Plugin Preload File

This format can be used to make a master file that preloads out of plugin files. Typically, I will name this utils_remote.gd or something similar, to denote that these files are not local to the plugin. This file can either be preloaded in your plugin scripts, or given a global class name. 

This is useful if the desired files are not global classes, you can preload any classes that you want to use in your plugin.

You can also declare files as dependencies if they are not preloadable. You can also give these a custom path. `#! dependency current` will place the file in the same directory as the file it is declared in. You also put a path there, it must be within your plugin folder to be valid.

``` gdscript
#! remote
class_name MyPluginUtilsRemote

const MyClass = preload("res://some_other/folder/my_class.gd")
const MyOtherClass = preload("res://some_other/folder/my_other_class.gd")

const MY_FILE = "res://some_other/folder/non-resource.file" #! dependency
const MY_CUST_FILE = "res://file.file" #! dependency res://addons/my_plugin/deps
```

In another script you can access like:

``` gdscript
## if you don't have a global name, preload the class
const UtilsRemote = preload("res://addons/my_plugin/utils_remote.gd")

func _ready():
	var my_instance = UtilsRemote.MyClass.new()
	UtilsRemote.MyOtherClass.static_func(my_instance)
```

On export, these files will be copied into your plugin, and have their paths adjusted. If you want to organize your scripts into a hierarchy, you can use my (pseudo-namespace)[https://github.com/brohd11/Godot-Pseudo-Namespace] plugin. This works well with this workflow.

### Tags

There are a couple of tags you can use to change how files are processed.
 - "#! ignore-remote" - This will stop a file path from being pulled into the plugin on export and from being updated to relative or on name change
 - "#! dependency" - This will add the path to the list to copy and process. This is mostly for non preloadable or loadable files, config, JSON, etc.
 - "#! singleton-module" - This is for a singleton class I use to share libraries between plugins. Only useful if extending one of the Singleton classes.

The reason I mention the singleton-module tag is because you could add your own tags and parse them with your own custom parser. You can add any parsers to folder "plugin_exporter/src/class/export/parse/<extension>" replace with your file extension and the parser will be called on those files. You can add parameters in the "plugin_export.json" file under "parser_settings", more info (here)[./export_settings.md].

### Full Plugin Copy

Something I am experimenting with is creating "portable" plugins. These plugins would be agnostic to their location, and might interact with an instance of a class in the tree. This allows for packaging the plugin into multiple other plugins, but all can interact with each other, despite being technically different classes.

To copy an entire plugin in, I do this:
``` gdscript
#! remote
extends "res://addons/my_other_plugin/plugin.gd"

const PLUGIN_CFG = "res://addons/my_other_plugin/plugin.cfg" #! dependency current
```

This file would be in a folder for sub-plugins inside the main plugin. 

`res://addons/my_plugin/sub_plugins/plugin_to_copy/plugin.gd`

The other plugin.gd will replace the above file, and have it's config file copied next to it, allowing it to be enabled by Godot. All the dependencies will be placed in the designated remote directory, so they can share common files. As long as any required files are preloaded, global classes, or used in a tscn file, they will be copied over. If they are not directly referenced, you can add them to the above similar to the config file.

You don't want the main plugin to enable this sub plugin in your dev repo, and in fact you can't since plugin.cfg will not be present until export. So, to avoid errors I have a class that will enable and disable sub-plugins. I use the plugin exported flag to determine if the main plugin has been exported. Right clicking on an empty line in a script will give you the option to add the exported flag(avoids spelling mistakes).

``` gdscript
const PLUGIN_EXPORTED = false
const SUB_PLUGIN_DIR = "res://addons/my_plugin/sub_plugins"

func _enable_plugin():
	if PLUGIN_EXPORTED:
		SubPluginManager.toggle_plugins(SUB_PLUGIN_DIR, true)

func _disable_plugin():
	if PLUGIN_EXPORTED:
		SubPluginManager.toggle_plugins(SUB_PLUGIN_DIR, false)
```

On export, the exported flag will be changed to true, allowing the sub-plugins to be enabled. There is also a backport flag available, that can be used to change your logic depending on the backport target version.

Using this method, you can copy multiple sub-plugins into your plugin, while leaving their source intact for updates.


### Backport

In the "plugin_export.json" file, under "parser_settings" can change "backport_target" to the minor version you are targeting. ie: "backport_target": 3 == Godot 4.3.x

This will apply any backports necessary for your plugin. For example, if you use static vars, they will not need to be adjusted, but EditorContextMenuPlugins will. If the backport_target was 0, static vars would be adjusted too.

This does not have all incompatibilities fixed. It is mainly things I have run into with my own plugins. So a changed property name between versions in a random class is not likely to have been fixed yet. However, it is pretty simple to add extra rules to the backport parser, so substitutions can be made.

Main backports:
- EditorInterface direct singleton access converts to compatibility class
 - EditorContextMenuPlugin converts to compatibility class
 - static var are converted to a singleton using static func getters and setters
 - typed for loops and dictionaries stripped
 - raw strings converted to escaped strings
 - "X is not Y" syntax converted to "not X is Y"
 - various other methods recreated in a compatibility class
 - remove @abstract keyword
 - convert DPITexture resources to SVG


### Shipping Docs

With `include_docs` on (the default), the `doc` folder beside your `plugin_export.yml` is copied
into the exported plugin as `.doc`, structure intact. Nothing in it is parsed or crawled for
dependencies, it is copied verbatim, and no `.uid`/`.import` sidecars come along. The dot prefix
keeps Godot from importing the folder, so it never reaches a game export.

The `DocViewer` component renders those docs. You provide the entry point - a button, a menu item,
whatever suits the plugin - and the addon directory to read from:

``` gdscript
const DocViewer = preload("res://addons/my_plugin/src/components/doc_viewer/doc_viewer.gd")

func _on_help_pressed() -> void:
	DocViewer.open("res://addons/my_plugin/")
```

`open()` puts the viewer in its own window that frees itself when closed. To embed it instead,
instance it as a normal Control and set `docs_path`.

It resolves a directory itself: `<addon>/.doc` in a released plugin, `<addon>/export_ignore/doc` in
this dev project, or the plugin's `README.md` when there is no doc folder at all. Docs are listed
depth first, files before folders, on a contents page, with navigation between them.

Give it a **file** instead and that file is the whole viewer - nothing is scanned or guessed at,
and the contents page and navigation stay out of the way:

``` gdscript
DocViewer.open("res://addons/my_plugin/README.md")   # window on one file
viewer.display("res://addons/my_plugin/README.md")   # same, on an embedded instance
```

Links follow through: a doc in the contents opens as a page, a `.md` outside it opens too (the
Contents button goes back), a `res://` file is revealed in the FileSystem dock, and anything else
is handed to the OS.

Markdown support covers headings, emphasis, lists, quotes, links, rules, images and fenced code.
Code fences render as read-only `CodeEdit`s - gdscript is highlighted out of the box, and
`highlighter_provider` takes a `(lang:String) -> SyntaxHighlighter` callable for anything else.
Heading sizes are ratios of the editor's own font size, so the whole view follows the editor scale.
