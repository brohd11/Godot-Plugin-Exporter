
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
 - export_name - package folder under export_root + plugin_folder, zipped as a whole. Defaults to the last segment of plugin_folder
 - export_folder - install path relative to res://, e.g. `addons/addon_lib/my_lib`. Recreated inside the package, so it extracts straight into a project. Any path relative to res:// (no `{{version}}` templates); defaults to source. A path different from source renames the plugin and rewrites its paths to match
 - other_transfers - other files to transfer into plugin on export
 - ignore_dependencies - do not export any dependencies for the files
 - parser_overide_settings - overide settings per export for the file parser
 
### options
 - include_import - bool
 - include_uid - bool
 - overwrite - bool, erases the contents of export_root + plugin_folder before export, if false, it will abort if any file already exists
 - include_docs - bool, defaults true. Copies the doc folder beside this config (export_ignore/doc) into the exported plugin as `.doc`, preserving its structure. No dependency crawl, the files are copied verbatim without uid or import sidecars. Dot-prefixed so Godot never imports them and they stay out of a game export, while DocViewer can still read them.
 - include_project_license - bool, defaults false. Licenses are gathered by matching every copied file against the closest LICENSE above it, so a nested library keeps its own. The project root (`res://LICENSE`) is held out of that matching - it contains everything, so it would otherwise claim every file no other license covers. Turn this on for a plugin that has no LICENSE of its own and takes the project's; it ships at the export root. Ignored when the plugin does have one.
 - parser_settings - Dictionary of settings for file parser. Applied to all exports unless overiden

#### parser_settings
these settings are passed to parsers. You can overide on a per export basis using "parser_overide_settings" in each export. This is the exact same data structure

##### general - applies to all extensions
 - use_relative_paths - Instead of absolute paths, uses relative paths from current file.
 - backport_target - target minor version for backport as int

##### parse_gd
 - replace_editor_interface - replaces 'EditorInterface' direct singleton access with 'Engine.get_singleton(&"EditorInterface")'
 - class_rename_ignore - Array of class_name to not strip and preload
 - reduce_access_paths - bool, default false. Rewrites dotted access paths to direct preloads: `ALibRuntime.Utils.UFile` becomes `UFile` with `const UFile = preload("...")` added to the script. Stops at the deepest segment that names a script file, so an inner class or enum on the end is kept (`A.B.UProfile.TimeFunction` -> `UProfile.TimeFunction`). Classes left with no bare use anywhere are then dropped from the export, which is what keeps a namespace hub from dragging in every file it preloads.
 - backport_string_renames - dictionary, key is the method to replace, value is a dictionary with key "replace":"replace_as", "min_ver": backport_target as int

##### parse_cs
 - namespace_rename - Dictionary with keys "namespace":"rename_as"


### GDScript optimizer

`plugin_init` seeds the following block in each new `plugin_export.yml`. Existing files
without it use the same defaults; omit individual keys to inherit their defaults.

```yaml
options:
  parser_settings:
    parse_gd:
      optimizer:
        enabled: true
        structs: true
        inline_functions: true
        debug_tags: false
        scalar_replacement: true
        struct_read_types: typed_locals # off | typed_locals | as_casts
        scalar_replacement_allow_ref_counted: false
        struct_read_types_allow_ref_counted: false
        inline_functions_allow_ref_counted: false
        inline_functions_allow_variants: false
```

`enabled: false` bypasses the whole optimizer, including struct lowering and validation
of inactive optimization options. Packaging, path relocation, and backporting still run.
When enabled, invalid optimizer keys or values invalidate the export before its files
are copied. Unsupported inline sites remain unchanged with diagnostic reasons.

Structs run before inlining. Mark data classes with `#! struct`, and supported top-level
static functions with `#! inline`. Scalar replacement removes eligible non-escaping local
struct allocations; typed locals restore known types on surviving struct reads. Cast mode
uses `as` at the read site and can cost more than it saves. Reference fields remain excluded
unless their respective `scalar_replacement_allow_ref_counted` or
`struct_read_types_allow_ref_counted` flag is enabled. These can extend lifetimes and
introduce type checks on freed objects. Optimizer output then passes through the normal packaging rewrites.

Each export entry can override individual optimizer keys, inheriting the rest:

```yaml
exports:
  - source: res://addons/my_plugin
    export_name: my-plugin-baseline
    parser_overide_settings:
      parse_gd:
        optimizer:
          enabled: false
```

Keep an optimized export entry alongside this baseline for performance comparisons.
The export log reports optimizer source-site statistics, including applied/skipped inline
calls, direct/expanded calls, scalar replacements, typed captures, and casts. These count
transformations, not runtime invocations. Source scripts and original helper definitions
are retained; no separate optimizer YAML file is needed by PluginExporter.

Direct inlining supports single-return boolean/comparison expressions and String
`begins_with`, `ends_with`, `contains`, and `is_empty` predicates, including conditional
call sites. Arguments must be literals or locals; no conditional temporaries are introduced.
`inline_functions_allow_ref_counted` permits direct reference member/index access and
method calls without parameter lifetime protection. `inline_functions_allow_variants`
permits unchecked Variant substitution, removing signature checks/conversions; unknown
runtime values may include references. Known reference types still require their own opt-in.
Both flags default to false and leave existing template expansion rules unchanged.
The old `allow_ref_counted` key is rejected; replace it with the two struct flags above.

`#! inline; substitute` opts one helper into direct expression substitution: supplied
arguments can be skipped, repeated, or evaluated in body order. Type opt-ins remain
separate. Native rest parameters are supported in eligible templates; simple all/any
loops over a sole rest parameter lower to `and`/`or` chains. Normal inline requires
proven safe arguments for these chains; substitution permits effectful arguments.
Nested expression helpers expand inside arguments and templates, with cycle/depth/size
checks. General loop expansion and conditional temporary extraction remain deferred.

`debug_tags: true` adds searchable `# optimizer-inline;`, `# optimizer-struct;`,
`# optimizer-scalar-replacement;`, and `# optimizer-struct-read;` comments beside
successful transformations. Inline comments record the helper, mode, tag arguments,
nesting depth, and source site. This defaults off and does not change runtime behavior.
