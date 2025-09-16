
extends RefCounted

const _MEMBER_ARGS = ["signal", "property", "method", "enum", "const"]

static func class_get_all_members(script:GDScript=null):
	if script == null:
		script = EditorInterface.get_script_editor().get_current_script()
	if script == null:
		return []
	var members = _recur_get_class_members(script)
	return members

static func class_get_all_signals(script):
	if script == null:
		script = EditorInterface.get_script_editor().get_current_script()
	if script == null:
		return []
	var members = _recur_get_class_members(script, ["signal"])
	return members

static func class_get_all_properties(script):
	if script == null:
		script = EditorInterface.get_script_editor().get_current_script()
	if script == null:
		return []
	var members = _recur_get_class_members(script, ["property"])
	return members

static func class_get_all_methods(script):
	if script == null:
		script = EditorInterface.get_script_editor().get_current_script()
	if script == null:
		return []
	var members = _recur_get_class_members(script, ["method"])
	return members

static func class_get_all_constants(script):
	if script == null:
		script = EditorInterface.get_script_editor().get_current_script()
	if script == null:
		return []
	var members = _recur_get_class_members(script, ["const"])
	return members

static func class_get_all_enums(script):
	if script == null:
		script = EditorInterface.get_script_editor().get_current_script()
	if script == null:
		return []
	var members = _recur_get_class_members(script, ["enum"])
	return members


static func _recur_get_class_members(script:Script, desired_members:=_MEMBER_ARGS):
	var members_dict = {}
	
	var instance_type = script.get_instance_base_type()
	if instance_type == null:
		return []
	if "signal" in desired_members:
		var class_signals = ClassDB.class_get_signal_list(instance_type)
		for data in class_signals:
			var name = data.get("name")
			members_dict[name] = true
	if "property" in desired_members:
		var class_properties = ClassDB.class_get_property_list(instance_type)
		for data in class_properties:
			var name = data.get("name")
			members_dict[name] = true
	if "method" in desired_members:
		var class_methods = ClassDB.class_get_method_list(instance_type)
		for data in class_methods:
			var name = data.get("name")
			members_dict[name] = true
	if "enum" in desired_members:
		var class_enums = ClassDB.class_get_enum_list(instance_type)
		for i in class_enums:
			members_dict[i] = true
	if "const" in desired_members:
		var const_map = ClassDB.class_get_integer_constant_list(instance_type)
		for i in const_map:
			members_dict[i] = true
	
	var base_script = script.get_base_script()
	if base_script == null:
		var members_array = members_dict.keys()
		return members_array
	
	var script_members = _get_script_members(base_script, desired_members)
	for i in script_members:
		members_dict[i] = true
	
	var recurs_array = _recur_get_class_members(base_script, desired_members)
	for i in recurs_array:
		members_dict[i] = true
	
	var members_array = members_dict.keys()
	return members_array
	
	
	
	#var members_array = []
	#var instance_type = script.get_instance_base_type()
	#if instance_type == null:
		#return []
	#if "signal" in desired_members:
		#var class_signals = ClassDB.class_get_signal_list(instance_type)
		#for data in class_signals:
			#var name = data.get("name")
			#members_array.append(name)
	#if "property" in desired_members:
		#var class_properties = ClassDB.class_get_property_list(instance_type)
		#for data in class_properties:
			#var name = data.get("name")
			#members_array.append(name)
	#if "method" in desired_members:
		#var class_methods = ClassDB.class_get_method_list(instance_type)
		#for data in class_methods:
			#var name = data.get("name")
			#members_array.append(name)
	#if "enum" in desired_members:
		#var class_enums = ClassDB.class_get_enum_list(instance_type)
		#members_array.append_array(class_enums)
	#if "const" in desired_members:
		#var const_map = ClassDB.class_get_integer_constant_list(instance_type)
		#members_array.append_array(const_map)
	#
	#var base_script = script.get_base_script()
	#if base_script == null:
		#return members_array
	#
	#var script_members = _get_script_members(base_script, desired_members)
	#for i in script_members:
		#if not i in members_array:
			#members_array.append(i)
	#
	#var recurs_array = _recur_get_class_members(base_script, desired_members)
	#for i in recurs_array:
		#if not i in members_array:
			#members_array.append(i)
	#
	#return members_array



static func script_get_all_members(script:Script):
	if script == null:
		script = EditorInterface.get_script_editor().get_current_script()
	return _get_script_members(script)

static func script_get_all_signals(script:Script, inh_class_members:Array=[]):
	if script == null:
		script = EditorInterface.get_script_editor().get_current_script()
	if script == null:
		return []
	var members = _get_script_members(script, ["signal"])
	return members

static func script_get_all_properties(script:Script, inh_class_members:Array=[]):
	if script == null:
		script = EditorInterface.get_script_editor().get_current_script()
	if script == null:
		return []
	var members = _get_script_members(script, ["property"])
	return members

static func script_get_all_methods(script:Script, inh_class_members:Array=[]):
	if script == null:
		script = EditorInterface.get_script_editor().get_current_script()
	if script == null:
		return []
	var members = _get_script_members(script, ["method"])
	return members

static func script_get_all_constants(script:Script, inh_class_members:Array=[]):
	if script == null:
		script = EditorInterface.get_script_editor().get_current_script()
	if script == null:
		return []
	var members = _get_script_members(script, ["const"])
	return members

#static func script_get_all_enums(script:Script, inh_class_members:Array):
	#if script == null:
		#script = EditorInterface.get_script_editor().get_current_script()
	#if script == null:
		#return []
	#var members = _get_script_members(script, inh_class_members, ["enum"])
	#return members


static func _get_script_members(script:Script, desired_members:=_MEMBER_ARGS):
	var members_dict = {}
	if "signal" in desired_members:
		var script_members = script.get_script_signal_list()
		for data in script_members:
			var name = data.get("name")
			members_dict[name] = true
	if "method" in desired_members:
		var script_method_list = script.get_script_method_list()
		for data in script_method_list:
			var name = data.get("name")
			members_dict[name] = true
	if "property" in desired_members:
		var script_property_list = script.get_script_property_list()
		for data in script_property_list:
			var name = data.get("name")
			members_dict[name] = true
	if "const" in desired_members:
		var const_array = script.get_script_constant_map().keys()
		for name in const_array:
			members_dict[name] = true
	
	
	var members_array = members_dict.keys()
	
	#var members_array = []
	#if "signal" in desired_members:
		#var script_members = script.get_script_signal_list()
		#for data in script_members:
			#var name = data.get("name")
			#if not name in inh_class_members:
				#members_array.append(name)
	#if "method" in desired_members:
		#var script_method_list = script.get_script_method_list()
		#for data in script_method_list:
			#var name = data.get("name")
			#if not name in inh_class_members:
				#members_array.append(name)
	#if "property" in desired_members:
		#var script_property_list = script.get_script_property_list()
		#for data in script_property_list:
			#var name = data.get("name")
			#if not name in inh_class_members:
				#members_array.append(name)
	#if "const" in desired_members:
		#var const_array = script.get_script_constant_map().keys()
		#for name in const_array:
			#if not name in inh_class_members:
				#members_array.append(name)
	
	#if "enum" in desired_members:
		#var enum_list = script
	
	return members_array

