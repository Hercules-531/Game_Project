extends Resource
@export var bands: Array[Resource] = []
func salvage(count: int = -1) -> Array:
	var result := []
	for i in (bands.size() if count<0 else count): result.append_array(bands[i].salvage())
	return result
func valid() -> bool:
	if bands.size()>6: return false
	for i in bands.size():
		if bands[i].index!=i or not bands[i].valid(): return false
		if i>0 and (bands[i].scrap_amount<=bands[i-1].scrap_amount or bands[i].scrap_sites.size()<bands[i-1].scrap_sites.size()): return false
	return true
