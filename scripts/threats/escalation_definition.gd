extends Resource
@export var decay_per_second := 0.015
@export var growth_intervals: Array[float] = [3600.0,3300.0,3000.0,2700.0,2400.0,2100.0]
@export var initial_growth: Array[int] = [0,1,1,2,2,3]
@export var reinforce_seconds := 60.0
