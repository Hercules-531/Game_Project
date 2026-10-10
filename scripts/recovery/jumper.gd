extends RefCounted
## Finite energy transfer: never conjures energy into a dead cell.
static func transfer(donor: Node, target: Node, amount: float = 0.25) -> float:
	if not is_finite(amount) or amount <= 0.0 or amount > 0.25:
		return 0.0
	if donor == null or target == null or donor == target or not donor.deployed or not target.deployed or donor.global_position.distance_to(target.global_position) > 3.0 or donor.module_efficiency("jumper") <= 0.0 or target.component_efficiency("cell") <= 0.0:
		return 0.0
	if target.destroyed() or donor.destroyed() or target.hull().external_power:
		return 0.0
	var paid := minf(amount,minf(maxf(0.0,donor.battery - 0.05),(target.hull().battery_kwh - target.battery) / 0.9))
	if paid <= 0.0:
		return 0.0
	donor.battery -= paid
	target.battery += paid * 0.9
	return paid * 0.9

