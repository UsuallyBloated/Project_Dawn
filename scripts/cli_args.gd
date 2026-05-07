class_name CliArgs
extends RefCounted

# Parses the launcher → game handoff arguments. Returns a Dictionary on
# success, or `null` when the launcher didn't pass them — the alpha-with-
# fallback path that keeps the local-save Test Room flow working.
#
# Args the launcher sets (track B + track D):
#   --auth-token=<64-char hex>     session_token from LoginOk
#   --char-id=<i64>                selected character row id
#   --world-token-path=<path>      tempfile holding the renet ConnectToken
#                                  bytes; game reads then deletes
#   --world-endpoint=<host:port>   informational; signed inside the token
#   --client-version=<semver>      forwarded to the server's Connect msg
#
# `--world-token-path` is the gate: if present, we treat it as launcher
# mode and require the others. If absent, fall through silently (or warn
# if other handoff args were partially supplied — see Q4 in the handoff).

const RESULT_KEYS := [
	"auth_token",
	"char_id",
	"world_token_path",
	"world_endpoint",
	"client_version",
]

static func parse() -> Variant:
	var raw: Dictionary = _parse_raw(OS.get_cmdline_args())
	if not raw.has("world_token_path") or str(raw["world_token_path"]) == "":
		# No token path → not launcher mode. Warn if the user clearly tried
		# to launch with partial args (e.g. old launcher build).
		if raw.has("auth_token") or raw.has("char_id"):
			push_warning(
				"CliArgs: --auth-token / --char-id present without --world-token-path; "
				+ "falling through to local-save mode")
		return null

	var char_id_str := str(raw.get("char_id", ""))
	var char_id := -1
	if char_id_str.is_valid_int():
		char_id = int(char_id_str)
	else:
		push_warning("CliArgs: --char-id missing or not an integer")
		return null

	return {
		"auth_token": str(raw.get("auth_token", "")),
		"char_id": char_id,
		"world_token_path": str(raw["world_token_path"]),
		"world_endpoint": str(raw.get("world_endpoint", "")),
		"client_version": str(raw.get("client_version", "")),
	}

# Build a `key → value` dict from the `--key=value` arg slice. Keys are
# normalized to snake_case so `--world-token-path` lands at `world_token_path`.
static func _parse_raw(args: PackedStringArray) -> Dictionary:
	var d := {}
	for arg in args:
		if not arg.begins_with("--"):
			continue
		var stripped := arg.substr(2)
		var eq_idx := stripped.find("=")
		if eq_idx < 0:
			continue
		var key := stripped.substr(0, eq_idx).replace("-", "_")
		d[key] = stripped.substr(eq_idx + 1)
	return d
