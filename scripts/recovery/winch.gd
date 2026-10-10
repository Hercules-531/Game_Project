extends RefCounted
static func capacity(donor: Node) -> float:
	if donor.hull_id != "tracked":
		return 0.0
	return 650.0 * donor.module_efficiency("heavy_winch") * minf(1.0,donor.component_efficiency("joints"))
static func can_tow(donor: Node, target: Node) -> bool:
	return donor != null and target != null and donor != target and donor.deployed and donor.battery > 0.05 and donor.global_position.distance_to(target.global_position) <= 4.0 and capacity(donor) >= 300.0

