extends RefCounted
## Rakip komutan. Oyuncuyla AYNI komut API'sini (SimWorld.issue) kullanır, kaynak hilesi yok.
## Zorluk tek bir sürekli değer (0..1): karar gecikmesi, eşik kalitesi, komut dağarcığı.

var team: int
var diff: float
var personality: String
var flags: Dictionary = {}   # deney bayrakları (denge aracı): camp (kamp avı, ölçümde zararlı çıktığı için varsayılan KAPALI), nostance, lowret, nohelp, generic
var _next: float = 0.0
var _camp_next: float = 90.0

const PLANS := {
	"murmillo": ["parma", "galea", "scutum", "manica", "lorica_segmentata", "hordeum"],
	"thraex": ["pugio", "funda", "spatha", "plumbata", "gladius_hispaniensis", "galea"],
	"secutor": ["caligae", "pugio", "cothurnus", "spatha", "talaria", "gladius_hispaniensis"],
	"retiarius": ["caligae", "vexillum", "cothurnus", "cornu", "talaria", "aquila"],
	"veles": ["pugio", "caligae", "spatha", "cothurnus", "gladius_hispaniensis", "talaria"],
}
const GENERIC := ["parma", "pugio", "hordeum", "scutum", "spatha", "cataplasma"]

func _init(t: int, d: float, pers: String = "dengeli") -> void:
	team = t
	diff = d
	personality = pers

func setup(w) -> void:
	var ts: Dictionary = w.teams[team]
	for i in 2:
		ts["plan"][i] = (PLANS[ts["pair"][i]] if diff >= 0.3 and not flags.has("generic") else GENERIC).duplicate()
	ts["rules"]["hp_return"] = 0.20 if flags.has("lowret") else lerpf(0.20, 0.38, diff)
	ts["munus_auto"] = true
	var st: String = "agg"
	match personality:
		"temkinli": st = "def"
		"pusucu": st = "pusu"
	if diff >= 0.3 and not flags.has("nostance"):
		for l in 2:
			w.issue(team, {"type": "group", "lane": l, "op": "stance", "val": st})

func think(w) -> void:
	if w.time < _next:
		return
	_next = w.time + lerpf(7.0, 1.5, diff)
	var ts: Dictionary = w.teams[team]
	var e = ts["glads"][ts["active"]]
	if not e.alive:
		return
	# orta/zor: yaralıyken uzaksa Hypogeum ile Ludus'a dön
	if diff >= 0.4 and not flags.has("nohelp") and e.g["mode"] == "retreat":
		var lud = w.ludus(team)
		if e.pos.distance_to(lud.pos) > 700.0:
			w.issue(team, {"type": "hypogeum", "dest": lud.id})
	# orta/zor: yakın, sağlıklıyken ve düşman gladyatör görünmüyorken en yakın canlı arena yaratığına git
	# (hydra yalnızca zorda). Ölçüm: kamp avı zor AI'yı zayıflattı → yalnızca `camp` bayrağıyla açılır (bkz. docs/09).
	if diff >= 0.5 and flags.has("camp") and w.time >= _camp_next and ts["orders"].is_empty() and e.g["mode"] != "retreat" and e.hp / e.max_hp >= 0.85:
		var foe_near: bool = false
		for o in w.near(e.pos, 800.0):
			if o.team != team and o.kind == "glad" and o.alive and w.is_visible(team, o):
				foe_near = true
		var best: int = -1
		var bd: float = 750.0
		for i in w.camps.size():
			var ce = w.camp_ent(i)
			if ce == null or foe_near:
				continue
			if ce.t["def"] == "hydra" and (diff < 0.8 or w.time < 420.0):
				continue
			var dd: float = ce.pos.distance_to(e.pos)
			if dd < bd:
				bd = dd
				best = i
		_camp_next = w.time + 25.0
		if best >= 0:
			w.issue(team, {"type": "camp", "camp": best})
	# iyileş düğmesi
	if diff >= 0.3 and not flags.has("nohelp") and e.hp / e.max_hp < 0.5:
		w.issue(team, {"type": "heal"})
	# zor: ikinci gladyatör karşı seçim için Ludus'ta değişim (basit: canı çok düşükse)
	if diff >= 0.7 and not flags.has("nohelp") and e.hp / e.max_hp < 0.25:
		w.issue(team, {"type": "swap"})
