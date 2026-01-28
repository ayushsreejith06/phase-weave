extends RefCounted
class_name PhaseRules

const Config = preload("res://scripts/config.gd")

var _cohesion_ratio := 0.5

func set_cohesion_ratio(ratio: float) -> void:
	_cohesion_ratio = clamp(ratio, 0.0, 1.0)

func compute_phase(current_phase: int, local_density: float, phase_time: float) -> int:
	if phase_time < Config.PHASE_MIN_DURATION:
		return current_phase
	var low = Config.DENSITY_THRESHOLD_LOW
	var high = Config.DENSITY_THRESHOLD_HIGH
	var hysteresis = Config.DENSITY_HYSTERESIS
	if _cohesion_ratio >= 0.999:
		if local_density > low + hysteresis:
			return Config.Phase.ALIGN
		return Config.Phase.WANDER
	if _cohesion_ratio <= 0.001:
		if local_density > high:
			return Config.Phase.REPEL
		return Config.Phase.WANDER
	match current_phase:
		Config.Phase.WANDER:
			if local_density > high:
				return Config.Phase.REPEL
			if local_density > low + hysteresis:
				return Config.Phase.ALIGN
			return Config.Phase.WANDER
		Config.Phase.ALIGN:
			if local_density < low - hysteresis:
				return Config.Phase.WANDER
			if local_density > high + hysteresis:
				return Config.Phase.REPEL
			return Config.Phase.ALIGN
		Config.Phase.REPEL:
			if local_density < low:
				return Config.Phase.WANDER
			if local_density < high - hysteresis:
				return Config.Phase.ALIGN
			return Config.Phase.REPEL
		_:
			return Config.Phase.WANDER

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
	var lattice := Vector2.ZERO

	for neighbor in neighbors:
		avg_pos += neighbor.position
		avg_vel += neighbor.velocity
		var delta = _delta(agent.position, neighbor.position)
		var dist_sq = delta.length_squared()
		if dist_sq > 0.0001:
			separation -= delta / dist_sq
			var dist = sqrt(dist_sq)
			var dir = delta / dist
			var offset = (dist - Config.TRIANGLE_LATTICE_DISTANCE) / Config.TRIANGLE_LATTICE_DISTANCE
			lattice += dir * offset

	avg_pos /= float(neighbors.size())
	avg_vel /= float(neighbors.size())
	lattice /= float(neighbors.size())

	var alignment = (avg_vel - agent.velocity).normalized()
	var cohesion = _delta(agent.position, avg_pos).normalized()
	var separation_dir = separation.normalized()
	var noise = _wander_force(rng)
	var forward = agent.velocity.normalized() if agent.velocity.length_squared() > 0.0001 else _wander_force(rng).normalized()
	var cohesion_scale = _cohesion_ratio
	var repel_scale = 1.0 - _cohesion_ratio

	match phase:
		Config.Phase.WANDER:
			return (noise * Config.FORCE_WANDER) \
				+ (alignment * Config.FORCE_ALIGN * Config.WANDER_ALIGN_FACTOR) \
				+ (cohesion * Config.FORCE_COHESION * Config.WANDER_COHESION_FACTOR * cohesion_scale) \
				+ (forward * Config.FORCE_FORWARD)
		Config.Phase.ALIGN:
			return (alignment * Config.FORCE_ALIGN) \
				+ (cohesion * Config.FORCE_COHESION * cohesion_scale) \
				+ (separation_dir * Config.FORCE_SEPARATION * Config.ALIGN_SEPARATION_FACTOR * repel_scale) \
				+ (lattice * Config.FORCE_ALIGN * Config.ALIGN_TRIANGLE_LATTICE_FACTOR) \
				+ (noise * Config.FORCE_WANDER * Config.ALIGN_NOISE_FACTOR) \
				+ (forward * Config.FORCE_FORWARD)
		Config.Phase.REPEL:
			return (separation_dir * Config.FORCE_REPEL * repel_scale) \
				+ (noise * Config.FORCE_WANDER * Config.REPEL_NOISE_FACTOR) \
				+ (forward * Config.FORCE_FORWARD)
		_:
			return noise * Config.FORCE_WANDER

func _wander_force(rng: RandomNumberGenerator) -> Vector2:
	var angle = rng.randf_range(0.0, TAU)
	return Vector2.RIGHT.rotated(angle) * Config.NOISE_MAGNITUDE

func _delta(a: Vector2, b: Vector2) -> Vector2:
	return b - a
