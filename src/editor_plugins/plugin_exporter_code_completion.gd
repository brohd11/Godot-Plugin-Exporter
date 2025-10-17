extends EditorCodeCompletion

func _singleton_ready():
	singleton.register_tag("#!", "remote", EditorCodeCompletionSingleton.TagLocation.START)
	singleton.register_tag("#!", "ignore-remote", EditorCodeCompletionSingleton.TagLocation.END)
	singleton.register_tag("#!", "dependency", EditorCodeCompletionSingleton.TagLocation.END)
	singleton.register_tag("#!", "singleton-module", EditorCodeCompletionSingleton.TagLocation.END)
	
