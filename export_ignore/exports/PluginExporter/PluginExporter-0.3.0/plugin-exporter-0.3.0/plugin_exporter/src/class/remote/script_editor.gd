extends RefCounted

static func get_current_script_editor():
	var current = EditorInterface.get_script_editor().get_current_editor()
	return current

static func get_popup():
	var current = get_current_script_editor()
	var popup = current.get_child(1)
	return popup

static func get_current_script():
	var current = EditorInterface.get_script_editor().get_current_script()
	return current

#static func get_menu_bar():
	#var current = get_current_script_editor()
	#var menu_bar = current.get_parent().get_parent().get_parent().get_parent().get_child(0)
	#return menu_bar

#static func get_edit_menu_popup():
	#
	#var menu_bar = get_menu_bar()
	#var edit_button = menu_bar.get_child(1).get_child(0) as MenuButton
	#edit_button.show_popup()
	#await menu_bar.get_tree().process_frame
	#var popup = edit_button.get_popup() as PopupMenu
	#var syntax_popup = popup.get_child(popup.get_child_count(true) - 1, true) as PopupMenu
	#for i in range(syntax_popup.item_count):
		#var text = syntax_popup.get_item_text(i)
		#if text != "GDSynTags":
			#continue
		#var id = syntax_popup.get_item_id(i)
		#await menu_bar.get_tree().process_frame
		#syntax_popup.id_pressed.emit(id)
		#
		#print("EMITTED")
		#break












