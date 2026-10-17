extends RefCounted


static func tier(drone: Node) -> int:
	return 2 if advanced(drone) else (1 if neural(drone) or "ccd" in drone.modules.values() else 0)
static func advanced(drone: Node) -> bool:
	return "multispectrum" in drone.modules.values()
static func clean(drone: Node) -> bool:
	return advanced(drone) or neural(drone)
static func working(drone: Node) -> bool:
	return neural(drone) or drone.module_efficiency("multispectrum")>0 or (not advanced(drone) and drone.module_efficiency("ccd")>0)
static func neural(drone: Node) -> bool:
	if drone.get_parent()==null or drone.get_parent().get_parent()==null: return false
	var artifacts: Node = drone.get_parent().get_parent().get_node_or_null("Artifacts")
	return artifacts!=null and artifacts.small(drone,"neural")
