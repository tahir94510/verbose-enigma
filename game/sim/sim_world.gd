extends RefCounted
## Deterministik simülasyon çekirdeği. Sahne/çizimden bağımsız: aynı tohum + aynı komutlar = aynı sonuç.

const Ent = preload("res://sim/ent.gd")
const Glad = preload("res://sim/glad.gd")

var cfg: Dictionary
var gdefs: Dictionary
var items: Dictionary
var dt: float = 0.1
var time: float = 0.0
var rng := RandomNumberGenerator.new()
var ents: Array = []
var by_id: Dictionary = {}
var next_id: int = 1
var teams: Array = [{}, {}]
var lane_pts: Array = []
var lane_cum: Array = []
var winner: int = -1
var events: Array = []
var record_events: bool = false
var grid: Dictionary = {}
var seen: Array = [{}, {}]            # takım -> yapı id -> son görülen kayıt
var _vis_cache: Array = [{}, {}]
var _next_wave: float = 0.0
var _next_passive: float = 0.0
var wave_n: int = 0
var stats: Dictionary = {"gold_income": [0.0, 0.0], "first_tower": -1}
var cover: Array = []

func _init(data: Dictionary, seed_: int, pairs: Array) -> void:
	cfg = data["cfg"]
	gdefs = data["glads"]
	items = data["items"]
	dt = float(cfg["dt"])
	rng.seed = seed_
	for l in cfg["lanes"]:
		var pts := PackedVector2Array()
		var cum: Array = [0.0]
		for p in l["pts"]:
			pts.append(Vector2(p[0], p[1]))
		for i in range(1, pts.size()):
			cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
		lane_pts.append(pts)
		lane_cum.append(cum)
	for c in cfg["cover"]:
		cover.append({"pos": Vector2(c[0], c[1]), "r": float(c[2])})
	_next_wave = float(cfg["wave"]["first"])
	_next_passive = float(cfg["economy"]["passive_from"])
	for t in 2:
		_setup_team(t, pairs[t])

# ---------- kurulum ----------
func _new_ent(kind: String, team: int, pos: Vector2) -> Ent:
	var e := Ent.new()
	e.id = next_id
	next_id += 1
	e.kind = kind
	e.team = team
	e.pos = pos
	ents.append(e)
	by_id[e.id] = e
	return e

func _setup_team(t: int, pair: Array) -> void:
	var lc: Dictionary = cfg["ludus"]
	var ludus := _new_ent("ludus", t, lane_pos(0, 0.0 if t == 0 else lane_len(0)))
	ludus.max_hp = float(lc["hp"]); ludus.hp = ludus.max_hp
	ludus.atk = float(lc["atk"]); ludus.armor = float(lc["armor"])
	ludus.rng = float(lc["range"]); ludus.sight = float(lc["sight"]); ludus.radius = float(lc["radius"])
	ludus.label = "Ludus"
	ludus.t = {"cd": 0.0, "target": -1, "ramp": 0}
	var ts := {
		"gold": float(cfg["economy"]["start_gold"]), "pair": pair, "glads": [], "active": 0,
		"auto": true, "orders": [], "stance": ["agg", "agg"], "goal": [null, null], "follow": [false, false],
		"tower_prio": {}, "rules": {"hp_return": 0.35, "gold_return": 0.0}, "plan": [[], []],
		"ludus": ludus.id, "towers": [], "munus_auto": true, "munus_fire": false,
		"swap_ready": 0.0, "heal_cd": 0.0, "field_empty_since": -100.0,
		"ambush_until": [0.0, 0.0], "focus_lane": 0, "kills": 0, "first_tower_taken": false,
		"cmd_count": 0, "extra_plan": 0, "extra_rules": 0, "extra_cmd_range": 0.0, "heal_bonus": 0.0
	}
	teams[t] = ts
	for lane in 2:
		for kind in ["inner", "outer"]:
			var s_own: float = float(cfg["tower_s"][kind])
			var tc: Dictionary = cfg["tower"][kind]
			var s_abs: float = s_own if t == 0 else lane_len(lane) - s_own
			var tw := _new_ent("tower", t, lane_pos(lane, s_abs))
			tw.lane = lane
			tw.max_hp = float(tc["hp"]); tw.hp = tw.max_hp
			tw.atk = float(tc["atk"]); tw.armor = float(tc["armor"])
			tw.rng = float(cfg["tower"]["range"]); tw.sight = float(cfg["tower"]["sight"])
			tw.radius = float(cfg["tower"]["radius"])
			tw.label = "%s %s" % [cfg["lanes"][lane]["name"], "dış" if kind == "outer" else "iç"]
			tw.t = {"outer": kind == "outer", "cd": 0.0, "target": -1, "ramp": 0, "s": s_abs, "gold": float(tc["gold"])}
			ts["towers"].append(tw.id)
			ts["tower_prio"][tw.id] = "smart"
	for i in 2:
		var g = Glad.make(self, t, pair[i], i)
		ts["glads"].append(g)
	Glad.spawn(self, ts["glads"][0], true)

# ---------- geometri ----------
func lane_len(l: int) -> float:
	return lane_cum[l][lane_cum[l].size() - 1]

func lane_pos(l: int, s: float) -> Vector2:
	var pts: PackedVector2Array = lane_pts[l]
	var cum: Array = lane_cum[l]
	s = clampf(s, 0.0, float(cum[cum.size() - 1]))
	for i in range(1, pts.size()):
		if s <= cum[i]:
			var seg: float = cum[i] - cum[i - 1]
			var f: float = 0.0 if seg <= 0.0 else (s - cum[i - 1]) / seg
			return pts[i - 1].lerp(pts[i], f)
	return pts[pts.size() - 1]

func lane_proj(l: int, p: Vector2) -> float:
	var pts: PackedVector2Array = lane_pts[l]
	var cum: Array = lane_cum[l]
	var best_d: float = INF
	var best_s: float = 0.0
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var ab: Vector2 = b - a
		var f: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var q: Vector2 = a + ab * f
		var d: float = p.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best_s = cum[i - 1] + f * ab.length()
	return best_s

func dir_of(team: int) -> float:
	return 1.0 if team == 0 else -1.0

func own_s(team: int, lane: int, abs_s: float) -> float:   # kendi üssünden uzaklık
	return abs_s if team == 0 else lane_len(lane) - abs_s

func abs_s(team: int, lane: int, own: float) -> float:
	return own if team == 0 else lane_len(lane) - own

func ludus(team: int) -> Ent:
	return by_id[teams[team]["ludus"]]

func in_cover(p: Vector2) -> bool:
	for c in cover:
		if p.distance_to(c["pos"]) <= c["r"]:
			return true
	return false

# ---------- uzamsal sorgu ----------
func _rebuild_grid() -> void:
	grid.clear()
	for e in ents:
		if e.alive and not (e.kind == "glad" and e.g["mode"] == "tunnel"):
			var key := Vector2i(int(e.pos.x / 200.0), int(e.pos.y / 200.0))
			if not grid.has(key):
				grid[key] = []
			grid[key].append(e)

func near(p: Vector2, r: float) -> Array:
	var out: Array = []
	var c0 := Vector2i(int((p.x - r) / 200.0), int((p.y - r) / 200.0))
	var c1 := Vector2i(int((p.x + r) / 200.0), int((p.y + r) / 200.0))
	for cx in range(c0.x, c1.x + 1):
		for cy in range(c0.y, c1.y + 1):
			var key := Vector2i(cx, cy)
			if grid.has(key):
				for e in grid[key]:
					if e.alive and e.pos.distance_to(p) <= r:
						out.append(e)
	return out

func is_visible(team: int, e: Ent) -> bool:
	if e.team == team or not e.alive:
		return true
	var cache: Dictionary = _vis_cache[team]
	if cache.has(e.id):
		return cache[e.id]
	var res: bool = false
	for v in near(e.pos, 520.0):
		if v.team == team and v.alive:
			var d: float = v.pos.distance_to(e.pos)
			if d <= v.sight and (not e.hidden or d <= 120.0):
				res = true
				break
	cache[e.id] = res
	return res

# ---------- ana adım ----------
func step() -> void:
	if winner >= 0:
		return
	time += dt
	_vis_cache = [{}, {}]
	_rebuild_grid()
	_economy()
	_waves()
	for t in 2:
		_team_update(t)
	for e in ents.duplicate():
		if not e.alive:
			continue
		e.atk_cd = maxf(0.0, e.atk_cd - dt)
		match e.kind:
			"glad": Glad.update(self, e)
			"aux", "sag", "bal": _unit_update(e)
			"tower", "ludus": _structure_update(e)
	_update_seen()
	for t in 2:
		if not by_id[teams[t]["ludus"]].alive:
			winner = 1 - t

func run(max_seconds: float) -> void:
	while winner < 0 and time < max_seconds:
		step()

func _economy() -> void:
	var ec: Dictionary = cfg["economy"]
	if time + 1e-6 >= _next_passive:
		_next_passive += float(ec["passive_every"])
		for t in 2:
			add_gold(t, float(ec["passive_amount"]))

func add_gold(t: int, amount: float) -> void:
	teams[t]["gold"] += amount
	stats["gold_income"][t] += amount

func _waves() -> void:
	if time < _next_wave:
		return
	_next_wave += float(cfg["wave"]["every"])
	wave_n += 1
	var wc: Dictionary = cfg["wave"]
	for t in 2:
		for lane in 2:
			var list: Array = []
			for i in int(wc["aux"]): list.append("aux")
			for i in int(wc["sag"]): list.append("sag")
			for i in int(wave_n / int(wc["extra_aux_every"])): list.append("aux")
			if wave_n % int(wc["balista_every"]) == 0: list.append("bal")
			var n: int = 0
			for kind in list:
				var u: Dictionary = cfg["units"][kind]
				var s_here: float = abs_s(t, lane, 70.0 + n * 22.0)
				var e := _new_ent(kind, t, lane_pos(lane, s_here))
				e.lane = lane
				var sc: float = 1.0 + float(wc["scale_per_min"]) * (time / 60.0)
				e.max_hp = float(u["hp"]) * sc; e.hp = e.max_hp
				e.atk = float(u["atk"]) * sc; e.armor = float(u["armor"]); e.aspd = float(u["aspd"])
				e.ms = float(u["ms"]); e.rng = float(u["range"]); e.sight = float(u["sight"])
				e.ranged = bool(u["ranged"]); e.radius = 9.0
				e.label = kind
				n += 1

func _team_update(t: int) -> void:
	var ts: Dictionary = teams[t]
	ts["heal_cd"] = maxf(0.0, ts["heal_cd"] - dt)
	var field_alive: bool = false
	for g in ts["glads"]:
		if g.g["mode"] == "dead" and time >= g.g["respawn_at"]:
			g.g["mode"] = "bench"
		if g.alive:
			field_alive = true
	var lud: Ent = ludus(t)
	# yedek/ikinci gladyatör Ludus'ta iyileşir
	for g in ts["glads"]:
		if g.g["mode"] == "bench" and lud.alive:
			g.hp = minf(g.max_hp, g.hp + g.max_hp * float(cfg["ludus"]["heal_pct"]) * dt)
	if not field_alive:
		if ts["field_empty_since"] < 0.0:
			ts["field_empty_since"] = time
		if time - ts["field_empty_since"] >= float(cfg["respawn"]["reserve_delay"]):
			for i in 2:
				var g: Ent = ts["glads"][i]
				if g.g["mode"] == "bench":
					ts["active"] = i
					Glad.spawn(self, g, false)
					break
	else:
		ts["field_empty_since"] = -100.0
	Glad.team_shop(self, t)

func _structure_update(e: Ent) -> void:
	var is_tower: bool = e.kind == "tower"
	var period: float = float(cfg["tower"]["period"]) if is_tower else float(cfg["ludus"]["period"])
	# Ludus yapıyı çok yavaş yeniler (kuleler yenilenmez)
	if not is_tower:
		e.hp = minf(e.max_hp, e.hp + e.max_hp * float(cfg["ludus"]["regen_pct"]) * dt)
	var tgt: Ent = by_id.get(e.t["target"], null)
	if tgt == null or not tgt.alive or tgt.pos.distance_to(e.pos) > e.rng + tgt.radius or (tgt.hidden and tgt.pos.distance_to(e.pos) > 120.0):
		tgt = null
		e.t["target"] = -1
		e.t["ramp"] = 0
	var prio: String = teams[e.team]["tower_prio"].get(e.id, "smart") if is_tower else "smart"
	var cand_best: Ent = _tower_pick(e, prio)
	if cand_best != null and (tgt == null or cand_best.id != tgt.id and _tower_should_switch(e, tgt, cand_best, prio)):
		if tgt == null or cand_best.id != tgt.id:
			e.t["ramp"] = 0
		tgt = cand_best
		e.t["target"] = tgt.id
	if tgt == null or e.atk_cd > 0.0:
		return
	e.atk_cd = period
	var ramp: int = int(e.t["ramp"])
	var mult: float = 1.0 + float(cfg["tower"]["ramp_step"]) * minf(float(ramp), float(cfg["tower"]["ramp_max"]))
	e.t["ramp"] = ramp + 1
	e.last_attacked_at = time
	deal(e, tgt, e.atk * mult, "tower")

func _tower_should_switch(e: Ent, cur: Ent, cand: Ent, prio: String) -> bool:
	# LoL kuralı: menzilde müttefik gladyatöre vuran düşman gladyatör varsa hemen ona dön
	if cand.kind == "glad" and cand.g.get("hit_ally_until", 0.0) > time and cur.kind != "glad":
		return true
	if prio == "protect" and cand.kind == "glad":
		return cur.kind != "glad"
	return false

func _tower_pick(e: Ent, prio: String) -> Ent:
	var cands: Array = []
	for o in near(e.pos, e.rng + 30.0):
		if o.team != e.team and o.alive and not o.is_structure() and o.pos.distance_to(e.pos) <= e.rng + o.radius:
			if o.hidden and o.pos.distance_to(e.pos) > 120.0:
				continue
			cands.append(o)
	if cands.is_empty():
		return null
	# müttefik gladyatöre vuran düşman gladyatör en önde
	for o in cands:
		if o.kind == "glad" and o.g.get("hit_ally_until", 0.0) > time:
			return o
	var best: Ent = null
	var bs: float = INF
	for o in cands:
		var score: float = e.pos.distance_to(o.pos)
		match prio:
			"low": score = o.hp
			"high": score = -o.hp
			"protect":
				score = e.pos.distance_to(o.pos) - (400.0 if o.kind == "glad" else 0.0)
			_:
				score += 0.0 if o.kind != "glad" else 1000.0   # varsayılan: önce birimler
		if score < bs:
			bs = score
			best = o
	return best

func _unit_update(e: Ent) -> void:
	_tick_status(e)
	if e.has_status("stun", time):
		return
	var ts: Dictionary = teams[e.team]
	var lane: int = e.lane
	# hedef
	var tgt: Ent = by_id.get(e.target, null)
	var aggro: float = float(cfg["unit_aggro"])
	var ambushed: bool = ts["stance"][lane] == "pusu" and time > ts["ambush_until"][lane]
	if tgt != null and (not tgt.alive or tgt.pos.distance_to(e.pos) > aggro * 1.6 or (tgt.hidden and tgt.pos.distance_to(e.pos) > 120.0)):
		tgt = null
		e.target = -1
	if tgt == null:
		tgt = _unit_find(e, aggro, ambushed)
		e.target = tgt.id if tgt != null else -1
	# pusu: örtüde gizlen, düşman çok yakınsa açığa çık
	if ambushed:
		if tgt != null and tgt.pos.distance_to(e.pos) <= 120.0:
			ts["ambush_until"][lane] = time + 6.0
			ambushed = false
		else:
			tgt = null
	e.hidden = ambushed and in_cover(e.pos) and time - e.last_attacked_at > 1.5
	if tgt != null:
		var d: float = e.pos.distance_to(tgt.pos)
		if d <= e.rng + tgt.radius:
			e.facing = (tgt.pos - e.pos).normalized()
			if e.atk_cd <= 0.0:
				e.atk_cd = 1.0 / maxf(0.1, e.aspd)
				e.last_attacked_at = time
				e.hidden = false
				deal(e, tgt, e.atk, "attack")
		else:
			_move_to(e, tgt.pos)
		return
	# hat boyunca ilerle
	var goal: float = _group_goal(e.team, lane)
	var s_now: float = lane_proj(lane, e.pos)
	if ambushed:
		goal = _cover_goal(e, s_now)
	if absf(goal - s_now) > 12.0:
		var step_s: float = s_now + signf(goal - s_now) * 90.0
		_move_to(e, lane_pos(lane, step_s))

func _cover_goal(e: Ent, s_now: float) -> float:
	# en yakın örtü bölgesinin hat üzerindeki izdüşümü
	var best: float = s_now
	var bd: float = INF
	for c in cover:
		var sc: float = lane_proj(e.lane, c["pos"])
		if lane_pos(e.lane, sc).distance_to(c["pos"]) < c["r"]:
			var d: float = absf(sc - s_now)
			if d < bd:
				bd = d
				best = sc
	return best

func _group_goal(team: int, lane: int) -> float:
	var ts: Dictionary = teams[team]
	if ts["follow"][lane]:
		var g: Ent = ts["glads"][ts["active"]]
		if g.alive:
			return lane_proj(lane, g.pos)
	var v = ts["goal"][lane]
	if v != null:
		return float(v)
	return lane_len(lane) if team == 0 else 0.0

func _unit_find(e: Ent, aggro: float, passive: bool) -> Ent:
	var best: Ent = null
	var bd: float = INF
	for o in near(e.pos, aggro):
		if o.team == e.team or not o.alive or o.is_structure():
			continue
		if o.hidden and o.pos.distance_to(e.pos) > 120.0:
			continue
		if passive and o.pos.distance_to(e.pos) > 120.0:
			continue
		var d: float = o.pos.distance_to(e.pos)
		if d < bd:
			bd = d
			best = o
	if best != null:
		return best
	for o in near(e.pos, e.rng + 70.0):
		if o.team != e.team and o.alive and o.is_structure() and o.pos.distance_to(e.pos) <= e.rng + o.radius + 10.0:
			return o
	return null

func _move_to(e: Ent, p: Vector2) -> void:
	var v: Vector2 = p - e.pos
	var dist: float = v.length()
	if dist < 0.5:
		return
	e.facing = v / dist
	var sp: float = eff_ms(e)
	e.pos += e.facing * minf(dist, sp * dt)

func eff_ms(e: Ent) -> float:
	if e.has_status("stun", time) or e.has_status("root", time):
		return 0.0
	var m: float = e.ms * e.status_val("slow", time, 1.0) * e.status_val("haste", time, 1.0)
	if e.kind != "glad" and e.lane >= 0 and teams[e.team]["stance"][e.lane] == "def":
		m *= float(cfg["stance"]["testudo_ms"])
	return m

func _tick_status(e: Ent) -> void:
	if e.status.is_empty():
		return
	for k in e.status.keys():
		if e.status[k]["until"] <= time:
			e.status.erase(k)
	if e.status.has("bleed"):
		var b: Dictionary = e.status["bleed"]
		var src: Ent = by_id.get(int(b.get("src", -1)), null)
		deal(src, e, float(b["v"]) * dt, "dot")

# ---------- hasar / ölüm ----------
func deal(src: Ent, dst: Ent, raw: float, tag: String) -> float:
	if not dst.alive or winner >= 0:
		return 0.0
	var arm: float = dst.armor + dst.status_val("armor_up", time, 0.0)
	var dmg: float = raw * 100.0 / (100.0 + maxf(arm, 0.0))
	if tag == "dot":
		dmg = raw
	if dst.kind == "glad":
		dmg *= dst.status_val("untouchable", time, 1.0)
		if dst.g["cls"] == "murmillo" and src != null:
			var dirv: Vector2 = (src.pos - dst.pos).normalized()
			var dot: float = dst.facing.dot(dirv)
			if dot > 0.2: dmg *= 0.8
			elif dot < -0.2: dmg *= 1.25
	elif not dst.is_structure():
		dmg *= dst.status_val("untouchable", time, 1.0)
		if src != null and src.ranged and dst.lane >= 0 and teams[dst.team]["stance"][dst.lane] == "def":
			dmg *= float(cfg["stance"]["testudo_ranged_mult"])
	if dst.kind == "tower" and src != null and dst.t["outer"]:
		var support: bool = false
		for o in near(dst.pos, float(cfg["tower"]["plating_radius"])):
			if o.team == src.team and o.kind != "glad" and not o.is_structure():
				support = true
				break
		if not support:
			dmg *= float(cfg["tower"]["plating_mult"])
	if src != null and src.kind == "glad" and src.g["cls"] == "retiarius" and dst.status_val("slow", time, 1.0) < 1.0:
		dmg *= 1.2
	dmg = minf(dmg, dst.hp)
	dst.hp -= dmg
	dst.last_damaged_at = time
	if record_events and tag != "dot":
		events.append({"t": "hit", "a": src.id if src != null else -1, "b": dst.id, "d": dmg, "tag": tag})
	if src != null:
		if src.kind == "glad":
			src.g["dmg_out"] += dmg
			Glad.add_favor(self, src, dmg / src.max_hp * float(cfg["favor"]["per_dmg"]))
		if dst.kind == "glad":
			dst.g["dmg_in"] += dmg
			Glad.add_favor(self, dst, dmg / dst.max_hp * float(cfg["favor"]["per_dmg"]))
		# kule/birim müttefik gladyatöre vurduysa saldıran düşman gladyatör "kule hedefi" olur
		if dst.kind == "glad" and src.kind == "glad":
			src.g["hit_ally_until"] = time + 2.5
	if dst.hp <= 0.001:
		_kill(dst, src)
	return dmg

func _kill(dst: Ent, src: Ent) -> void:
	dst.alive = false
	dst.hp = 0.0
	dst.target = -1
	var killer_team: int = 1 - dst.team
	var kts: Dictionary = teams[killer_team]
	if record_events:
		events.append({"t": "die", "b": dst.id, "kind": dst.kind})
	match dst.kind:
		"glad":
			var gd: Dictionary = dst.g
			gd["mode"] = "dead"
			gd["deaths"] += 1
			var ec: Dictionary = cfg["economy"]
			var bounty: float = float(ec["glad_kill"]) * maxf(float(ec["glad_kill_floor"]), 1.0 - float(ec["glad_kill_decay"]) * gd["deaths_row"])
			gd["deaths_row"] += 1
			gd["respawn_at"] = time + float(cfg["respawn"]["base"]) + float(cfg["respawn"]["per_sec"]) * time
			add_gold(killer_team, bounty)
			kts["kills"] += 1
			var kg: Ent = kts["glads"][kts["active"]]
			if kg.alive:
				kg.g["kills"] += 1
				kg.g["deaths_row"] = 0
				Glad.add_favor(self, kg, float(cfg["favor"]["kill"]))
			dst.g["favor"] = 0.0
		"tower":
			var tg: float = dst.t["gold"]
			if not kts["first_tower_taken"] and stats["first_tower"] < 0:
				kts["first_tower_taken"] = true
				stats["first_tower"] = killer_team
				tg += float(cfg["economy"]["first_tower_bonus"])
			add_gold(killer_team, tg)
			var kg2: Ent = kts["glads"][kts["active"]]
			if kg2.alive:
				Glad.add_favor(self, kg2, float(cfg["favor"]["tower"]))
		"ludus":
			pass
		_:
			var u: Dictionary = cfg["units"][dst.kind]
			var full: bool = false
			var kg3: Ent = kts["glads"][kts["active"]]
			if kg3.alive and kg3.pos.distance_to(dst.pos) <= float(cfg["glad_sight"]):
				full = true
			add_gold(killer_team, float(u["gold"]) * (1.0 if full else float(cfg["economy"]["far_kill_ratio"])))

func _update_seen() -> void:
	for t in 2:
		for e in ents:
			if e.is_structure() and e.team != t:
				if is_visible(t, e) or not seen[t].has(e.id):
					# ilk kayıt: yapılar başlangıçta bilinir (harita tek ve sabit)
					if is_visible(t, e):
						seen[t][e.id] = {"hp": e.hp, "alive": e.alive, "time": time}
					elif not seen[t].has(e.id):
						seen[t][e.id] = {"hp": e.max_hp, "alive": true, "time": 0.0}

# ---------- komutlar ----------
func cmd_range(team: int) -> float:
	return float(cfg["cmd_range"]) * (1.0 + teams[team]["extra_cmd_range"])

func max_plan(team: int) -> int:
	return int(cfg["plan_steps"]) + int(teams[team]["extra_plan"])

func issue(team: int, cmd: Dictionary) -> bool:
	var ts: Dictionary = teams[team]
	var ty: String = cmd["type"]
	ts["cmd_count"] += 1
	match ty:
		"auto":
			ts["auto"] = bool(cmd["on"])
			return true
		"rule":
			ts["rules"][cmd["key"]] = float(cmd["val"])
			return true
		"munus_auto":
			ts["munus_auto"] = bool(cmd["on"])
			return true
		"swap":
			return Glad.swap(self, team)
		"munus":
			ts["munus_fire"] = true
			return true
		"group", "tower", "retreat", "heal", "hypogeum":
			if cmd.get("queue", false):
				if ts["orders"].size() >= max_plan(team):
					return false
				ts["orders"].append(cmd)
				return true
			if ty == "group" or ty == "tower":
				ts["orders"] = [cmd]
				return true
			if ty == "retreat":
				ts["orders"] = [cmd]
				return true
			# anlık düğmeler (iyileş, hypogeum)
			return Glad.instant(self, team, cmd)
		"clear":
			if cmd.get("all", true):
				ts["orders"].clear()
			elif not ts["orders"].is_empty():
				ts["orders"].pop_back()
			return true
	return false

func apply_group_order(team: int, cmd: Dictionary) -> void:
	var ts: Dictionary = teams[team]
	var lane: int = int(cmd["lane"])
	match cmd["op"]:
		"stance":
			ts["stance"][lane] = cmd["val"]
			ts["follow"][lane] = false
			if cmd["val"] != "pusu":
				ts["ambush_until"][lane] = 0.0
		"advance":
			ts["goal"][lane] = float(cmd["val"])
			ts["follow"][lane] = false
		"hold":
			var sum: float = 0.0
			var n: int = 0
			for e in ents:
				if e.alive and e.team == team and e.lane == lane and not e.is_structure() and e.kind != "glad":
					sum += lane_proj(lane, e.pos)
					n += 1
			ts["goal"][lane] = sum / n if n > 0 else null
			ts["follow"][lane] = false
		"follow":
			ts["follow"][lane] = true

func group_members(team: int, lane: int) -> Array:
	var out: Array = []
	for e in ents:
		if e.alive and e.team == team and e.lane == lane and not e.is_structure() and e.kind != "glad":
			out.append(e)
	return out

func state_hash() -> int:
	var h: int = 17
	for e in ents:
		h = (h * 31 + int(e.pos.x * 10.0) + int(e.pos.y * 10.0) * 7 + int(e.hp)) & 0x7fffffff
	h = (h * 31 + int(teams[0]["gold"]) + int(teams[1]["gold"]) * 3) & 0x7fffffff
	return h
