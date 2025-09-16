@tool
extends EditorScript

# running this script will clone the other repositories it relies on as sibling submodules.
# Project repo should be initialized, though it will not be used for pushing or pulling

const DEPENDENCIES = {
	"editor_console": "https://github.com/brohd11/Godot-Editor-Console",
	"addon_lib/brohd": "https://github.com/brohd11/Godot-Addon-Lib"
}

func _run() -> void:
	
	var check_exit = OS.execute("git", ["--version"])
	if check_exit != 0:
		printerr("Error accessing git, make sure it is installed and the main repo has been initialized.")
		return
	var check_init = OS.execute("git", ["rev-parse", "--is-inside-work-tree"])
	if check_init != 0:
		printerr("Not inside a git repo. Make sure main repo is initialized.")
		return
	
	for dep_folder in DEPENDENCIES.keys():
		var addon_path = "res://addons".path_join(dep_folder)
		if DirAccess.dir_exists_absolute(addon_path):
			printerr("Path already exists: %s" % addon_path)
			continue
		var repo_url = DEPENDENCIES.get(dep_folder)
		var args = ["submodule", "add", repo_url, dep_folder]
		var exit = OS.execute("git", args)
		if exit != 0:
			printerr("Error getting submodule: %s" % dep_folder)
	
	EditorInterface.get_resource_filesystem().scan()
	
