extends RefCounted
## Resolve the same finite cell/tender/pylon sources used by defensive hardware.
static func source(world: Node, drone: Node, amount: float) -> Dictionary:
	if drone==null or not is_finite(amount) or amount<=0 or not drone.has_power(): return {}
	if not drone.hull().external_power:
		return {"owner":drone,"amount":amount} if drone.battery>=amount else {}
	var territory: Node = world.get_node("Territory")
	var paid := amount/0.9
	if territory.power_links.has(drone.identity):
		var site: Dictionary = territory.sites[int(territory.power_links[drone.identity])]
		return {"owner":site,"amount":paid} if site.battery>=paid else {}
	var tether: Node = world.get_node("PowerTether")
	var donor: Node = world.get_node("Fleet").drone(tether.links.get(drone.identity,""))
	return {"owner":donor,"amount":paid} if donor!=null and donor.battery>=paid else {}
static func available(world: Node, drone: Node, amount: float) -> bool:
	return not source(world,drone,amount).is_empty()
static func spend(world: Node, drone: Node, amount: float) -> bool:
	var resolved := source(world,drone,amount)
	if resolved.is_empty(): return false
	resolved.owner["battery"] = maxf(0,resolved.owner.get("battery")-resolved.amount)
	return true
