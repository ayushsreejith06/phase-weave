extends RefCounted
class_name Agent

const Config = preload("res://scripts/config.gd")

var position: Vector2
var velocity: Vector2
var phase: int
var energy: float
var phase_time: float
var local_density: float
var steering_phase: Vector2
var steering_memory: Vector2
var steering_zone: Vector2

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
	phase_time = 0.0
	local_density = 0.0
	steering_phase = Vector2.ZERO
	steering_memory = Vector2.ZERO
	steering_zone = Vector2.ZERO
