@tool
extends EditorScript
## PackageCfg: which file in a dir is the package cfg, [addon] winning over [plugin] per key, and
## the released cfg's require rewrite.

const PackageCfg = preload("res://addons/package_exporter/src/class/export/package_cfg.gd")
const Runner = preload("res://addons/package_exporter/src/class/release/release_runner.gd")
const ROOT = "user://pe_package_cfg_tests"

static var _failures:Array[String] = []
static var _passed:int = 0


static func run_tests() -> Dictionary:
	_failures = []
	_passed = 0
	_test_section()
	_test_config_file()
	_test_find()
	_test_set_require()
	var output:Array[String] = ["package_cfg: %d passed, %d failed" % [_passed, _failures.size()]]
	for failure in _failures:
		output.append("  FAIL  " + failure)
	return {"result": _failures.size(), "output": output}


func _run() -> void: # EditorScript entry, for running this from the editor
	print("\n".join(run_tests().output))


static func _test_section() -> void:
	var text = '[plugin]\nname="p"\nversion="1.0.0"\n\n[addon]\nversion="2.0.0"\nurl="u"\n\n[namespace]\npath="ns"\n'
	_check("section: [addon] overrides, [plugin]-only kept, others ignored", PackageCfg.section(text),
		{"name": '"p"', "version": '"2.0.0"', "url": '"u"'})
	_check("section: [addon] before [plugin] still wins", PackageCfg.section('[addon]\nv=1\n[plugin]\nv=2\n'), {"v": "1"})
	_check("key_section: [addon] holds it", PackageCfg.key_section(text, "version"), "addon")
	_check("key_section: only [plugin] holds it", PackageCfg.key_section(text, "name"), "plugin")
	_check("key_section: nowhere falls back to default", PackageCfg.key_section(text, "deps"), PackageCfg.DEFAULT_SECTION)


static func _test_config_file() -> void:
	var cfg = ConfigFile.new()
	cfg.parse('[plugin]\nname="p"\nversion="1.0.0"\n[addon]\nversion="2.0.0"\n')
	_check("get_value: [addon] wins", PackageCfg.get_value(cfg, "version"), "2.0.0")
	_check("get_value: [plugin] fallback", PackageCfg.get_value(cfg, "name"), "p")
	_check("get_value: default", PackageCfg.get_value(cfg, "url", "none"), "none")


static func _test_find() -> void:
	Runner.remove_dir(ProjectSettings.globalize_path(ROOT))
	_write("all/plugin.cfg", '[plugin]\nversion="1"\n')
	_write("all/addon.cfg", '[plugin]\nversion="2"\n')
	_write("all/version.cfg", '[plugin]\nversion="3"\n')
	_write("av/addon.cfg", '[addon]\nversion="2"\n')
	_write("av/version.cfg", '[plugin]\nversion="3"\n')
	_write("v/version.cfg", '[plugin]\nversion="3"\n')
	DirAccess.make_dir_recursive_absolute(ROOT.path_join("none"))
	_check("find: plugin.cfg first", PackageCfg.find(ROOT.path_join("all")).get_file(), "plugin.cfg")
	_check("find: addon.cfg before version.cfg", PackageCfg.find(ROOT.path_join("av")).get_file(), "addon.cfg")
	_check("find: version.cfg alone", PackageCfg.find(ROOT.path_join("v")).get_file(), "version.cfg")
	_check("find: none", PackageCfg.find(ROOT.path_join("none")), "")
	_check("has_cfg: none", PackageCfg.has_cfg(ROOT.path_join("none")), false)
	_check("dir_value: first file only", PackageCfg.dir_value(ROOT.path_join("all"), "version"), "1")
	_check("dir_value: [addon] in addon.cfg", PackageCfg.dir_value(ROOT.path_join("av"), "version"), "2")
	_check("dir_value: no cfg default", PackageCfg.dir_value(ROOT.path_join("none"), "version", ""), "")
	Runner.remove_dir(ProjectSettings.globalize_path(ROOT))


## Released cfgs list only what an installer must add; the rest of the file is left as written.
static func _test_set_require() -> void:
	var multi = '[plugin]\nname="p"\nversion="1.0.0"\n\nrequire=[\n"a/b@v1",\n"c/d@v2",\n]\n\n[namespace]\npath=""\n'
	_check("multi-line list emptied", PackageCfg.set_require(multi, []),
		'[plugin]\nname="p"\nversion="1.0.0"\n\nrequire=[]\n\n[namespace]\npath=""\n')
	_check("one-line list replaced", PackageCfg.set_require('[plugin]\nrequire=["a/b@v1"]\nversion="1"\n', ["x/y@v3", "z/w@v1"]),
		'[plugin]\nrequire=["x/y@v3", "z/w@v1"]\nversion="1"\n')
	_check("legacy deps key", PackageCfg.set_require('[plugin]\ndeps=["a/b@v1"]\n', []), '[plugin]\ndeps=[]\n')
	_check("[namespace] require untouched", PackageCfg.set_require('[namespace]\nrequire=["k"]\n[plugin]\nversion="1"\n', []),
		'[namespace]\nrequire=["k"]\n[plugin]\nversion="1"\n')
	var plain = '[plugin]\nname="p"\nversion="1"\n\n[namespace]\npath=""\n'
	_check("no key, nothing to add: unchanged", PackageCfg.set_require(plain, []), plain)
	_check("no key: added after version's section", PackageCfg.set_require(plain, ["a/b@v1"]),
		'[plugin]\nname="p"\nversion="1"\nrequire=["a/b@v1"]\n\n[namespace]\npath=""\n')
	_check("[addon] version: added there", PackageCfg.set_require('[plugin]\nname="p"\n[addon]\nversion="1"\n', ["a/b@v1"]),
		'[plugin]\nname="p"\n[addon]\nversion="1"\nrequire=["a/b@v1"]\n')
	_check("multiline replaces a one-line list", PackageCfg.set_require('[plugin]\nrequire=["a/b@v1"]\nversion="1"\n', ["a/b@v2", "c/d@v1"], true),
		'[plugin]\nrequire=[\n"a/b@v2",\n"c/d@v1",\n]\nversion="1"\n')
	_check("multiline adds a missing key", PackageCfg.set_require('[plugin]\nversion="1"\n', ["a/b@v1"], true),
		'[plugin]\nversion="1"\nrequire=[\n"a/b@v1",\n]\n')
	_check("multiline empty stays one line", PackageCfg.set_require(multi, [], true),
		'[plugin]\nname="p"\nversion="1.0.0"\n\nrequire=[]\n\n[namespace]\npath=""\n')


static func _write(relative:String, text:String) -> void:
	var path = ROOT.path_join(relative)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)


static func _check(label:String, got, expected) -> void:
	if got == expected:
		_passed += 1
	else:
		_failures.append("%s (expected %s, got %s)" % [label, expected, got])
