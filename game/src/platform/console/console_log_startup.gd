extends Node
## The autoload that starts the console log before the main scene loads, and
## stops it before the scripts unload.


func _init() -> void:
	ConsoleLog.install()


func _exit_tree() -> void:
	ConsoleLog.uninstall()
