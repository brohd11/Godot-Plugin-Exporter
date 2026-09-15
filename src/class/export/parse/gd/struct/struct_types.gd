extends RefCounted
## Parser-backed lookups for struct_rewrite.gd's access and flow passes, over one source file. The
## GDScriptParser script is passed in rather than preloaded, so this stays import-free for headless
## suites while the exporter reaches the parser through utils_remote like its other libraries.

var parser
var structs:Dictionary
var _ins:String


func _init(parser_script:GDScript, source:String, p_structs:Dictionary, cache:Dictionary) -> void:
	structs = p_structs
	_ins = parser_script.Keys.INS_DELIM
	var ucd = parser_script.UClassDetail
	if ucd.global_class_registry.is_empty(): # filled by an editor signal, absent headless
		ucd.global_class_registry = ucd.get_all_global_class_paths()

	var script = load(source) as GDScript
	parser = parser_script.new()
	parser.set_autoload_cache()
	parser.set_parser_cache(cache)
	parser.set_parser_cache_size(-1) # never evicts, so nothing is written to the on-disk parse cache
	parser.active_parser = parser
	parser.set_current_script(script)
	parser.set_source_code(script.source_code)
	parser.parse()


## Class path of the struct `expr` holds at `line`, or "". A bare class reference resolves without
## the instance mark, so `StructVec` itself never reads as a struct value.
func type_of(expr:String, line:int) -> String:
	var resolved:String = parser.resolve_expression_to_type(expr, line)
	if not resolved.ends_with(_ins):
		return ""
	var path = resolved.trim_suffix(_ins)
	return path if structs.has(path) else ""


func raw_type(expr:String, line:int) -> String:
	return parser.resolve_expression_to_type(expr, line).trim_suffix(_ins)


## The enclosing func's written return type as a class path; "" when it has none, since the parser
## would otherwise infer one from the very return being checked.
func return_path(line:int) -> String:
	var class_obj = parser.get_class_object(parser.get_class_at_line(line))
	if class_obj == null:
		return ""
	var function = class_obj.functions.get(parser.get_function_at_line(line))
	if function == null or not function.has_static_return():
		return ""
	return function.get_return_type().trim_suffix(_ins)


## has_static_type per parameter of `callee`, or null when the parser cannot find it.
func params(callee:String, line:int) -> Variant:
	var args = parser.get_function_data(callee, line).get(&"func_args")
	if not args is Dictionary or args.is_empty():
		return null
	var out = []
	for arg in args.values():
		out.append(arg.get(&"has_static_type", true))
	return out
