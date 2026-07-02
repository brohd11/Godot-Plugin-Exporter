extends RefCounted

## Hardcoded min-version rules for GDScript *language* features that have no
## presence in extension_api.json (annotations, operators, typed containers,
## literal forms). Everything with an engine-API footprint is dated data-driven
## via `version_api.gd` instead — this table stays deliberately small.
##
## Patterns are lifted verbatim from the backport parsers
## (`.../parse/gd/backport/4_0_backports.gd`, `4_4_backports.gd`).

## Each rule: { name, version, on_raw, regex:RegEx }
##   on_raw = true  -> match against the untouched line (needed for string
##                     literal forms like raw strings, which the string-safe
##                     sanitizer would otherwise mask).
##   on_raw = false -> match against string/comment-sanitized code.
const _DEFS := [
	{"name": "static var", "version": "4.1", "on_raw": false,
		"pattern": "^\\s*static\\s+var\\s+"},
	{"name": "@export_tool_button", "version": "4.4", "on_raw": false,
		"pattern": "^\\s*@export_tool_button\\b"},
	{"name": "is not operator", "version": "4.4", "on_raw": false,
		"pattern": "\\S+\\s+is\\s+not\\s+\\S+"},
	{"name": "typed Dictionary", "version": "4.4", "on_raw": false,
		"pattern": "\\bDictionary\\s*\\["},
	{"name": "raw string literal", "version": "4.4", "on_raw": true,
		"pattern": "(?<!\\w)r(\"\"\"|'''|\"|')"},
	{"name": "@abstract / abstract class", "version": "4.5", "on_raw": false,
		"pattern": "^\\s*(@abstract\\b|abstract\\s+(class|func)\\b)"},
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
