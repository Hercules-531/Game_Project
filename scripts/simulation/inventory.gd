extends Node

signal changed
const CATALOG = preload("res://resources/drones/opening_fleet.tres")
var scrap: int = 80
var fuel: float = 60.0
var rations: float = 4.0
var hulls: Dictionary = {}
var next_serial: int = 4
var cells: Array = []
var next_cell_serial: int = 1
var parts: Array = [{"serial":1,"id":"sonar","condition":100.0},
	{"serial":2,"id":"thermal","condition":85.0},{"serial":3,"id":"cargo_rack","condition":100.0}]


func spend_scrap(amount: int) -> bool:
	if amount < 0 or scrap < amount:
		return false
	scrap -= amount
	changed.emit()
	return true


func part(serial: int) -> Dictionary:
	for item in parts:
		if item.serial == serial:
			return item
	return {}


func take_part(serial: int) -> Dictionary:
	var item := part(serial)
	if not item.is_empty():
		parts.erase(item)
		changed.emit()
	return item


func add_part(id: String, condition: float = 100.0) -> void:
	assert(CATALOG.module(id) != null and condition >= 0.0 and condition <= 100.0)
	parts.append({"serial":next_serial,"id":id,"condition":condition})
	next_serial += 1
	changed.emit()
func add_cell() -> void:
	cells.append({"serial":next_cell_serial,"charge":0.0})
	next_cell_serial += 1
	changed.emit()
func cell(serial: int) -> Dictionary:
	for pack in cells:
		if int(pack.serial)==serial: return pack
	return {}


func snapshot() -> Dictionary:
	return {"scrap":scrap,"fuel":fuel,"rations":rations,"hulls":hulls.duplicate(),
		"parts":parts.duplicate(true),"next_serial":next_serial,"cells":cells.duplicate(true),"next_cell_serial":next_cell_serial}


static func validate(data: Variant) -> bool:
	if not data is Dictionary or not _integer(data.get("scrap"),0,1000000) or not _integer(data.get("next_serial"),1,10000000):
		return false
	if not _number(data.get("fuel")) or data.fuel < 0 or data.fuel > 1000000 or not _number(data.get("rations")) or data.rations < 0 or data.rations > 1000000:
		return false
	if not data.get("hulls") is Dictionary or not data.get("parts") is Array or data.parts.size() > 2000:
		return false
	if data.has("cells") or data.has("next_cell_serial"):
		if not _integer(data.get("next_cell_serial"),1,10000000) or not validate_cells(data.get("cells"),int(data.next_cell_serial)): return false
	for id in data.hulls:
		if CATALOG.hull(id) == null or not _integer(data.hulls[id],0,32):
			return false
	var serials := {}
	for item in data.parts:
		if not item is Dictionary or not _integer(item.get("serial"),1,int(data.next_serial) - 1) or serials.has(item.serial):
			return false
		if CATALOG.module(str(item.get("id",""))) == null or not _number(item.get("condition")) or item.condition < 0 or item.condition > 100:
			return false
		serials[item.serial] = true
	return true
static func validate_cells(data: Variant, next_id: int = 10000000) -> bool:
	if not data is Array or data.size()>128: return false
	var seen := {}
	for pack in data:
		if not pack is Dictionary or not _integer(pack.get("serial"),1,next_id-1) or seen.has(pack.serial) or not _number(pack.get("charge")) or pack.charge<0 or pack.charge>1: return false
		seen[pack.serial] = true
	return true


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value) and value == int(value) and value >= minimum and value <= maximum


func restore(data: Dictionary) -> void:
	assert(validate(data))
	scrap = int(data.scrap)
	fuel = data.fuel
	rations = data.rations
	hulls = data.hulls.duplicate()
	parts = data.parts.duplicate(true)
	next_serial = int(data.next_serial)
	cells = data.get("cells",[]).duplicate(true)
	next_cell_serial = int(data.get("next_cell_serial",1))
	changed.emit()
