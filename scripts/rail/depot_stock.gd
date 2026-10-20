extends Node
signal changed
const Inventory = preload("res://scripts/simulation/inventory.gd")
var allocator: Node
var scrap := 0
var fuel := 0.0
var rations := 0.0
var parts: Array = []
var cells: Array = []
func notify() -> void:
	changed.emit()
	if allocator!=null: allocator.changed.emit()
func spend_scrap(amount: int) -> bool:
	if amount<0 or amount>scrap: return false
	scrap -= amount
	notify()
	return true
func part(serial: int) -> Dictionary:
	for item in parts:
		if int(item.serial)==serial: return item
	return {}
func take_part(serial: int) -> Dictionary:
	var item := part(serial)
	if not item.is_empty():
		parts.erase(item)
		notify()
	return item
func add_part(id: String, condition: float = 100.0) -> void:
	assert(allocator!=null and Inventory.CATALOG.module(id)!=null and condition>=0 and condition<=100)
	parts.append({"serial":allocator.next_serial,"id":id,"condition":condition})
	allocator.next_serial += 1
	notify()
func cell(serial: int) -> Dictionary:
	for pack in cells:
		if int(pack.serial)==serial: return pack
	return {}
func snapshot() -> Dictionary:
	return {"scrap":scrap,"fuel":fuel,"rations":rations,"parts":parts.duplicate(true),"cells":cells.duplicate(true)}
static func validate(data: Variant) -> bool:
	if not data is Dictionary: return false
	return Inventory.validate({"scrap":data.get("scrap"),"fuel":data.get("fuel"),"rations":data.get("rations"),"parts":data.get("parts"),"cells":data.get("cells"),"hulls":{},"next_serial":10000000,"next_cell_serial":10000000})
func restore(data: Dictionary) -> void:
	assert(validate(data))
	scrap = int(data.scrap)
	fuel = data.fuel
	rations = data.rations
	parts = data.parts.duplicate(true)
	cells = data.cells.duplicate(true)
