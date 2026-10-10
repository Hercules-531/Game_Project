extends RefCounted
static func can_strip(donor: Node, target: Node) -> bool:
	return donor != null and target != null and donor.deployed and donor.battery > 0.0 and donor.module_efficiency("torch") > 0.0 and donor.global_position.distance_to(target.global_position) <= 3.0 and donor.payload_remaining() >= 20.0

