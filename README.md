# Godot Plugin Exporter

This plugin is used to create release packages for your plugins.

[Youtube Walkthrough](https://youtu.be/G0ZlF8FJ94U)

The main feature is to get any global classes used in your plugin and remove the class_name, then declare said class in any script that uses it, as a preload. This allows you to work in your development repo with global class names for convenience, but distribute the plugin with only the classes the user will use in the global space. Classes to preload can be [customized](./export_ignore/export_settings.md).

The other aspect of this is that the global class can be outside of the plugin. It would then be copied into your plugin on export. This allows you to keep shared classes in a central folder/submodule, but use the classes as normal.

In the image below, you can see how the exporter itself is exported. The main logic lives in the plugin_exporter folder, it pulls utility classes from addon_lib folder, and then pulls the editor_console plugin as a sub plugin.


<img width="1161" height="955" alt="exporter-example-git" src="https://github.com/user-attachments/assets/d391a7b0-84dc-416e-a221-6a5fa798d9ee" />


This will also work with preloaded classes if you want to limit global classes in your dev repo. See [here](./export_ignore/advanced_usage.md) for more details.

All global class or "#! remote" files will be scanned, and any global classes used, preload/loaded files used within will be copied as well, and then scanned recursively.

**Note**: on export a new copy of the files is created. Any plugins using the same classes will technically be a different class. If the classes are not self contained, meaning multiple plugins would need to interact with the same instance of the class, you must account for this.

### Setup

You can open a plugin exporter instance from the project menu. With a new plugin instance, you can select "Plugin Init" in the tool menu of the GUI.  This will prompt you to select your plugin folder. Once selected, an "export_ignore" folder will be created in your plugin. It holds a json configuration file, as well as a gdscript file that has a pre and post export function. These will be called during export and can be used to do anything that may need to be done before or after export.  For example, resetting config files to default values or creating a .gdignore file manually.

The default export location is "export_ignore/exports". A .gdignore file is created in "exports" so that the files are not imported into your project.

Alternatively, you can run this setup from the [editor console plugin](https://github.com/brohd11/Godot-Editor-Console) that is bundled with this plugin. With or without the GUI open, run: `PluginExporter call -- plugin_init my_plugin_folder`

With the setup complete, you can click "Read" in the GUI tool menu. This will create a tree that displays all the files that will be exported including the files outside of the plugin. These will be labeled with the file's relationship to the plugin.
 - remote file - global class or "#! remote" files
 - dependency - file found in a remote file when scanned

Console command: `PluginExporter call -- gui_open my_plugin_folder` will open a GUI instance and read the export file.

### Export

You can export through the GUI by clicking "Export" in the tool menu.

Console command: `PluginExporter call -- export my_plugin_folder`
