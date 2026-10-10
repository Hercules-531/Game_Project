extends Resource

@export var hulls: Array[Resource] = []
@export var modules: Array[Resource] = []
@export var opening: Array[Dictionary] = []


func hull(id: String) -> Resource:
	for definition in hulls:
		if definition.id == id:
			return definition
	return null


func module(id: String) -> Resource:
	for definition in modules:
		if definition.id == id:
			return definition
	return null
