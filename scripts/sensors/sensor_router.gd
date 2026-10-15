extends RefCounted


static func tier(drone: Node) -> int:
	return 1 if neural(drone) or "ccd" in drone.modules.values() else 0
static func neural(drone: Node) -> bool:
	if drone.get_parent()==null or drone.get_parent().get_parent()==null: return false
	var artifacts: Node = drone.get_parent().get_parent().get_node_or_null("Artifacts")
	return artifacts!=null and artifacts.small(drone,"neural")
