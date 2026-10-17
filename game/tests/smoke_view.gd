extends SceneTree
## Görünüm duman testi (xvfb ile): sahneyi yükler, menüden başlatır, birkaç saniye oynatır, ekran görüntüsü alır.
func _init() -> void:
	var packed: PackedScene = load("res://view/main.tscn")
	var m = packed.instantiate()
	root.add_child(m)
	await process_frame
	m.pick = ["thraex", "veles"]
	m._start()
	for i in 600:
		await process_frame
	m.sel = {"type": "lane", "lane": 0}
	m._rebuild_cmds()
	m._cmd({"type": "group", "lane": 0, "op": "stance", "val": "def"})
	for i in 300:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png("/tmp/claude-0/shot.png")
	print("shot ok t=", m.w.time)
	quit()
