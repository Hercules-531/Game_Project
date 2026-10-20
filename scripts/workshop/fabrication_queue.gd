extends Node

signal changed
const BOOK = preload("res://resources/balance/recipes.tres")
var job: Dictionary = {}
@onready var inventory: Node = get_parent().get_node("Inventory")
@onready var life: Node = get_parent().get_node("LifeSupport")

func _ready() -> void:
	life.energy_step.connect(_cell_energy_step)

func _cell_energy_step(fraction: float) -> void:
	if not job.is_empty() and BOOK.recipes[job.recipe].kind=="cell": _progress(clampf(fraction,0,1))


func start(recipe_id: String) -> bool:
	if not job.is_empty() or not BOOK.recipes.has(recipe_id):
		return false
	var research: Node = get_parent().get_node_or_null("Research")
	if research != null and not research.permits_recipe(recipe_id): return false
	var recipe: Dictionary = BOOK.recipes[recipe_id]
	if (recipe.kind == "module" and inventory.parts.size() >= 2000) or (recipe.kind == "hull" and int(inventory.hulls.get(recipe.output,0)) >= 32):
		return false
	if recipe.kind=="cell" and (inventory.cells.size()>=128 or inventory.next_cell_serial>=10000000): return false
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
	if BOOK.recipes[job.recipe].kind=="cell": return
	_progress(seconds*life.supplied_fraction)

func _progress(paid_seconds: float) -> void:
	job.remaining = maxf(0.0,job.remaining - paid_seconds)
	if job.remaining <= 0.0:
		var recipe: Dictionary = BOOK.recipes[job.recipe]
		job = {}
		life.external_load_kw = 0.0
		if recipe.kind == "module":
			inventory.add_part(recipe.output)
		elif recipe.kind=="cell":
			inventory.add_cell()
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
