@tool
extends EditorScript
## package_init's package cfg template and the unpackaged-dir completion scan.

const Discovery = preload("res://addons/package_exporter/src/class/export/package_discovery.gd")
const PluginInit = preload("res://addons/package_exporter/src/class/export/plugin_init.gd")
const Runner = preload("res://addons/package_exporter/src/class/release/release_runner.gd")
const ROOT = "user://pe_package_init_tests"

static var _failures:Array[String] = []
static var _passed:int = 0


static func run_tests() -> Dictionary:
	_failures = []
	_passed = 0
	_test_package_cfg()
	_test_unpackaged()
	_test_release_workflow()
	_test_godot_build_name()
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
	var dir = "res://addons/package_exporter/export_ignore/test/fixtures/_release_workflow_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	var notes:Array[String] = []
	_check("not a package refused", PluginInit.write_release_workflow(dir, notes), "")
	_check("not a package says why", notes.size() == 1 and notes[0].begins_with("Not a package"), true)
	FileAccess.open(dir.path_join("version.cfg"), FileAccess.WRITE).store_string('[plugin]\nversion="0.1.0"\n')
	notes.clear()
	var path = PluginInit.write_release_workflow(dir, notes)
	_check("written at the package root", path, dir.path_join(".github/workflows/release.yml"))
	_check("warns without a .git dir", notes.size() == 1 and "no .git dir" in notes[0], true)
	var text = FileAccess.get_file_as_string(path)
	_check("calls the reusable workflow", "uses: brohd11/godot-package-exporter/.github/workflows/package-release.yml@%s" % PluginInit.RELEASE_WORKFLOW_REF in text, true)
	_check("runs on version tags", 'tags: ["v*", "[0-9]*"]' in text, true)
	_check("builds on the editor's Godot", 'godot-version: "%s"' % PluginInit.godot_build_name() in text, true)
	_check("manual runs are dry runs", ["workflow_dispatch:" in text, "publish: ${{ github.event_name == 'push' }}" in text], [true, true])
	FileAccess.open(path, FileAccess.WRITE).store_string("edited")
	notes.clear()
	_check("existing not overwritten", [PluginInit.write_release_workflow(dir, notes), FileAccess.get_file_as_string(path)], ["", "edited"])
	_check("existing says why", notes.size() == 1 and notes[0].begins_with("Release workflow already exists"), true)
	Runner.remove_dir(ProjectSettings.globalize_path(dir))


## Names must match godot-builds releases exactly, since CI downloads by them.
static func _test_godot_build_name() -> void:
	_check("patch release", PluginInit.godot_build_name({"major": 4, "minor": 6, "patch": 3, "status": "stable"}), "4.6.3-stable")
	_check("x.y.0 drops the patch", PluginInit.godot_build_name({"major": 4, "minor": 7, "patch": 0, "status": "stable"}), "4.7-stable")
	_check("pre-release", PluginInit.godot_build_name({"major": 4, "minor": 8, "patch": 0, "status": "beta1"}), "4.8-beta1")
	_check("custom build", PluginInit.godot_build_name({"major": 4, "minor": 8, "patch": 0, "status": "custom_build"}), "")
	_check("running editor is official", PluginInit.godot_build_name() != "", true)


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
