extends RefCounted
## Tek varlık tipi: gladyatör, auxilia, specula, Ludus. Saf veri; mantık SimWorld'de.

var id: int = 0
var kind: String = ""      # glad | aux | sag | bal | tower | ludus
var team: int = 0
var pos: Vector2 = Vector2.ZERO
var hp: float = 1.0
var max_hp: float = 1.0
var atk: float = 0.0
var armor: float = 0.0
var aspd: float = 1.0
var ms: float = 0.0
var rng: float = 0.0
var sight: float = 300.0
var radius: float = 14.0
var alive: bool = true
var lane: int = -1
var ranged: bool = false
var atk_cd: float = 0.0
var target: int = -1
var facing: Vector2 = Vector2.RIGHT
var status: Dictionary = {}       # ad -> {"until": float, "v": float}
var hidden: bool = false
var last_damaged_at: float = -100.0
var last_attacked_at: float = -100.0
var g: Dictionary = {}            # gladyatör durumu
var t: Dictionary = {}            # specula/Ludus durumu
var label: String = ""

func is_structure() -> bool:
	return kind == "tower" or kind == "ludus"

func has_status(n: String, now: float) -> bool:
	return status.has(n) and status[n]["until"] > now

func status_val(n: String, now: float, default_v: float = 0.0) -> float:
	if status.has(n) and status[n]["until"] > now:
		return status[n]["v"]
	return default_v
