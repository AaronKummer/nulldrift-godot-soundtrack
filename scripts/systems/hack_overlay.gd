extends Node

## HackOverlay — autoload. The CyberDeck terminal, ported from the Phaser
## HackingScene + hackingDefs.js. A linux-ish shell (ls, cd, cat,
## download, help, exit) over a small filesystem, with a trace meter that
## climbs while you're jacked in. Difficulty configs are canon. The first
## hack runs the CYBER GIRL tutorial inline (HACKING_TUTORIAL_DIALOGUE).
##
## Usage:  HackOverlay.open(1, true)   # difficulty, tutorial?
##         HackOverlay.finished.connect(func(success): ...)

signal finished(success: bool)

const GIRL := "[color=#00ffaa]CYBER GIRL: %s[/color]"
const SYS := "[color=#7f9aa8]%s[/color]"
const ERR := "[color=#ff5544]%s[/color]"
const OK := "[color=#9fe870]%s[/color]"

const CONFIGS := {
	1: {
		"title": "CORTEX ATM v1.2", "trace_rate": 1.0,
		"objectives": [
			{ "id": "read_transactions", "type": "read",
			  "target": "/var/secure/transactions.db", "description": "Access transaction logs" },
			{ "id": "download_key", "type": "download",
			  "target": "/var/secure/vault_key.dat", "description": "Download vault access key" },
		],
		"base": 200, "bonus": 100,
	},
	2: {
		"title": "NEXUS CORP TERMINAL v3.1", "trace_rate": 1.5,
		"objectives": [
			{ "id": "find_notes", "type": "read",
			  "target": "/home/admin/notes.txt", "description": "Read admin notes for intel" },
			{ "id": "read_auth", "type": "read",
			  "target": "/var/log/auth.log", "description": "Check authentication logs" },
			{ "id": "download_data", "type": "download",
			  "target": "/var/secure/transactions.db", "description": "Exfiltrate transaction data" },
			{ "id": "download_key", "type": "download",
			  "target": "/var/secure/vault_key.dat", "description": "Steal vault access credentials" },
		],
		"base": 400, "bonus": 200,
	},
	3: {
		"title": "ARASAKA SECURE NODE v5.0", "trace_rate": 2.0,
		"objectives": [
			{ "id": "read_passwd", "type": "read",
			  "target": "/etc/passwd", "description": "Enumerate system users" },
			{ "id": "find_ssh", "type": "read",
			  "target": "/home/admin/.ssh/authorized_keys", "description": "Find SSH credentials" },
			{ "id": "read_notes", "type": "read",
			  "target": "/home/admin/notes.txt", "description": "Gather intel from admin notes" },
			{ "id": "download_transactions", "type": "download",
			  "target": "/var/secure/transactions.db", "description": "Exfiltrate transaction database" },
			{ "id": "download_key", "type": "download",
			  "target": "/var/secure/vault_key.dat", "description": "Extract vault encryption key" },
		],
		"base": 700, "bonus": 300,
	},
}

# Dirs are dictionaries, files are content strings
const FS := {
	"bin": { "sh": "#!binary", "trace_d": "#!binary" },
	"etc": {
		"passwd": "root:x:0:0:root:/root:/bin/sh\nadmin:x:1000:1000:sysadmin:/home/admin:/bin/sh\ncortex_svc:x:401:401:service:/:/usr/bin/nologin",
	},
	"home": {
		"admin": {
			"notes.txt": "reminder: rotate the vault key. IT keeps saying the old one\nleaked. also the coffee machine on 4 is bugged again.\n- do NOT email the key. last time legal lost their minds.",
			".ssh": {
				"authorized_keys": "ssh-rsa AAAAB3NzaC1yc2E...4Zw== admin@cortex-hq",
			},
		},
	},
	"var": {
		"log": {
			"auth.log": "03:12 auth failure root from 10.4.7.22\n03:12 auth failure root from 10.4.7.22\n03:14 session opened for admin\n03:47 WARNING: unrecognized device on port 7",
		},
		"secure": {
			"transactions.db": "TXN 8842 · 2,400 cr · SHELL CORP HOLDINGS\nTXN 8843 · 11,050 cr · NIGHT SHIFT PAYROLL\nTXN 8844 · 600,000 cr · [REDACTED] — memo: 'the usual'",
			"vault_key.dat": "<encrypted binary — download to exfiltrate>",
		},
	},
}

var _layer: CanvasLayer
var _log: RichTextLabel
var _input: LineEdit
var _title_label: Label
var _trace_label: Label
var _obj_label: RichTextLabel
var _prompt_label: Label

var _active := false
var _cfg: Dictionary = {}
var _tutorial := false
var _cwd: Array = []            # path parts from root
var _trace := 0.0
var _done: Dictionary = {}      # objective id -> true
var _tut_seen: Dictionary = {}  # tutorial beat -> true
var _closing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 70
	_layer.visible = false
	add_child(_layer)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.03, 0.02, 0.97)
	panel.add_theme_stylebox_override("panel", sb)
	_layer.add_child(panel)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
	_title_label.position = Vector2(40, 20)
	panel.add_child(_title_label)

	_trace_label = Label.new()
	_trace_label.add_theme_font_size_override("font_size", 18)
	_trace_label.position = Vector2(40, 50)
	panel.add_child(_trace_label)

	_obj_label = RichTextLabel.new()
	_obj_label.bbcode_enabled = true
	_obj_label.scroll_active = false
	_obj_label.anchor_left = 0.68
	_obj_label.anchor_right = 0.98
	_obj_label.anchor_top = 0.0
	_obj_label.anchor_bottom = 0.4
	_obj_label.offset_top = 20
	_obj_label.add_theme_font_size_override("normal_font_size", 13)
	panel.add_child(_obj_label)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.anchor_left = 0.03
	_log.anchor_right = 0.65
	_log.anchor_top = 0.12
	_log.anchor_bottom = 0.88
	_log.add_theme_font_size_override("normal_font_size", 14)
	_log.add_theme_color_override("default_color", Color(0.55, 0.95, 0.65))
	panel.add_child(_log)

	var row := HBoxContainer.new()
	row.anchor_left = 0.03
	row.anchor_right = 0.65
	row.anchor_top = 0.90
	row.anchor_bottom = 0.96
	panel.add_child(row)
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 14)
	_prompt_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
	row.add_child(_prompt_label)
	_input = LineEdit.new()
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.add_theme_font_size_override("font_size", 14)
	_input.text_submitted.connect(_on_command)
	row.add_child(_input)

	var hint := Label.new()
	hint.text = "type 'help' for commands · 'exit' disconnects"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.35, 0.5, 0.42))
	hint.anchor_top = 0.965
	hint.anchor_left = 0.03
	panel.add_child(hint)

func is_active() -> bool:
	return _active

func open(difficulty: int = 1, tutorial: bool = false) -> void:
	if _active:
		return
	_cfg = CONFIGS.get(difficulty, CONFIGS[1])
	_tutorial = tutorial
	_cwd = []
	_trace = 0.0
	_done = {}
	_tut_seen = {}
	_closing = false
	_active = true
	_log.clear()
	_title_label.text = _cfg.title
	get_tree().paused = true
	_layer.visible = true
	_print(SYS % ("connected · " + _cfg.title))
	_print(SYS % "secure shell v0.9 — unauthorized access is a felony. anyway.")
	if _tutorial:
		_girl([
			"Hey, you made it in. I'm already connected to your feed.",
			"This is your first real hack, so I'll walk you through it.",
			"We split the take 50/50. Do this right and meet me at the diner.",
			"Type 'ls' to see what's in this directory.",
		])
	_refresh_objectives()
	_refresh_prompt()
	_input.clear()
	_input.grab_focus()

func _process(delta: float) -> void:
	if not _active or _closing:
		return
	_trace += _cfg.trace_rate * delta
	var t := int(_trace)
	var col := Color(0.4, 0.9, 0.5)
	if _trace >= 75.0:
		col = Color(1.0, 0.3, 0.2)
	elif _trace >= 45.0:
		col = Color(1.0, 0.75, 0.2)
	_trace_label.text = "TRACE %d%%" % t
	_trace_label.add_theme_color_override("font_color", col)
	if _trace >= 60.0 and not _tut_seen.get("warn", false):
		_tut_seen["warn"] = true
		if _tutorial:
			_girl(["Trace is climbing. Work faster or bail out."])
		else:
			_print(ERR % "! trace threshold 60% — hurry")
	if _trace >= 100.0:
		_traced()

func _traced() -> void:
	_closing = true
	if _tutorial:
		_girl(["They're tracing us! Type 'exit' NOW!"])
	_print(ERR % ">>> TRACE COMPLETE — CONNECTION SEIZED <<<")
	_print(ERR % "counter-ice scrubbed your session. you got nothing.")
	get_tree().create_timer(1.6).timeout.connect(func(): _close(false))

func _close(success: bool) -> void:
	_active = false
	_layer.visible = false
	get_tree().paused = false
	finished.emit(success)

# ── shell ────────────────────────────────────────────────────────────────

func _on_command(raw: String) -> void:
	if not _active or _closing:
		return
	var line := raw.strip_edges()
	_input.clear()
	if line == "":
		return
	_print("[color=#3aff9d]%s$[/color] %s" % [_cwd_str(), line])
	var parts := line.split(" ", false)
	var cmd: String = parts[0].to_lower()
	var arg: String = parts[1] if parts.size() > 1 else ""
	match cmd:
		"help":
			_print(SYS % "ls · cd <dir> · cd .. · cat <file> · download <file> · clear · exit")
		"clear":
			_log.clear()
		"ls":
			_cmd_ls()
		"cd":
			_cmd_cd(arg)
		"cat":
			_cmd_cat(arg)
		"download", "dl":
			_cmd_download(arg)
		"exit", "logout", "quit":
			_cmd_exit()
		_:
			_print(ERR % ("sh: %s: command not found" % cmd))

func _cwd_node() -> Dictionary:
	var node: Dictionary = FS
	for p in _cwd:
		node = node[p]
	return node

func _cwd_str() -> String:
	return "/" + "/".join(_cwd)

func _cmd_ls() -> void:
	var node := _cwd_node()
	var out: Array = []
	for k in node:
		if node[k] is Dictionary:
			out.append("[color=#4fb3ff]%s/[/color]" % k)
		else:
			out.append(k)
	_print("  ".join(out) if not out.is_empty() else SYS % "(empty)")
	# Tutorial beats keyed to where you just looked
	if _tutorial:
		if _cwd.is_empty():
			_tut_once("afterLs", [
				"Good. See those folders? The money's usually hidden in /var/secure.",
				"Type 'cd var' to move into the var directory.",
			])
		elif _cwd == ["var"]:
			_tut_once("foundSecure", [
				"There it is - the 'secure' folder. That's where they hide the good stuff.",
				"Type 'cd secure' to get inside.",
			])
		elif _cwd == ["var", "secure"]:
			_tut_once("foundTarget", [
				"Jackpot. See those files? That's what we came for.",
				"Use 'cat <filename>' to read a file, or 'download <filename>' to grab it.",
				"Try: cat transactions.db",
			])

func _cmd_cd(arg: String) -> void:
	if arg == "":
		_print(ERR % "cd: missing operand")
		return
	if arg == "..":
		if not _cwd.is_empty():
			_cwd.pop_back()
		_refresh_prompt()
		return
	var node := _cwd_node()
	if node.has(arg) and node[arg] is Dictionary:
		_cwd.append(arg)
		_refresh_prompt()
		if _tutorial and _cwd == ["var"]:
			_tut_once("inVar", ["Nice. Now type 'ls' again to see what's here."])
		elif _tutorial and _cwd == ["var", "secure"]:
			_tut_once("inSecure", ["You're in. Type 'ls' to see what files they're protecting."])
	else:
		_print(ERR % ("cd: %s: no such directory" % arg))

func _cmd_cat(arg: String) -> void:
	var node := _cwd_node()
	if arg == "" or not node.has(arg) or node[arg] is Dictionary:
		_print(ERR % ("cat: %s: no such file" % arg))
		return
	_print(SYS % str(node[arg]))
	_mark("read", _cwd_str().trim_suffix("/") + "/" + arg)
	if _tutorial:
		_tut_once("afterCat", [
			"Good, you can see the data. But reading isn't enough - we need to take it.",
			"Type 'download vault_key.dat' to exfiltrate the encryption key.",
		])

func _cmd_download(arg: String) -> void:
	var node := _cwd_node()
	if arg == "" or not node.has(arg) or node[arg] is Dictionary:
		_print(ERR % ("download: %s: no such file" % arg))
		return
	_print(OK % ("downloading %s ▓▓▓▓▓▓▓▓ 100%%" % arg))
	_mark("download", _cwd_str().trim_suffix("/") + "/" + arg)
	if _tutorial:
		_tut_once("afterDownload", [
			"Nice! Check the objectives panel - see what else you need.",
			"Download everything marked as an objective. Watch that trace meter!",
		])

func _cmd_exit() -> void:
	if _all_done():
		var pay: int = _cfg.base + (_cfg.bonus if _trace < 50.0 else 0)
		GameState.add_credits(pay)
		_print(OK % (">>> clean disconnect · +%d cr%s <<<" % [pay,
			" (speed bonus)" if _trace < 50.0 else ""]))
		if _tutorial:
			_girl([
				"Clean work, newbie. You're a natural.",
				"Meet me at the diner. I'll have your cut ready.",
			])
		_closing = true
		get_tree().create_timer(1.6).timeout.connect(func(): _close(true))
	else:
		_print(SYS % "disconnected. objectives incomplete — no payout.")
		_closing = true
		get_tree().create_timer(0.8).timeout.connect(func(): _close(false))

# ── objectives / tutorial helpers ────────────────────────────────────────

func _mark(kind: String, path: String) -> void:
	for obj in _cfg.objectives:
		if obj.type == kind and obj.target == path.replace("//", "/"):
			if not _done.get(obj.id, false):
				_done[obj.id] = true
				_print(OK % ("✓ objective: " + obj.description))
	_refresh_objectives()
	if _all_done() and not _tut_seen.get("all", false):
		_tut_seen["all"] = true
		if _tutorial:
			_girl([
				"That's everything! Now get out before they trace us.",
				"Type 'exit' to disconnect safely.",
			])
		else:
			_print(OK % "all objectives complete — 'exit' to bank it")

func _all_done() -> bool:
	for obj in _cfg.objectives:
		if not _done.get(obj.id, false):
			return false
	return true

func _refresh_objectives() -> void:
	var txt := "[color=#7f9aa8]OBJECTIVES[/color]\n"
	for obj in _cfg.objectives:
		var hit: bool = _done.get(obj.id, false)
		txt += ("[color=#9fe870]✓ %s[/color]\n" if hit else "[color=#cfd8e3]○ %s[/color]\n") % obj.description
	_obj_label.text = txt

func _refresh_prompt() -> void:
	_prompt_label.text = "ghost@%s:%s$ " % [_cfg.title.split(" ")[0].to_lower(), _cwd_str()]

func _tut_once(key: String, lines: Array) -> void:
	if _tut_seen.get(key, false):
		return
	_tut_seen[key] = true
	_girl(lines)

func _girl(lines: Array) -> void:
	for l in lines:
		_print(GIRL % l)

func _print(bb: String) -> void:
	_log.append_text(bb + "\n")
