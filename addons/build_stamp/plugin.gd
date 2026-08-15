@tool
extends EditorPlugin

# Registers the export plugin that stamps every exported build with its git
# commit. See export_plugin.gd for the mechanism and scripts/build_info.gd for
# how the stamp is read back at runtime.
#
# This addon must stay ENABLED in project.godot's [editor_plugins] list. If it is
# disabled, exports silently ship without a stamp — which BuildInfo reports as
# UNSTAMPED rather than letting it pass as a blank, precisely so a disabled
# plugin cannot go unnoticed.

const ExportPlugin := preload("res://addons/build_stamp/export_plugin.gd")

var _export_plugin: EditorExportPlugin = null

func _get_plugin_name() -> String:
	return "BuildStamp"

func _enter_tree() -> void:
	_export_plugin = ExportPlugin.new()
	add_export_plugin(_export_plugin)

func _exit_tree() -> void:
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null
