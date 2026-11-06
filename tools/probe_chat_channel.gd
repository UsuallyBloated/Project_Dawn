extends SceneTree
# Headless probe for the sticky chat channel (2026-10-26): ChatChannel's rules
# (a channel command switches and leaves the text, stacked commands collapse,
# /sit is not /s, a tell needs its name's space, /r needs a sender, plain text
# is a say) and a real ChatWindow driven through typing, pasting, submitting,
# the sticky channel and TAB. Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_chat_channel.gd

const LONG := "The quick brown fox jumps over the lazy dog near the old stone well. The quick brown fox jumps ovétü end."

var _fails: int = 0
var _sent: Array[String] = []

func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok    " + what)
	else:
		print("FAIL  " + what)
		_fails += 1

# The autoloads join the tree after _initialize, so the checks run on the
# first frame.
func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	_rules()
	_window()
	_macros()
	_cap()
	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)

func _c(text: String, at_end: bool, reply_to: String = "") -> Dictionary:
	return ChatChannel.consume(text, ChatChannel.SAY, "", reply_to, at_end)

func _rules() -> void:
	var r := _c("/say hello", false)
	_check(r["channel"] == "say" and r["text"] == "hello", "/say hello: Say, text 'hello'")
	r = _c("/say /say hello", false)
	_check(r["text"] == "hello", "/say /say hello: both commands leave the text")
	r = _c("/sh ", false)
	_check(r["consumed"] and r["channel"] == "shout" and r["text"] == "", "'/sh ' switches to Shout")
	r = _c("/sh", false)
	_check(not r["consumed"], "'/sh' with no space yet waits (could still become /shout)")
	r = _c("/sit", false)
	_check(not r["consumed"] and r["text"] == "/sit", "/sit is not read as /s")
	r = _c("/t Bob", false)
	_check(not r["consumed"], "a tell waits for the space after the name")
	r = _c("/t Bob hey", false)
	_check(r["channel"] == "tell" and r["target"] == "Bob" and r["text"] == "hey", "/t Bob hey: Tell Bob, text 'hey'")
	r = _c("/say /shout hi", false)
	_check(r["channel"] == "shout" and r["text"] == "hi", "the last of stacked commands wins")
	r = _c("/r hi", false)
	_check(not r["consumed"], "/r with nobody to reply to is left for the hud")
	r = _c("/r hi", false, "Ann")
	_check(r["channel"] == "tell" and r["target"] == "Ann" and r["text"] == "hi", "/r hi replies to the last sender")
	r = _c("/shout", true)
	_check(r["consumed"] and r["channel"] == "shout" and r["text"] == "", "on Enter, a bare /shout switches")

	_check(ChatChannel.normalize("hello", "") == "/say hello", "plain text normalizes to a say")
	_check(ChatChannel.normalize("/say /say hi", "") == "/say hi", "/say /say hi normalizes to /say hi")
	_check(ChatChannel.normalize("/sit", "") == "/sit", "/sit passes through")
	_check(ChatChannel.normalize("/say /sit", "") == "/sit", "a command after a channel command runs as that command")
	_check(ChatChannel.normalize("/shout", "") == "", "a bare channel command sends nothing")
	_check(ChatChannel.normalize("/g /t Bob hi", "") == "/tell Bob hi", "stacked group then tell is a tell")

# ChatWindow is loaded here, not named at the top: naming it there compiles
# it before the autoloads (CombatLog) exist.
func _window() -> void:
	var window_script: Script = load("res://scripts/chat_window.gd")
	var w = window_script.new()
	root.add_child(w)
	w.text_submitted.connect(func(_id: int, t: String) -> void: _sent.append(t))
	w.show_input()
	_check(w._line_channel == "say", "a window with no default channel starts on Say")
	_check(w._channel_label.text == "[Say]", "the line shows [Say]")

	w._on_chat_input_text_changed("/say hello")
	_check(w._line_channel == "say" and w._chat_input.text == "hello", "typing '/say hello' leaves 'hello' on a Say line")
	w._on_chat_input_text_changed("/sit")
	_check(w._chat_input.text == "/sit" and w._line_channel == "say", "typing /sit leaves it alone")

	_sent.clear()
	w._on_chat_text_submitted("/say " + LONG)
	_check(_sent.size() == 1 and _sent[0] == "/say " + LONG, "the playtest paste sends one /say and the text untouched")
	w._on_chat_text_submitted("/say /say hi")
	_check(_sent.back() == "/say hi", "'/say /say hi' sends '/say hi'")

	w._on_chat_text_submitted("/shout loud")
	_check(_sent.back() == "/shout loud" and w._channel_label.text == "[Shout]", "/shout loud shouts and the line shows [Shout]")
	w._on_chat_text_submitted("again")
	_check(_sent.back() == "/shout again", "sticky: plain text after a shout shouts")
	w._on_chat_text_submitted("/t Bob hey")
	_check(_sent.back() == "/tell Bob hey", "/t Bob hey tells Bob")
	w._on_chat_text_submitted("more")
	_check(_sent.back() == "/tell Bob more" and w._channel_label.text == "[Tell: Bob]", "sticky: the next line tells Bob too")
	var before: int = _sent.size()
	w._on_chat_text_submitted("/loc")
	_check(_sent.size() == before + 1 and _sent.back() == "/loc" and w._line_channel == "tell", "/loc runs as a command and keeps the channel")
	before = _sent.size()
	w._on_chat_text_submitted("/s")
	_check(_sent.size() == before and w._line_channel == "say", "a bare /s on Enter switches to Say and sends nothing")

	# A window whose default is OOC starts there.
	var w2 = window_script.new()
	root.add_child(w2)
	w2.set_display_settings({"default_channel": "ooc"})
	_check(w2._line_channel == "ooc" and w2._channel_label.text == "[OOC]", "a default channel of OOC starts the line on OOC")

	# TAB on an empty Say line with a tell sender known: the line becomes a tell.
	root.get_node("/root/CombatLog")._note_tell_sender("Ann")
	w._set_line_channel("say", "")
	w.show_input()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	w._on_chat_input_gui_input(tab)
	_check(w._line_channel == "tell" and w._line_target == "Ann" and w._chat_input.text == "", "TAB on an empty line makes it a tell to the last sender")

	w.queue_free()
	w2.queue_free()

# A social macro's lines go to the real chat handler (CombatLog.chat_submitted,
# which hud.gd answers) instead of being printed locally as "[Say] ...".
func _macros() -> void:
	var log = root.get_node("/root/CombatLog")
	var hotkeys = root.get_node("/root/SocialHotkeys")
	var submitted: Array[String] = []
	var local_lines: Array[String] = []
	log.chat_submitted.connect(func(t: String) -> void: submitted.append(t))
	log.line_added.connect(func(t: String, _ty: int) -> void: local_lines.append(t))
	hotkeys._execute_social({"lines": ["/say hello", "  ", "/sit", "/shout %n here"], "library_id": ""})
	var me: String = root.get_node("/root/PlayerStats").player_name
	_check(submitted == ["/say hello", "/sit", "/shout %s here" % me], "a macro's lines reach the chat handler in order, blanks skipped, %n filled")
	var printed_locally := false
	for t in local_lines:
		if t.begins_with("[Say") or t.begins_with("[Shout") or t == "You sit down.":
			printed_locally = true
	_check(not printed_locally, "a macro no longer prints its lines locally instead of sending them")

# The 250-character cap (2026-10-26): every message is cut to the server's
# MAX_CHAT_CHARS, counted in characters, so the sender's echo is what everyone
# else sees; the chat line stops typing there.
func _cap() -> void:
	var cap: int = ChatChannel.MAX_CHARS
	_check(cap == 250, "the cap is 250 characters")
	var long := "a".repeat(300)
	_check(ChatChannel.normalize(long, "") == "/say " + "a".repeat(250), "plain text is cut to 250")
	_check(ChatChannel.normalize("/shout " + long, "") == "/shout " + "a".repeat(250), "a shout is cut to 250")
	_check(ChatChannel.normalize("/t Bob " + long, "") == "/tell Bob " + "a".repeat(250), "a tell's message is cut to 250, the name kept")
	var accents := "é".repeat(300)
	_check(ChatChannel.normalize("/say " + accents, "") == "/say " + "é".repeat(250), "an accented letter counts as one character")
	_check(ChatChannel.normalize("/say " + "a".repeat(250), "") == "/say " + "a".repeat(250), "exactly 250 is untouched")
	var w = load("res://scripts/chat_window.gd").new()
	root.add_child(w)
	_check(w._chat_input.max_length == cap, "the chat line stops typing at 250 (max_length %d)" % w._chat_input.max_length)
	w.queue_free()
