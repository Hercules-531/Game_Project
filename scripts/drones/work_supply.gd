extends RefCounted
## Ephemeral work time backed by this supply step; never restored from a save.
var credits: Dictionary = {}
func begin_step() -> void: credits.clear()
func grant(id: String, seconds: float, linked: bool) -> void:
	credits[id] = {"seconds":seconds,"linked":linked}
func discard(id: String) -> void: credits.erase(id)
func consume(id: String, maximum: float) -> Dictionary:
	var paid: Dictionary = credits.get(id,{"seconds":0.0,"linked":false})
	credits.erase(id)
	return {"seconds":minf(maximum,paid.seconds),"linked":paid.linked}
