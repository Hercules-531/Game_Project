extends Resource
@export var index := 0
@export var title := ""
@export var route: Array[Vector3] = []
@export var shelters: Array[Vector3] = []
@export var scrap_sites: Array[Vector3] = []
@export var fuel_sites: Array[Vector3] = []
@export var ration_sites: Array[Vector3] = []
@export var scrap_amount := 16
@export var fuel_amount := 20.0
@export var ration_amount := 3.0
func salvage() -> Array:
	var result := []
	for kind in ["scrap","fuel","rations"]:
		var sites: Array = scrap_sites if kind=="scrap" else (fuel_sites if kind=="fuel" else ration_sites)
		var amount: float = scrap_amount if kind=="scrap" else (fuel_amount if kind=="fuel" else ration_amount)
		for i in sites.size():
			result.append({"id":"band_%02d_%s_%02d" % [index+1,kind,i+1],"kind":kind,"amount":int(amount) if kind=="scrap" else amount,"mass":amount*(1.5 if kind=="scrap" else (0.5 if kind=="fuel" else 2.0)),"at":sites[i]})
	return result
func valid() -> bool:
	if index<0 or index>=6 or title.is_empty() or route.size()<2 or scrap_sites.is_empty() or fuel_sites.is_empty() or ration_sites.is_empty() or scrap_amount<=0 or fuel_amount<=0 or ration_amount<=0: return false
	for point in route+shelters+scrap_sites+fuel_sites+ration_sites:
		if not point.is_finite() or absf(point.x)>55 or point.y<0 or point.y>0.1 or point.z> -maxf(10,index*100) or point.z< -(index+1)*100: return false
	# Reserve potential earned switchback apertures at every legal lining width.
	var portals = preload("res://scripts/infrastructure/ingress_layout.gd")
	for point in scrap_sites+fuel_sites+ration_sites:
		for i in range(1,route.size()):
			var a := Vector2(route[i-1].x,route[i-1].z)
			var delta := Vector2(route[i].x,route[i].z)-a
			var p := Vector2(point.x,point.z)
			var fraction := clampf((p-a).dot(delta)/maxf(0.0001,delta.length_squared()),0,1)
			if p.distance_to(a+delta*fraction)<1.8: return false
		for edge in 5:
			for kind in ["mouth","wall"]:
				if point.x>=0 and absf(point.z-(portals.row_for(kind,edge)+3))<1.7: return false
	return true
