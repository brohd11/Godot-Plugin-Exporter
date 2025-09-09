# Godot Plugin Exporter

This plugin is used to create release packages for your plugins.

The main feature is to get any global classes used in your plugin and remove the class_name, then declare said class in any script that uses it, as a preload. This allows you to work in your development repo with global class names for convenience, but distribute the plugin with only the classes the user will use in the global space.

The other aspect of this is that the global class can be outside of the plugin. It would then be copied into your plugin on export. This allows you to keep shared classes in a central folder/submodule, but use the classes as normal.

This will also work with preloaded classes if you want to limit global classes in your dev repo. See "Plugin Preload File" in examples.

All global class or "#! remote" files will be scanned, and any global classes used, preload/loaded files used within will be copied as well, and then scanned recursively.

**Note**: on export a new copy of the files is created. Any plugins using the same classes will technically be a different class. If the classes are not self contained, meaning multiple plugins would need to interact with the same instance of the class, you must account for this.

### Setup

You can open a plugin exporter instance from the project menu. With a new plugin instance, you can select "Plugin Init" in the tool menu of the GUI.  This will prompt you to select your plugin folder. Once selected, an "export_ignore" folder will be created in your plugin. It holds a json configuration file, as well as a gdscript file that has a pre and post export function. These will be called during export and can be used to do anything that may need to be done before or after export.  For example, resetting config files to default values or creating a .gdignore file manually.

The default export location is "export_ignore/exports". A .gdignore file is created in "exports" so that the files are not imported into your project.

Alternatively, you can run this setup from the [editor console plugin](https://github.com/brohd11/Godot-Editor-Console) that is bundled with this plugin. With or without the GUI open, run: `PluginExporter call -- plugin_init my_plugin_folder`

With the setup complete, you can click "Read" in the GUI tool menu. This will create a tree that displays all the files that will be exported including the files outside of the plugin. These will be labeled with the file's relationship to the plugin.
 - remote file - global class or "#! remote" files
 - dependency - file found during recursive scan for dependencies

Console command: `PluginExporter call -- gui_open my_plugin_folder` will open a GUI instance and read the export file.

### Export

You can export through the GUI by clicking "Export" in the tool menu.

Console command: `PluginExporter call -- export my_plugin_folder`

### Examples
#### Global Class

Global classes can just be used as-is wherever they are in your project.

#### Remote Class

The simplest way to use a class is to simply extend it.

``` gdscript
#! remote
extends "res://some_other/folder/my_class.gd"
```

On export, this file will be replaced with the extended class, and all dependencies copied to plugin.

**Note**: because this is extending the class, it is not the same as the class. It has identical functionality, but if you need to type check, this class is not the same as the extended class. If you need to type check, use the plugin preload file method.

If you want to add functionality to the class, you should not add it to this file. Either, extend this file in a new file then add functionality there, or use the plugin preload file method to extend the class.

``` gdscript
extends MyPluginUtilsRemote.MyClass

## add functionality here
```

#### Plugin Preload File

This format can be used to make a master file that preloads 'out of plugin' files. Typically, I will name this utils_remote.gd or something similar, to denote that these files are not local to the plugin. This file can either be preloaded in your plugin scripts, or given a global class name. 

This is useful for files that are not global classes, you can preload any classes that you want to include in your plugin.

You can also declare files as dependencies if they are not preloadable.
 - `#! dependency` - places the file in it's standard path with in "remote_dir" declared in the json export file
 - `#! dependency current` - places the file in the same directory as the file where it is declared
 - `#! dependency res://addons/my_plugin/deps` - sets a custom dir for the file to be placed

``` gdscript
#! remote
class_name MyPluginUtilsRemote

const MyClass = preload("res://some_other/folder/my_class.gd")
const MyOtherClass = preload("res://some_other/folder/my_other_class.gd")

const MY_FILE = "res://some_other/folder/non-resource.file" #! dependency
```

In another script you can access like this:

``` gdscript
## if you don't have a global name, preload the class.
## name can be less verbose than if you need to avoid class name clashes between plugins

const UtilsRemote = preload("res://addons/my_plugin/utils_remote.gd")

func _ready():
	var my_instance = UtilsRemote.MyClass.new()
	UtilsRemote.MyOtherClass.static_func(my_instance)
```

On export, these files will be copied into your plugin, and have their paths adjusted.

#### Full Plugin Copy

Something I am experimenting with is creating "portable" plugins. These plugins would be agnostic to their location, and might interact with an instance of a class in the tree. This allows for packaging the plugin into multiple other plugins, but all can interact with each other, despite being technically different classes.

With this in mind, it could be handy to bundle an entire different plugin within your plugin.

Another example would be if you wanted to create a master plugin that includes multiple smaller ones, but keep the smaller ones distributable on their own.

To copy an entire plugin in, I create a gd file that has the same name as the other plugin's main script. Then declare the plugin.cfg as a dependency to be placed next to the new plugin file.

``` gdscript
#! remote
extends "res://addons/my_other_plugin/plugin.gd"

const PLUGIN_CFG = "res://addons/my_other_plugin/plugin.cfg" #! dependency current
```

This file would be in a folder for sub-plugins inside the main plugin. 

`res://addons/my_plugin/sub_plugins/plugin_to_copy/plugin.gd`

The other plugin.gd will replace the above file, and have it's config file copied next to it, allowing it to be enabled by Godot. All the dependencies will be placed in the designated remote directory, so they can share common files. As long as any required files are preloaded, global classes, or used in a tscn file, they will be copied over. If they are not directly referenced, you can add them to the above similar to the config file.

**Note:** The non-referenced files will not have their paths changed in the export. You can account for this by using the plugin exported flag(see below), and/or using relative paths. Placing the files next to the plugin.gd or in that directory can make that easier to manage.

You don't want the main plugin to enable this sub plugin in your dev repo, and in fact you can't since plugin.cfg will not be present until export. So, to avoid errors I created a class that will enable and disable sub-plugins. I use the plugin exported flag to determine if the main plugin has been exported. Right clicking on an empty line in a script will give you the option to add the exported flag(avoids spelling mistakes).

``` gdscript
const PLUGIN_EXPORTED = false

func _enable_plugin():
	if PLUGIN_EXPORTED:
		var sub_plugin_dir = "res://addons/my_plugin/sub_plugins"
		var sub_plugin_path = "my_plugin/sub_plugins"
		SubPluginManager.toggle_plugins(sub_plugin_dir, sub_plugin_path, true)
```

On export, the exported flag will be changed to true, allowing the sub-plugins to be enabled.

Using this method, you can copy multiple sub-plugins into your plugin, while leaving their source intact for updates.






