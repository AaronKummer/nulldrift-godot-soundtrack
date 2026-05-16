## PhoneOverlay — autoload CanvasLayer. The "phone" is the central UI hub:
## inventory, map, messages, dating, email, news, stocks, uber, quests, etc.
## Toggled with P. Each app is a procedurally-built screen pushed onto a
## small nav stack so back gestures pop one screen at a time.
##
## Architecture: chassis (bezel + status bar + app container + home indicator)
## is fixed; the inner content is rebuilt per push. Apps are currently stubs
## — each gets its own _build_<id>() once we flesh them out.
##
## Mobile-friendly: swipe right anywhere → back, swipe down on home → close.
## Touch and mouse events route through the same _check_swipe path.
extends CanvasLayer

# Apps registry now lives in res://data/phone_apps.gd. This overlay is a
# pure view layer that reads data files.
const PhoneAppsData := preload("res://data/phone_apps.gd")
const NewsData := preload("res://data/news_articles.gd")
const EmailsData := preload("res://data/emails.gd")
const DatingData := preload("res://data/dating_profiles.gd")

# Convenience: most code referenced APPS as a constant. Keep a wrapper.
var APPS: Array:
	get: return PhoneAppsData.APPS

const PHONE_ASPECT := 9.0 / 19.5   # portrait phone (e.g. iPhone-ish)
const PHONE_MAX_H := 1080.0
const PHONE_MIN_H := 600.0
const VIEWPORT_USAGE := 0.94       # how much of viewport height to fill
const STATUS_BAR_H := 48
const HOME_BAR_H := 36
const APP_GRID_COLS := 4
const SWIPE_MIN := 80.0   # px

# ───────────────────────────── state ─────────────────────────────
var _open := false
var _stack: Array = []  # array of { id, node }
var _input_capture: Control      # invisible full-screen catcher for swipes
var _backdrop: ColorRect
var _phone: PanelContainer
var _app_container: Control
var _status_bar: Label
var _home_bar: Label
var _drag_start := Vector2.ZERO
var _dragging := false
var _persistent_button: Button

func set_button_visible(v: bool) -> void:
	if _persistent_button:
		_persistent_button.visible = v

func _ready() -> void:
	layer = 100
	visible = false
	_build_chassis()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	# Always-on persistent HUD button — taps open the phone from any scene.
	# Lives on a SEPARATE CanvasLayer so it shows even when this overlay is
	# hidden.
	_install_persistent_button()

func _install_persistent_button() -> void:
	var layer_node := CanvasLayer.new()
	layer_node.layer = 50    # above world, below this overlay (100)
	add_child(layer_node)
	_persistent_button = Button.new()
	_persistent_button.text = "📱"
	_persistent_button.tooltip_text = "Phone (P)"
	_persistent_button.add_theme_font_size_override("font_size", 28)
	_persistent_button.custom_minimum_size = Vector2(64, 64)
	# Top-right corner with margin
	_persistent_button.anchor_left = 1.0
	_persistent_button.anchor_top = 0.0
	_persistent_button.anchor_right = 1.0
	_persistent_button.anchor_bottom = 0.0
	_persistent_button.offset_left = -84
	_persistent_button.offset_top = 16
	_persistent_button.offset_right = -16
	_persistent_button.offset_bottom = 80
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.04, 0.06, 0.1, 0.85)
	bsb.border_width_left = 2
	bsb.border_width_top = 2
	bsb.border_width_right = 2
	bsb.border_width_bottom = 2
	bsb.border_color = Color(0.0, 1.0, 0.8, 0.7)
	bsb.corner_radius_top_left = 16
	bsb.corner_radius_top_right = 16
	bsb.corner_radius_bottom_left = 16
	bsb.corner_radius_bottom_right = 16
	bsb.shadow_color = Color(0.0, 1.0, 0.8, 0.35)
	bsb.shadow_size = 8
	_persistent_button.add_theme_stylebox_override("normal", bsb)
	var bhover := bsb.duplicate() as StyleBoxFlat
	bhover.bg_color = Color(0.1, 0.18, 0.24, 0.95)
	_persistent_button.add_theme_stylebox_override("hover", bhover)
	_persistent_button.add_theme_stylebox_override("pressed", bhover)
	_persistent_button.pressed.connect(toggle)
	layer_node.add_child(_persistent_button)

# ═══════════════════════════════════════════════════════════════════
# CHASSIS — built once, kept around between opens
# ═══════════════════════════════════════════════════════════════════

func _build_chassis() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.65)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_PASS
	_backdrop.gui_input.connect(_on_global_gui_input)
	root.add_child(_backdrop)

	_phone = PanelContainer.new()
	_phone.anchor_left = 0.5
	_phone.anchor_top = 0.5
	_phone.anchor_right = 0.5
	_phone.anchor_bottom = 0.5
	_phone.mouse_filter = Control.MOUSE_FILTER_PASS
	_phone.add_theme_stylebox_override("panel", _make_phone_style())
	root.add_child(_phone)
	_resize_phone()
	get_viewport().size_changed.connect(_resize_phone)

	# Phone interior — vbox: status bar / app container / home bar
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_phone.add_child(vbox)

	_status_bar = Label.new()
	_status_bar.text = "NULLDRIFT//OS  ·  23:47  ·  ▮▮▮▮▯"
	_status_bar.add_theme_font_size_override("font_size", 16)
	_status_bar.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8))
	_status_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_bar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_bar.custom_minimum_size = Vector2(0, STATUS_BAR_H)
	vbox.add_child(_status_bar)

	# Top divider line
	var div := Panel.new()
	var div_sb := StyleBoxFlat.new()
	div_sb.bg_color = Color(0.0, 0.7, 0.6, 0.4)
	div.add_theme_stylebox_override("panel", div_sb)
	div.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(div)

	# App container
	_app_container = Control.new()
	_app_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_app_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_app_container.clip_contents = true
	_app_container.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_app_container)

	# Home bar
	_home_bar = Label.new()
	_home_bar.text = "— swipe → back · P close —"
	_home_bar.add_theme_font_size_override("font_size", 11)
	_home_bar.add_theme_color_override("font_color", Color(0.35, 0.45, 0.6))
	_home_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home_bar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_home_bar.custom_minimum_size = Vector2(0, HOME_BAR_H)
	vbox.add_child(_home_bar)

func _resize_phone() -> void:
	if _phone == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var h: float = clamp(vp_size.y * VIEWPORT_USAGE, PHONE_MIN_H, PHONE_MAX_H)
	var w: float = h * PHONE_ASPECT
	# Don't let the phone exceed 80% of viewport width either
	if w > vp_size.x * 0.80:
		w = vp_size.x * 0.80
		h = w / PHONE_ASPECT
	_phone.custom_minimum_size = Vector2(w, h)
	_phone.size = Vector2(w, h)
	_phone.offset_left = -w / 2.0
	_phone.offset_top = -h / 2.0
	_phone.offset_right = w / 2.0
	_phone.offset_bottom = h / 2.0

func _make_phone_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.035, 0.06)
	sb.corner_radius_top_left = 40
	sb.corner_radius_top_right = 40
	sb.corner_radius_bottom_left = 40
	sb.corner_radius_bottom_right = 40
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.18, 0.28, 0.42)
	sb.shadow_color = Color(0.0, 1.0, 1.0, 0.25)
	sb.shadow_size = 12
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	return sb

# ═══════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════

func open(initial: String = "home") -> void:
	_open = true
	visible = true
	_clear_stack()
	_push(initial)

func close() -> void:
	_open = false
	visible = false
	_clear_stack()

func toggle() -> void:
	if _open: close()
	else: open()

# ═══════════════════════════════════════════════════════════════════
# NAV STACK
# ═══════════════════════════════════════════════════════════════════

func _clear_stack() -> void:
	for child in _app_container.get_children():
		child.queue_free()
	_stack.clear()

func _push(app_id: String) -> void:
	for child in _app_container.get_children():
		child.visible = false
	var screen: Control
	if app_id == "home":
		screen = _build_home()
	else:
		screen = _build_app(app_id)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_PASS
	_app_container.add_child(screen)
	_stack.append({ "id": app_id, "node": screen })

func _back() -> void:
	if _stack.size() <= 1:
		close()
		return
	var top: Dictionary = _stack.pop_back()
	(top["node"] as Node).queue_free()
	var new_top: Dictionary = _stack[-1]
	(new_top["node"] as Control).visible = true

# ═══════════════════════════════════════════════════════════════════
# HOME SCREEN — 4 column grid of all visible apps
# ═══════════════════════════════════════════════════════════════════

func _build_home() -> Control:
	var screen := VBoxContainer.new()
	screen.add_theme_constant_override("separation", 10)

	# Greeting
	var greeting := Label.new()
	greeting.text = "good evening, ghost"
	greeting.add_theme_font_size_override("font_size", 16)
	greeting.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(greeting)

	# Compute icon size from current phone width so 4 cols fit
	var inner_w: float = _phone.size.x - 44.0
	var gap: float = 8.0
	var cell_w: float = (inner_w - gap * (APP_GRID_COLS - 1)) / float(APP_GRID_COLS)
	var icon_size: float = max(48.0, min(cell_w, 110.0))

	var grid := GridContainer.new()
	grid.columns = APP_GRID_COLS
	grid.add_theme_constant_override("h_separation", int(gap))
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for app in APPS:
		grid.add_child(_build_app_icon(app, icon_size))
	screen.add_child(grid)

	# Tip
	var tip := Label.new()
	tip.text = "swipe → back · tap outside to close"
	tip.add_theme_font_size_override("font_size", 10)
	tip.add_theme_color_override("font_color", Color(0.35, 0.4, 0.55))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tip.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	screen.add_child(tip)

	return screen

func _build_app_icon(app: Dictionary, icon_size: float = 64.0) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 3)
	cell.custom_minimum_size = Vector2(icon_size, icon_size + 18)
	var color: Color = app.get("color", Color.WHITE)
	var app_id: String = app.get("id", "")

	# Build the icon styling — used for both glyph-button and image-button
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.14)
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.border_color = Color(color.r, color.g, color.b, 0.55)
	sb.corner_radius_top_left = 18; sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18; sb.corner_radius_bottom_right = 18
	sb.shadow_color = Color(color.r, color.g, color.b, 0.18)
	sb.shadow_size = 6
	var sb_hover := sb.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color(0.12, 0.18, 0.26)
	sb_hover.border_color = Color(color.r, color.g, color.b, 1.0)

	var icon_path: String = app.get("icon_path", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		# Image-mode icon: Button with icon texture, no text glyph
		var btn := Button.new()
		btn.icon = load(icon_path)
		btn.expand_icon = true
		btn.custom_minimum_size = Vector2(icon_size, icon_size)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb_hover)
		btn.add_theme_stylebox_override("pressed", sb_hover)
		btn.pressed.connect(func(): _push(app_id))
		cell.add_child(btn)
	else:
		# Glyph fallback (kept so adding a new app doesn't require artwork)
		var btn := Button.new()
		btn.text = app.get("icon", "?")
		btn.add_theme_font_size_override("font_size", int(icon_size * 0.45))
		btn.custom_minimum_size = Vector2(icon_size, icon_size)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb_hover)
		btn.add_theme_stylebox_override("pressed", sb_hover)
		btn.add_theme_color_override("font_color", color)
		btn.add_theme_color_override("font_hover_color", color)
		btn.add_theme_color_override("font_pressed_color", color)
		btn.pressed.connect(func(): _push(app_id))
		cell.add_child(btn)

	var label := Label.new()
	label.text = app.get("label", "")
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(label)
	return cell

# ═══════════════════════════════════════════════════════════════════
# APP SCREENS — currently stubs. Each gets its own builder later.
# ═══════════════════════════════════════════════════════════════════

func _build_app_default(app_id: String) -> Control:
	var app := _find_app(app_id)
	var color: Color = app.get("color", Color.WHITE)

	var screen := VBoxContainer.new()
	screen.add_theme_constant_override("separation", 12)

	# Top bar: ‹ back · ICON title
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)

	var back := Button.new()
	back.text = "‹"
	back.add_theme_font_size_override("font_size", 28)
	back.custom_minimum_size = Vector2(48, 48)
	var back_sb := StyleBoxFlat.new()
	back_sb.bg_color = Color(0.07, 0.09, 0.14)
	back_sb.border_color = Color(color.r, color.g, color.b, 0.4)
	back_sb.border_width_left = 1
	back_sb.border_width_top = 1
	back_sb.border_width_right = 1
	back_sb.border_width_bottom = 1
	back_sb.corner_radius_top_left = 14
	back_sb.corner_radius_top_right = 14
	back_sb.corner_radius_bottom_left = 14
	back_sb.corner_radius_bottom_right = 14
	back.add_theme_stylebox_override("normal", back_sb)
	back.add_theme_color_override("font_color", color)
	back.pressed.connect(_back)
	top.add_child(back)

	var title := Label.new()
	title.text = "%s  %s" % [app.get("icon", ""), app.get("label", "")]
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", color)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(48, 0)
	top.add_child(spacer)

	screen.add_child(top)

	# Body — let each app override; default is a "coming soon" stub
	var body := _build_app_body(app_id, color)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_child(body)
	return screen

func _build_app_body(app_id: String, color: Color) -> Control:
	# Apps with real data implementations; the rest fall through to a stub.
	match app_id:
		"messages": return _stub_messages(color)
		"dating":   return _app_dating(color)
		"news":     return _app_news(color)
		"stocks":   return _app_stocks(color)
		"email":    return _app_email(color)
		"profile":  return _app_profile(color)
		"map":      return _stub_map(color)
		"deck":     return _stub_deck(color)
		_:          return _stub_generic(app_id, color)

# ─────────────────────────────────────────────────────────────────────
# News — reads res://data/news_articles.gd, gated by flags
# ─────────────────────────────────────────────────────────────────────
func _app_news(color: Color) -> Control:
	var flags: Dictionary = GameState.flags if GameState else {}
	var articles: Array = NewsData.visible(flags)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for a in articles:
		list.add_child(_news_card(a, color))
	return scroll

func _news_card(article: Dictionary, color: Color) -> Control:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.12)
	sb.border_color = Color(color.r, color.g, color.b, 0.35)
	sb.border_width_left = 1; sb.border_width_top = 1
	sb.border_width_right = 1; sb.border_width_bottom = 1
	sb.corner_radius_top_left = 8; sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	var headline := Label.new()
	headline.text = article.get("headline", "")
	headline.add_theme_font_size_override("font_size", 13)
	headline.add_theme_color_override("font_color", color)
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(headline)
	var meta := Label.new()
	meta.text = "%s  ·  %s" % [article.get("source", ""), article.get("time", "")]
	meta.add_theme_font_size_override("font_size", 9)
	meta.add_theme_color_override("font_color", Color(0.4, 0.5, 0.65))
	v.add_child(meta)
	var body := Label.new()
	body.text = article.get("body", "")
	body.add_theme_font_size_override("font_size", 11)
	body.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)
	card.add_child(v)
	return card

# ─────────────────────────────────────────────────────────────────────
# Stocks — reads StocksState (live prices that tick + react to events)
# ─────────────────────────────────────────────────────────────────────
func _app_stocks(color: Color) -> Control:
	var snap: Array = StocksState.snapshot()
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	# Header row
	var head := HBoxContainer.new()
	for col_text in [["TICKER", 60], ["NAME", 0], ["PRICE", 70], ["CHG", 60]]:
		var l := Label.new()
		l.text = col_text[0]
		l.custom_minimum_size = Vector2(col_text[1], 0)
		l.add_theme_font_size_override("font_size", 10)
		l.add_theme_color_override("font_color", Color(0.4, 0.5, 0.65))
		if col_text[1] == 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(l)
	list.add_child(head)
	# Rows
	for row in snap:
		list.add_child(_stocks_row(row, color))
	return scroll

func _stocks_row(row: Dictionary, color: Color) -> Control:
	var hb := HBoxContainer.new()
	var ticker := Label.new()
	ticker.text = row.get("ticker", "")
	ticker.custom_minimum_size = Vector2(60, 0)
	ticker.add_theme_font_size_override("font_size", 12)
	ticker.add_theme_color_override("font_color", color)
	hb.add_child(ticker)
	var name := Label.new()
	name.text = row.get("name", "")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override("font_size", 11)
	name.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	name.clip_text = true
	hb.add_child(name)
	var price := Label.new()
	var price_value: float = row.get("price", 0.0)
	price.text = "%.2f" % price_value if price_value >= 1.0 else "%.4f" % price_value
	price.custom_minimum_size = Vector2(70, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.add_theme_font_size_override("font_size", 12)
	price.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	hb.add_child(price)
	var chg := Label.new()
	var c: float = row.get("change", 0.0)
	chg.text = "%+.1f%%" % c
	chg.custom_minimum_size = Vector2(60, 0)
	chg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chg.add_theme_font_size_override("font_size", 11)
	chg.add_theme_color_override("font_color",
		Color(0.27, 1.0, 0.4) if c >= 0 else Color(1.0, 0.3, 0.3))
	hb.add_child(chg)
	return hb

# ─────────────────────────────────────────────────────────────────────
# Email — reads res://data/emails.gd; drip count is PhoneState.drip_arrived
# ─────────────────────────────────────────────────────────────────────
func _app_email(color: Color) -> Control:
	# PhoneState doesn't track drip_arrived yet — drip count = 0 for now.
	# Wiring it up to a quest event later is a one-liner here.
	var arrived: int = 0
	var inbox: Array = EmailsData.inbox(arrived)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for e in inbox:
		list.add_child(_email_row(e, color))
	return scroll

func _email_row(email: Dictionary, color: Color) -> Control:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.12)
	sb.border_color = Color(color.r, color.g, color.b, 0.3)
	sb.border_width_left = 1; sb.border_width_top = 1
	sb.border_width_right = 1; sb.border_width_bottom = 1
	sb.corner_radius_top_left = 8; sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 10; sb.content_margin_right = 10
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	var top := HBoxContainer.new()
	var from := Label.new()
	from.text = email.get("from", "")
	from.add_theme_font_size_override("font_size", 12)
	from.add_theme_color_override("font_color", color)
	from.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(from)
	var ts := Label.new()
	ts.text = email.get("time", "")
	ts.add_theme_font_size_override("font_size", 10)
	ts.add_theme_color_override("font_color", Color(0.4, 0.5, 0.65))
	top.add_child(ts)
	v.add_child(top)
	var subj := Label.new()
	subj.text = email.get("subject", "")
	subj.add_theme_font_size_override("font_size", 11)
	subj.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	v.add_child(subj)
	var body := Label.new()
	body.text = email.get("body", "")
	body.add_theme_font_size_override("font_size", 10)
	body.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)
	card.add_child(v)
	return card

# ─────────────────────────────────────────────────────────────────────
# Dating — reads res://data/dating_profiles.gd; votes persist in PhoneState
# ─────────────────────────────────────────────────────────────────────
func _app_dating(color: Color) -> Control:
	var votes: Dictionary = PhoneState.dating_votes if PhoneState else {}
	var stack: Array = DatingData.unvoted(votes)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if stack.is_empty():
		var done := Label.new()
		done.text = "no more profiles in your area.\ntry again tomorrow."
		done.add_theme_font_size_override("font_size", 14)
		done.add_theme_color_override("font_color", Color(0.5, 0.6, 0.75))
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done.size_flags_vertical = Control.SIZE_EXPAND_FILL
		done.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(done)
		return v

	var profile: Dictionary = stack[0]
	var p_color: Color = profile.get("color", color)

	# Photo placeholder — colored panel until we have art
	var pic := Panel.new()
	pic.custom_minimum_size = Vector2(220, 240)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(p_color.r * 0.3, p_color.g * 0.3, p_color.b * 0.3)
	sb.border_color = p_color
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.corner_radius_top_left = 18; sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18; sb.corner_radius_bottom_right = 18
	sb.shadow_color = Color(p_color.r, p_color.g, p_color.b, 0.3)
	sb.shadow_size = 6
	pic.add_theme_stylebox_override("panel", sb)
	v.add_child(pic)

	# Name + age
	var name_label := Label.new()
	name_label.text = "%s · %s" % [profile.get("name", ""), str(profile.get("age", ""))]
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", p_color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)

	# Tagline
	var tag := Label.new()
	tag.text = profile.get("tagline", "")
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tag)

	# Bio
	var bio := Label.new()
	bio.text = profile.get("bio", "")
	bio.add_theme_font_size_override("font_size", 10)
	bio.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	bio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(bio)

	# Interests
	var interests_txt := Label.new()
	var interests: Array = profile.get("interests", [])
	interests_txt.text = "  ·  ".join(interests)
	interests_txt.add_theme_font_size_override("font_size", 9)
	interests_txt.add_theme_color_override("font_color", Color(0.45, 0.55, 0.7))
	interests_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interests_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(interests_txt)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	# Swipe buttons
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 40)
	var pass_btn := _date_button("✕", Color(0.5, 0.6, 0.7))
	var like_btn := _date_button("♥", Color(1.0, 0.27, 0.4))
	var profile_id: String = profile.get("id", "")
	pass_btn.pressed.connect(func(): _on_date_vote(profile_id, false))
	like_btn.pressed.connect(func(): _on_date_vote(profile_id, true))
	hb.add_child(pass_btn)
	hb.add_child(like_btn)
	v.add_child(hb)
	return v

func _date_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", color)
	btn.custom_minimum_size = Vector2(64, 64)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.14)
	sb.border_color = color
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.corner_radius_top_left = 18; sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18; sb.corner_radius_bottom_right = 18
	sb.shadow_color = Color(color.r, color.g, color.b, 0.4)
	sb.shadow_size = 6
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_h)
	return btn

func _on_date_vote(profile_id: String, liked_it: bool) -> void:
	PhoneState.vote(profile_id, liked_it)
	# Refresh the dating view in-place
	var top: Dictionary = _stack[-1]
	(top["node"] as Node).queue_free()
	var screen := _build_app("dating")
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_PASS
	_app_container.add_child(screen)
	top["node"] = screen
	_stack[-1] = top

# ─────────────────────────────────────────────────────────────────────
# Profile — pulls from GameState (credits, hp, inventory size, active quest)
# ─────────────────────────────────────────────────────────────────────
func _app_profile(color: Color) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var gs := GameState
	var rows := [
		["NAME",     "Ghost"],
		["ID",       "0x4f7a-9e21"],
		["CREDITS",  "₡ %s" % _fmt_num(gs.credits if gs else 0)],
		["HP",       "%d / %d" % [gs.hp if gs else 6, 6]],
		["INVENTORY","%d items" % (gs.inventory.size() if gs else 0)],
		["QUEST",    str(gs.active_quest) if gs and gs.active_quest else "—"],
		["LEVEL",    "1"],
		["TRACE",    "0%"],
	]
	for r in rows:
		var hb := HBoxContainer.new()
		var k := Label.new()
		k.text = r[0]
		k.add_theme_font_size_override("font_size", 12)
		k.add_theme_color_override("font_color", Color(0.4, 0.5, 0.65))
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(k)
		var vv := Label.new()
		vv.text = r[1]
		vv.add_theme_font_size_override("font_size", 14)
		vv.add_theme_color_override("font_color", color)
		hb.add_child(vv)
		v.add_child(hb)
	return v

func _fmt_num(n: int) -> String:
	# Simple thousands separator
	var s := str(n)
	var out := ""
	var i := s.length()
	while i > 3:
		out = "," + s.substr(i - 3, 3) + out
		i -= 3
	return s.substr(0, i) + out

func _stub_generic(app_id: String, color: Color) -> Control:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := Label.new()
	l.text = "[ %s coming soon ]" % app_id.to_upper()
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(color.r, color.g, color.b, 0.8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(l)
	return v

# Messages app — reads res://data/messages.gd, mutates PhoneState (read flags,
# choice picks). Phone overlay is purely a view; data + state live elsewhere.
const MessagesData := preload("res://data/messages.gd")

# Tracks how far we've revealed each thread (so player choices can advance
# the conversation). Lives at PhoneOverlay scope, not on Messages data.
var _msg_open_thread: String = ""
var _msg_progress: Dictionary = {}   # { thread_id: revealed_count }

func _stub_messages(color: Color) -> Control:
	# Reading: ask data layer for visible threads given current flags
	var flags: Dictionary = GameState.flags if GameState else {}
	var threads: Array = MessagesData.visible_threads(flags)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for t in threads:
		list.add_child(_message_row(t, color))
	return scroll

func _message_row(t: Dictionary, app_color: Color) -> Control:
	var color: Color = t.get("color", app_color)
	var thread_id: String = t.get("id", "")
	var unread: bool = not PhoneState.is_read(thread_id)
	var row := Button.new()
	row.toggle_mode = false
	row.flat = true
	row.custom_minimum_size = Vector2(0, 64)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Use a Panel inside to get the visual styling; Button gives us press behavior
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.12)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(color.r, color.g, color.b, 0.25 if not unread else 0.6)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	row.add_theme_stylebox_override("normal", sb)
	var sb_hover := sb.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color(0.08, 0.12, 0.18)
	row.add_theme_stylebox_override("hover", sb_hover)
	row.add_theme_stylebox_override("pressed", sb_hover)

	row.pressed.connect(func(): _open_thread(thread_id))

	# Build the content into a vbox added as a child of the button (Buttons
	# render their `text` but we want richer content, so we use children)
	var rv := VBoxContainer.new()
	rv.anchor_left = 0; rv.anchor_top = 0
	rv.anchor_right = 1; rv.anchor_bottom = 1
	rv.offset_left = 12; rv.offset_top = 8
	rv.offset_right = -12; rv.offset_bottom = -8
	row.add_child(rv)

	var top := HBoxContainer.new()
	var n := Label.new()
	var dot := "●  " if unread else ""
	n.text = "%s%s" % [dot, t.get("from", "")]
	n.add_theme_font_size_override("font_size", 14)
	n.add_theme_color_override("font_color", color)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(n)
	var when_label := Label.new()
	when_label.text = t.get("time", "")
	when_label.add_theme_font_size_override("font_size", 10)
	when_label.add_theme_color_override("font_color", Color(0.4, 0.5, 0.65))
	top.add_child(when_label)
	rv.add_child(top)

	var p := Label.new()
	p.text = t.get("preview", "")
	p.add_theme_font_size_override("font_size", 11)
	p.add_theme_color_override("font_color",
		Color(0.85, 0.85, 0.95) if unread else Color(0.55, 0.6, 0.7))
	p.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.clip_text = true
	rv.add_child(p)
	return row

# ─────────────────────────────────────────────────────────────────────
# Thread view — chat bubbles, player choices push more bubbles
# ─────────────────────────────────────────────────────────────────────

func _open_thread(thread_id: String) -> void:
	_msg_open_thread = thread_id
	# A new thread opens fully (no slow-reveal yet — that's animation polish).
	if not _msg_progress.has(thread_id):
		_msg_progress[thread_id] = 999
	PhoneState.mark_read(thread_id)
	_push("messages_thread")

# Special-case nav: "messages_thread" is an app id we render with state above
func _build_app(app_id: String) -> Control:
	if app_id == "messages_thread":
		return _build_thread_view()
	return _build_app_default(app_id)

func _build_thread_view() -> Control:
	var thread: Dictionary = MessagesData.get_thread(_msg_open_thread)
	var color: Color = thread.get("color", Color(1, 0, 1))

	var screen := VBoxContainer.new()
	screen.add_theme_constant_override("separation", 8)

	# Top bar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var back := _back_button(color)
	top.add_child(back)
	var title := Label.new()
	title.text = thread.get("from", "")
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", color)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(48, 0)
	top.add_child(spacer)
	screen.add_child(top)

	# Scrollable bubble area
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.scroll_horizontal_custom_step = 0
	var bubbles := VBoxContainer.new()
	bubbles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubbles.add_theme_constant_override("separation", 6)
	scroll.add_child(bubbles)
	screen.add_child(scroll)

	# Render the thread up to recorded progress; player-choice nodes become
	# interactive buttons that, when pressed, record the choice in PhoneState.
	var msgs: Array = thread.get("thread", [])
	for i in msgs.size():
		var m: Dictionary = msgs[i]
		if m.get("sender", "") == "you" and m.has("choices"):
			var picked := PhoneState.choice_for(_msg_open_thread, i)
			if picked >= 0:
				var ch: Dictionary = m["choices"][picked]
				bubbles.add_child(_bubble(ch.get("text", ""), color, true))
				bubbles.add_child(_bubble(ch.get("reply", ""), color, false))
			else:
				bubbles.add_child(_choice_buttons(m["choices"], i, color))
				break  # stop rendering until they pick
		else:
			var is_player: bool = m.get("sender", "") == "you"
			bubbles.add_child(_bubble(m.get("text", ""), color, is_player))
	return screen

func _bubble(text: String, color: Color, is_player: bool) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_player:
		row.alignment = BoxContainer.ALIGNMENT_END
	var bubble := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	if is_player:
		sb.bg_color = Color(0.12, 0.2, 0.32)
		sb.border_color = Color(0.0, 1.0, 1.0, 0.4)
	else:
		sb.bg_color = Color(0.08, 0.06, 0.12)
		sb.border_color = Color(color.r, color.g, color.b, 0.5)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	bubble.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color",
		Color(0.85, 0.95, 1.0) if is_player else Color(0.95, 0.9, 1.0))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Without an explicit width, autowrap inside a SHRINK container collapses
	# to one character per line. Force the label to a usable bubble width.
	l.custom_minimum_size = Vector2(220, 0)
	bubble.add_child(l)
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if is_player else Control.SIZE_SHRINK_BEGIN
	row.add_child(bubble)
	return row

func _choice_buttons(choices: Array, turn: int, color: Color) -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	var head := Label.new()
	head.text = "— reply —"
	head.add_theme_font_size_override("font_size", 10)
	head.add_theme_color_override("font_color", Color(0.5, 0.6, 0.75))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	for i in choices.size():
		var ch: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = ch.get("text", "")
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(0.8, 1.0, 1.0))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.12, 0.18)
		sb.border_color = Color(0.0, 1.0, 1.0, 0.4)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.corner_radius_top_left = 10
		sb.corner_radius_top_right = 10
		sb.corner_radius_bottom_left = 10
		sb.corner_radius_bottom_right = 10
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		btn.add_theme_stylebox_override("normal", sb)
		var sb_hover := sb.duplicate() as StyleBoxFlat
		sb_hover.bg_color = Color(0.1, 0.2, 0.3)
		btn.add_theme_stylebox_override("hover", sb_hover)
		btn.add_theme_stylebox_override("pressed", sb_hover)
		var captured_i := i
		btn.pressed.connect(func(): _on_choice_picked(turn, captured_i))
		v.add_child(btn)
	return v

func _on_choice_picked(turn: int, choice_index: int) -> void:
	PhoneState.set_choice(_msg_open_thread, turn, choice_index)
	# Rebuild the thread view in place
	var top: Dictionary = _stack[-1]
	(top["node"] as Node).queue_free()
	var screen := _build_thread_view()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_PASS
	_app_container.add_child(screen)
	top["node"] = screen
	_stack[-1] = top

func _back_button(color: Color) -> Button:
	var back := Button.new()
	back.text = "‹"
	back.add_theme_font_size_override("font_size", 26)
	back.custom_minimum_size = Vector2(48, 48)
	var back_sb := StyleBoxFlat.new()
	back_sb.bg_color = Color(0.07, 0.09, 0.14)
	back_sb.border_color = Color(color.r, color.g, color.b, 0.4)
	back_sb.border_width_left = 1
	back_sb.border_width_top = 1
	back_sb.border_width_right = 1
	back_sb.border_width_bottom = 1
	back_sb.corner_radius_top_left = 14
	back_sb.corner_radius_top_right = 14
	back_sb.corner_radius_bottom_left = 14
	back_sb.corner_radius_bottom_right = 14
	back.add_theme_stylebox_override("normal", back_sb)
	back.add_theme_color_override("font_color", color)
	back.pressed.connect(_back)
	return back

func _stub_dating(color: Color) -> Control:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)

	var pic := Panel.new()
	pic.custom_minimum_size = Vector2(220, 280)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.05, 0.12)
	sb.border_color = Color(color.r, color.g, color.b, 0.7)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 22
	sb.corner_radius_top_right = 22
	sb.corner_radius_bottom_left = 22
	sb.corner_radius_bottom_right = 22
	pic.add_theme_stylebox_override("panel", sb)
	v.add_child(pic)

	var name := Label.new()
	name.text = "KERRY · 24"
	name.add_theme_font_size_override("font_size", 22)
	name.add_theme_color_override("font_color", color)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name)

	var bio := Label.new()
	bio.text = "neon witch.  art-school dropout.\nasks the wrong questions."
	bio.add_theme_font_size_override("font_size", 13)
	bio.add_theme_color_override("font_color", Color(0.85, 0.7, 0.85))
	bio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(bio)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 30)
	var pass_btn := Button.new()
	pass_btn.text = "✕"
	pass_btn.add_theme_font_size_override("font_size", 24)
	pass_btn.custom_minimum_size = Vector2(64, 64)
	hb.add_child(pass_btn)
	var like_btn := Button.new()
	like_btn.text = "♥"
	like_btn.add_theme_font_size_override("font_size", 24)
	like_btn.add_theme_color_override("font_color", Color(1, 0.27, 0.4))
	like_btn.custom_minimum_size = Vector2(64, 64)
	hb.add_child(like_btn)
	v.add_child(hb)
	return v

func _stub_map(color: Color) -> Control:
	var v := VBoxContainer.new()
	var l := Label.new()
	l.text = "city map"
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	# Simple cyber map block
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 380)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.08)
	sb.border_color = Color(color.r, color.g, color.b, 0.5)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	p.add_theme_stylebox_override("panel", sb)
	v.add_child(p)
	var legend := Label.new()
	legend.text = "▲ your apartment   ◉ neo city block 7"
	legend.add_theme_font_size_override("font_size", 11)
	legend.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85))
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(legend)
	return v

func _stub_profile(color: Color) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	var rows := [
		["NAME", "Ghost"],
		["ID", "0x4f7a-9e21"],
		["CREDITS", str(GameState.credits if GameState else 0)],
		["LEVEL", "1"],
		["TRACE", "0%"],
	]
	for r in rows:
		var hb := HBoxContainer.new()
		var k := Label.new()
		k.text = r[0]
		k.add_theme_font_size_override("font_size", 13)
		k.add_theme_color_override("font_color", Color(0.5, 0.6, 0.75))
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(k)
		var vv := Label.new()
		vv.text = r[1]
		vv.add_theme_font_size_override("font_size", 14)
		vv.add_theme_color_override("font_color", color)
		hb.add_child(vv)
		v.add_child(hb)
	return v

func _stub_deck(color: Color) -> Control:
	var v := VBoxContainer.new()
	var lines := [
		"deck v2.1 — online",
		"$ scan",
		"  found 3 nearby targets",
		"  > corp_atm_007 [trivial]",
		"  > sec_camera_15 [easy]",
		"  > nexus_gate_3  [hard]",
		"$ _",
	]
	for line in lines:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", color)
		v.add_child(l)
	return v

# ═══════════════════════════════════════════════════════════════════
# INPUT — toggle, back, swipe-right-to-back
# ═══════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("phone_toggle"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()

func _on_global_gui_input(event: InputEvent) -> void:
	# The backdrop catches swipe drags that miss buttons. We also treat a
	# click on the dim area outside the phone as "close".
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var ev := event as InputEventFromWindow
		if event.is_pressed():
			_drag_start = _event_position(event)
			_dragging = true
		else:
			if _dragging:
				_dragging = false
				var end_pos := _event_position(event)
				_handle_release(end_pos - _drag_start, end_pos)

func _event_position(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	return Vector2.ZERO

func _handle_release(delta: Vector2, end_pos: Vector2) -> void:
	# Swipe right anywhere → back. Tap on dim area outside the phone → close.
	if delta.length() < SWIPE_MIN:
		# Tap with no drag — if it landed outside the phone rect, close.
		var rect := _phone.get_global_rect()
		if not rect.has_point(end_pos):
			close()
		return
	if absf(delta.x) > absf(delta.y) * 1.3 and delta.x > 0:
		_back()
	elif absf(delta.y) > absf(delta.x) * 1.3 and delta.y > 0 and _stack.size() <= 1:
		# Swipe down on home → close phone
		close()

# ═══════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════

func _find_app(id: String) -> Dictionary:
	for app in APPS:
		if app.get("id", "") == id:
			return app
	return {}
