extends RefCounted
const Inventory = preload("res://scripts/simulation/inventory.gd")
static func quote(condition: float, fault: bool, length: float) -> Dictionary:
	return {"scrap":maxi(1 if fault else 0,ceili((100-condition)*0.2)),"seconds":15.0+(100-condition)*0.5+length*0.05}
static func valid(job: Variant, length: float) -> bool:
	if not job is Dictionary or job.get("kind") not in ["rail","wire"] or not job.get("worker") is String or job.worker.is_empty() or job.worker.length()>80 or not job.get("fault") is bool: return false
	if not Inventory._number(job.get("condition")) or job.condition<0 or job.condition>100: return false
	var expected := quote(job.condition,job.fault,length)
	return expected.scrap>0 and job.get("scrap")==expected.scrap and Inventory._number(job.get("seconds")) and absf(job.seconds-expected.seconds)<0.000001 and Inventory._number(job.get("remaining")) and job.remaining>0 and job.remaining<=job.seconds
