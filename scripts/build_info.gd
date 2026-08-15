class_name BuildInfo
extends RefCounted

# Identifies which build of the client is running, so a tester's screenshot or
# debug.log tells us exactly what they have. The server got the same treatment
# via its build.rs (`build="0ff0387"` on the boot line); this is the client half.
#
# The whole design constraint is that a build stamp must be IMPOSSIBLE TO FORGET
# to update. A stamp a human has to bump goes stale, and a stale stamp is worse
# than none because it is believed. So nothing here is hand-typed:
#
#   Exported build  the addons/build_stamp export plugin derives the sha from
#                   git at export time and injects STAMP_PATH straight into the
#                   PCK. Exporting IS the stamping step; there is no second step
#                   to skip. Nothing is written to the working tree, so there is
#                   no generated file that can be committed stale or go missing
#                   on a fresh clone.
#   Editor run      STAMP_PATH does not exist (it only lives inside an export),
#                   so we read live git state instead and mark it `-dev`.
#   Neither         Reported as UNSTAMPED, loudly. See `is_trustworthy()`.
#
# Note `.git/` is NOT shipped inside an exported build, so the editor path here
# genuinely cannot work for testers. That asymmetry is the reason for the export
# plugin rather than a plain runtime git read.

const STAMP_PATH := "res://generated/build_stamp.json"
const UNKNOWN := "UNSTAMPED"

# Cached so the git subprocesses in the editor fallback run once per session
# rather than on every call site (the login footer, the log header, /version).
static var _cache: Dictionary = {}

# ── Public API ────────────────────────────────────────────────────────────────

## Full stamp as a Dictionary. Always has a `status` key: "ok" when the build
## carries real provenance, "unstamped" when it does not.
static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = _load()
	return _cache

## True when we actually know what this build is. False means any version shown
## to a user is a guess and must be presented as a failure, not a value.
static func is_trustworthy() -> bool:
	return str(data().get("status", "")) == "ok"

## One-line identifier, e.g. `09ad51e-dirty` / `09ad51e-dev` / `UNSTAMPED`.
## Deliberately short enough for a login-screen footer.
static func short() -> String:
	var d := data()
	if str(d.get("status", "")) != "ok":
		return UNKNOWN
	var s := str(d.get("commit", UNKNOWN))
	if bool(d.get("dirty", false)):
		s += "-dirty"
	if bool(d.get("editor", false)):
		s += "-dev"
	return s

## Multi-line detail for `/version` and the debug.log header. This is the text
## we actually want pasted back to us during triage.
static func verbose() -> String:
	var d := data()
	if str(d.get("status", "")) != "ok":
		return "Build: %s (%s)" % [UNKNOWN, d.get("reason", "no stamp and no git")]
	var parts := PackedStringArray()
	parts.append("Build %s" % short())
	var branch := str(d.get("branch", ""))
	if branch != "":
		var unpushed := int(d.get("unpushed", 0))
		parts.append("branch %s%s" % [branch, (" +%d unpushed" % unpushed) if unpushed > 0 else ""])
	var built := str(d.get("exported_at", ""))
	if built != "":
		parts.append("exported %s UTC" % built)
	# The GDExtension is gitignored and hand-copied next to the .exe, so the
	# commit sha says nothing about it. A "clean" client can still be carrying a
	# stale wire layer, which looks like a server bug. Fingerprint it separately.
	var dll := str(d.get("gdext_md5", ""))
	if dll != "":
		parts.append("gdext %s (%d bytes)" % [dll.substr(0, 8), int(d.get("gdext_bytes", 0))])
	return "\n".join(parts)

## Same content as `verbose()` on one greppable line, for the debug.log header.
static func one_line() -> String:
	return verbose().replace("\n", " | ")

# ── Derivation (shared with the export plugin) ────────────────────────────────

## Builds a stamp from the git repo at `root` (an absolute OS path). Called by
## addons/build_stamp at export time AND by the editor fallback below, so there
## is exactly one definition of what a stamp contains.
##
## `root` MUST be passed explicitly. A bare `git rev-parse` inherits the calling
## process's working directory, and this is a two-repo project: an editor
## launched from a shell sitting in F:/Projects/server would stamp the SERVER's
## commit into the client. That stamp would be well-formed, plausible and wrong,
## which is the single worst outcome for a diagnostic. Hence `-C <root>` on every
## call, plus the rev-parse --show-toplevel cross-check.
static func derive_from_git(root: String) -> Dictionary:
	var top := _git(root, ["rev-parse", "--show-toplevel"])
	if not top["ok"]:
		return _unstamped("git unavailable or not a repository: %s" % top["text"])
	if _norm(str(top["text"])) != _norm(root):
		return _unstamped("git resolved a different repo (%s, expected %s)" % [top["text"], root])

	var sha := _git(root, ["rev-parse", "--short", "HEAD"])
	if not sha["ok"] or str(sha["text"]) == "":
		return _unstamped("could not read HEAD: %s" % sha["text"])

	# --untracked-files=no on purpose. Untracked files are the normal state of
	# this repo (docs/deployment/ is deliberately uncommitted, .uid files come
	# and go), so counting them makes every build "dirty" and the flag carries
	# no information. Only tracked modifications mean the build differs from its
	# commit.
	var status := _git(root, ["status", "--porcelain", "--untracked-files=no"])
	var branch := _git(root, ["rev-parse", "--abbrev-ref", "HEAD"])
	# Fails when the branch has no upstream, which is fine and not worth warning
	# about; unpushed simply stays 0.
	var ahead := _git(root, ["rev-list", "--count", "@{u}..HEAD"])

	return {
		"status": "ok",
		"commit": str(sha["text"]),
		"dirty": str(status["text"]) != "",
		"branch": str(branch["text"]) if branch["ok"] else "",
		"unpushed": int(str(ahead["text"])) if ahead["ok"] and str(ahead["text"]).is_valid_int() else 0,
		"editor": false,
	}

# ── Internals ─────────────────────────────────────────────────────────────────

static func _load() -> Dictionary:
	# An exported build carries the stamp injected at export time.
	if FileAccess.file_exists(STAMP_PATH):
		var f := FileAccess.open(STAMP_PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				return parsed
		return _unstamped("stamp file present but unreadable")

	# No stamp file. In the editor that is expected, because the file only ever
	# exists inside an export, so fall back to live git.
	if OS.has_feature("editor"):
		var d := derive_from_git(ProjectSettings.globalize_path("res://"))
		d["editor"] = true
		return d

	# No stamp file in a TEMPLATE build means the export plugin did not run.
	# Most likely it is disabled: Godot silently disables an addon whose script
	# fails to load and rewrites project.godot to match. That is precisely the
	# silent-staleness failure this system exists to prevent, so it must be as
	# visible as a wrong stamp rather than degrading to a blank.
	return _unstamped("exported build carries no stamp — is addons/build_stamp enabled?")

static func _unstamped(reason: String) -> Dictionary:
	return {"status": "unstamped", "reason": reason, "commit": UNKNOWN}

static func _git(root: String, args: Array) -> Dictionary:
	var argv := PackedStringArray(["-C", root])
	argv.append_array(PackedStringArray(args))
	var out: Array = []
	# read_stderr so a failure yields git's actual message instead of an empty
	# string we would have to guess about.
	var code := OS.execute("git", argv, out, true)
	var text := "" if out.is_empty() else str(out[0]).strip_edges()
	return {"ok": code == 0, "text": text}

## Normalizes an OS path for comparison: forward slashes, no trailing slash,
## lowercased. Windows drive letters differ in case between
## `globalize_path` (`f:/...`) and git (`F:/...`), which would otherwise fail
## the repo cross-check on every single export.
static func _norm(p: String) -> String:
	var s := p.strip_edges().replace("\\", "/").to_lower()
	while s.length() > 1 and s.ends_with("/"):
		s = s.substr(0, s.length() - 1)
	return s
