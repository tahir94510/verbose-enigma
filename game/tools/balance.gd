extends SceneTree
## Denge simülatörü: godot --headless --path game -s tools/balance.gd -- N [zorluk]
## Tüm 10 çift-çift karşılaşmalarını AI-vs-AI oynatır; süre, kazanan ve gelir istatistiği basar.

const SimWorld = preload("res://sim/sim_world.gd")
const GameData = preload("res://sim/game_data.gd")
const AIController = preload("res://ai/ai_controller.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n: int = int(args[0]) if args.size() > 0 else 4
	var diff: float = float(args[1]) if args.size() > 1 else 0.5
	var data := GameData.load_all()
	var names: Array = data["glads"].keys()
	var times: Array = []
	var wins := [0, 0, 0]
	var income: Array = []
	var cls_wins: Dictionary = {}
	var cls_games: Dictionary = {}
	var timeouts: int = 0
	var seed_: int = 1
	for rep in n:
		var p0: Array = _pair(names, rep * 3 + 1)
		var p1: Array = _pair(names, rep * 5 + 2)
		var w := SimWorld.new(data, seed_, [p0, p1])
		seed_ += 1
		var ais := [AIController.new(0, diff, "dengeli"), AIController.new(1, diff, "dengeli")]
		for a in ais: a.setup(w)
		while w.winner < 0 and w.time < 2400.0:
			for a in ais: a.think(w)
			w.step()
		if w.winner < 0:
			timeouts += 1
		else:
			times.append(w.time)
			wins[w.winner] += 1
			for c in [p0, p1][w.winner]:
				cls_wins[c] = cls_wins.get(c, 0) + 1
		for c in p0: cls_games[c] = cls_games.get(c, 0) + 1
		for c in p1: cls_games[c] = cls_games.get(c, 0) + 1
		income.append((w.stats["gold_income"][0] + w.stats["gold_income"][1]) * 0.5)
		print("maç %d: %s vs %s → kazanan %d, %.0f sn, gelir %.0f/%.0f" % [rep, p0, p1, w.winner, w.time, w.stats["gold_income"][0], w.stats["gold_income"][1]])
	times.sort()
	var avg: float = 0.0
	for t in times: avg += t
	avg = avg / maxf(1.0, times.size())
	var iavg: float = 0.0
	for v in income: iavg += v
	iavg /= maxf(1.0, income.size())
	print("— özet: ortalama süre %.0f sn (%.1f dk), medyan %.0f, zaman aşımı %d, takım0 galibiyet %d / takım1 %d, ort. gelir %.0f" % [avg, avg / 60.0, times[times.size() / 2] if times.size() > 0 else 0.0, timeouts, wins[0], wins[1], iavg])
	for c in names:
		print("  %s: %d/%d" % [c, cls_wins.get(c, 0), cls_games.get(c, 0)])
	quit()

func _pair(names: Array, k: int) -> Array:
	var a: int = k % names.size()
	var b: int = (a + 1 + (k / names.size()) % (names.size() - 1)) % names.size()
	return [names[a], names[b]]
