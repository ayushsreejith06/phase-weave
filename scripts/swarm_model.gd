extends RefCounted
class_name SwarmModel

const Config = preload("res://scripts/config.gd")
const Agent = preload("res://scripts/agent.gd")

class Zone:
	var type: int
	var center: Vector2
	var radius: float
	var start_time: float
	var duration: float
	var strength: float

var agents: Array[Agent] = []
var bounds_size := Vector2.ZERO
var rng: RandomNumberGenerator
var _grid: Dictionary = {}
var _grid_size := Vector2i.ZERO
var zones: Array[Zone] = []
var _time := 0.0
var _zone_grid: Dictionary = {}
var _zone_grid_size := Vector2i.ZERO
var _zone_grid_dirty := true

func initialize(agent_count: int, p_bounds_size: Vector2, p_rng: RandomNumberGenerator) -> void:
	agents.clear()
	zones.clear()
	_time = 0.0
	_zone_grid.clear()
	_zone_grid_size = Vector2i.ZERO
	_zone_grid_dirty = true
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

	_time += dt
	_prune_zones()
	_rebuild_zone_grid_if_needed()
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

		var phase_steering = phase_rules.compute_steering(agent, neighbors, next_phase, bounds_size, rng)
		var zone_steering = _compute_zone_force(agent.position)
		var steering = phase_steering + zone_steering

		var velocity = agent.velocity + steering * dt
		velocity *= Config.DAMPING
		if velocity.length() > Config.MAX_SPEED:
			velocity = velocity.normalized() * Config.MAX_SPEED
		velocity = _ensure_min_speed(velocity)

		next_phases[i] = next_phase
		next_velocities[i] = velocity
		agent.local_density = local_density
		agent.steering_phase = phase_steering
		agent.steering_zone = zone_steering

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
	_zone_grid_dirty = true

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

func get_zones() -> Array[Zone]:
	return zones

func add_zone(zone_type: int, position: Vector2) -> void:
	if _refresh_zone(zone_type, position, Config.ZONE_RADIUS_GROWTH):
		return

	var zone = Zone.new()
	zone.type = zone_type
	zone.center = position
	zone.radius = Config.ZONE_RADIUS
	zone.start_time = _time
	zone.duration = Config.ZONE_DURATION
	zone.strength = Config.ZONE_FORCE_REPEL if zone_type == Config.ZoneType.REPULSE else Config.ZONE_FORCE_ATTRACT
	zones.append(zone)
	_zone_grid_dirty = true

func grow_zone_at(zone_type: int, position: Vector2, amount: float) -> void:
	if _refresh_zone(zone_type, position, amount):
		_zone_grid_dirty = true

func find_agent_at_position(position: Vector2, radius: float) -> Agent:
	var best_agent: Agent = null
	var best_dist_sq = radius * radius
	for agent in agents:
		var delta = position - agent.position
		var dist_sq = delta.length_squared()
		if dist_sq <= best_dist_sq:
			best_agent = agent
			best_dist_sq = dist_sq
	return best_agent

func _find_zone_index(zone_type: int, position: Vector2) -> int:
	var best_index := -1
	var best_dist_sq := INF
	for i in zones.size():
		var zone = zones[i]
		if zone.type != zone_type:
			continue
		var dist_sq = position.distance_squared_to(zone.center)
		if dist_sq <= zone.radius * zone.radius and dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_index = i
	return best_index

func _refresh_zone(zone_type: int, position: Vector2, radius_delta: float) -> bool:
	var refresh_index = _find_zone_index(zone_type, position)
	if refresh_index < 0:
		return false
	var zone = zones[refresh_index]
	zone.radius = min(zone.radius + radius_delta, Config.ZONE_RADIUS_MAX)
	zone.start_time = _time
	zone.duration = Config.ZONE_DURATION
	zones[refresh_index] = zone
	return true

func _prune_zones() -> void:
	if zones.is_empty():
		return
	for i in range(zones.size() - 1, -1, -1):
		var zone = zones[i]
		if _time - zone.start_time >= zone.duration:
			zones.remove_at(i)
			_zone_grid_dirty = true

func _compute_zone_force(position: Vector2) -> Vector2:
	if zones.is_empty():
		return Vector2.ZERO
	var best_force := Vector2.ZERO
	var best_strength := 0.0
	for zone in _candidate_zones(position):
		var to_center = zone.center - position
		var dist = to_center.length()
		if dist > zone.radius:
			continue
		var falloff = 1.0 - (dist / zone.radius)
		if Config.ZONE_FALLOFF_POWER != 1.0:
			falloff = pow(falloff, Config.ZONE_FALLOFF_POWER)
		var strength = zone.strength * falloff
		if strength <= best_strength:
			continue
		var dir: Vector2
		if dist > 0.0001:
			dir = to_center / dist
		else:
			dir = _random_direction()
		if zone.type == Config.ZoneType.REPULSE:
			dir = -dir
		best_strength = strength
		best_force = dir * strength
	return best_force

func _rebuild_zone_grid_if_needed() -> void:
	if not _zone_grid_dirty:
		return
	_zone_grid.clear()
	if bounds_size == Vector2.ZERO:
		return
	var cell_size = max(1.0, Config.ZONE_RADIUS_MAX)
	var size_x = max(1, int(ceil(bounds_size.x / cell_size)))
	var size_y = max(1, int(ceil(bounds_size.y / cell_size)))
	_zone_grid_size = Vector2i(size_x, size_y)
	for i in zones.size():
		var zone = zones[i]
		var cell = _zone_cell_for_position(zone.center, cell_size)
		if not _zone_grid.has(cell):
			_zone_grid[cell] = []
		_zone_grid[cell].append(i)
	_zone_grid_dirty = false

func _zone_cell_for_position(pos: Vector2, cell_size: float) -> Vector2i:
	var x = int(floor(pos.x / cell_size))
	var y = int(floor(pos.y / cell_size))
	x = clampi(x, 0, _zone_grid_size.x - 1)
	y = clampi(y, 0, _zone_grid_size.y - 1)
	return Vector2i(x, y)

func _candidate_zones(pos: Vector2) -> Array[Zone]:
	if _zone_grid_size == Vector2i.ZERO or _zone_grid.is_empty():
		return zones
	var results: Array[Zone] = []
	var cell_size = max(1.0, Config.ZONE_RADIUS_MAX)
	var base = _zone_cell_for_position(pos, cell_size)
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			var cell = Vector2i(base.x + ox, base.y + oy)
			if cell.x < 0 or cell.x >= _zone_grid_size.x:
				continue
			if cell.y < 0 or cell.y >= _zone_grid_size.y:
				continue
			if not _zone_grid.has(cell):
				continue
			for zone_index in _zone_grid[cell]:
				results.append(zones[zone_index])
	return results

func _random_direction() -> Vector2:
	var angle = rng.randf_range(0.0, TAU)
	return Vector2.RIGHT.rotated(angle)
