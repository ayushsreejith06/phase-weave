extends RefCounted
class_name Agent

const Config = preload("res://scripts/config.gd")

var position: Vector2
var velocity: Vector2
var phase: int
var energy: float

func _init(
	p_position := Vector2.ZERO,
	p_velocity := Vector2.ZERO,
	p_phase := Config.Phase.WANDER,
	p_energy := 0.0
) -> void:
	position = p_position
	velocity = p_velocity
	phase = p_phase
	energy = p_energy
