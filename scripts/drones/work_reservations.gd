extends RefCounted
const SYSTEMS = ["Excavation","Rail/Infrastructure"]
static func busy(world: Node, id: String) -> bool:
	for path in SYSTEMS:
		var system: Node = world.get_node_or_null(path)
		if system!=null and system.busy(id): return true
	return false
static func controls(world: Node, id: String) -> bool:
	for path in SYSTEMS:
		var system: Node = world.get_node_or_null(path)
		if system!=null and system.controls(id): return true
	return false
