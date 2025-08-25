extends RefCounted

static func load_config_data(config_file_path):
	if not FileAccess.file_exists(config_file_path):
		printerr("Config file doesn't exist: %s" % config_file_path)
		return
	
	var config = ConfigFile.new()
	var err = config.load(config_file_path)
		
	if err != OK:
		printerr("Load Config Data Error: %s" % err)
		return
	
	return config

static func save_val_to_config(section, setting, new_value, config_file_path):
	if not FileAccess.file_exists(config_file_path):
		printerr("Config file doesn't exist: %s" % config_file_path)
		return
	
	var config = ConfigFile.new()
	var err = config.load(config_file_path)
	
	if err != OK:
		printerr("Save To Config Error: %s" % err)
		return 
	
	config.set_value(section,setting,new_value)
	
	config.save(config_file_path)

static func load_val_from_config(section, setting, default_val, config_file_path):
	if not FileAccess.file_exists(config_file_path):
		printerr("Config file doesn't exist, returning default: %s" % config_file_path)
		return default_val
	
	var config = ConfigFile.new()
	var err = config.load(config_file_path)
	
	if err != OK:
		printerr("Load From Config Error: %s" % err)
		return default_val
	
	var setting_val = config.get_value(section, setting, default_val)
	return setting_val



