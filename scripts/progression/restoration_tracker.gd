extends Node
signal changed
signal achieved
const BANDS := 6
const DENSITY_LIMIT := 0.5
var completed := false
var credits_seen := false
var completed_at := -1.0
var check_clock := 0.0
func checklist() -> Dictionary:
	var world := get_parent()
	var rows := []
	var all_ready := true
	for band in BANDS:
		var nest: Node = world.get_node("Trace").nests[band]
		var record: Dictionary = world.get_node("Defense").perimeters.get(str(band),{})
		var fence: bool = not record.is_empty()
		for health in record.get("health",[]): fence = fence and health>0
		var held: bool = world.get_node("Territory").sites[band].held
		var quiet: bool = nest.state in ["cleared","suppressed"]
		rows.append({"band":band,"held":held,"quiet":quiet,"fence":fence})
		all_ready = all_ready and held and quiet and fence
	var alive := 0
	for actor in world.get_node("Threats").actors.values():
		if actor.integrity>0: alive += 1
	var density := float(alive)/BANDS
	return {"bands":rows,"density":density,"pressure_clear":density<DENSITY_LIMIT,"ready":all_ready and density<DENSITY_LIMIT}
func evaluate() -> bool:
	var world := get_parent()
	if completed or world.get_node("LifeSupport").dead or world.get_node("HumanSortie").dead: return false
	if not checklist().ready: changed.emit(); return false
	completed = true
	completed_at = world.elapsed_seconds
	changed.emit()
	achieved.emit()
	return true
func _physics_process(delta: float) -> void:
	check_clock -= delta
	if check_clock<=0:
		check_clock = 0.5
		evaluate()
func snapshot() -> Dictionary: return {"completed":completed,"credits_seen":credits_seen,"completed_at":completed_at}
static func validate(data: Variant) -> bool:
	if not data is Dictionary or not data.get("completed") is bool or not data.get("credits_seen") is bool: return false
	var at: Variant = data.get("completed_at")
	if not (at is int or at is float) or not is_finite(at): return false
	return (data.completed and at>=0) or (not data.completed and not data.credits_seen and at==-1)
func restore(data: Dictionary) -> void:
	assert(validate(data))
	completed = data.completed
	credits_seen = data.credits_seen
	completed_at = data.completed_at
	check_clock = 0.5
	changed.emit()
