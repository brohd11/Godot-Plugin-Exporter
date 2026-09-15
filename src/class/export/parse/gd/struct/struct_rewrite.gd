extends RefCounted
## Text side of `#! struct`: reads a tagged data-only class, generates its array form and rewrites
## the sites naming it. Import-light so a headless suite can load it - parse/gd/struct.gd resolves
## names against the export and applies the results.

const TagRegistry = preload("res://addons/plugin_exporter/src/class/export/tag_registry.gd")

const CREATE_FUNC = "create"
const ALLOWED_EXTENDS = ["", "RefCounted", "Object"]

const _CHAIN = r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*"

static var _regexes:Dictionary = {}
static var _variant_types:Dictionary = {}


#region Definition

## {class_path, fields:[{name, enum, type, default, fill, line}], args:[{name, text}], arg_slots,
## body_start, body_end, indent, literal_ok, errors}. `target` is the class line, or for a
## whole-file struct any header line. Errors are "line N: message".
static func parse_def(lines:PackedStringArray, target:int, is_file:bool, class_path:String) -> Dictionary:
	var def = {
		"class_path": class_path, "fields": [], "args": [], "arg_slots": [],
		"body_start": -1, "body_end": -1, "indent": "", "literal_ok": true, "errors": [],
	}
	var errors:Array = def.errors
	if target < 0 or target >= lines.size():
		errors.append(_err(target, "#! struct target line is out of range"))
		return def

	var decl_indent = _indent_of(lines[target])
	if not is_file:
		var cm = _rx("class").search(lines[target].strip_edges())
		if cm == null:
			errors.append(_err(target, "#! struct must sit above a class declaration"))
			return def
		if not cm.get_string("extends") in ALLOWED_EXTENDS:
			errors.append(_err(target, "a struct cannot extend " + cm.get_string("extends")))
		if cm.get_string("rest") != "":
			errors.append(_err(target, "a one-line struct class is not supported"))

	var state = {"quote": "", "depth": 0, "cont": false}
	var body_indent = -1
	var in_init = false
	var assigns:Array = [] # [field, arg, line]
	for i in range(0 if is_file else target + 1, lines.size()):
		var raw = lines[i]
		var continued:bool = state.cont
		var comment_idx = TagRegistry.scan_code(raw, state)
		var code = (raw.substr(0, comment_idx) if comment_idx > -1 else raw).strip_edges()
		if code.is_empty():
			continue
		var indent = _indent_of(raw)
		if not is_file and indent <= decl_indent and not continued:
			break
		if continued:
			errors.append(_err(i, "multi-line statements are not supported in a struct"))
			continue
		if is_file and indent == 0 and _is_header(code):
			var ext = _header_extends(code)
			if not ext in ALLOWED_EXTENDS:
				errors.append(_err(i, "a struct cannot extend " + ext))
			continue

		if def.body_start == -1:
			def.body_start = i
			body_indent = indent
			def.indent = raw.substr(0, indent)
		def.body_end = i

		if indent > body_indent:
			if not in_init:
				errors.append(_err(i, "unexpected indentation: " + code))
			elif code != "pass":
				_add_assign(code, i, assigns, errors)
			continue

		in_init = false
		var vm = _rx("var").search(code)
		if vm:
			def.fields.append({
				"name": vm.get_string("name"),
				"type": "" if vm.get_string("op") == ":=" else vm.get_string("type").strip_edges(),
				"default": vm.get_string("default").strip_edges(),
				"line": i,
			})
			continue
		var fm = _rx("func").search(code)
		if fm and fm.get_string("name") == "_init" and not code.begins_with("static"):
			_parse_init(code, i, def, assigns)
			in_init = true
			continue
		if code != "pass":
			errors.append(_err(i, "a struct only holds var fields and _init: " + code))

	_resolve_slots(def, target, assigns)
	return def


static func _parse_init(code:String, line:int, def:Dictionary, assigns:Array) -> void:
	var open = code.find("(")
	var close = _find_close(code, _string_mask(code), open)
	if close == -1:
		def.errors.append(_err(line, "a multi-line _init signature is not supported"))
		return
	for arg_text:String in _split_args(code.substr(open + 1, close - open - 1)):
		var am = _rx("arg").search(arg_text)
		if am == null:
			def.errors.append(_err(line, "unreadable _init argument: " + arg_text))
			continue
		def.args.append({"name": am.get_string("name"), "text": arg_text})

	var tail = code.substr(close + 1).strip_edges()
	if tail.begins_with("->"):
		tail = tail.substr(tail.find(":")) if tail.contains(":") else ""
	var inline = tail.trim_prefix(":").strip_edges()
	if inline != "" and inline != "pass":
		for stmt in inline.split(";", false):
			_add_assign(stmt.strip_edges(), line, assigns, def.errors)


static func _add_assign(code:String, line:int, assigns:Array, errors:Array) -> void:
	var am = _rx("assign").search(code)
	if am == null:
		errors.append(_err(line, "_init may only assign fields from its arguments: " + code))
	else:
		assigns.append([am.get_string("field"), am.get_string("arg"), line])


## Maps _init args onto slots and decides what fills the rest. A site can only be inlined as a
## literal when args already land in slot order (evaluation order is kept) and every other slot
## fills with a literal - a default naming something in the struct's scope means nothing elsewhere.
static func _resolve_slots(def:Dictionary, target:int, assigns:Array) -> void:
	var errors:Array = def.errors
	if def.fields.is_empty():
		errors.append(_err(target, "a struct needs at least one var field"))

	var slots = {}
	var enums = {}
	for idx in def.fields.size():
		var field:Dictionary = def.fields[idx]
		field.enum = field.name.to_upper()
		if enums.has(field.enum):
			errors.append(_err(field.line, "fields %s and %s both become enum %s" % [enums[field.enum], field.name, field.enum]))
		enums[field.enum] = field.name
		slots[field.name] = idx

	var arg_index = {}
	for k in def.args.size():
		arg_index[def.args[k].name] = k
	def.arg_slots.resize(def.args.size())
	def.arg_slots.fill(-1)
	var slot_taken = {}
	for a in assigns:
		if not slots.has(a[0]):
			errors.append(_err(a[2], "%s is not a field" % a[0]))
		elif not arg_index.has(a[1]):
			errors.append(_err(a[2], "%s is not an _init argument" % a[1]))
		elif slot_taken.has(slots[a[0]]):
			errors.append(_err(a[2], "field %s is assigned twice" % a[0]))
		elif def.arg_slots[arg_index[a[1]]] != -1:
			errors.append(_err(a[2], "argument %s is assigned twice" % a[1]))
		else:
			def.arg_slots[arg_index[a[1]]] = slots[a[0]]
			slot_taken[slots[a[0]]] = true
	for k in def.args.size():
		if def.arg_slots[k] == -1:
			errors.append(_err(target, "_init argument %s is never assigned to a field" % def.args[k].name))
		elif k > 0 and def.arg_slots[k] <= def.arg_slots[k - 1]:
			def.literal_ok = false

	for idx in def.fields.size():
		var field:Dictionary = def.fields[idx]
		field.fill = field.default if field.default != "" else type_default(field.type)
		if not slot_taken.has(idx) and _rx("literal").search(field.fill) == null:
			def.literal_ok = false


## What an unassigned typed var holds before anything writes it.
static func type_default(type:String) -> String:
	if type.begins_with("Array"):
		return "[]"
	if type.begins_with("Dictionary"):
		return "{}"
	match type:
		"int": return "0"
		"float": return "0.0"
		"bool": return "false"
		"String": return '""'
		"StringName": return '&""'
		"NodePath": return '^""'
	if _is_variant_type(type) and type != "Object" and type != "Nil":
		return type + "()"
	return "null"


## The class body that replaces lines body_start..body_end: slot enum plus a constructor.
static func build_body(def:Dictionary) -> PackedStringArray:
	var indent:String = def.indent
	var inner = indent + ("    " if indent.begins_with(" ") else "\t")
	var names = []
	for field in def.fields:
		names.append(field.enum)
	var args = []
	var arg_names = []
	for a in def.args:
		args.append(a.text)
		arg_names.append(a.name)
	return PackedStringArray([
		indent + "enum { %s }" % ", ".join(names),
		indent + "static func %s(%s) -> Array:" % [CREATE_FUNC, ", ".join(args)],
		inner + "return [%s]" % ", ".join(_slot_values(def, arg_names)),
	])


static func _slot_values(def:Dictionary, arg_values:Array) -> Array:
	var values = []
	for idx in def.fields.size():
		var k = def.arg_slots.find(idx)
		values.append(arg_values[k] if k > -1 else def.fields[idx].fill)
	return values

#endregion


#region Sites

## Rewrites constructors and type hints naming a struct. `resolve.call(head, line)` returns the
## class path a written name refers to, or "". Returns {lines, ops, errors}; `ops` is
## {line: [[from, to], ...]} in order, so apply_ops() can replay them on the export's copy of the
## file, which earlier passes may already have edited elsewhere on the line.
static func rewrite_lines(lines:PackedStringArray, resolve:Callable, structs:Dictionary) -> Dictionary:
	var out:PackedStringArray = lines.duplicate()
	var ops = {}
	var errors = []
	var state = {"quote": "", "depth": 0, "cont": false}
	for i in lines.size():
		var in_string = state.quote != ""
		var comment_idx = TagRegistry.scan_code(lines[i], state)
		if in_string:
			continue
		var code = lines[i].substr(0, comment_idx) if comment_idx > -1 else lines[i]
		var line_ops = []
		code = _rewrite_constructors(code, i, resolve, structs, line_ops)
		_check_is(code, i, resolve, structs, errors)
		code = _rewrite_hints(code, i, resolve, structs, line_ops)
		if line_ops.is_empty():
			continue
		out[i] = code + (lines[i].substr(comment_idx) if comment_idx > -1 else "")
		ops[i] = line_ops
	return {"lines": out, "ops": ops, "errors": errors}


## Replays rewrite_lines() ops onto `lines` in place; returns what could not be found.
static func apply_ops(lines:Array, ops:Dictionary) -> Array:
	var errors = []
	for i:int in ops:
		for op in ops[i]:
			var idx = lines[i].find(op[0]) if i < lines.size() else -1
			if idx == -1:
				errors.append(_err(i, "expected `%s` on this line" % op[0]))
				continue
			lines[i] = lines[i].substr(0, idx) + op[1] + lines[i].substr(idx + op[0].length())
	return errors


## Innermost first, so a constructor nested in another's args is already an array when the outer
## one splits its args.
static func _rewrite_constructors(code:String, line:int, resolve:Callable, structs:Dictionary, line_ops:Array) -> String:
	var limit = code.length()
	while true:
		var mask = _string_mask(code)
		var best:RegExMatch = null
		var def:Dictionary = {}
		for m in _rx("new").search_all(code):
			if m.get_start() >= limit:
				break
			if mask[m.get_start()] == 1:
				continue
			var found = _struct_for(m.get_string("head"), line, resolve, structs)
			if not found.is_empty():
				best = m
				def = found
		if best == null:
			return code

		var start = best.get_start()
		var open = best.get_end() - 1
		var head = best.get_string("head")
		var close = _find_close(code, mask, open)
		var from:String
		var to:String
		if close == -1: # args continue on the next line, which create() takes as they are
			from = code.substr(start, open + 1 - start)
			to = "%s.%s(" % [head, CREATE_FUNC]
		else:
			from = code.substr(start, close + 1 - start)
			var given = _split_args(code.substr(open + 1, close - open - 1))
			if def.literal_ok and given.size() == def.args.size():
				to = "[%s]" % ", ".join(_slot_values(def, given))
			else:
				to = "%s.%s%s" % [head, CREATE_FUNC, code.substr(open, close + 1 - open)]
		code = code.substr(0, start) + to + code.substr(start + from.length())
		line_ops.append([from, to])
		limit = start
	return code


static func _check_is(code:String, line:int, resolve:Callable, structs:Dictionary, errors:Array) -> void:
	var mask = _string_mask(code)
	for m in _rx("is").search_all(code):
		if mask[m.get_start()] == 1:
			continue
		if not _struct_for(m.get_string("chain"), line, resolve, structs).is_empty():
			errors.append(_err(line, "`is %s` cannot work once the struct is an Array" % m.get_string("chain")))


## `: S`, `-> S`, `as S`, `Array[S]`, `Dictionary[K, S]` -> Array. Right to left within a pattern so
## earlier match positions stay valid.
static func _rewrite_hints(code:String, line:int, resolve:Callable, structs:Dictionary, line_ops:Array) -> String:
	for key in ["hint", "typed_first", "typed_second"]:
		var mask = _string_mask(code)
		var matches = _rx(key).search_all(code)
		for k in range(matches.size() - 1, -1, -1):
			var m:RegExMatch = matches[k]
			if mask[m.get_start("chain")] == 1:
				continue
			if _struct_for(m.get_string("chain"), line, resolve, structs).is_empty():
				continue
			var to = m.get_string("pre") + "Array"
			line_ops.append([m.get_string(), to])
			code = code.substr(0, m.get_start()) + to + code.substr(m.get_end())
	return code


static func _struct_for(head:String, line:int, resolve:Callable, structs:Dictionary) -> Dictionary:
	if not head.contains(".") and (_is_variant_type(head) or ClassDB.class_exists(head)):
		return {}
	return structs.get(resolve.call(head, line), {})

#endregion


#region Text helpers

## 1 for every character inside a string literal on this single line.
static func _string_mask(code:String) -> PackedByteArray:
	var mask = PackedByteArray()
	mask.resize(code.length())
	var quote = ""
	var i = 0
	while i < code.length():
		var c = code[i]
		if quote == "" and (c == '"' or c == "'"):
			var triple = c + c + c
			quote = triple if code.substr(i, 3) == triple else c
			for k in quote.length():
				mask[i + k] = 1
			i += quote.length()
			continue
		if quote != "":
			mask[i] = 1
			if c == "\\" and i + 1 < code.length():
				mask[i + 1] = 1
				i += 2
				continue
			if code.substr(i, quote.length()) == quote:
				for k in quote.length():
					mask[i + k] = 1
				i += quote.length()
				quote = ""
				continue
		i += 1
	return mask


static func _find_close(code:String, mask:PackedByteArray, open:int) -> int:
	var depth = 0
	for i in range(open, code.length()):
		if mask[i] == 1:
			continue
		var c = code[i]
		if c in "([{":
			depth += 1
		elif c in ")]}":
			depth -= 1
			if depth == 0:
				return i
	return -1


static func _split_args(text:String) -> Array:
	if text.strip_edges() == "":
		return []
	var mask = _string_mask(text)
	var out = []
	var depth = 0
	var last = 0
	for i in text.length():
		if mask[i] == 1:
			continue
		var c = text[i]
		if c in "([{":
			depth += 1
		elif c in ")]}":
			depth -= 1
		elif c == "," and depth == 0:
			out.append(text.substr(last, i - last).strip_edges())
			last = i + 1
	out.append(text.substr(last).strip_edges())
	return out


static func _is_header(code:String) -> bool:
	return code.begins_with("extends") or code.begins_with("class_name") or _rx("annotation").search(code) != null


static func _header_extends(code:String) -> String:
	var m = _rx("extends").search(code)
	return m.get_string("name") if m else ""


static func _indent_of(line:String) -> int:
	return line.length() - line.strip_edges(true, false).length()


static func _is_variant_type(type:String) -> bool:
	if _variant_types.is_empty():
		for i in TYPE_MAX:
			_variant_types[type_string(i)] = true
	return _variant_types.has(type)


static func _err(line:int, msg:String) -> String:
	return "line %d: %s" % [line + 1, msg]


static func _rx(key:String) -> RegEx:
	if _regexes.is_empty():
		var patterns = {
			"class": r"^class\s+(?<name>\w+)(?:\s+extends\s+(?<extends>[\w.]+))?\s*:\s*(?<rest>.*)$",
			"var": r"^var\s+(?<name>\w+)\s*(?::\s*(?<type>[\w.\[\], ]+?))?\s*(?:(?<op>:?=)\s*(?<default>.+?))?\s*$",
			"func": r"^(?:static\s+)?func\s+(?<name>\w+)\s*\(",
			"arg": r"^(?<name>\w+)\s*(?::\s*(?<type>[^=]+?))?\s*(?:(?<op>:?=)\s*(?<default>.+?))?\s*$",
			"assign": r"^(?:self\.)?(?<field>\w+)\s*=\s*(?<arg>\w+)$",
			"extends": r"(?:^|\s)extends\s+(?<name>\S+)",
			"annotation": r"^@\w+(?:\(.*\))?$",
			"new": r"(?<![\w.])(?<head>" + _CHAIN + r")\.new\(",
			"is": r"\bis\s+(?<chain>" + _CHAIN + ")",
			"hint": r"(?<pre>->\s*|\bas\s+|\b\w+\s*:\s*)(?<chain>" + _CHAIN + r")(?![\w.(\[])",
			"typed_first": r"(?<pre>\b(?:Array|Dictionary)\[\s*)(?<chain>" + _CHAIN + r")(?=\s*[\],])",
			"typed_second": r"(?<pre>\bDictionary\[\s*" + _CHAIN + r"\s*,\s*)(?<chain>" + _CHAIN + r")(?=\s*\])",
			"literal": r'^(?:-?\d[\d_.eE+-]*|true|false|null|"[^"\\]*"|&"[^"\\]*"|\^"[^"\\]*"|\[\s*\]|\{\s*\}|[A-Z]\w*\(\s*\))$',
		}
		for k in patterns:
			var regex = RegEx.new()
			regex.compile(patterns[k])
			_regexes[k] = regex
	return _regexes[key]

#endregion
