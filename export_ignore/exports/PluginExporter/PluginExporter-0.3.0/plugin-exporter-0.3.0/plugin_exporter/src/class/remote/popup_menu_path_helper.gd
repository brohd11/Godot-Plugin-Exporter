extends PopupMenu

var popup_items_dict:Dictionary = {}

var mouse_helper :MouseHelper

signal item_pressed_parsed_menu_path(menu_path)
signal item_pressed_parsed(id_text)
signal item_pressed(id, popup)

func _parse_item_clicked(id, popup:PopupMenu):
	item_pressed.emit(id,popup)
	item_pressed_parsed.emit(parse_id_text(id, popup))
	item_pressed_parsed_menu_path.emit(parse_menu_path(id, popup))

static func parse_id_text(id, popup:PopupMenu):
	var index = popup.get_item_index(id)
	return popup.get_item_text(index)

static func parse_menu_path(id:int, popup:PopupMenu):
	var metadata = get_metadata(id, popup)
	return metadata.get("menu_path")

static func parse_callable(id, popup, dict, callable_key=ParamKeys.CALLABLE_KEY):
	var menu_path = parse_menu_path(id, popup)
	var data = dict.get(menu_path, {})
	var callable = data.get(callable_key)
	if callable:
		callable.call()

static func get_metadata(id, popup:PopupMenu):
	var index = popup.get_item_index(id)
	return popup.get_item_metadata(index)

static func set_popup_description(popup:PopupMenu, id:int, text:String):
	var index = popup.get_item_index(id)
	popup.set_item_metadata(index, {"description": text})

func _init(path_dict=null, mouse_signal_node=null, base_id=-1) -> void:
	if not path_dict:
		return
	parse_dict(path_dict, mouse_signal_node, base_id)


func parse_dict(path_dict, mouse_signal_node, base_id=-1, extra_args=[]):
	if mouse_signal_node == null:
		popup_hide.connect(_on_popup_hide.bind(self))
		mouse_helper = MouseHelper.new(self)
		mouse_signal_node = mouse_helper
	_parse_dict(path_dict, self, _parse_item_clicked, popup_items_dict, base_id, extra_args)
	connect_mouse_signals(popup_items_dict, mouse_signal_node)

# use static func to process an existing popup
static func parse_dict_static(path_dict, popup, callable,  mouse_signal_node=null, base_id=-1, extra_args=[]):
	var item_dict = {}
	_parse_dict(path_dict, popup, callable ,item_dict, base_id, extra_args)
	connect_mouse_signals(item_dict, mouse_signal_node)


static func _parse_dict(path_dict, popup:PopupMenu, callable:Callable, item_dict, base_id=-1, extra_args=[]):
	if not popup.id_pressed.is_connected(callable):
		if extra_args.is_empty():
			popup.id_pressed.connect(callable.bind(popup))
		else:
			popup.id_pressed.connect(callable.bindv(extra_args).bind(popup))
	item_dict["ZZ_ROOT_POPUP_MENU_ZZ"] = popup # adds popup to dict to include in connect_signals
	var current_id = base_id
	for key in path_dict:
		var menu_path = key
		var data = path_dict.get(key)
		var icons = data.get(ParamKeys.ICON_KEY)
		var icon_colors = data.get(ParamKeys.ICON_COLOR_KEY)
		var tool_tips = data.get(ParamKeys.TOOL_TIP_KEY)
		var metadata = data.get(ParamKeys.METADATA_KEY)
		
		var params = PopupMenuPathParams.new(menu_path, popup, callable, item_dict)
		if icons:
			params.icon_array = icons
		if icon_colors:
			params.icon_color_array = icon_colors
		if tool_tips:
			params.tool_tip_array = tool_tips
		if metadata:
			params.metadata = metadata
		_parse_popup_menu_path(params, current_id, extra_args)
		
		if base_id != -1:
			current_id += 1
		

static func connect_mouse_signals(item_dict, mouse_signal_node):
	if not mouse_signal_node:
		return
	for popup:PopupMenu in item_dict.values():
		if not popup.mouse_entered.is_connected(mouse_signal_node._on_mouse_entered):
			popup.mouse_entered.connect(mouse_signal_node._on_mouse_entered)
		if not popup.mouse_exited.is_connected(mouse_signal_node._on_mouse_exited):
			popup.mouse_exited.connect(mouse_signal_node._on_mouse_exited)


static func _parse_popup_menu_path(popup_menu_path_params:PopupMenuPathParams, current_id, extra_args=[]):
	popup_menu_path_params.even_array_sizes()
	var popup_menu_path = popup_menu_path_params.popup_menu_path
	var icon_array = popup_menu_path_params.icon_array
	var icon_color_array = popup_menu_path_params.icon_color_array
	var base_popup = popup_menu_path_params.base_popup
	var signal_callable = popup_menu_path_params.signal_callable
	var tool_tip_array = popup_menu_path_params.tool_tip_array
	var item_dict = popup_menu_path_params.popup_items_dict
	var user_metadata = popup_menu_path_params.metadata
	
	var slice_count = popup_menu_path.get_slice_count("/")
	var working_menu_path = ""
	var parent_popup:PopupMenu = base_popup
	
	for i in range(slice_count):
		var icon
		if i < icon_array.size():
			icon = icon_array[i]
		var icon_color
		if i < icon_color_array.size():
			icon_color = icon_color_array[i]
		var tool_tip
		if i < tool_tip_array.size():
			tool_tip = tool_tip_array[i]
		
		var slice = popup_menu_path.get_slice("/", i)
		working_menu_path = working_menu_path.path_join(slice)
		if  i == slice_count - 1: # THIS IS THE CLICKABLE
			if working_menu_path.begins_with("sep"):
				parent_popup.add_separator()
				break
			
			_create_popup_item(parent_popup, slice, tool_tip, icon, icon_color, current_id)
			var popup_index = parent_popup.item_count - 1
			var metadata = {
				"menu_path": popup_menu_path,
				"description":tool_tip
			}
			if not user_metadata.is_empty():
				for key in user_metadata.keys():
					metadata[key] = user_metadata.get(key)
			
			parent_popup.set_item_metadata(popup_index, metadata)
			break
		
		var path_popup: PopupMenu
		if working_menu_path in item_dict:
			path_popup = item_dict.get(working_menu_path)
		else:
			path_popup = PopupMenu.new()
			if signal_callable != null:
				if extra_args.is_empty():
					path_popup.id_pressed.connect(signal_callable.bind(path_popup))
				else:
					path_popup.id_pressed.connect(signal_callable.bindv(extra_args).bind(path_popup))
			path_popup.submenu_popup_delay = 0
			_create_popup_item(parent_popup, slice, tool_tip, icon, icon_color, -1, path_popup)
			item_dict[working_menu_path] = path_popup
			
		
		parent_popup = path_popup
	
	return parent_popup

static func _create_popup_item(popup:PopupMenu, text, tool_tip, icon, color, id, submenu_node:PopupMenu=null):
	if submenu_node:
		popup.add_submenu_node_item(text, submenu_node)
		var popup_index = popup.item_count - 1
		if icon:
			if icon is String:
				icon = _get_icon(icon)
			popup.set_item_icon(popup_index, icon)
			if color:
				popup.set_item_icon_modulate(popup_index, color)
		if tool_tip:
			popup.set_item_metadata(popup_index, {"description":tool_tip})
			#popup.set_item_tooltip(popup_index, tool_tip) # this doesn't seem to work
	else:
		if icon:
			if icon is String:
				icon = _get_icon(icon)
			popup.add_icon_item(icon, text, id)
			var popup_index = popup.item_count - 1
			if color:
				popup.set_item_icon_modulate(popup_index, color)
			#if tool_tip:
				#popup.set_item_tooltip(popup_index, tool_tip)
		else:
			popup.add_item(text, id)
		#if tool_tip:
			#var popup_index = popup.item_count - 1
			#popup.set_item_tooltip(popup_index, tool_tip)

static func _on_popup_hide(popup): # if no mouse signal node, free popup
	popup.queue_free()

class ParamKeys:
	const ICON_KEY = "ICON_KEY"
	const ICON_COLOR_KEY = "ICON_COLOR_KEY"
	const TOOL_TIP_KEY = "TOOL_TIP_KEY"
	const CALLABLE_KEY = "CALLABLE_KEY"
	const METADATA_KEY = "METADATA_KEY"

class PopupMenuPathParams:
	func _init(_popup_menu_path, _base_popup, _callable, _popup_items_dict) -> void:
		popup_menu_path = clean_menu_path(_popup_menu_path)
		base_popup = _base_popup
		signal_callable = _callable
		popup_items_dict = _popup_items_dict
	
	var popup_menu_path:String
	var base_popup:PopupMenu
	var signal_callable#:Callable
	var popup_items_dict:Dictionary
	
	var icon_array:Array = []
	var icon_color_array:Array = []
	var tool_tip_array:Array = []
	var metadata:Dictionary = {}
	
	static func clean_menu_path(path):
		if path.ends_with("/"):
			path = path.erase(path.length()-1)
		if path.begins_with("/"):
			path = path.erase(0)
		return path
	
	func even_array_sizes():
		var slice_count = popup_menu_path.get_slice_count("/")
		var arrays = [
			icon_array,
			icon_color_array,
			tool_tip_array,
		]
		for array in arrays:
			var items_missing = slice_count - array.size()
			for i in range(items_missing):
				array.push_front(null)


class MouseHelper:
	var timer:Timer
	var selected_node
	var _mouse_in_panel:= true
	var _mouse_in_panel_time = 1
	
	signal timer_elapsed
	
	func _init(sel_node, callable=null) -> void:
		selected_node = sel_node
		
		timer = Timer.new()
		timer.wait_time = _mouse_in_panel_time
		selected_node.add_child(timer)
		
		if selected_node is PopupMenu:
			selected_node.popup_hide.connect(stop_timer)
			timer_elapsed.connect(hide_popup)
		else:
			if not callable:
				print("No callable set for Popup Mouse Helper.")
			timer_elapsed.connect(callable)
		connect_node(selected_node)
	
	func connect_node(node):
		if not node.mouse_entered.is_connected(_on_mouse_entered):
			node.mouse_entered.connect(_on_mouse_entered)
		if not node.mouse_exited.is_connected(_on_mouse_exited):
			node.mouse_exited.connect(_on_mouse_exited)
	
	func _on_mouse_exited():
		_mouse_in_panel = false
		timer.start()
		await timer.timeout
		if _mouse_in_panel:
			return
		timer_elapsed.emit()
	
	func _on_mouse_entered():
		_mouse_in_panel = true
		if not timer.is_stopped():
			stop_timer()
	
	func stop_timer():
		timer.stop()
		timer.timeout.emit()
		timer.wait_time = _mouse_in_panel_time
	
	func hide_popup():
		selected_node.hide()
	
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			if is_instance_valid(timer):
				timer.queue_free()

static func create_popup_items_dict(popup:PopupMenu):
	var dict = {}
	_create_popup_items_dict(popup, dict)
	return dict

static func _create_popup_items_dict(popup:PopupMenu, dict:Dictionary, path=""):
	for i in range(popup.item_count):
		var submenu = popup.get_item_submenu_node(i)
		if not is_instance_valid(submenu):
			continue
		var text = popup.get_item_text(i)
		var popup_path = text
		if path != "":
			popup_path = path.path_join(text)
		dict[popup_path] = submenu
		_create_popup_items_dict(submenu, dict, popup_path)


static func add_single_item(popup:PopupMenu, popup_path:String, popup_data:Dictionary, popup_items_dict:Dictionary):
	var path_count = popup_path.count("/")
	var callable = popup_data.get(ParamKeys.CALLABLE_KEY)
	var id = popup_data.get("id", -1)
	
	var popup_params = PopupMenuPathParams.new(popup_path, popup, callable, popup_items_dict)
	var icons = popup_data.get(ParamKeys.ICON_KEY)
	if icons:
		popup_params.icon_array = icons
	var tooltip = popup_data.get(ParamKeys.TOOL_TIP_KEY)
	if tooltip:
		popup_params.tool_tip_array = tooltip
	var metadata = popup_data.get(ParamKeys.METADATA_KEY)
	if metadata:
		popup_params.metadata = metadata
	
	return _parse_popup_menu_path(popup_params, id)

static func set_popup_position(popup:PopupMenu, offset:=Vector2i.ZERO):
	offset = offset * EditorInterface.get_editor_scale()
	popup.position = DisplayServer.mouse_get_position() - offset

static func _get_icon(icon_name:String, theme_type:String="EditorIcons"):
	return EditorInterface.get_editor_theme().get_icon(icon_name, theme_type)

### EXAMPLE
#func _menu_pressed(btn_id:int, popup:PopupMenu):   # example func for static parse
	#var layout_name = popup.get_item_text(btn_id)  # popup will be binded to the signal
	#_add_browser_window(layout_name)

#var items_dict = {        # example for parse dict.  Note path seperated by '/'.
	#"Dock|Undock" : {     # add icons in array if desired, else it will default to none.
		#ParamKeys.ICON_KEY: [Icons.make_floating],
		#option_keys.callable_key: on_dock_undock_button_pressed,
		#},
	#"Window/Toggle Split" : {
		#ParamKeys.ICON_KEY: [Icons.window, Icons.split_container],
		#ParamKeys.ICON_COLOR_KEY: [null, Color(5,5,5)],
		#option_keys.callable_key: on_toggle_split_button_pressed,
		#
		#},
	#"Window/Layouts" : {
		#ParamKeys.ICON_KEY: [Icons.window, Icons.panels_3_alt],
		#ParamKeys.TOOL_TIP_KEY: [null, "Open Layouts"]
		#option_keys.callable_key: on_layout_button_pressed,
		#}
	#}



