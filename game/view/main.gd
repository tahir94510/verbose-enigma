extends Node2D
## Oyun görünümü: sim durumunu okur, çizer, oyuncu girdisini Command'a çevirir.
## Yer tutucu geometrik ikonlar kullanır; nihai sanat sonradan aynı id'lerle değiştirilir.

const SimWorld = preload("res://sim/sim_world.gd")
const GameData = preload("res://sim/game_data.gd")
const AIController = preload("res://ai/ai_controller.gd")
const Glad = preload("res://sim/glad.gd")

const COL_BG := Color("2a2118")
const COL_SAND := Color("3a2e20")
const COL_LANE := Color("56452f")
const COL_COVER := Color("3f4a2b")
const COL_T := [Color("3d86a8"), Color("b8452f")]
const COL_CLS := {"murmillo": Color("c79a4a"), "thraex": Color("e0762f"), "secutor": Color("d94a2b"), "retiarius": Color("3aa3b8"), "veles": Color("8fa646")}
const FOG_CELL := 40.0
const STANCE_NAME := {"agg": "Saldırgan", "def": "Savunmacı", "pusu": "Pusu"}

var data: Dictionary
var w
var ai
var player: int = 0
var speed: float = 1.0
var paused: bool = false
var acc: float = 0.0
var cam := Vector2(400, 1200)
var sel = null                 # {"type": "lane"/"tower"/"ludus"/"glad", ...}
var pending = null             # bekleyen hedef seçimi
var queue_mode: bool = false
var fog_vis := PackedByteArray()
var fog_t: float = 0.0
var fw: int = 60
var fh: int = 40
var over_text: String = ""
var _drag := false
var _drag_from := Vector2.ZERO
var _cam_start := Vector2.ZERO
var ui: CanvasLayer
var lbl_top: Label
var lbl_info: Label
var lbl_plan: Label
var lbl_msg: Label
var cmd_box: HBoxContainer
var shop_panel: PanelContainer
var menu: Control
var minimap: Control
var btns: Dictionary = {}
var pick: Array = []
var diff_val: float = 0.5
var msg_t: float = 0.0
var font: Font

func _ready() -> void:
	data = GameData.load_all()
	font = ThemeDB.fallback_font
	ui = CanvasLayer.new()
	add_child(ui)
	_show_menu()

# ---------- menü ----------
func _show_menu() -> void:
	if menu != null:
		menu.queue_free()
	pick = []
	menu = PanelContainer.new()
	menu.set_anchors_preset(Control.PRESET_CENTER)
	menu.custom_minimum_size = Vector2(560, 360)
	menu.position = Vector2(360, 160)
	var vb := VBoxContainer.new()
	menu.add_child(vb)
	var t := Label.new()
	t.text = "GLADYATÖR KOMUTANI — çalışma adı\nİki gladyatör seç, zorluğu seç"
	vb.add_child(t)
	var row := HBoxContainer.new()
	vb.add_child(row)
	for cls in data["glads"].keys():
		var b := Button.new()
		b.text = data["glads"][cls]["name"] + "\n" + data["glads"][cls]["role"]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(100, 60)
		b.toggled.connect(func(on): _toggle_pick(cls, on, b))
		row.add_child(b)
	var drow := HBoxContainer.new()
	vb.add_child(drow)
	var dl := Label.new(); dl.text = "Zorluk: "; drow.add_child(dl)
	for pr in [["Kolay", 0.15], ["Orta", 0.5], ["Zor", 0.9]]:
		var b := Button.new()
		b.text = pr[0]
		b.toggle_mode = true
		b.button_pressed = pr[1] == 0.5
		b.pressed.connect(func(): diff_val = pr[1])
		drow.add_child(b)
	var go := Button.new()
	go.text = "Başla"
	go.pressed.connect(_start)
	vb.add_child(go)
	var help := Label.new()
	help.text = "Tıkla: grup/specula seç · Q/W/E duruş · D iyileş · F Hypogeum · B geri çekil\nSpace: gladyatöre git · P: duraklat · +/-: hız · Sağ tık sürükle / WASD: kamera"
	vb.add_child(help)
	ui.add_child(menu)

func _toggle_pick(cls: String, on: bool, b: Button) -> void:
	if on:
		if pick.size() >= 2:
			b.set_pressed_no_signal(false)
			return
		pick.append(cls)
	else:
		pick.erase(cls)

func _start() -> void:
	if pick.size() != 2:
		return
	var rest: Array = []
	for c in data["glads"].keys():
		if not pick.has(c):
			rest.append(c)
	var seed_ := int(Time.get_ticks_usec() & 0x7fffffff)
	var ai_pair: Array = [rest[seed_ % rest.size()], rest[(seed_ / 7 + 1) % rest.size()]]
	if ai_pair[0] == ai_pair[1]:
		ai_pair[1] = rest[(rest.find(ai_pair[0]) + 1) % rest.size()]
	w = SimWorld.new(data, seed_, [pick.duplicate(), ai_pair])
	ai = AIController.new(1, diff_val, ["temkinli", "pusucu", "dengeli"][seed_ % 3])
	ai.setup(w)
	var g = w.teams[0]["glads"][0]
	for i in 2:
		w.teams[0]["plan"][i] = AIController.PLANS[pick[i]].duplicate()
	cam = w.ludus(0).pos - Vector2(640, 360)
	over_text = ""
	menu.queue_free()
	menu = null
	_build_hud()

# ---------- HUD ----------
func _mk_btn(text: String, cb: Callable, key: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	if key != "":
		btns[key] = b
	return b

func _build_hud() -> void:
	for c in ui.get_children():
		c.queue_free()
	btns.clear()
	var top := PanelContainer.new()
	top.position = Vector2(0, 0)
	top.size = Vector2(1280, 40)
	lbl_top = Label.new()
	top.add_child(lbl_top)
	ui.add_child(top)
	var right := PanelContainer.new()
	right.position = Vector2(1020, 46)
	right.custom_minimum_size = Vector2(250, 200)
	lbl_info = Label.new()
	lbl_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_info.custom_minimum_size = Vector2(240, 190)
	right.add_child(lbl_info)
	ui.add_child(right)
	var plan := PanelContainer.new()
	plan.position = Vector2(300, 46)
	lbl_plan = Label.new()
	plan.add_child(lbl_plan)
	ui.add_child(plan)
	lbl_msg = Label.new()
	lbl_msg.position = Vector2(440, 320)
	lbl_msg.add_theme_font_size_override("font_size", 22)
	ui.add_child(lbl_msg)
	var bottom := PanelContainer.new()
	bottom.position = Vector2(220, 640)
	bottom.size = Vector2(1060, 80)
	var vb := VBoxContainer.new()
	bottom.add_child(vb)
	var r1 := HBoxContainer.new()
	var r2 := HBoxContainer.new()
	vb.add_child(r1)
	vb.add_child(r2)
	cmd_box = r1
	for p in [["İyileş (D)", _on_heal], ["Hypogeum (F)", _on_hyp], ["Geri çekil (B)", _on_retreat], ["Munus", _on_munus], ["Değiştir", _on_swap]]:
		r2.add_child(_mk_btn(p[0], p[1]))
	r2.add_child(_mk_btn("Oto: açık", _on_auto, "auto"))
	r2.add_child(_mk_btn("Plan: kapalı", _on_queue, "queue"))
	r2.add_child(_mk_btn("Son adımı sil", func(): _cmd({"type": "clear", "all": false})))
	r2.add_child(_mk_btn("Hepsini sil", func(): _cmd({"type": "clear", "all": true})))
	r2.add_child(_mk_btn("Armamentarium", _on_shop))
	r2.add_child(_mk_btn("Menü", func(): _show_menu()))
	ui.add_child(bottom)
	_build_shop()
	minimap = Control.new()
	minimap.position = Vector2(6, 560)
	minimap.custom_minimum_size = Vector2(210, 154)
	minimap.size = Vector2(210, 154)
	minimap.draw.connect(_draw_minimap)
	minimap.gui_input.connect(_minimap_input)
	ui.add_child(minimap)
	_rebuild_cmds()

func _build_shop() -> void:
	shop_panel = PanelContainer.new()
	shop_panel.position = Vector2(220, 140)
	shop_panel.visible = false
	var vb := VBoxContainer.new()
	shop_panel.add_child(vb)
	var h := Label.new()
	h.text = "Armamentarium — plana eklenir, Ludus'ta otomatik alınır (4 slot)"
	vb.add_child(h)
	for line in ["lorica", "gladius", "caliga", "medicus", "signum"]:
		var row := HBoxContainer.new()
		vb.add_child(row)
		var l := Label.new(); l.text = line.capitalize() + ":"; l.custom_minimum_size = Vector2(70, 0)
		row.add_child(l)
		for id in data["items"].keys():
			var it: Dictionary = data["items"][id]
			if it["line"] == line:
				var b := Button.new()
				b.text = "%s %d" % [it["name"], it["total"]]
				b.tooltip_text = JSON.stringify(it["fx"])
				b.focus_mode = Control.FOCUS_NONE
				b.pressed.connect(func(): _plan_add(id))
				row.add_child(b)
	var clr := Button.new()
	clr.text = "Planı temizle (aktif gladyatör)"
	clr.pressed.connect(func():
		var ts = w.teams[0]
		ts["plan"][ts["active"]] = []
		_flash("Alım planı temizlendi"))
	vb.add_child(clr)
	ui.add_child(shop_panel)

func _plan_add(id: String) -> void:
	var ts = w.teams[0]
	var gi: int = ts["active"]
	if ts["plan"][gi].size() >= 6:
		_flash("Alım planı en çok 6 adım")
		return
	ts["plan"][gi].append(id)
	_flash("Plana eklendi: " + data["items"][id]["name"])

func _rebuild_cmds() -> void:
	for c in cmd_box.get_children():
		c.queue_free()
	if sel == null:
		var l := Label.new(); l.text = "Seç: bir grup (kendi birimine tıkla) ya da specula"; cmd_box.add_child(l)
	elif sel["type"] == "lane":
		var lane: int = sel["lane"]
		cmd_box.add_child(_mk_btn("İlerle", func(): _need_target({"op": "advance", "lane": lane})))
		cmd_box.add_child(_mk_btn("Mevzi al", func(): _cmd({"type": "group", "lane": lane, "op": "hold"})))
		cmd_box.add_child(_mk_btn("Beni takip et", func(): _cmd({"type": "group", "lane": lane, "op": "follow"})))
		cmd_box.add_child(_mk_btn("Saldırgan (Q)", func(): _stance("agg")))
		cmd_box.add_child(_mk_btn("Savunmacı (W)", func(): _stance("def")))
		cmd_box.add_child(_mk_btn("Pusu (E)", func(): _stance("pusu")))
	elif sel["type"] == "tower":
		var id: int = sel["id"]
		cmd_box.add_child(_mk_btn("Canı az olan", func(): _cmd({"type": "tower", "tower": id, "val": "low"})))
		cmd_box.add_child(_mk_btn("Canı çok olan", func(): _cmd({"type": "tower", "tower": id, "val": "high"})))
		cmd_box.add_child(_mk_btn("Bana saldıranı koru", func(): _cmd({"type": "tower", "tower": id, "val": "protect"})))
		cmd_box.add_child(_mk_btn("Akıllı (varsayılan)", func(): _cmd({"type": "tower", "tower": id, "val": "smart"})))
	for c in [["Üst yol grubu", 0], ["Alt yol grubu", 1]]:
		cmd_box.add_child(_mk_btn(c[0], func(): _select_lane(c[1])))

func _select_lane(l: int) -> void:
	sel = {"type": "lane", "lane": l}
	_rebuild_cmds()

func _need_target(op: Dictionary) -> void:
	pending = op
	_flash("Haritada hedef noktaya tıkla")

func _stance(v: String) -> void:
	if sel != null and sel["type"] == "lane":
		_cmd({"type": "group", "lane": sel["lane"], "op": "stance", "val": v})
	else:
		_flash("Önce bir grup seç")

func _cmd(c: Dictionary) -> void:
	if w == null or w.winner >= 0:
		return
	if queue_mode and c["type"] != "clear":
		c["queue"] = true
	if not w.issue(player, c):
		_flash("Emir verilemedi (kuyruk dolu ya da şu an uygun değil)")

func _flash(t: String) -> void:
	lbl_msg.text = t
	msg_t = 2.0

func _on_heal() -> void: _cmd({"type": "heal"})
func _on_retreat() -> void: _cmd({"type": "retreat"})
func _on_hyp() -> void:
	pending = {"op": "hypogeum"}
	_flash("Çıkış yapılarına tıkla (kendi specula/Ludus)")
func _on_munus() -> void:
	w.issue(player, {"type": "munus"})
	_flash("Munus: Favor doluysa kullanılır")
func _on_swap() -> void:
	if not w.issue(player, {"type": "swap"}):
		_flash("Değişim: Ludus'ta ve yedek hazırken")
func _on_auto() -> void:
	var on: bool = not w.teams[player]["auto"]
	w.issue(player, {"type": "auto", "on": on})
	btns["auto"].text = "Oto: açık" if on else "Oto: kapalı"
func _on_queue() -> void:
	queue_mode = not queue_mode
	btns["queue"].text = "Plan: açık" if queue_mode else "Plan: kapalı"
func _on_shop() -> void:
	shop_panel.visible = not shop_panel.visible

# ---------- girdi ----------
func _screen_to_world(p: Vector2) -> Vector2:
	return p + cam

func _unhandled_input(ev: InputEvent) -> void:
	if w == null:
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = mb.pressed
			_drag_from = mb.position
			_cam_start = cam
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_map_click(_screen_to_world(mb.position))
	elif ev is InputEventMouseMotion and _drag:
		cam = _cam_start - ((ev as InputEventMouseMotion).position - _drag_from)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_Q: _stance("agg")
			KEY_W: _stance("def")
			KEY_E: _stance("pusu")
			KEY_D: _on_heal()
			KEY_F: _on_hyp()
			KEY_B: _on_retreat()
			KEY_P: paused = not paused
			KEY_EQUAL, KEY_KP_ADD: speed = minf(4.0, speed * 2.0)
			KEY_MINUS, KEY_KP_SUBTRACT: speed = maxf(0.25, speed * 0.5)
			KEY_SPACE:
				var g = w.teams[player]["glads"][w.teams[player]["active"]]
				cam = g.pos - Vector2(640, 360)
			KEY_1: _select_lane(0)
			KEY_2: _select_lane(1)
			KEY_ESCAPE:
				pending = null
				sel = null
				_rebuild_cmds()

func _nearest_own(p: Vector2, struct_only: bool) -> Variant:
	var best = null
	var bd: float = 70.0
	for e in w.ents:
		if e.alive and e.team == player and e.kind != "glad" and (not struct_only or e.is_structure()):
			var d: float = e.pos.distance_to(p)
			if d < bd:
				bd = d
				best = e
	return best

func _map_click(p: Vector2) -> void:
	if pending != null:
		var op: Dictionary = pending
		pending = null
		if op["op"] == "advance":
			if sel == null or sel["type"] != "lane":
				return
			var lane: int = op["lane"]
			_cmd({"type": "group", "lane": lane, "op": "advance", "val": w.lane_proj(lane, p)})
		elif op["op"] == "hypogeum":
			var s = _nearest_own(p, true)
			if s != null:
				_cmd({"type": "hypogeum", "dest": s.id})
		return
	var e = _nearest_own(p, false)
	if e == null:
		sel = null
	elif e.is_structure():
		sel = {"type": "tower", "id": e.id} if e.kind == "tower" else {"type": "ludus", "id": e.id}
	else:
		sel = {"type": "lane", "lane": e.lane}
	_rebuild_cmds()

func _minimap_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var wsz: Vector2 = Vector2(float(data["cfg"]["world"]["w"]), float(data["cfg"]["world"]["h"]))
		var f: Vector2 = ev.position / minimap.size
		cam = f * wsz - Vector2(640, 360)

# ---------- döngü ----------
func _process(delta: float) -> void:
	if w == null:
		return
	var mv := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	cam += mv * 900.0 * delta
	var wsz := Vector2(float(data["cfg"]["world"]["w"]), float(data["cfg"]["world"]["h"]))
	cam = cam.clamp(Vector2(-200, -100), wsz - Vector2(1080, 620))
	if not paused and w.winner < 0:
		acc += delta * speed
		var n: int = 0
		while acc >= w.dt and n < 8:
			acc -= w.dt
			ai.think(w)
			w.step()
			n += 1
		if n == 8:
			acc = 0.0
	if w.winner >= 0 and over_text == "":
		over_text = "ZAFER — rakip Ludus yıkıldı" if w.winner == player else "YENİLGİ — Ludus'un yıkıldı"
	fog_t -= delta
	if fog_t <= 0.0:
		fog_t = 0.2
		_update_fog()
	msg_t -= delta
	if msg_t <= 0.0 and lbl_msg != null:
		lbl_msg.text = ""
	_update_hud()
	queue_redraw()
	if minimap != null:
		minimap.queue_redraw()

func _update_fog() -> void:
	fog_vis.resize(fw * fh)
	fog_vis.fill(0)
	for e in w.ents:
		if e.alive and e.team == player:
			var r: float = e.sight
			var c0 := Vector2i(maxi(0, int((e.pos.x - r) / FOG_CELL)), maxi(0, int((e.pos.y - r) / FOG_CELL)))
			var c1 := Vector2i(mini(fw - 1, int((e.pos.x + r) / FOG_CELL)), mini(fh - 1, int((e.pos.y + r) / FOG_CELL)))
			for cx in range(c0.x, c1.x + 1):
				for cy in range(c0.y, c1.y + 1):
					var cp := Vector2((cx + 0.5) * FOG_CELL, (cy + 0.5) * FOG_CELL)
					if cp.distance_to(e.pos) <= r:
						fog_vis[cy * fw + cx] = 1

func _update_hud() -> void:
	var ts = w.teams[player]
	var g = ts["glads"][ts["active"]]
	var other = ts["glads"][1 - ts["active"]]
	lbl_top.text = "Süre %d:%02d   Altın %d   | %s  Can %d/%d  Favor %d%%  Niyet: %s  Yedek: %s (%s)  | Hız x%s%s" % [
		int(w.time) / 60, int(w.time) % 60, int(ts["gold"]), g.label, int(g.hp), int(g.max_hp), int(g.g["favor"]),
		g.g["intent"] if g.alive else "ölü", other.label, other.g["mode"], str(speed), "  DURAKLADI" if paused else ""]
	var s := ""
	if sel != null:
		match sel["type"]:
			"lane":
				var mem: Array = w.group_members(player, sel["lane"])
				s = "%s manipuli\nBirim: %d\nDuruş: %s\nHedef: %s" % [w.cfg["lanes"][sel["lane"]]["name"], mem.size(), STANCE_NAME[ts["stance"][sel["lane"]]], "takip" if ts["follow"][sel["lane"]] else ("var" if ts["goal"][sel["lane"]] != null else "yol sonu")]
			"tower", "ludus":
				var e = w.by_id[sel["id"]]
				s = "%s\nCan %d/%d  Zırh %d\nÖncelik: %s" % [e.label, int(e.hp), int(e.max_hp), int(e.armor), ts["tower_prio"].get(e.id, "akıllı")]
	else:
		s = "Gladyatör: %s\nİtemler: %s\nStatlar: Atk %d  Zırh %d  Hız %d" % [g.label, ", ".join(PackedStringArray(g.g["items"].map(func(i): return data["items"][i]["name"]))), int(g.atk), int(g.armor), int(g.ms)]
		s += "\nSıradaki alım: " + _next_buy(ts, ts["active"])
	if over_text != "":
		s = over_text + "\n" + s
	lbl_info.text = s
	var pl := ""
	var i: int = 1
	for o in ts["orders"]:
		pl += "%d) %s  " % [i, _order_text(o)]
		i += 1
	lbl_plan.text = ("Emir sırası: " + pl) if pl != "" else ("Plan modu açık — emirler sıraya girer (%d/%d)" % [ts["orders"].size(), w.max_plan(player)] if queue_mode else "Emir yok (Oto)")

func _next_buy(ts: Dictionary, gi: int) -> String:
	var gg = ts["glads"][gi]
	for id in ts["plan"][gi]:
		if not gg.g["bought"].has(id):
			return "%s (%d)" % [data["items"][id]["name"], int(Glad.quote(w, gg, id)["cost"])]
	return "—"

func _order_text(o: Dictionary) -> String:
	match o["type"]:
		"group": return "Grup %s %s" % [o["lane"], o["op"]]
		"tower": return "Specula öncelik %s" % o["val"]
		"retreat": return "Geri çekil"
		"heal": return "İyileş"
		"hypogeum": return "Hypogeum"
	return o["type"]

# ---------- çizim ----------
func _draw() -> void:
	if w == null:
		draw_rect(Rect2(0, 0, 1280, 720), COL_BG)
		return
	draw_set_transform(-cam)
	var wsz := Vector2(float(data["cfg"]["world"]["w"]), float(data["cfg"]["world"]["h"]))
	draw_rect(Rect2(Vector2.ZERO, wsz), COL_SAND)
	for l in w.lane_pts.size():
		draw_polyline(w.lane_pts[l], COL_LANE, 90.0, true)
	for c in w.cover:
		draw_circle(c["pos"], c["r"], COL_COVER)
		draw_arc(c["pos"], c["r"], 0, TAU, 24, Color("5b6b3a"), 3.0)
	_draw_structures()
	_draw_units()
	_draw_fog()
	if sel != null:
		_draw_selection()
	if pending != null:
		draw_set_transform(Vector2.ZERO)
		draw_string(font, Vector2(500, 90), "HEDEF SEÇ…", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

func _stage_marks(e) -> void:
	var f: float = e.hp / e.max_hp
	if f < 0.75:
		draw_line(e.pos + Vector2(-8, -10), e.pos + Vector2(4, 4), Color(0, 0, 0, 0.7), 2.0)
	if f < 0.5:
		draw_circle(e.pos + Vector2(10, -22), 9, Color(0.4, 0.4, 0.4, 0.6))
		draw_circle(e.pos + Vector2(2, -34), 7, Color(0.5, 0.5, 0.5, 0.45))
	if f < 0.25:
		draw_circle(e.pos + Vector2(-8, -6), 8, Color(1.0, 0.5, 0.1, 0.8))

func _draw_structures() -> void:
	for e in w.ents:
		if not e.is_structure():
			continue
		var col: Color = COL_T[e.team]
		if e.team == player or w.is_visible(player, e):
			if not e.alive:
				draw_circle(e.pos, e.radius * 0.9, Color(0.15, 0.12, 0.1))
				continue
			if e.kind == "tower":
				draw_rect(Rect2(e.pos - Vector2(e.radius * 0.8, e.radius * 0.8), Vector2(e.radius * 1.6, e.radius * 1.6)), col)
				draw_rect(Rect2(e.pos - Vector2(e.radius * 0.8, e.radius * 0.8), Vector2(e.radius * 1.6, e.radius * 1.6)), Color.WHITE if e.t["outer"] else Color("bbbbbb"), false, 3.0)
			else:
				draw_circle(e.pos, e.radius, col)
				draw_arc(e.pos, e.radius, 0, TAU, 32, Color("e7d9a8"), 4.0)
			_stage_marks(e)
			_hpbar(e, e.radius * 2.0)
			if e.t.get("target", -1) >= 0 and w.time - e.last_attacked_at < 0.4:
				var tg = w.by_id.get(e.t["target"], null)
				if tg != null and tg.alive:
					draw_line(e.pos, tg.pos, Color(1, 0.9, 0.4, 0.8), 2.0)
		else:
			var rec = w.seen[player].get(e.id, null)
			if rec == null:
				continue
			var dead: bool = not rec["alive"]
			var c2 := Color(col, 0.35)
			if dead:
				draw_circle(e.pos, e.radius * 0.9, Color(0.15, 0.12, 0.1))
			elif e.kind == "tower":
				draw_rect(Rect2(e.pos - Vector2(e.radius * 0.8, e.radius * 0.8), Vector2(e.radius * 1.6, e.radius * 1.6)), c2)
			else:
				draw_circle(e.pos, e.radius, c2)

func _hpbar(e, wd: float) -> void:
	var f: float = clampf(e.hp / e.max_hp, 0.0, 1.0)
	var p: Vector2 = e.pos + Vector2(-wd * 0.5, -e.radius - 12.0)
	draw_rect(Rect2(p, Vector2(wd, 5)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(p, Vector2(wd * f, 5)), Color("6fcf5a") if e.team == player else Color("e0603f"))

func _draw_units() -> void:
	for e in w.ents:
		if e.is_structure() or not e.alive:
			continue
		if e.kind == "glad" and (e.g["mode"] == "tunnel" or e.g["mode"] == "bench"):
			continue
		if e.team != player and not w.is_visible(player, e):
			continue
		var col: Color = COL_T[e.team]
		var a: float = 0.45 if e.hidden else 1.0
		match e.kind:
			"aux": draw_circle(e.pos, 7, Color(col, a))
			"sag": draw_colored_polygon(PackedVector2Array([e.pos + Vector2(0, -8), e.pos + Vector2(7, 6), e.pos + Vector2(-7, 6)]), Color(col, a))
			"bal": draw_rect(Rect2(e.pos - Vector2(9, 9), Vector2(18, 18)), Color(col, a))
			"glad":
				draw_circle(e.pos, e.radius, COL_CLS[e.g["cls"]])
				draw_arc(e.pos, e.radius + 2, 0, TAU, 24, col, 4.0)
				draw_line(e.pos, e.pos + e.facing * (e.radius + 8), Color.WHITE, 3.0)
				draw_string(font, e.pos + Vector2(-5, 5), String(e.label).substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
				if e.team == player or true:
					draw_string(font, e.pos + Vector2(-30, -e.radius - 18), e.g["intent"], HORIZONTAL_ALIGNMENT_LEFT, 120, 11, Color(1, 1, 1, 0.9))
				var st := ""
				if e.has_status("stun", w.time): st += "S"
				if e.has_status("slow", w.time): st += "Y"
				if e.has_status("root", w.time): st += "K"
				if e.status.has("bleed"): st += "B"
				if e.g["cls"] == "secutor" and e.g["heat"] > 60.0: st += "H"
				if st != "":
					draw_string(font, e.pos + Vector2(-8, e.radius + 14), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffd34d"))
		if e.hp < e.max_hp or e.kind == "glad":
			_hpbar(e, e.radius * 2.0 if e.kind == "glad" else 18.0)
		# hedef ikonu sağ üstte
		var tg = w.by_id.get(e.target, null) if e.kind != "glad" else null
		if e.kind == "glad":
			tg = _glad_target(e)
		if tg != null and tg.alive and w.time - e.last_attacked_at < 0.6 and (e.team == player or w.is_visible(player, tg)):
			var q: Vector2 = e.pos + Vector2(e.radius + 6, -e.radius - 6)
			draw_circle(q, 6, Color("1b1b1b"))
			draw_arc(q, 6, 0, TAU, 12, Color("ffd34d"), 2.0)
			draw_string(font, q + Vector2(-3, 4), _glyph(tg), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ffd34d"))

func _glyph(e) -> String:
	match e.kind:
		"glad": return "G"
		"tower": return "S"
		"ludus": return "L"
		"aux": return "a"
		"sag": return "s"
		"bal": return "b"
	return "?"

func _glad_target(e):
	var best = null
	var bd: float = INF
	for o in w.near(e.pos, e.rng + 40.0):
		if o.team != e.team and o.alive and o.pos.distance_to(e.pos) < bd:
			bd = o.pos.distance_to(e.pos)
			best = o
	return best

func _draw_fog() -> void:
	for cx in fw:
		for cy in fh:
			if fog_vis.size() > 0 and fog_vis[cy * fw + cx] == 0:
				draw_rect(Rect2(cx * FOG_CELL, cy * FOG_CELL, FOG_CELL, FOG_CELL), Color(0.05, 0.04, 0.08, 0.5))

func _draw_selection() -> void:
	match sel["type"]:
		"lane":
			for m in w.group_members(player, sel["lane"]):
				draw_arc(m.pos, 11, 0, TAU, 16, Color("ffe27a"), 2.0)
			var gl = w.teams[player]["goal"][sel["lane"]]
			if gl != null:
				draw_circle(w.lane_pos(sel["lane"], float(gl)), 10, Color("ffe27a"))
		"tower", "ludus":
			var e = w.by_id[sel["id"]]
			draw_arc(e.pos, e.radius + 8, 0, TAU, 32, Color("ffe27a"), 3.0)
			if e.kind == "tower":
				draw_arc(e.pos, e.rng, 0, TAU, 48, Color(1, 1, 1, 0.25), 1.5)

func _draw_minimap() -> void:
	var sz: Vector2 = minimap.size
	var wsz := Vector2(float(data["cfg"]["world"]["w"]), float(data["cfg"]["world"]["h"]))
	var k: Vector2 = sz / wsz
	minimap.draw_rect(Rect2(Vector2.ZERO, sz), Color("1d1711"))
	for l in w.lane_pts.size():
		var pts := PackedVector2Array()
		for p in w.lane_pts[l]:
			pts.append(p * k)
		minimap.draw_polyline(pts, COL_LANE, 5.0)
	for e in w.ents:
		if not e.alive:
			continue
		if e.is_structure():
			if e.team == player or w.is_visible(player, e) or (w.seen[player].has(e.id) and w.seen[player][e.id]["alive"]):
				minimap.draw_rect(Rect2(e.pos * k - Vector2(3, 3), Vector2(6, 6)), COL_T[e.team] if (e.team == player or w.is_visible(player, e)) else Color(COL_T[e.team], 0.4))
				if e.team == player and w.time - e.last_damaged_at < 2.0:
					minimap.draw_arc(e.pos * k, 8, 0, TAU, 12, Color.RED, 2.0)
		elif e.team == player or w.is_visible(player, e):
			minimap.draw_circle(e.pos * k, 2.5 if e.kind == "glad" else 1.2, COL_T[e.team])
	minimap.draw_rect(Rect2(cam * k, Vector2(1280, 720) * k), Color.WHITE, false, 1.5)
