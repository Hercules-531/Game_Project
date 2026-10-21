extends RefCounted
const Inventory = preload("res://scripts/simulation/inventory.gd")
static func initial() -> Dictionary:
	return {"condition":100.0,"tier":0,"forced":false,"contact":0.0}
static func risk(record: Dictionary, trace: float, defense: float = 1.0) -> float:
	if trace<40 or record.forced: return 0.0
	var pressure := clampf((trace-40.0)/60.0,0,1)
	return clampf((0.03+0.12*pressure)*(2.0-record.condition/100.0)/(1.0+2.0*record.tier)*defense,0.001,0.5)
static func valid(record: Variant) -> bool:
	return record is Dictionary and Inventory._number(record.get("condition")) and record.condition>=0 and record.condition<=100 and Inventory._integer(record.get("tier"),0,3) and record.get("forced") is bool and Inventory._number(record.get("contact")) and record.contact>=0 and record.contact<10.0
