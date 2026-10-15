@tool
extends EditorScript
## package_init's package cfg template and the unpackaged-dir completion scan.

const Discovery = preload("res://addons/plugin_exporter/src/class/export/package_discovery.gd")
const PluginInit = preload("res://addons/plugin_exporter/src/class/export/plugin_init.gd")
const Runner = preload("res://addons/plugin_exporter/src/class/release/release_runner.gd")
const ROOT = "user://pe_package_init_tests"

static var _failures:Array[String] = []
static var _passed:int = 0


static func run_tests() -> Dictionary:
	_failures = []
	_passed = 0
	_test_package_cfg()
	_test_unpackaged()
	_test_release_workflow()
	var output:Array[String] = ["package_init: %d passed, %d failed" % [_passed, _failures.size()]]
	for failure in _failures:
		output.append("  FAIL  " + failure)
	return {"result": _failures.size(), "output": output}


static func _test_package_cfg() -> void:
	var cfg = ConfigFile.new()
	_check("cfg parses", cfg.parse(PluginInit.package_cfg_text("res://addons/_lib/my_pkg/")), OK)
	_check("name is folder", cfg.get_value("plugin", "name"), "my_pkg")
	_check("path drops res://", cfg.get_value("plugin", "path"), "addons/_lib/my_pkg")
	_check("version", cfg.get_value("plugin", "version"), "0.1.0")
	_check("url", cfg.get_value("plugin", "url"), "")
	_check("require", cfg.get_value("plugin", "require"), [])
	_check("namespace path", cfg.get_value("namespace", "path"), "")


static func _test_unpackaged() -> void:
	Runner.remove_dir(ProjectSettings.globalize_path(ROOT))
	_mkdir("bare/deep/deeper")
	_mkdir("group/lib/src")
	_mkdir("group/new_lib")
	_write("addon_pkg/addon.cfg")
	_mkdir(".hidden/x")
	_mkdir("_export_ignore/x")
	_write("plugin/plugin.cfg")
	_mkdir("plugin/src")
	_write("group/lib/version.cfg")
	var dir = DirAccess.open(ROOT)
	_check("symlink fixture", dir.create_link(ProjectSettings.globalize_path(ROOT), "loop"), OK)
	_check("unpackaged default depth", Discovery.discover_unpackaged(ROOT).keys(),
		["bare", "bare/deep", "group", "group/new_lib"])
	_check("depth 1", Discovery.discover_unpackaged(ROOT, 1).keys(), ["bare", "group"])
	_write("group/new_lib/version.cfg")
	_check("initialized drops off", Discovery.discover_unpackaged(ROOT).keys(), ["bare", "bare/deep", "group"])
	_check("missing root", Discovery.discover_unpackaged(ROOT.path_join("missing")), {})
	DirAccess.remove_absolute(ROOT.path_join("loop"))
	Runner.remove_dir(ProjectSettings.globalize_path(ROOT))


## Opt-in only: written at the package root, never over an existing file, refused for non-packages.
static func _test_release_workflow() -> void:
	var dir = "res://addons/plugin_exporter/export_ignore/test/fixtures/_release_workflow_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	_check("not a package refused", PluginInit.add_release_workflow(dir), "")
	FileAccess.open(dir.path_join("version.cfg"), FileAccess.WRITE).store_string('[plugin]\nversion="0.1.0"\n')
	var path = PluginInit.add_release_workflow(dir)
	_check("written at the package root", path, dir.path_join(".github/workflows/release.yml"))
	var text = FileAccess.get_file_as_string(path)
	_check("calls the reusable workflow", "uses: brohd11/Godot-Plugin-Exporter/.github/workflows/package-release.yml@%s" % PluginInit.RELEASE_WORKFLOW_REF in text, true)
	_check("runs on version tags", 'tags: ["v*", "[0-9]*"]' in text, true)
	FileAccess.open(path, FileAccess.WRITE).store_string("edited")
	_check("existing not overwritten", [PluginInit.add_release_workflow(dir), FileAccess.get_file_as_string(path)], ["", "edited"])
	Runner.remove_dir(ProjectSettings.globalize_path(dir))


static func _mkdir(relative:String) -> void:
	DirAccess.make_dir_recursive_absolute(ROOT.path_join(relative))


static func _write(relative:String) -> void:
	var path = ROOT.path_join(relative)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("")


static func _check(label:String, got, expected) -> void:
	if got == expected:
		_passed += 1
	else:
		_failures.append("%s (expected %s, got %s)" % [label, expected, got])
