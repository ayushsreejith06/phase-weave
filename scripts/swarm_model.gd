extends RefCounted
class_name SwarmModel

const Config = preload("res://scripts/config.gd")
const Agent = preload("res://scripts/agent.gd")

var agents: Array[Agent] = []
var bounds_size := Vector2.ZERO
var rng: RandomNumberGenerator
var _grid: Dictionary = {}
var _grid_size := Vector2i.ZERO

func initialize(agent_count: int, p_bounds_size: Vector2, p_rng: RandomNumberGenerator) -> void:
	agents.clear()
	bounds_size = p_bounds_size
	rng = p_rng

	var min_x = Config.SPAWN_PADDING
	var min_y = Config.SPAWN_PADDING
	var max_x = max(bounds_size.x - Config.SPAWN_PADDING, min_x)
	var max_y = max(bounds_size.y - Config.SPAWN_PADDING, min_y)

	for i in agent_count:
		var pos = Vector2(
			rng.randf_range(min_x, max_x),
			rng.randf_range(min_y, max_y)
		)
		var angle = rng.randf_range(0.0, TAU)
		var speed = rng.randf_range(Config.SPAWN_SPEED_MIN, Config.SPAWN_SPEED_MAX)
		var vel = Vector2.RIGHT.rotated(angle) * speed
		var agent = Agent.new(pos, vel, Config.Phase.WANDER, 0.0)
		agents.append(agent)

func step(dt: float, phase_rules) -> void:
	if bounds_size == Vector2.ZERO:
		return
	if phase_rules == null:
		return

	_build_grid()

	var next_phases: Array[int] = []
	var next_velocities: Array[Vector2] = []
	next_phases.resize(agents.size())
	next_velocities.resize(agents.size())

	var radius_sq = Config.NEIGHBOR_RADIUS * Config.NEIGHBOR_RADIUS
	var density_area = PI * radius_sq

	for i in agents.size():
		var agent = agents[i]
		var neighbors = _get_neighbors(i, agent.position, radius_sq)
		var local_density = (float(neighbors.size()) / density_area) * Config.DENSITY_SCALE
		var next_phase = phase_rules.compute_phase(agent.phase, local_density)

		var steering = phase_rules.compute_steering(agent, neighbors, next_phase, bounds_size, rng)

		var velocity = agent.velocity + steering * dt
		velocity *= Config.DAMPING
		if velocity.length() > Config.MAX_SPEED:
			velocity = velocity.normalized() * Config.MAX_SPEED
		velocity = _ensure_min_speed(velocity)

		next_phases[i] = next_phase
		next_velocities[i] = velocity

	for i in agents.size():
		var agent = agents[i]
		agent.phase = next_phases[i]
		agent.velocity = next_velocities[i]
		agent.position += agent.velocity * dt
		_contain_agent(agent)

func _contain_agent(agent: Agent) -> void:
	if agent.position.x < 0.0:
		agent.position.x = 0.0
		agent.velocity.x = abs(agent.velocity.x)
	elif agent.position.x > bounds_size.x:
		agent.position.x = bounds_size.x
		agent.velocity.x = -abs(agent.velocity.x)
	if agent.position.y < 0.0:
		agent.position.y = 0.0
		agent.velocity.y = abs(agent.velocity.y)
	elif agent.position.y > bounds_size.y:
		agent.position.y = bounds_size.y
		agent.velocity.y = -abs(agent.velocity.y)

func _ensure_min_speed(velocity: Vector2) -> Vector2:
	var speed = velocity.length()
	if speed >= Config.MIN_SPEED:
		return velocity
	if speed > 0.0001:
		return velocity.normalized() * Config.MIN_SPEED
	var angle = rng.randf_range(0.0, TAU)
	return Vector2.RIGHT.rotated(angle) * Config.MIN_SPEED

func set_bounds_size(p_bounds_size: Vector2) -> void:
	bounds_size = p_bounds_size

func _build_grid() -> void:
	_grid.clear()
	if Config.GRID_CELL_SIZE <= 0.0:
		return

	var size_x = max(1, int(ceil(bounds_size.x / Config.GRID_CELL_SIZE)))
	var size_y = max(1, int(ceil(bounds_size.y / Config.GRID_CELL_SIZE)))
	_grid_size = Vector2i(size_x, size_y)

	for i in agents.size():
		var cell = _cell_for_position(agents[i].position)
		if not _grid.has(cell):
			_grid[cell] = []
		_grid[cell].append(i)

func _cell_for_position(pos: Vector2) -> Vector2i:
	var x = int(floor(pos.x / Config.GRID_CELL_SIZE))
	var y = int(floor(pos.y / Config.GRID_CELL_SIZE))
	x = clampi(x, 0, _grid_size.x - 1)
	y = clampi(y, 0, _grid_size.y - 1)
	return Vector2i(x, y)

func _get_neighbors(index: int, pos: Vector2, radius_sq: float) -> Array[Agent]:
	var results: Array[Agent] = []
	if _grid_size == Vector2i.ZERO:
		return results

	var base = _cell_for_position(pos)
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			var cell = Vector2i(base.x + ox, base.y + oy)
			if cell.x < 0 or cell.x >= _grid_size.x:
				continue
			if cell.y < 0 or cell.y >= _grid_size.y:
				continue

			if not _grid.has(cell):
				continue
			for other_index in _grid[cell]:
				if other_index == index:
					continue
				var other = agents[other_index]
				var delta = _delta(pos, other.position)
				if delta.length_squared() <= radius_sq:
					results.append(other)
	return results

func _delta(a: Vector2, b: Vector2) -> Vector2:
	return b - a

func get_agents() -> Array[Agent]:
	return agents
