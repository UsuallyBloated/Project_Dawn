@tool
extends EditorExportPlugin

# Derives a build stamp from git and injects it into the exported PCK.
#
# Why _export_begin + add_file, rather than generating a file on disk:
# add_file() writes the stamp straight into the pack without touching the working
# tree. That matters because every on-disk alternative reintroduces the staleness
# this exists to kill. A generated + gitignored file is absent on a fresh clone;
# a generated + tracked file churns on every build and can be committed stale;
# and either way it is produced by a step ordered independently of the export, so
# it drifts the moment someone exports without re-running it. An injected file
# cannot be stale, because it is created by the act of exporting.
#
# Verified against Godot 4.4 by building and running a real export: files added
# in _export_begin land in the pack ahead of per-file iteration, survive this
# project's script_export_mode=2 (compressed binary tokens), and read back
# normally at runtime.

const BUILD_INFO := preload("res://scripts/build_info.gd")

# Fingerprinted separately from the commit sha because .gitignore excludes
# addons/gdext_net/*.dll and the DLL is hand-copied next to the .exe. It carries
# the wire protocol, so a client sitting on a clean commit can still be running a
# stale wire layer — which presents as a server bug. The sha alone would lie by
# omission here.
const GDEXT_DLL := "res://addons/gdext_net/gdext_net.dll"

func _get_name() -> String:
	return "BuildStamp"

func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	var root := ProjectSettings.globalize_path("res://")
	var stamp := BUILD_INFO.derive_from_git(root)

	# Answers "did you install the build I sent an hour ago?", which a sha alone
	# cannot: two exports of one commit are byte-identical under a hash-only
	# stamp, and re-exporting without committing is the normal iteration loop.
	stamp["exported_at"] = Time.get_datetime_string_from_system(true, false)
	stamp["debug_build"] = is_debug
	stamp["export_path"] = path.get_file()

	if FileAccess.file_exists(GDEXT_DLL):
		stamp["gdext_md5"] = FileAccess.get_md5(GDEXT_DLL)
		var f := FileAccess.open(GDEXT_DLL, FileAccess.READ)
		if f != null:
			stamp["gdext_bytes"] = f.get_length()
			f.close()

	var json := JSON.stringify(stamp, "\t")
	add_file(BUILD_INFO.STAMP_PATH, json.to_utf8_buffer(), false)

	# Surfaced in the editor's export log. A failed stamp is not a failed export
	# (blocking a release over a diagnostic would be worse than the diagnostic
	# being absent), so this print is the only place the operator learns of it at
	# export time — the runtime UNSTAMPED banner is the real backstop.
	if str(stamp.get("status", "")) == "ok":
		var dirty := " DIRTY TREE" if bool(stamp.get("dirty", false)) else ""
		print("[BuildStamp] stamped %s%s (%s)" % [stamp.get("commit", "?"), dirty, stamp["exported_at"]])
	else:
		push_warning("[BuildStamp] UNSTAMPED export: %s" % stamp.get("reason", "unknown"))
