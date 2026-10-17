extends RefCounted
## Gladyatör davranışı: otomatik mod, emir kuryeliği, yetenekler, dükkân, Hypogeum.
## Oyuncu gladyatörü sürmez; emirler `ts["orders"]` kuyruğundan kurye olarak uygulanır.

static func make(w, team: int, cls: String, idx: int):
	var lud = w.ludus(team)
	var e = w._new_ent("glad", team, lud.pos)
	e.alive = false
	e.label = w.gdefs[cls]["name"]
	e.g = {
		"cls": cls, "idx": idx, "items": [], "mode": "bench", "intent": "", "favor": 0.0, "heat": 0.0,
		"skill_cd": 0.0, "hits": 0, "deaths_row": 0, "deaths": 0, "kills": 0, "respawn_at": 0.0,
		"dmg_out": 0.0, "dmg_in": 0.0, "hit_ally_until": 0.0, "moved": false, "moved_prev": false,
		"tunnel": {}, "crit": 0.0, "bought": {},
	}
	e.hp = 1.0
	e.max_hp = 0.0
	recompute(w, e)
	e.hp = e.max_hp
	return e

static func fx(w, e, key: String) -> float:
	var s: float = 0.0
	for id in e.g["items"]:
		s += float(w.items[id]["fx"].get(key, 0.0))
	return s

static func recompute(w, e) -> void:
	var d: Dictionary = w.gdefs[e.g["cls"]]
	var sc: Dictionary = w.cfg["glad_scale"]
	var ratio: float = 1.0 if e.max_hp <= 0.0 else e.hp / e.max_hp
	e.max_hp = float(sc["hp"]) * float(d["hp"]) / 100.0 * (1.0 + fx(w, e, "hp"))
	e.atk = float(sc["atk"]) * float(d["atk"]) / 100.0 * (1.0 + fx(w, e, "atk"))
	e.aspd = float(sc["aspd"]) * float(d["aspd"]) / 100.0 * (1.0 + fx(w, e, "aspd"))
	e.armor = float(sc["armor"]) * float(d["armor"]) / 100.0 * (1.0 + fx(w, e, "armor"))
	e.ms = float(sc["ms"]) * float(d["ms"]) / 100.0 * (1.0 + fx(w, e, "ms"))
	e.rng = float(sc["range"]) * float(d["range"]) / 100.0 * (1.0 + fx(w, e, "range"))
	e.g["crit"] = float(d["crit"]) + fx(w, e, "crit")
	e.sight = float(w.cfg["glad_sight"])
	e.radius = float(w.cfg["glad_radius"])
	e.ranged = bool(d["ranged"])
	e.hp = e.max_hp * ratio
	_recalc_team(w, e.team)

static func _recalc_team(w, t: int) -> void:
	var ts: Dictionary = w.teams[t]
	if ts["glads"].is_empty():
		return
	var a = ts["glads"][ts["active"]]
	ts["extra_plan"] = int(fx(w, a, "plan_steps"))
	ts["extra_rules"] = int(fx(w, a, "rule_slots"))
	ts["extra_cmd_range"] = fx(w, a, "cmd_range")
	ts["heal_bonus"] = fx(w, a, "heal")

static func spawn(w, e, full: bool) -> void:
	var lud = w.ludus(e.team)
	e.pos = lud.pos + Vector2(36.0 * (1 if e.team == 0 else -1), 0.0).rotated(0.6 * e.g["idx"])
	e.alive = true
	e.g["mode"] = "idle"
	e.g["intent"] = ""
	e.status.clear()
	if full:
		e.hp = e.max_hp
	e.target = -1
	_recalc_team(w, e.team)

static func add_favor(w, e, amount: float) -> void:
	e.g["favor"] = minf(100.0, e.g["favor"] + amount)

# ---------- dükkân ----------
static func _gather(w, item_id: String, inv: Array, depth: int) -> Dictionary:
	# envanterde bulunan bileşenleri düşer; eksik bileşenin alt bileşenlerine iner
	var value: float = 0.0
	var removed: Array = []
	for c in w.items[item_id]["comps"]:
		var i: int = inv.find(c)
		if i >= 0:
			inv.remove_at(i)
			value += float(w.items[c]["total"])
			removed.append(c)
		else:
			var sub: Dictionary = _gather(w, c, inv, depth + 1)
			value += sub["value"]
			removed.append_array(sub["removed"])
	return {"value": value, "removed": removed}

static func quote(w, e, item_id: String) -> Dictionary:
	var inv: Array = e.g["items"].duplicate()
	var res: Dictionary = _gather(w, item_id, inv, 0)
	var cost: float = float(w.items[item_id]["total"]) - res["value"]
	var slots_ok: bool = inv.size() < 4
	return {"cost": cost, "inv_after": inv, "ok_slots": slots_ok}

static func buy(w, t: int, gi: int, item_id: String) -> bool:
	var ts: Dictionary = w.teams[t]
	var e = ts["glads"][gi]
	if e.g["items"].has(item_id) and w.items[item_id]["tier"] == "legend":
		return false
	var q: Dictionary = quote(w, e, item_id)
	if not q["ok_slots"] or ts["gold"] < q["cost"]:
		return false
	ts["gold"] -= q["cost"]
	var inv: Array = q["inv_after"]
	inv.append(item_id)
	e.g["items"] = inv
	e.g["bought"][item_id] = true
	recompute(w, e)
	return true

static func team_shop(w, t: int) -> void:
	var ts: Dictionary = w.teams[t]
	var lud = w.ludus(t)
	if not lud.alive:
		return
	for gi in 2:
		var e = ts["glads"][gi]
		var near_lud: bool = (e.alive and e.pos.distance_to(lud.pos) <= float(w.cfg["ludus"]["heal_radius"])) or e.g["mode"] == "bench"
		if not near_lud:
			continue
		var plan: Array = ts["plan"][gi]
		for id in plan:
			if e.g["bought"].has(id):
				continue
			if buy(w, t, gi, id):
				if w.record_events:
					w.events.append({"t": "buy", "team": t, "item": id})
			break   # sırayla: sıradaki alınamıyorsa bekle

static func next_cost(w, t: int, gi: int) -> float:
	var ts: Dictionary = w.teams[t]
	var e = ts["glads"][gi]
	for id in ts["plan"][gi]:
		if not e.g["bought"].has(id):
			return float(quote(w, e, id)["cost"])
	return -1.0

# ---------- komut yardımcıları ----------
static func swap(w, t: int) -> bool:
	var ts: Dictionary = w.teams[t]
	var cur = ts["glads"][ts["active"]]
	var other = ts["glads"][1 - ts["active"]]
	var lud = w.ludus(t)
	if not cur.alive or other.g["mode"] != "bench" or w.time < ts["swap_ready"]:
		return false
	if cur.pos.distance_to(lud.pos) > float(w.cfg["ludus"]["heal_radius"]):
		return false
	cur.alive = false
	cur.g["mode"] = "bench"
	ts["active"] = 1 - ts["active"]
	spawn(w, other, false)
	ts["swap_ready"] = w.time + float(w.cfg["respawn"]["swap_cd"])
	return true

static func instant(w, t: int, cmd: Dictionary) -> bool:
	var ts: Dictionary = w.teams[t]
	var e = ts["glads"][ts["active"]]
	if not e.alive:
		return false
	match cmd["type"]:
		"heal":
			if ts["heal_cd"] > 0.0:
				return false
			var amt: float = e.max_hp * float(w.cfg["heal"]["pct"]) * (1.0 + ts["heal_bonus"])
			e.hp = minf(e.max_hp, e.hp + amt)
			ts["heal_cd"] = float(w.cfg["heal"]["cd"])
			return true
		"hypogeum":
			return start_hypogeum(w, e, int(cmd["dest"]))
	return false

static func _tunnel_len(w, a, b) -> float:
	# yüzey yolu: aynı hatta |Δs|, farklı hatlarda Ludus üzerinden
	var la: int = a.lane if a.lane >= 0 else (b.lane if b.lane >= 0 else 0)
	var lb: int = b.lane if b.lane >= 0 else la
	var sa: float = 0.0 if a.kind == "ludus" else w.own_s(a.team, a.lane, a.t["s"])
	var sb: float = 0.0 if b.kind == "ludus" else w.own_s(b.team, b.lane, b.t["s"])
	if la == lb or a.kind == "ludus" or b.kind == "ludus":
		return absf(sa - sb)
	return sa + sb

static func start_hypogeum(w, e, dest_id: int) -> bool:
	var dest = w.by_id.get(dest_id, null)
	if dest == null or not dest.alive or dest.team != e.team or not dest.is_structure():
		return false
	var entry = _nearest_own_struct(w, e)
	if entry == null or entry.id == dest.id:
		return false
	e.g["tunnel"] = {"dest": dest_id, "entry": entry.id}
	e.g["mode"] = "to_entry"
	return true

static func _nearest_own_struct(w, e):
	var best = null
	var bd: float = INF
	for o in w.ents:
		if o.alive and o.team == e.team and o.is_structure():
			var d: float = o.pos.distance_to(e.pos)
			if d < bd:
				bd = d
				best = o
	return best

# ---------- hareket ----------
static func move_to(w, e, p: Vector2) -> void:
	var before: Vector2 = e.pos
	w._move_to(e, p)
	if e.pos != before:
		e.g["moved"] = true

# ---------- ana güncelleme ----------
static func update(w, e) -> void:
	var ts: Dictionary = w.teams[e.team]
	var gd: Dictionary = e.g
	if gd["mode"] == "bench" or gd["mode"] == "dead":
		return
	w._tick_status(e)
	if not e.alive:
		return
	gd["moved_prev"] = gd["moved"]
	gd["moved"] = false
	gd["skill_cd"] = maxf(0.0, gd["skill_cd"] - w.dt)
	var lud = w.ludus(e.team)
	var at_ludus: bool = lud.alive and e.pos.distance_to(lud.pos) <= float(w.cfg["ludus"]["heal_radius"])
	# yenilenme
	var regen: float = 0.004 * (1.0 + fx(w, e, "regen")) * e.max_hp
	e.hp = minf(e.max_hp, e.hp + regen * w.dt)
	if at_ludus:
		e.hp = minf(e.max_hp, e.hp + e.max_hp * float(w.cfg["ludus"]["heal_pct"]) * w.dt)
	if gd["cls"] == "secutor":
		gd["heat"] = maxf(0.0, gd["heat"] - (24.0 if at_ludus else 6.0) * w.dt)
	# tünel durumları
	match gd["mode"]:
		"tunnel":
			gd["intent"] = "hypogeum"
			gd["tunnel"]["left"] -= w.dt
			if gd["tunnel"]["left"] <= 0.0:
				var dest = w.by_id.get(gd["tunnel"]["dest"], null)
				if dest == null or not dest.alive:
					dest = lud
				e.pos = dest.pos + Vector2(30.0, 20.0)
				gd["mode"] = "idle"
			return
		"to_entry":
			gd["intent"] = "hypogeum"
			var entry = w.by_id.get(gd["tunnel"]["entry"], null)
			var dest2 = w.by_id.get(gd["tunnel"]["dest"], null)
			if entry == null or not entry.alive or dest2 == null or not dest2.alive:
				gd["mode"] = "idle"
				return
			if e.pos.distance_to(entry.pos) > float(w.cfg["hypogeum"]["entry"]):
				move_to(w, e, entry.pos)
				return
			if w.time - entry.last_damaged_at < float(w.cfg["hypogeum"]["block_after_hit"]):
				gd["intent"] = "tünel kapalı"
				return
			var secs: float = _tunnel_len(w, entry, dest2) / maxf(1.0, e.ms) * float(w.cfg["hypogeum"]["ratio"]) * (1.0 - fx(w, e, "tunnel"))
			gd["tunnel"]["left"] = maxf(1.0, secs)
			gd["mode"] = "tunnel"
			return
	if e.has_status("stun", w.time):
		gd["intent"] = "sersem"
		return
	_abilities(w, e, ts)
	_think(w, e, ts, lud, at_ludus)

static func _think(w, e, ts: Dictionary, lud, at_ludus: bool) -> void:
	var gd: Dictionary = e.g
	var hpf: float = e.hp / e.max_hp
	var rules: Dictionary = ts["rules"]
	# kural yuvaları: can eşiği / altın eşiği → Ludus
	if gd["mode"] != "retreat":
		if hpf < float(rules["hp_return"]) and not at_ludus:
			gd["mode"] = "retreat"
		elif float(rules["gold_return"]) > 0.0 and ts["gold"] >= float(rules["gold_return"]) and not at_ludus and next_cost(w, e.team, gd["idx"]) >= 0.0 and ts["gold"] >= next_cost(w, e.team, gd["idx"]):
			gd["mode"] = "retreat"
	if gd["mode"] == "retreat":
		gd["intent"] = "geri çekiliyor"
		if at_ludus:
			var pending: bool = float(rules["gold_return"]) > 0.0 and next_cost(w, e.team, gd["idx"]) >= 0.0 and ts["gold"] >= next_cost(w, e.team, gd["idx"])
			if hpf >= 0.9 and not pending:
				gd["mode"] = "idle"
			else:
				gd["intent"] = "iyileşiyor"
				return
		else:
			move_to(w, e, lud.pos)
			return
	# emir kuyruğu (kurye)
	if not ts["orders"].is_empty():
		if _process_order(w, e, ts, lud, at_ludus):
			return
	if ts["auto"]:
		_auto(w, e, ts, lud)
	else:
		_hold(w, e)

static func _process_order(w, e, ts: Dictionary, lud, at_ludus: bool) -> bool:
	var o: Dictionary = ts["orders"][0]
	var rngc: float = w.cmd_range(e.team)
	match o["type"]:
		"group":
			var members: Array = w.group_members(e.team, int(o["lane"]))
			if members.is_empty():
				ts["orders"].pop_front()
				return false
			var best = null
			var bd: float = INF
			for m in members:
				var d: float = m.pos.distance_to(e.pos)
				if d < bd:
					bd = d
					best = m
			if bd <= rngc:
				w.apply_group_order(e.team, o)
				ts["orders"].pop_front()
				return false
			e.g["intent"] = "emir iletiyor"
			move_to(w, e, best.pos)
			return true
		"tower":
			var tw = w.by_id.get(int(o["tower"]), null)
			if tw == null or not tw.alive:
				ts["orders"].pop_front()
				return false
			if e.pos.distance_to(tw.pos) <= rngc:
				ts["tower_prio"][tw.id] = o["val"]
				ts["orders"].pop_front()
				return false
			e.g["intent"] = "emir iletiyor"
			move_to(w, e, tw.pos)
			return true
		"camp":
			var ce = w.camp_ent(int(o["camp"]))
			if ce == null:
				ts["orders"].pop_front()
				return false
			e.g["intent"] = "arena yaratığı"
			_engage(w, e, ce, true)
			return true
		"retreat":
			if at_ludus:
				ts["orders"].pop_front()
				return false
			e.g["intent"] = "geri çekiliyor"
			move_to(w, e, lud.pos)
			return true
		"heal":
			instant(w, e.team, o)
			ts["orders"].pop_front()
			return false
		"hypogeum":
			var ok: bool = start_hypogeum(w, e, int(o["dest"]))
			ts["orders"].pop_front()
			return ok
	ts["orders"].pop_front()
	return false

# ---------- savaş ----------
static func _hold(w, e) -> void:
	e.g["intent"] = "mevzide"
	var tgt = _pick_target(w, e, e.rng, false)
	if tgt != null:
		_engage(w, e, tgt, false)

static func _support(w, t: int, p: Vector2) -> int:
	var n: int = 0
	for o in w.near(p, 280.0):
		if o.team == t and not o.is_structure() and o.kind != "glad":
			n += 1
	return n

static func _unsafe(w, e, p: Vector2) -> bool:
	for o in w.ents:
		if o.alive and o.team != e.team and o.is_structure() and o.pos.distance_to(p) <= o.rng + 30.0:
			if _support(w, e.team, o.pos) < 2:
				return true
	return false

static func _pick_target(w, e, reach: float, allow_struct: bool):
	var best = null
	var bd: float = INF
	for o in w.near(e.pos, reach + 40.0):
		if o.team == e.team or not o.alive or o.is_structure():
			continue
		if not w.is_visible(e.team, o):
			continue
		var d: float = o.pos.distance_to(e.pos)
		if d > reach + o.radius:
			continue
		var score: float = d - (180.0 if o.kind == "glad" else 0.0)
		if score < bd:
			bd = score
			best = o
	if best != null:
		return best
	if allow_struct:
		for o in w.near(e.pos, reach + 80.0):
			if o.team != e.team and o.alive and o.is_structure() and o.pos.distance_to(e.pos) <= reach + o.radius:
				return o
	return null

static func _engage(w, e, tgt, may_chase: bool) -> void:
	var d: float = e.pos.distance_to(tgt.pos)
	var reach: float = e.rng + tgt.radius
	e.g["intent"] = "saldırıyor"
	if d <= reach:
		e.facing = (tgt.pos - e.pos).normalized()
		# menzilli: yakına gelen gladyatörden geri sıçra
		if e.ranged and tgt.kind == "glad" and d < e.rng * 0.45 and may_chase:
			var away: Vector2 = e.pos + (e.pos - tgt.pos).normalized() * 40.0
			move_to(w, e, away)
			e.g["intent"] = "mesafe açıyor"
			return
		if e.atk_cd <= 0.0:
			_attack(w, e, tgt)
	elif may_chase:
		move_to(w, e, tgt.pos)

static func _attack(w, e, tgt) -> void:
	var gd: Dictionary = e.g
	var aspd: float = e.aspd * e.status_val("weak_aspd", w.time, 1.0)
	e.atk_cd = 1.0 / maxf(0.1, aspd)
	var raw: float = e.atk * e.status_val("atk_up", w.time, 1.0)
	if gd["cls"] == "secutor" and gd["heat"] >= 50.0 and tgt.kind == "neutral":
		tgt.status["burn"] = {"until": w.time + 3.0, "v": 1.0}
	match gd["cls"]:
		"secutor":
			raw *= 1.0 + gd["heat"] * 0.003
			gd["heat"] += 5.0
			if gd["heat"] >= 100.0:
				gd["heat"] = 0.0
				e.status["slow"] = {"until": w.time + 3.0, "v": 0.7}
				e.status["weak_aspd"] = {"until": w.time + 3.0, "v": 0.7}
		"veles":
			if gd["moved_prev"]:
				raw *= 1.3
		"thraex":
			gd["hits"] += 1
			if gd["hits"] % 3 == 0:
				tgt.status["bleed"] = {"until": w.time + 3.0, "v": e.atk * 0.12, "src": e.id}
	if not tgt.is_structure() and w.rng.randf() < gd["crit"]:
		raw *= 1.75
	e.last_attacked_at = w.time
	w.deal(e, tgt, raw, "attack")

# ---------- otomatik mod ----------
static func _front_aux(w, t: int, lane: int):
	var best = null
	var bs: float = -1.0
	for m in w.group_members(t, lane):
		var s: float = w.own_s(t, lane, w.lane_proj(lane, m.pos))
		if s > bs:
			bs = s
			best = m
	return best

static func _pick_lane(w, e, ts: Dictionary) -> int:
	var cur: int = ts["focus_lane"]
	var cnt: Array = [w.group_members(e.team, 0).size(), w.group_members(e.team, 1).size()]
	if cnt[1 - cur] >= cnt[cur] + 3 or cnt[cur] == 0 and cnt[1 - cur] > 0:
		ts["focus_lane"] = 1 - cur
	return ts["focus_lane"]

static func _auto(w, e, ts: Dictionary, lud) -> void:
	var lane: int = _pick_lane(w, e, ts)
	var tgt = _pick_target(w, e, e.rng + 90.0, true)
	if tgt != null:
		var ok: bool = _support(w, e.team, tgt.pos) >= 2 if tgt.is_structure() else not _unsafe(w, e, tgt.pos)
		if ok:
			_engage(w, e, tgt, true)
			return
	# yoksa üstlenilen hatta ön safın biraz gerisinde bekle
	var front = _front_aux(w, e.team, lane)
	var anchor: Vector2 = lud.pos
	if front != null:
		var s_own: float = w.own_s(e.team, lane, w.lane_proj(lane, front.pos)) - 50.0
		anchor = w.lane_pos(lane, w.abs_s(e.team, lane, maxf(s_own, 0.0)))
		var tries: int = 0
		while _unsafe(w, e, anchor) and tries < 12:
			s_own -= 40.0
			anchor = w.lane_pos(lane, w.abs_s(e.team, lane, maxf(s_own, 0.0)))
			tries += 1
		e.g["intent"] = "yürüyor"
	else:
		e.g["intent"] = "bekliyor"
		for tid in ts["towers"]:
			var tw = w.by_id[tid]
			if tw.alive and tw.lane == lane and tw.t["outer"]:
				anchor = tw.pos
	if e.pos.distance_to(anchor) > 25.0:
		move_to(w, e, anchor)

# ---------- yetenekler ----------
static func _enemy_glad(w, e, r: float):
	var best = null
	var bd: float = INF
	for o in w.near(e.pos, r):
		if o.team != e.team and o.kind == "glad" and o.alive and w.is_visible(e.team, o):
			var d: float = o.pos.distance_to(e.pos)
			if d < bd:
				bd = d
				best = o
	return best

static func _abilities(w, e, ts: Dictionary) -> void:
	var gd: Dictionary = e.g
	var cls: String = gd["cls"]
	var hpf: float = e.hp / e.max_hp
	if gd["skill_cd"] <= 0.0:
		var did: bool = false
		match cls:
			"murmillo":
				var t1 = _enemy_glad(w, e, 90.0)
				if t1 != null:
					t1.pos += (t1.pos - e.pos).normalized() * 100.0
					t1.status["stun"] = {"until": w.time + 1.0, "v": 1.0}
					w.deal(e, t1, e.atk * 0.8, "skill")
					did = true
			"thraex":
				var t2 = _enemy_glad(w, e, 240.0)
				if t2 != null and e.pos.distance_to(t2.pos) > e.rng + 10.0 and not _unsafe(w, e, t2.pos):
					e.pos = t2.pos - t2.facing * (e.rng * 0.6)
					w.deal(e, t2, e.atk * 0.8, "skill")
					did = true
			"secutor":
				var t3 = _enemy_glad(w, e, 330.0)
				if t3 != null and e.pos.distance_to(t3.pos) > e.rng + 20.0:
					e.status["haste"] = {"until": w.time + 3.0, "v": 1.4}
					did = true
			"retiarius":
				var t4 = _enemy_glad(w, e, e.rng + 90.0)
				if t4 != null:
					var slowed: bool = t4.status_val("slow", w.time, 1.0) < 1.0
					t4.status["root"] = {"until": w.time + (2.5 if slowed else 1.5), "v": 1.0}
					t4.status["slow"] = {"until": w.time + 3.5, "v": 0.7}
					w.deal(e, t4, e.atk * 0.5, "skill")
					did = true
			"veles":
				var hit: int = 0
				var cand: Array = []
				for o in w.near(e.pos, e.rng):
					if o.team != e.team and o.alive and not o.is_structure() and w.is_visible(e.team, o):
						cand.append(o)
				if cand.size() >= 2:
					for o in cand:
						if hit < 3:
							w.deal(e, o, e.atk * 0.7, "skill")
							hit += 1
					did = true
		if did:
			gd["skill_cd"] = float(w.gdefs[cls]["skill"]["cd"])
			if w.record_events:
				w.events.append({"t": "skill", "a": e.id})
	# Munus
	if gd["favor"] >= 100.0:
		var foe = _enemy_glad(w, e, 350.0)
		var fire: bool = ts["munus_fire"] and e.id == ts["glads"][ts["active"]].id
		if not fire and ts["munus_auto"] and foe != null:
			fire = true
		if not fire and hpf < 0.3 and foe != null:
			fire = true
		if fire:
			if _munus(w, e, foe):
				gd["favor"] = 0.0
				ts["munus_fire"] = false
				if w.record_events:
					w.events.append({"t": "munus", "a": e.id})

static func _munus(w, e, foe) -> bool:
	var cls: String = e.g["cls"]
	match cls:
		"murmillo":
			e.status["untouchable"] = {"until": w.time + 5.0, "v": 0.2}
			e.status["root"] = {"until": w.time + 5.0, "v": 1.0}
			for o in w.near(e.pos, 300.0):
				if o.team == e.team and not o.is_structure() and o.kind != "glad":
					o.status["armor_up"] = {"until": w.time + 5.0, "v": 50.0}
			return true
		"thraex":
			if foe == null:
				return false
			e.pos = foe.pos - foe.facing * 20.0
			for o in w.near(e.pos, 150.0):
				if o.team != e.team and o.alive and not o.is_structure():
					w.deal(e, o, e.atk * 2.5, "munus")
					o.status["slow"] = {"until": w.time + 2.5, "v": 0.6}
			return true
		"secutor":
			var t = foe
			if t == null:
				t = _pick_target(w, e, 250.0, true)
			if t == null:
				return false
			w.deal(e, t, e.atk * (2.0 + e.g["heat"] / 20.0), "munus")
			e.g["heat"] = 0.0
			return true
		"retiarius":
			if foe == null:
				return false
			for o in w.near(e.pos, 200.0):
				if o.team != e.team and o.alive and not o.is_structure():
					o.pos += (o.pos - e.pos).normalized() * 150.0
					o.status["slow"] = {"until": w.time + 2.5, "v": 0.6}
					w.deal(e, o, e.atk * 1.5, "munus")
			return true
		"veles":
			var t2 = foe
			if t2 == null:
				t2 = _pick_target(w, e, 420.0, true)
			if t2 == null:
				return false
			w.deal(e, t2, e.atk * 5.0, "munus")
			return true
	return false
