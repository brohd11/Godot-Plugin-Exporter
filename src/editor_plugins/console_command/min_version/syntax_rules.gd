extends RefCounted

## Hardcoded min-version rules for GDScript *language* features that have no
## presence in extension_api.json (annotations, operators, typed containers,
## literal forms). Everything with an engine-API footprint is dated data-driven
## via `version_api.gd` instead — this table stays deliberately small.
##
## Patterns match the string/comment-sanitized line (on_raw = false) except raw
## strings, which must inspect the literal itself (on_raw = true).
##
## Intentionally NOT covered (not reliably detectable by regex):
##   - Local constants used as type hints (4.2) — indistinguishable from normal
##     typing.
##   - Typed node exports `@export var x: NodeType` (4.2) — the `@export var x: T`
##     syntax isn't new; only a Node-typed target is, which needs a type check.
## `@export_storage` (4.3) is grouped with the 4.3 export additions but is
## UNVERIFIED (no 4.3 binary to confirm against).

## Each rule: { name, version, on_raw, regex:RegEx }
##   on_raw = true  -> match against the untouched line (needed for string
##                     literal forms like raw strings, which the string-safe
##                     sanitizer would otherwise mask).
##   on_raw = false -> match against string/comment-sanitized code.
const _DEFS := [
	# 4.1
	{"name": "static var", "version": "4.1", "on_raw": false,
		"pattern": "^\\s*static\\s+var\\s+"},
	{"name": "_static_init() static constructor", "version": "4.1", "on_raw": false,
		"pattern": "^\\s*(static\\s+)?func\\s+_static_init\\b"},
	{"name": "@static_unload", "version": "4.1", "on_raw": false,
		"pattern": "^\\s*@static_unload\\b"},
	# 4.2
	{"name": "typed for-loop variable", "version": "4.2", "on_raw": false,
		"pattern": "^\\s*for\\s+[A-Za-z_][A-Za-z0-9_]*\\s*:"},
	# 4.3
	{"name": "is not operator", "version": "4.3", "on_raw": false,
		"pattern": "\\S+\\s+is\\s+not\\s+\\S+"},
	{"name": "not in operator", "version": "4.3", "on_raw": false,
		"pattern": "\\bnot\\s+in\\b"},
	{"name": "@export_custom", "version": "4.3", "on_raw": false,
		"pattern": "^\\s*@export_custom\\b"},
	{"name": "@export_storage", "version": "4.3", "on_raw": false,  # unverified
		"pattern": "^\\s*@export_storage\\b"},
	# 4.4
	{"name": "@export_tool_button", "version": "4.4", "on_raw": false,
		"pattern": "^\\s*@export_tool_button\\b"},
	{"name": "typed Dictionary", "version": "4.4", "on_raw": false,
		"pattern": "\\bDictionary\\s*\\["},
	{"name": "raw string literal", "version": "4.4", "on_raw": true,
		"pattern": "(?<!\\w)r(\"\"\"|'''|\"|')"},
	# 4.5
	{"name": "@abstract / abstract class", "version": "4.5", "on_raw": false,
		"pattern": "^\\s*(@abstract\\b|abstract\\s+(class|func)\\b)"},
	{"name": "variadic function arguments", "version": "4.5", "on_raw": false,
		"pattern": "\\.\\.\\.[A-Za-z_]"},
]

var _rules: Array = []


## Returns [{ name, version, on_raw, regex:RegEx }, ...], compiled once.
func get_rules() -> Array:
	if not _rules.is_empty():
		return _rules
	for def in _DEFS:
		var re := RegEx.new()
		re.compile(def["pattern"])
		_rules.append({
			"name": def["name"],
			"version": def["version"],
			"on_raw": def["on_raw"],
			"regex": re,
		})
	return _rules
