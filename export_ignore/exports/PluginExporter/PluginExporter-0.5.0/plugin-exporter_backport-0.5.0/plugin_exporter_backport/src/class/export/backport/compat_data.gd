
const COMPAT_CLASSES = [
	"EditorContextMenuPlugin"
]

const VARIANT_TYPES = {
	0: "null",
	1: "bool",
	2: "int",
	3: "float",
	4: "String",
	5: "Vector2",
	6: "Vector2i",
	7: "Rect2",
	8: "Rect2i",
	9: "Vector3",
	10: "Vector3i",
	11: "Transform2D",
	12: "Vector4",
	13: "Vector4i",
	14: "Plane",
	15: "Quaternion",
	16: "AABB",
	17: "Basis",
	18: "Transform3D",
	19: "Projection",
	20: "Color",
	21: "StringName",
	22: "NodePath",
	23: "RID",
	24: "Object",
	25: "Callable",
	26: "Signal",
	27: "Dictionary",
	28: "Array",
	29: "PackedByteArray",
	30: "PackedInt32Array",
	31: "PackedInt64Array",
	32: "PackedFloat32Array",
	33: "PackedFloat64Array",
	34: "PackedStringArray",
	35: "PackedVector2Array",
	36: "PackedVector3Array",
	37: "PackedColorArray",
	38: "PackedVector4Array",
	39: "Max"
}

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER CONTEXT BACKPORT
const ContextPluginBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/context/context_backport.gd")
const EditorContextMenuPluginCompat = preload("res://addons/plugin_exporter_backport/src/class/export/backport/context/context_plugin_compat.gd")
### PLUGIN EXPORTER CONTEXT BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_compat_data = "res://addons/plugin_exporter_backport/src/class/export/backport/compat_data.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
