extends RefCounted
## Commands are leases. Loss, switching and exit invalidate all pending input.

var clock: float = 0.0
var packets: Array = []
var actions: Array = []
var received: Dictionary = {}


func advance(delta: float) -> void:
	clock += delta


func send(id: String, axes: Vector2, delay: float) -> void:
	packets.append({"id":id,"axes":axes,"due":clock + delay})


func send_action(id: String, kind: String, delay: float) -> void:
	if actions.size() < 32:
		actions.append({"id":id,"kind":kind,"due":clock + delay})


func receive(id: String, connected: bool) -> Vector2:
	if not connected:
		clear(id)
		return Vector2.ZERO
	for index in range(packets.size() - 1,-1,-1):
		var packet: Dictionary = packets[index]
		if packet.id == id and packet.due <= clock:
			if not received.has(id) or packet.due >= received[id].due:
				received[id] = packet
			packets.remove_at(index)
	if not received.has(id) or clock - received[id].due > 0.25:
		return Vector2.ZERO
	return received[id].axes


func ready_actions() -> Array:
	var ready := []
	for index in range(actions.size() - 1,-1,-1):
		if actions[index].due <= clock:
			ready.push_front(actions[index])
			actions.remove_at(index)
	return ready


func clear(id: String) -> void:
	received.erase(id)
	packets = packets.filter(func(packet: Dictionary): return packet.id != id)
	actions = actions.filter(func(packet: Dictionary): return packet.id != id)


func clear_all() -> void:
	packets.clear()
	actions.clear()
	received.clear()
