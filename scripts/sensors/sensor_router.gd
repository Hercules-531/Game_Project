extends RefCounted


static func tier(drone: Node) -> int:
	return 1 if "ccd" in drone.modules.values() else 0
