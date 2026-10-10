extends RefCounted

static func can_load(drone: Node, mass: float) -> bool:
	if drone == null or not drone.deployed or not drone.has_power() or mass <= 0.0 or mass > drone.payload_remaining():
		return false
	if drone.module_efficiency("cargo_rack") > 0.0:
		return true
	return drone.cargo_kg <= 0.000001 and drone.module_efficiency("winch") > 0.0 and mass <= 50.0 * drone.module_efficiency("winch")
