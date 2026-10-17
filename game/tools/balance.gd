extends SceneTree
## Denge simülatörü: godot --headless --path game -s tools/balance.gd -- BAŞLA SAYI ZORLUK0 [ZORLUK1]
## 10 gladyatör çiftinden 100 sıralı eşleşme (takım0 çifti × takım1 çifti) dolaşılır; maç k tohumu k'dir.
## 5. argüman (isteğe bağlı): takım0 AI deney bayrakları, virgülle (nocamp,nostance,lowret,nohelp).
## Çıktı satırları "R ..." biçimindedir; tools/balance_report.py bunları toplar. Paralel koşturulabilir.

const SimWorld = preload("res://sim/sim_world.gd")
const GameData = preload("res://sim/game_data.gd")
const AIController = preload("res://ai/ai_controller.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var start: int = int(args[0]) if args.size() > 0 else 0
	var count: int = int(args[1]) if args.size() > 1 else 4
	var d0: float = float(args[2]) if args.size() > 2 else 0.5
	var d1: float = float(args[3]) if args.size() > 3 else d0
	var flags: Dictionary = {}
	if args.size() > 4:
		for f in args[4].split(","):
			flags[f] = true
	var data := GameData.load_all()
	var names: Array = data["glads"].keys()
	var pairs: Array = []
	for i in names.size():
		for j in range(i + 1, names.size()):
			pairs.append([names[i], names[j]])
	for k in range(start, start + count):
		var m: int = k % (pairs.size() * pairs.size())
		var p0: Array = pairs[m / pairs.size()]
		var p1: Array = pairs[m % pairs.size()]
		var w := SimWorld.new(data, k + 1, [p0, p1])
		var ais := [AIController.new(0, d0, "dengeli"), AIController.new(1, d1, "dengeli")]
		ais[0].flags = flags
		for a in ais: a.setup(w)
		while w.winner < 0 and w.time < 2400.0:
			for a in ais: a.think(w)
			w.step()
		print("R %d %s,%s %s,%s %d %.0f %.0f %.0f %d" % [k, p0[0], p0[1], p1[0], p1[1], w.winner, w.time, w.stats["gold_income"][0], w.stats["gold_income"][1], w.nature_events])
	quit()
