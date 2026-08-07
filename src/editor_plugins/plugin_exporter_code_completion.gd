extends EditorCodeCompletion

const PREFIX = "#!"

func _singleton_ready():
	singleton.register_tag(PREFIX, "remote", TagLocation.START)
	singleton.register_tag(PREFIX, "ignore-remote", TagLocation.END)
	singleton.register_tag(PREFIX, "dependency", TagLocation.END)
	singleton.register_tag(PREFIX, "singleton-module", TagLocation.END)
	singleton.register_tag(PREFIX, "strip-cast", TagLocation.START)
