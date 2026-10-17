extends SceneTree
## Headless testler: godot --headless --path game -s tests/run_tests.gd

const SimWorld = preload("res://sim/sim_world.gd")
const GameData = preload("res://sim/game_data.gd")
const AIController = preload("res://ai/ai_controller.gd")
const Glad = preload("res://sim/glad.gd")

var fails: int = 0
var data: Dictionary

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok  ", msg)
	else:
		print("FAIL  ", msg)
		fails += 1

func run_match(seed_: int, pairs: Array, d0: float, d1: float, max_s: float = 1800.0) -> Dictionary:
	var w := SimWorld.new(data, seed_, pairs)
	var ais := [AIController.new(0, d0, "dengeli"), AIController.new(1, d1, "temkinli")]
	for a in ais: a.setup(w)
	while w.winner < 0 and w.time < max_s:
		for a in ais: a.think(w)
		w.step()
	return {"w": w, "hash": w.state_hash(), "winner": w.winner, "time": w.time}

func _init() -> void:
	data = GameData.load_all()
	print("== Veri")
	check(data["items"].size() == 25, "25 item")
	check(data["glads"].size() == 5, "5 gladyatör")
	var legends: int = 0
	for id in data["items"]:
		var it: Dictionary = data["items"][id]
		if it["tier"] == "legend":
			legends += 1
			var sum: float = 500.0
			for c in it["comps"]:
				sum += float(data["items"][c]["total"])
			check(is_equal_approx(sum, float(it["total"])), "efsanevi tarifi: " + id)
		elif it["tier"] == "epic":
			var c0: String = it["comps"][0]
			check(float(it["total"]) - float(data["items"][c0]["total"]) in [600.0, 560.0, 550.0], "epik tarifi: " + id)
	check(legends == 5, "5 efsanevi")

	print("== Dükkân")
	var w := SimWorld.new(data, 1, [["murmillo", "veles"], ["thraex", "retiarius"]])
	w.teams[0]["gold"] = 10000.0
	var g = w.teams[0]["glads"][0]
	check(Glad.buy(w, 0, 0, "scutum"), "scutum (bileşenler otomatik)")
	check(is_equal_approx(w.teams[0]["gold"], 10000.0 - 900.0), "scutum 900 altın")
	check(g.g["items"] == ["scutum"], "yalnızca scutum envanterde")
	Glad.buy(w, 0, 0, "manica")
	check(Glad.buy(w, 0, 0, "lorica_segmentata"), "efsanevi: iki epikten")
	check(g.g["items"].size() == 1, "birleşince tek slot")
	check(not Glad.buy(w, 0, 0, "lorica_segmentata"), "aynı efsanevi iki kez alınamaz")
	for id in ["pugio", "funda", "caligae", "hordeum"]:
		Glad.buy(w, 0, 0, id)
	check(g.g["items"].size() == 4, "4 slot dolu")
	check(not Glad.buy(w, 0, 0, "lampas"), "5. slot reddedilir")

	print("== Komutlar")
	var w2 := SimWorld.new(data, 2, [["murmillo", "veles"], ["thraex", "retiarius"]])
	for i in 400: w2.step()
	check(w2.group_members(0, 0).size() > 0, "dalga doğdu")
	check(w2.issue(0, {"type": "group", "lane": 0, "op": "stance", "val": "def"}), "duruş emri kuyruğa girdi")
	check(w2.teams[0]["stance"][0] == "agg", "emir kuryeye kadar uygulanmaz")
	for i in 600: w2.step()
	check(w2.teams[0]["stance"][0] == "def", "kurye emri iletti")
	var cnt: int = 0
	for k in 6:
		if w2.issue(0, {"type": "retreat", "queue": true}): cnt += 1
	check(cnt == 4, "plan sırası en çok 4 adım")
	check(w2.issue(0, {"type": "clear", "all": true}) and w2.teams[0]["orders"].is_empty(), "sıra temizlenir")

	print("== Determinizm")
	var pairs := [["murmillo", "veles"], ["thraex", "secutor"]]
	var a := run_match(7, pairs, 0.5, 0.5)
	var b := run_match(7, pairs, 0.5, 0.5)
	check(a["hash"] == b["hash"] and a["winner"] == b["winner"], "aynı tohum aynı sonuç")
	var c := run_match(8, pairs, 0.5, 0.5)
	print("  maç: kazanan=%d süre=%.0fs hash=%d" % [a["winner"], a["time"], a["hash"]])
	check(a["winner"] >= 0, "maç bitti (zaman aşımı yok)")
	check(c["winner"] >= 0, "ikinci tohum da bitti")

	print("== Sis")
	var w3 := SimWorld.new(data, 3, pairs)
	for i in 100: w3.step()
	var enemy_tower = null
	for e in w3.ents:
		if e.kind == "tower" and e.team == 1:
			enemy_tower = e
			break
	check(not w3.is_visible(0, enemy_tower), "uzaktaki düşman yapısı sisli")
	check(w3.seen[0].has(enemy_tower.id), "yapı için son-görülen kayıt var")

	print("\n%s (%d hata)" % ["BAŞARILI" if fails == 0 else "BAŞARISIZ", fails])
	quit(1 if fails > 0 else 0)
