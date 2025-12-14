@tool
extends EditorPlugin

# A class member to hold the editor export plugin during its lifecycle.
var export_plugin : AndroidExportPlugin

func _enter_tree():
	# Initialization of the plugin goes here.
	export_plugin = AndroidExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree():
	# Clean-up of the plugin goes here.
	remove_export_plugin(export_plugin)
	export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	var _plugin_name = "DroidAdMob"
	var _plugin_folder = "droid_admob"  # Actual folder name

	func _supports_platform(platform):
		# Support Android platform
		return platform.get_os_name() == "Android"

	func _get_android_libraries(platform, debug):
		if debug:
			return PackedStringArray([_plugin_folder + "/bin/debug/" + _plugin_name + "-debug.aar"])
		else:
			return PackedStringArray([_plugin_folder + "/bin/release/" + _plugin_name + "-release.aar"])

	func _get_android_dependencies(platform, debug):
		return PackedStringArray([
			"com.google.android.gms:play-services-ads:22.6.0",
			"com.google.android.ump:user-messaging-platform:2.1.0"
		])

	func _get_name():
		return _plugin_name
