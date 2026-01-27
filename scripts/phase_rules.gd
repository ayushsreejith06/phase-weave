extends RefCounted
class_name PhaseRules

const Config = preload("res://scripts/config.gd")

func compute_phase(current_phase: int, local_density: float) -> int:
	if local_density < Config.DENSITY_THRESHOLD_LOW:
		return Config.Phase.WANDER
	if local_density > Config.DENSITY_THRESHOLD_HIGH:
		return Config.Phase.REPEL
	return Config.Phase.ALIGN

func compute_steering(
	agent,
	neighbors: Array,
	phase: int,
	bounds_size: Vector2,
	rng: RandomNumberGenerator
) -> Vector2:
	if neighbors.is_empty():
		return _wander_force(rng)

	var avg_pos := Vector2.ZERO
	var avg_vel := Vector2.ZERO
	var separation := Vector2.ZERO

	for neighbor in neighbors:
		avg_pos += neighbor.position
		avg_vel += neighbor.velocity
		var delta = _delta(agent.position, neighbor.position)
		var dist_sq = delta.length_squared()
		if dist_sq > 0.0001:
			separation -= delta / dist_sq

	avg_pos /= float(neighbors.size())
	avg_vel /= float(neighbors.size())

	var alignment = (avg_vel - agent.velocity).normalized()
	var cohesion = _delta(agent.position, avg_pos).normalized()
	var separation_dir = separation.normalized()
	var noise = _wander_force(rng)

	match phase:
		Config.Phase.WANDER:
			return (noise * Config.FORCE_WANDER) \
				+ (alignment * Config.FORCE_ALIGN * Config.WANDER_ALIGN_FACTOR)
		Config.Phase.ALIGN:
			return (alignment * Config.FORCE_ALIGN) \
				+ (cohesion * Config.FORCE_COHESION) \
				+ (separation_dir * Config.FORCE_SEPARATION * Config.ALIGN_SEPARATION_FACTOR) \
				+ (noise * Config.FORCE_WANDER * Config.ALIGN_NOISE_FACTOR)
		Config.Phase.REPEL:
			return (separation_dir * Config.FORCE_REPEL) \
				+ (noise * Config.FORCE_WANDER * Config.REPEL_NOISE_FACTOR)
		_:
			return noise * Config.FORCE_WANDER

func _wander_force(rng: RandomNumberGenerator) -> Vector2:
	var angle = rng.randf_range(0.0, TAU)
	return Vector2.RIGHT.rotated(angle) * Config.NOISE_MAGNITUDE

func _delta(a: Vector2, b: Vector2) -> Vector2:
	return b - a
