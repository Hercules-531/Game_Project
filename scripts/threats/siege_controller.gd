extends Node
signal changed
const Model = preload("res://scripts/drones/drone.gd")
var phase := "idle"
var band := -1
var roster: Array = []
var clock := 0.0
var remaining := 0.0
var cooldowns: Array = [0.0,0.0,0.0,0.0,0.0,0.0]
@onready var threats: Node = get_parent().get_node("Threats")
@onready var trace: Node = get_parent().get_node("Trace")
@onready var defense: Node = get_parent().get_node("Defense")
func _physics_process(delta: float) -> void: advance(delta)
func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds<=0: return
	clock += seconds
	for i in 6: cooldowns[i] = maxf(0,cooldowns[i]-seconds)
	if phase=="idle":
		for i in 6:
			var nest: Node = trace.nests[i]
			if nest.state!="active" or not nest.home_known or cooldowns[i]>0 or nest.active_count()<2: continue
			roster.clear()
			for id in nest.population:
				if threats.actors.has(id) and threats.actors[id].integrity>0: roster.append(id)
			band = i
			phase = "forming"
			remaining = 12.0
			changed.emit()
			break
		return
	roster = roster.filter(func(id): return threats.actors.has(id) and threats.actors[id].integrity>0)
	if roster.is_empty():
		_finish()
		return
	remaining = maxf(0,remaining-seconds)
	if phase in ["forming","attacking"] and (get_parent().get_node("Weather").current=="rain" or trace.nests[band].state!="active" or roster.size()<2):
		phase = "retreat"
		remaining = 45.0
		changed.emit()
		return
	if phase=="forming" and remaining<=0:
		var assembled := true
		for id in roster:
			if threats.actors[id].position.distance_to(_rally(roster.find(id)))>3.0: assembled = false
		if assembled:
			phase = "attacking"
			remaining = 180.0
			changed.emit()
	elif phase=="attacking" and (remaining<=0 or roster.size()<2):
		phase = "retreat"
		remaining = 45.0
		changed.emit()
	elif phase=="retreat" and remaining<=0: _finish()
func _finish() -> void:
	if band>=0: cooldowns[band] = 300.0
	phase = "idle"
	roster.clear()
	band = -1
	remaining = 0.0
	changed.emit()
func _rally(slot: int) -> Vector3:
	return Vector3((slot-(roster.size()-1)*0.5)*2.5,0.02,-36)
func goal(id: String) -> Dictionary:
	if id not in roster or phase=="idle": return {}
	var slot := roster.find(id)
	if phase=="forming": return {"at":_rally(slot),"attack":false}
	if phase=="retreat": return {"at":trace.nests[band].position+Vector3((slot-2)*2,0,3),"attack":false}
	# Seek a real, intact north barrier first. Once broken, approach the airlock.
	var fence: Dictionary = defense.perimeters.get("0",{})
	if not fence.is_empty() and fence.health[0]>0: return {"at":Vector3(clampf((slot-(roster.size()-1)*0.5)*2.5,-8,8),0.02,-30),"attack":true}
	return {"at":Vector3(clampf((slot-(roster.size()-1)*0.5)*1.2,-2,2),0.02,-18),"attack":true}
func snapshot() -> Dictionary:
	return {"phase":phase,"band":band,"roster":roster.duplicate(),"clock":clock,"remaining":remaining,"cooldowns":cooldowns.duplicate()}
static func validate(data: Variant) -> bool:
	if not data is Dictionary or data.get("phase") not in ["idle","forming","attacking","retreat"] or not Model._range(data.get("band"),-1,5) or data.band!=int(data.band) or not data.get("roster") is Array or data.roster.size()>6 or not Model._range(data.get("clock"),0,1000000000) or not Model._range(data.get("remaining"),0,180) or not data.get("cooldowns") is Array or data.cooldowns.size()!=6: return false
	if (data.phase=="idle")!=(data.band==-1) or (data.phase=="idle" and (not data.roster.is_empty() or data.remaining>0)): return false
	if data.phase!="idle" and data.roster.is_empty(): return false
	if data.phase=="forming" and data.remaining>12: return false
	if data.phase=="retreat" and data.remaining>45: return false
	var seen := {}
	for id in data.roster:
		if not id is String or id.is_empty() or id.length()>80 or seen.has(id): return false
		seen[id] = true
	for delay in data.cooldowns:
		if not Model._range(delay,0,300): return false
	return true
func restore(data: Dictionary) -> void:
	assert(validate(data))
	phase = data.phase
	band = int(data.band)
	roster = data.roster.duplicate()
	clock = data.clock
	remaining = data.remaining
	cooldowns = data.cooldowns.duplicate()
	changed.emit()
