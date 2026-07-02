extends RefCounted

## Scans a plugin's source files and reports the minimum Godot version required.
##
## Per GDScript line:
##   1. Syntax rules (syntax_rules.gd) — hardcoded language features.
##   2. API extractors dated data-driven via version_api.gd (the merged index):
##      static `ClassName.member` access, global utilities, global enum values,
##      bare class references, and bare/`self.` member calls resolved against the
##      script's own base class.
## .tscn/.tres files are scanned for `type="ClassName"` (dates e.g. DPITexture).
##
## Type resolution we can do without a parser:
##   - `ClassName.member` — the receiver IS the class (static access).
##   - bare `foo()` / `self.member` — the receiver is the script's own base class,
##     obtained via `Script.get_instance_base_type()` (resolves the whole extends
##     chain, user classes/paths included, to the native engine type).
## Instance access on other variables (`node.method()`) needs real type inference
## and is deferred to the future parser-based scan.
## Members not present in the index are assumed user-defined and skipped.
##
## Matching is string/comment-safe via URegex's sanitizer (except raw-string
## detection, which must inspect the literal itself).

const URegex = preload("res://addons/addon_lib/brohd/alib_runtime/utils/u_regex.gd")
const VersionApi = preload("res://addons/plugin_exporter/src/editor_plugins/console_command/min_version/version_api.gd")
const SyntaxRules = preload("res://addons/plugin_exporter/src/editor_plugins/console_command/min_version/syntax_rules.gd")

var api := VersionApi.new()

var _syntax := SyntaxRules.new()

var _string_regex: RegEx
var _scoped_regex: RegEx        # Class.member (static access)
var _bare_call_regex: RegEx     # foo(  -> global utility or base-class method
var _self_regex: RegEx          # self.member -> base-class member
var _class_token_regex: RegEx   # bare PascalCase token (class existence)
var _enum_value_regex: RegEx    # bare ALL_CAPS token -> possible global enum value
var _res_type_regex: RegEx      # type="ClassName" in tscn/tres


func _init() -> void:
	_string_regex = URegex.get_strings()
	_scoped_regex = _re("\\b([A-Z][A-Za-z0-9_]*)\\.([A-Za-z_][A-Za-z0-9_]*)\\b")
	_bare_call_regex = _re("(?<![.\\w])([a-z_][A-Za-z0-9_]*)\\s*\\(")
	_self_regex = _re("\\bself\\.([A-Za-z_][A-Za-z0-9_]*)\\b")
	_class_token_regex = _re("\\b([A-Z][A-Za-z0-9_]*)\\b")
	_enum_value_regex = _re("(?<![.\\w])([A-Z][A-Z0-9_]+)\\b")
	_res_type_regex = _re("type=\"([A-Za-z_][A-Za-z0-9_]*)\"")


static func _re(pattern: String) -> RegEx:
	var re := RegEx.new()
	re.compile(pattern)
	return re


## Scan one file. Returns { min_version:String, findings:[{line,feature,version}] }.
func scan_file(file_path: String) -> Dictionary:
	var result := {"min_version": VersionApi.BASELINE, "findings": [], "_seen": {}}
	var ext := file_path.get_extension()
	if ext != "gd" and ext != "tscn" and ext != "tres":
		result.erase("_seen")
		return result

	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		result.erase("_seen")
		return result

	# For .gd, resolve the script's native base class so bare/self calls can be
	# dated against it. "" means unresolved -> bare-call dating is skipped.
	var base := ""
	if ext == "gd":
		base = _resolve_base_type(file_path)

	var line_no := 0
	while not f.eof_reached():
		line_no += 1
		var line := f.get_line()
		if ext == "gd":
			_scan_gd_line(line, line_no, result, base)
		else:
			_scan_resource_line(line, line_no, result)
	f.close()

	result.erase("_seen")
	return result


## Native base type of a .gd script via Script.get_instance_base_type(); "" if it
## can't be loaded as a script.
func _resolve_base_type(file_path: String) -> String:
	var res = load(file_path)
	if res is Script:
		return res.get_instance_base_type()
	return ""


func _scan_gd_line(line: String, line_no: int, result: Dictionary, base: String) -> void:
	var stripped := line.strip_edges()
	if stripped == "" or stripped.begins_with("#"):
		return

	# Sanitized code (strings -> placeholders, comment stripped) for everything
	# except raw-string detection. Lambdas capture locals by value, so use a
	# by-reference Array holder to get the sanitized string back out.
	var holder := [""]
	URegex.string_safe_regex_read(line, func(c): holder[0] = c, _string_regex)
	var sanitized: String = holder[0]

	# 1. Syntax rules.
	for rule in _syntax.get_rules():
		var target: String = line if rule["on_raw"] else sanitized
		if (rule["regex"] as RegEx).search(target) != null:
			_record(result, line_no, rule["name"], rule["version"])

	# 2a. Static ClassName.member access (every class). Class existence is dated
	# separately by 2e below.
	for m in _scoped_regex.search_all(sanitized):
		var cls := m.get_string(1)
		var member := m.get_string(2)
		if api.has_class(cls):
			_record(result, line_no, "%s.%s" % [cls, member], api.member_min_version(cls, member))

	# 2b. Bare calls: global utility, else a member of the script's base class.
	for m in _bare_call_regex.search_all(sanitized):
		var name := m.get_string(1)
		if api.is_global_utility(name):
			_record(result, line_no, "%s()" % name, api.utility_min_version(name))
		elif base != "":
			_record(result, line_no, "%s.%s" % [base, name], api.member_min_version(base, name))

	# 2c. self.member -> member of the script's base class.
	if base != "":
		for m in _self_regex.search_all(sanitized):
			var member := m.get_string(1)
			_record(result, line_no, "%s.%s" % [base, member], api.member_min_version(base, member))

	# 2d. Global enum values (bare ALL_CAPS identifiers).
	for m in _enum_value_regex.search_all(sanitized):
		var name := m.get_string(1)
		var ver := api.global_enum_min_version(name)
		if ver != "":
			_record(result, line_no, name, ver)

	# 2e. Bare engine-class references (dates class existence; 4.0 ones dropped).
	for m in _class_token_regex.search_all(sanitized):
		var cls := m.get_string(1)
		if api.has_class(cls):
			_record(result, line_no, "class %s" % cls, api.class_min_version(cls))


func _scan_resource_line(line: String, line_no: int, result: Dictionary) -> void:
	for m in _res_type_regex.search_all(line):
		var cls := m.get_string(1)
		if api.has_class(cls):
			_record(result, line_no, "resource %s" % cls, api.class_min_version(cls))


## Fold one (feature, version) hit into the result. "" is ignored (unknown /
## user-defined), "4.0" is the baseline (no floor), anything higher raises it.
## Deduped by feature+line so verbose can list every distinct occurrence while a
## feature matched twice on one line collapses.
func _record(result: Dictionary, line_no: int, feature: String, version: String) -> void:
	if version == "" or version == VersionApi.BASELINE:
		return
	var seen: Dictionary = result["_seen"]
	var key := "%s@%d" % [feature, line_no]
	if seen.has(key):
		return
	seen[key] = true
	result["findings"].append({"line": line_no, "feature": feature, "version": version})
	result["min_version"] = VersionApi.max_version(result["min_version"], version)
