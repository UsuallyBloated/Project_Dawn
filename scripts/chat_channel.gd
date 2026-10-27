extends RefCounted
class_name ChatChannel

# The chat line's channel, WoW style: typing a channel command at the start
# of the line (`/say `, `/shout `, `/tell Bob `) switches the line to that
# channel and the command leaves the text; the line stays on it (sticky) until
# another command moves it. ChatWindow drives the line with `consume`, and
# hud.gd runs every submitted line through `normalize`, so a channel command
# never reaches anyone as part of a message (`/say /say hello` says "hello").

const SAY := "say"
const SHOUT := "shout"
const OOC := "ooc"
const GROUP := "group"
const TELL := "tell"

# Command word to channel. A command switches only when followed by a space
# (or, on submit, the end of the line), so `/sit` never reads as `/s`.
const COMMANDS := {
	"/say": SAY, "/s": SAY,
	"/shout": SHOUT, "/sh": SHOUT,
	"/ooc": OOC,
	"/group": GROUP, "/g": GROUP, "/gsay": GROUP,
}
const TELL_COMMANDS := ["/tell", "/t"]
const REPLY_COMMANDS := ["/reply", "/r"]

const LABELS := {SAY: "Say", SHOUT: "Shout", OOC: "OOC", GROUP: "Group", TELL: "Tell"}

# The most characters a chat message carries, the server's `MAX_CHAT_CHARS`
# (kept in lockstep by tools/check_constant_lockstep.gd). The chat line stops
# typing at it and `normalize` cuts every message to it, macros included, so
# the line a sender sees is the line everyone else sees (user, 2026-10-26;
# EQ II's chat box took about 250). Counted in characters on both sides.
const MAX_CHARS := 250

## Eats every channel command at the start of `text`, last one winning.
## Returns {channel, target, text, consumed}. While typing (`at_end` false) a
## command counts only once its space is typed and a tell only once the name's
## space is; on submit (`at_end` true) the end of the line counts too.
## `reply_to` is the last tell sender (`/r`); with none, `/r` is left alone so
## the hud can say so.
static func consume(text: String, channel: String, target: String, reply_to: String, at_end: bool) -> Dictionary:
	var rest := text
	var consumed := false
	while true:
		var t := rest.strip_edges(true, false)
		var sp := t.find(" ")
		if sp < 0 and not at_end:
			break
		var word := (t if sp < 0 else t.substr(0, sp)).to_lower()
		var after := "" if sp < 0 else t.substr(sp + 1)
		if COMMANDS.has(word):
			channel = COMMANDS[word]
			target = ""
			rest = after
			consumed = true
			continue
		if word in TELL_COMMANDS:
			var a := after.strip_edges(true, false)
			var nsp := a.find(" ")
			if nsp < 0 and not at_end:
				break
			var name := a if nsp < 0 else a.substr(0, nsp)
			if name == "":
				break
			channel = TELL
			target = name
			rest = "" if nsp < 0 else a.substr(nsp + 1)
			consumed = true
			continue
		if word in REPLY_COMMANDS and reply_to != "":
			channel = TELL
			target = reply_to
			rest = after
			consumed = true
			continue
		break
	return {"channel": channel, "target": target, "text": rest, "consumed": consumed}

## The one-line command the hud's handlers understand for `body` on a channel.
static func command_for(channel: String, target: String, body: String) -> String:
	match channel:
		SHOUT:
			return "/shout " + body
		OOC:
			return "/ooc " + body
		GROUP:
			return "/g " + body
		TELL:
			return "/tell %s %s" % [target, body]
	return "/say " + body

## A submitted line in its one canonical form: plain text is a say; stacked
## channel commands collapse to the last; a message is cut to MAX_CHARS; a
## channel command with nothing to say returns "" (nothing to send); any other
## command passes through as typed.
static func normalize(text: String, reply_to: String) -> String:
	var t := text.strip_edges()
	if t == "":
		return ""
	if not t.begins_with("/"):
		return "/say " + t.left(MAX_CHARS)
	var r := consume(t, "", "", reply_to, true)
	if not r["consumed"]:
		return t
	var body := String(r["text"]).strip_edges()
	if body == "":
		return ""
	if body.begins_with("/"):
		return body
	return command_for(r["channel"], r["target"], body.left(MAX_CHARS))

## What the chat line shows for its channel: "Say", "Tell: Bob".
static func label_for(channel: String, target: String) -> String:
	if channel == TELL:
		return "Tell: %s" % target
	return LABELS.get(channel, "Say")
