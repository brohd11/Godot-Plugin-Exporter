

static func get_major_version():
	var godot_ver = Engine.get_version_info()
	return godot_ver.major

static func get_minor_version():
	var godot_ver = Engine.get_version_info()
	return godot_ver.minor

static func get_patch():
	var godot_ver = Engine.get_version_info()
	return godot_ver.patch

