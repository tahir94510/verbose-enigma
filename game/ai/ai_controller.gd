extends RefCounted
## Rakip komutan. Oyuncuyla AYNI komut API'sini (SimWorld.issue) kullanır, kaynak hilesi yok.
## Zorluk tek bir sürekli değer (0..1): karar gecikmesi, eşik kalitesi, komut dağarcığı.

var team: int
var diff: float
var personality: String
var _next: float = 0.0

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
		ts["plan"][i] = (PLANS[ts["pair"][i]] if diff >= 0.3 else GENERIC).duplicate()
	ts["rules"]["hp_return"] = lerpf(0.20, 0.38, diff)
	ts["munus_auto"] = true
	var st: String = "agg"
	match personality:
		"temkinli": st = "def"
		"pusucu": st = "pusu"
	if diff >= 0.3:
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
	if diff >= 0.4 and e.g["mode"] == "retreat":
		var lud = w.ludus(team)
		if e.pos.distance_to(lud.pos) > 700.0:
			w.issue(team, {"type": "hypogeum", "dest": lud.id})
	# iyileş düğmesi
	if diff >= 0.3 and e.hp / e.max_hp < 0.5:
		w.issue(team, {"type": "heal"})
	# zor: ikinci gladyatör karşı seçim için Ludus'ta değişim (basit: canı çok düşükse)
	if diff >= 0.7 and e.hp / e.max_hp < 0.25:
		w.issue(team, {"type": "swap"})
