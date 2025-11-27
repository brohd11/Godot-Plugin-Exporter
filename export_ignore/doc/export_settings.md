
## Main Settings
 - export_root - root of export can be local or global scope, inside or outside project
 - plugin_folder - appended to export_root, by default it uses the plugin version, so all different version exports can exist in this folder
 - pre_script - script called pre export
 - post_script - script called post export
 - exports - array of export objects dictionaries
 - options - dictionary of options

### exports
 - source - source location of the plugin
 - exclude - directories, file_extensions, and files to ignore on export
 - remote_dir - where all out of plugin files will be recreated
 - export_folder - final export location of files (export_root + plugin_folder + export_folder)
 - other_transfers - other files to transfer into plugin on export
 - ignore_dependencies - do not export any dependencies for the files
 - parser_overide_settings - overide settings per export for the file parser
 
### options
 - include_import - bool
 - include_uid - bool
 - overwrite - bool, erases the contents of export_folder before export, if false, it will abort if any file already exists
 - parser_settings - Dictionary of settings for file parser. Applied to all exports unless overiden

#### parser_settings
these settings are passed to parsers. You can overide on a per export basis using "parser_overide_settings" in each export. This is the exact same data structure

##### general - applies to all extensions
 - use_relative_paths - Instead of absolute paths, uses relative paths from current file.
 - backport_target - target minor version for backport as int

##### parse_gd
 - replace_editor_interface - replaces 'EditorInterface' direct singleton access with 'Engine.get_singleton(&"EditorInterface")'
 - class_rename_ignore - Array of class_name to not strip and preload
 - backport_string_renames - dictionary, key is the method to replace, value is a dictionary with key "replace":"replace_as", "min_ver": backport_target as int

##### parse_cs
 - namespace_rename - Dictionary with keys "namespace":"rename_as"
