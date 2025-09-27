const CompatData = preload("res://addons/plugin_exporter/src/class/export/backport/compat_data.gd")
const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const UNode = UtilsRemote.UNode

const BACKPORTED = 100

static func type_string_compat(type:int):
	return CompatData.VARIANT_TYPES.get(type, "Type not found: %s" % type)

static func has_static_method_compat(method:String, script:Script) -> bool:
	return UNode.has_static_method_compat(method, script)
