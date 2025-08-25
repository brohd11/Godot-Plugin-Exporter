extends RefCounted
const EditorNodes = preload("u_editor_nodes.gd")
const ScriptEd = preload("script_editor.gd")
const PopupHelper = preload("popup_menu_path_helper.gd")

class ItemParams extends PopupHelper.ParamKeys:
	const POSITION = "POSITION"
	enum Position{
		TOP,
		BOTTOM
	}
	const PRIORITY = "PRIORITY"

class WrapperParams:
	var fs_popup_callable = null
	var items_to_skip = []
	var show_shortcuts = false
	var custom_context_item_data = {}
	
	var non_plugin_base_id = 5000
	var non_plugin_pre_scripts_data = {}
	var non_plugin_post_scripts_data = {}

static func popup_wrapper(new_popup:PopupMenu, popup_to_copy:PopupMenu, wrapper_params=null):
	if wrapper_params == null:
		wrapper_params = WrapperParams.new()
	if wrapper_params.fs_popup_callable == null:
		wrapper_params.fs_popup_callable = _on_wrapper_pressed
	if wrapper_params.custom_context_item_data.is_empty():
		wrapper_params.custom_context_item_data = get_custom_context_items(popup_to_copy)
		wrapper_params.items_to_skip.append_array(wrapper_params.custom_context_item_data.keys())
	
	var popup_item_dict = PopupHelper.create_popup_items_dict(new_popup)
	var top_custom_item_data = {}
	var bottom_custom_item_data = {}
	sort_custom_context_items(wrapper_params.custom_context_item_data, top_custom_item_data, bottom_custom_item_data)
	
	for item_path in top_custom_item_data.keys():
		var item_data = top_custom_item_data.get(item_path)
		_add_custom_item(new_popup, item_path, item_data, popup_item_dict)
	
	if not top_custom_item_data.is_empty():
		new_popup.add_separator()
	
	_copy_popup(new_popup, popup_to_copy, wrapper_params)
	
	if not bottom_custom_item_data.is_empty():
		new_popup.add_separator()
	
	for item_path in bottom_custom_item_data:
		var item_data = bottom_custom_item_data.get(item_path)
		_add_custom_item(new_popup, item_path, item_data, {})
	
	new_popup.id_pressed.connect(wrapper_params.fs_popup_callable.bind(new_popup, popup_to_copy))


static func _copy_popup(new_popup:PopupMenu, popup_to_copy:PopupMenu, wrapper_params:WrapperParams):
	var callable = wrapper_params.fs_popup_callable
	var items_to_skip = wrapper_params.items_to_skip
	var shortcuts = wrapper_params.show_shortcuts
	var base_index = new_popup.item_count
	var new_popup_count = 0
	for i in range(popup_to_copy.item_count):
		var new_popup_index = base_index + new_popup_count
		var is_sep = popup_to_copy.is_item_separator(i)
		if is_sep:
			if new_popup_index > 0 and not new_popup.is_item_separator(new_popup_index - 1):
				new_popup.add_separator()
				new_popup_count += 1
			continue
		
		var id = popup_to_copy.get_item_id(i)
		var text = popup_to_copy.get_item_text(i)
		
		if text in items_to_skip:
			continue
		new_popup_count += 1
		
		var submenu = popup_to_copy.get_item_submenu_node(i)
		if is_instance_valid(submenu):
			var new_submenu = PopupMenu.new()
			_copy_popup(new_submenu, submenu, wrapper_params)
			new_submenu.id_pressed.connect(callable.bind(new_submenu, submenu))
			new_popup.add_submenu_node_item(text, new_submenu)
		else:
			
			new_popup.add_item(text, id)
			if shortcuts:
				var shortcut = popup_to_copy.get_item_shortcut(i)
				new_popup.set_item_shortcut(new_popup_index, shortcut)
		
		var icon = popup_to_copy.get_item_icon(i)
		if icon:
			new_popup.set_item_icon(new_popup_index, icon)
			var mod = popup_to_copy.get_item_icon_modulate(i)
			new_popup.set_item_icon_modulate(new_popup_index, mod)


static func get_custom_context_items(popup_to_copy:PopupMenu):
	var custom_item_data = {}
	_scan_popup_for_custom_items(popup_to_copy, custom_item_data)
	return custom_item_data

static func _scan_popup_for_custom_items(popup_to_copy:PopupMenu, custom_item_data:Dictionary, 
						custom_ancestor:bool=false, parent_data:Dictionary={}):
	
	var custom_item_start_id = 2000
	for i in range(popup_to_copy.item_count):
		var is_sep = popup_to_copy.is_item_separator(i)
		if is_sep:
			continue
		var id = popup_to_copy.get_item_id(i)
		var text = popup_to_copy.get_item_text(i)
		var path = text
		var submenu = popup_to_copy.get_item_submenu_node(i)
		if is_instance_valid(submenu):
			if id >= custom_item_start_id: # don't want to ignore standard submenus
				custom_item_data[path] = {}
				custom_item_data[path]["submenu"] = true
			var icon = popup_to_copy.get_item_icon(i)
			var submenu_data = {
				"popup_path": path,
				ItemParams.ICON_KEY: []
			}
			var is_custom = id >= custom_item_start_id or custom_ancestor
			if custom_ancestor:
				var popup_path = parent_data.get("popup_path")
				if popup_path:
					path = popup_path.path_join(text)
					submenu_data["popup_path"] = path
				if ItemParams.ICON_KEY in parent_data:
					submenu_data[ItemParams.ICON_KEY] = parent_data[ItemParams.ICON_KEY].duplicate()
			submenu_data[ItemParams.ICON_KEY].append(icon)
			
			_scan_popup_for_custom_items(submenu, custom_item_data, is_custom, submenu_data)
		else:
			if id >= custom_item_start_id or custom_ancestor:
				if custom_ancestor:
					var popup_path = parent_data.get("popup_path")
					if popup_path:
						path = popup_path.path_join(text)
				var signal_connections = popup_to_copy.get_signal_connection_list("id_pressed")
				if signal_connections.is_empty():
					print("--- POPUP HAS NO CONNECTIONS ---")
					print(text)
					print("---")
					continue
				var callable = signal_connections.get(0).get("callable") as Callable
				#var args = callable.get_bound_arguments()
				var icon = popup_to_copy.get_item_icon(i)
				var icons = []
				if ItemParams.ICON_KEY in parent_data:
					icons = parent_data.get(ItemParams.ICON_KEY).duplicate()
				icons.append(icon)
				
				var metadata = popup_to_copy.get_item_metadata(i)
				var user_metadata = {}
				if metadata != null:
					user_metadata = metadata
				
				custom_item_data[path] = {
					"id": id,
					PopupHelper.ParamKeys.CALLABLE_KEY: callable,
					#"args": callable.get_bound_arguments(),
					PopupHelper.ParamKeys.ICON_KEY: icons,
					PopupHelper.ParamKeys.METADATA_KEY: user_metadata,
				}

static func _add_custom_item(popup, item_path, item_data, popup_item_dict):
	var submenu = item_data.get("submenu", false)
	if submenu:
		return
	var id = item_data.get("id")
	var callable = item_data.get(ItemParams.CALLABLE_KEY) as Callable
	item_data[ItemParams.CALLABLE_KEY] = null
	if callable == null:
		return
	var parent = PopupHelper.add_single_item(popup, item_path, item_data, popup_item_dict)
	if id < 2000:
		if not parent.id_pressed.is_connected(callable):
			parent.id_pressed.connect(callable)

static func squash_icons(popup:PopupMenu, recursive=true):
	var popup_has_texture = false
	for i in range(popup.item_count):
		if popup.get_item_icon(i) != null:
			popup_has_texture = true
		
		var submenu = popup.get_item_submenu_node(i)
		if submenu and recursive:
			squash_icons(submenu)
	
	if popup_has_texture:
		for i in range(popup.item_count):
			if popup.get_item_icon(i) != null:
				continue
			popup.set_item_indent(i, -2)
			

static func popup_cleanup(popup:PopupMenu):
	if popup.is_item_separator(popup.item_count - 1):
		popup.remove_item(popup.item_count - 1)


static func create_context_plugin_items(plugin:EditorContextMenuPlugin, script_editor, menu_items:Dictionary, context_menu_callable):
	var fs_popup:PopupMenu
	if "SLOT" in plugin:
		if plugin.SLOT == plugin.CONTEXT_SLOT_SCRIPT_EDITOR_CODE:
			fs_popup = ScriptEd.get_popup()
	
	var meta_dict = {}
	var count = 0
	
	var multi_popup_groups = {}
	menu_items = menu_items.duplicate(true)
	
	for menu_path:String in menu_items:
		var slice_count = menu_path.get_slice_count("/")
		if slice_count > 1:
			var first_slice = menu_path.get_slice("/", 0)
			if not first_slice in multi_popup_groups:
				multi_popup_groups[first_slice] = {}
				
			multi_popup_groups[first_slice][menu_path] = menu_items.get(menu_path)
			continue
		
		var popup_data = menu_items.get(menu_path)
		var icon = popup_data.get(ItemParams.ICON_KEY)
		if icon is Array:
			icon = icon[icon.size() - 1]
		elif icon is String:
			icon = PopupHelper._get_icon(icon)
		
		var menu_name = menu_path.get_file()
		plugin.add_context_menu_item(menu_path, context_menu_callable.bind(menu_name), icon)
		
		var metadata = popup_data.get(ItemParams.METADATA_KEY)
		if metadata and fs_popup:
			meta_dict[fs_popup.item_count + count] = metadata
		count += 1
	
	var popup_items = {}
	for group in multi_popup_groups:
		var group_data = multi_popup_groups.get(group)
		var popup = PopupMenu.new()
		popup.id_pressed.connect(_context_plugin_submenu_pressed.bind(popup, script_editor, context_menu_callable))
		popup_items[group] = popup
		var icon = null
		var first_item = false
		for menu_path in group_data.keys():
			var popup_data = menu_items.get(menu_path)
			if not first_item:
				first_item = true
				var icons = popup_data.get(ItemParams.ICON_KEY,[])
				if icons.size() == menu_path.get_slice_count("/"):
					icon = icons[0]
				if icon is String:
					icon = PopupHelper._get_icon(icon)
			popup_data[ItemParams.CALLABLE_KEY] = _context_plugin_submenu_pressed.bind(script_editor, context_menu_callable)
			PopupHelper.add_single_item(popup, menu_path, popup_data, popup_items)
		
		plugin.add_context_submenu_item(group, popup, icon)
	
	if fs_popup:
		set_fs_popup_metadata.call_deferred(fs_popup, meta_dict)

static func set_fs_popup_metadata(fs_popup:PopupMenu, meta_data_dict): #TODO test on weaker machine
	for index in meta_data_dict:
		var meta = meta_data_dict.get(index)
		fs_popup.set_item_metadata(index, meta)


static func _context_plugin_submenu_pressed(id, popup, script_editor, callable):
	var path = PopupHelper.parse_menu_path(id, popup)
	callable.call(script_editor, path)

static func _on_wrapper_pressed(id:int, wrapper_popup:PopupMenu, fs_popup:PopupMenu):
	if id >= 5000:
		return
	fs_popup.id_pressed.emit(id)

static func sort_custom_context_items(all_custom_items, pre_dict, post_dict):
	var pre_priority_dict = {}
	var post_priority_dict = {}
	for item_path in all_custom_items:
		var item_data = all_custom_items.get(item_path)
		var meta = item_data.get(ItemParams.METADATA_KEY)
		if meta is Dictionary:
			var priority = meta.get(ItemParams.PRIORITY, 1000)
			var position = meta.get(ItemParams.POSITION, ItemParams.Position.TOP)
			if position == ItemParams.Position.TOP:
				var pre_priority_keys = pre_priority_dict.keys()
				while priority in pre_priority_keys:
					priority += 1
				pre_priority_dict[priority] = item_path
				pass
			elif position == ItemParams.Position.BOTTOM:
				var post_priority_keys = post_priority_dict.keys()
				while priority in post_priority_keys:
					priority += 1
				post_priority_dict[priority] = item_path
	
	var pre_priority_keys = pre_priority_dict.keys()
	pre_priority_keys.sort()
	
	for key in pre_priority_keys:
		var item_path = pre_priority_dict[key]
		pre_dict[item_path] = all_custom_items[item_path]
	
	var post_priority_keys = post_priority_dict.keys()
	post_priority_keys.sort()
	for key in post_priority_keys:
		var item_path = post_priority_dict[key]
		post_dict[item_path] = all_custom_items[item_path]
	



