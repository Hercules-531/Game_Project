extends Node

signal changed
const BOOK = preload("res://resources/balance/recipes.tres")
var job: Dictionary = {}
@onready var inventory: Node = get_parent().get_node("Inventory")
@onready var life: Node = get_parent().get_node("LifeSupport")


func start(recipe_id: String) -> bool:
	if not job.is_empty() or not BOOK.recipes.has(recipe_id):
		return false
	var recipe: Dictionary = BOOK.recipes[recipe_id]
	if (recipe.kind == "module" and inventory.parts.size() >= 2000) or (recipe.kind == "hull" and int(inventory.hulls.get(recipe.output,0)) >= 32):
		return false
	if not inventory.spend_scrap(recipe.scrap):
		return false
	job = {"recipe":recipe_id,"remaining":recipe.seconds}
	life.external_load_kw = 0.6
	changed.emit()
	return true


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(seconds: float) -> void:
	if job.is_empty() or not is_finite(seconds) or seconds <= 0.0:
		return
	job.remaining = maxf(0.0,job.remaining - seconds * life.supplied_fraction)
	if job.remaining <= 0.0:
		var recipe: Dictionary = BOOK.recipes[job.recipe]
		job = {}
		life.external_load_kw = 0.0
		if recipe.kind == "module":
			inventory.add_part(recipe.output)
		else:
			inventory.hulls[recipe.output] = int(inventory.hulls.get(recipe.output,0)) + 1
			inventory.changed.emit()
	changed.emit()


func snapshot() -> Dictionary:
	return job.duplicate()


static func validate(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.is_empty():
		return true
	if not data.get("recipe") is String or not BOOK.recipes.has(data.recipe):
		return false
	var remaining: Variant = data.get("remaining")
	return (remaining is int or remaining is float) and is_finite(float(remaining)) and remaining > 0.0 and remaining <= BOOK.recipes[data.recipe].seconds


func restore(data: Dictionary) -> void:
	assert(validate(data))
	job = data.duplicate()
	life.external_load_kw = 0.6 if not job.is_empty() else 0.0
	changed.emit()
