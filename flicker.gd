@tool
extends AreaLight3D

@export var base_energy: float = 1.0
@export var flicker_strength: float = 0.3
@export var flicker_speed: float = 10.0

var time: float = 0.0

func _process(delta: float) -> void:
	time += delta * flicker_speed
	var noise := sin(time * 3.7) * cos(time * 2.3) * sin(time * 5.1)
	light_energy = base_energy + noise * flicker_strength
