@tool
extends EditorPlugin

var _dock: Control


func _enter_tree() -> void:
	_dock = preload("res://addons/grb-builder/editor/BuilderDock.gd").new()
	_dock.name = "AestheticEngineBuilder"
	add_control_to_bottom_panel(_dock, "Aesthetic Engine Builder")


func _exit_tree() -> void:
	if _dock:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()
		_dock = null
