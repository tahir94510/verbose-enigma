extends RefCounted
## data/ altındaki JSON dosyalarını yükler. Tüm denge sayıları orada durur.

static func load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "veri dosyası açılamadı: " + path)
	var parsed = JSON.parse_string(f.get_as_text())
	assert(parsed != null, "JSON hatalı: " + path)
	return parsed

static func load_all() -> Dictionary:
	return {
		"cfg": load_json("res://data/config.json"),
		"glads": load_json("res://data/gladiators.json"),
		"items": load_json("res://data/items.json"),
	}
