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
var _density_grid: PackedFloat32Array = PackedFloat32Array()
var _density_grid_size := Vector2i.ZERO
var _density_cell_size := Vector2.ONE
var _density_enabled := false
var _density_version := 0
var _memory_grid: PackedFloat32Array = PackedFloat32Array()
var _memory_buffer: PackedFloat32Array = PackedFloat32Array()
var _memory_grid_size := Vector2i.ZERO
var _memory_cell_size := Vector2.ONE
var _memory_enabled := Config.MEMORY_ENABLED_DEFAULT
var _memory_tick_accum := 0
var _density_tick_accum := 0

func initialize(agent_count: int, p_bounds_size: Vector2, p_rng: RandomNumberGenerator) -> void:
	agents.clear()
	zones.clear()
	_time = 0.0
	_zone_grid.clear()
	_zone_grid_size = Vector2i.ZERO
	_zone_grid_dirty = true
	bounds_size = p_bounds_size
	rng = p_rng
	_init_density_grid()
	_update_density_cell_size()
	_density_version = 0
	_memory_tick_accum = 0
	_density_tick_accum = 0
	_init_memory_grid()
	_update_memory_cell_size()

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
	if _memory_enabled:
		var memory_step = max(1, Config.MEMORY_UPDATE_EVERY_TICKS)
		_memory_tick_accum += 1
		if _memory_tick_accum >= memory_step:
			var memory_dt = dt * float(_memory_tick_accum)
			_apply_memory_decay(memory_dt)
			_memory_tick_accum = 0

	var density_step = max(1, Config.DENSITY_UPDATE_EVERY_TICKS)
	_density_tick_accum += 1
	var update_density = _density_enabled and _density_tick_accum >= density_step
	if update_density:
		_density_tick_accum = 0
		_clear_density_grid()

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
		var next_phase = phase_rules.compute_phase(agent.phase, local_density, agent.phase_time)

		var phase_steering = phase_rules.compute_steering(agent, neighbors, next_phase, bounds_size, rng, local_density)
		var memory_steering = Vector2.ZERO
		if _memory_enabled:
			memory_steering = _compute_memory_force(agent.position, next_phase)
		var zone_steering = _compute_zone_force(agent.position)
		var steering = phase_steering + memory_steering + zone_steering

		var velocity = _apply_turn_limit(agent.velocity, steering, dt)
		velocity *= Config.DAMPING
		if velocity.length() > Config.MAX_SPEED:
			velocity = velocity.normalized() * Config.MAX_SPEED
		velocity = _ensure_min_speed(velocity)

		next_phases[i] = next_phase
		next_velocities[i] = velocity
		agent.local_density = local_density
		agent.steering_phase = phase_steering
		agent.steering_memory = memory_steering
		agent.steering_zone = zone_steering

	for i in agents.size():
		var agent = agents[i]
		var previous_pos = agent.position
		if next_phases[i] != agent.phase:
			agent.phase = next_phases[i]
			agent.phase_time = 0.0
		else:
			agent.phase_time += dt
		agent.velocity = next_velocities[i]
		agent.position += agent.velocity * dt
		_contain_agent(agent)
		var distance_traveled = agent.position.distance_to(previous_pos)
		if _memory_enabled:
			var memory_amount = 0.0
			if distance_traveled > 0.0:
				memory_amount += distance_traveled * Config.MEMORY_DEPOSIT_PER_UNIT
			if memory_amount > 0.0:
				_deposit_memory_at(agent.position, memory_amount)
		if update_density:
			_deposit_density_at(agent.position)
	if update_density:
		_density_version += 1

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

func _apply_turn_limit(current_velocity: Vector2, steering: Vector2, dt: float) -> Vector2:
	var desired = current_velocity + steering * dt
	var desired_len = desired.length()
	if desired_len < 0.0001:
		return current_velocity
	var current_len = current_velocity.length()
	if current_len < 0.0001:
		return desired
	var current_dir = current_velocity / current_len
	var desired_dir = desired / desired_len
	var angle = current_dir.angle_to(desired_dir)
	var max_angle = Config.MAX_TURN_RATE * dt
	if abs(angle) <= max_angle:
		return desired
	var limited_dir = current_dir.rotated(clamp(angle, -max_angle, max_angle))
	return limited_dir * desired_len

func set_bounds_size(p_bounds_size: Vector2) -> void:
	bounds_size = p_bounds_size
	_zone_grid_dirty = true
	_update_density_cell_size()
	_update_memory_cell_size()

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
	_refresh_zone(zone_type, position, amount)

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
	var sum_force := Vector2.ZERO
	for zone in _candidate_zones(position):
		var to_center = zone.center - position
		var dist_sq = to_center.length_squared()
		if dist_sq > zone.radius * zone.radius:
			continue
		var dist = sqrt(dist_sq)
		var falloff = 1.0 - (dist / zone.radius)
		if Config.ZONE_FALLOFF_POWER != 1.0:
			falloff = pow(falloff, Config.ZONE_FALLOFF_POWER)
		var strength = zone.strength * falloff
		var dir: Vector2
		if dist > 0.0001:
			dir = to_center / dist
		else:
			dir = _random_direction()
		if zone.type == Config.ZoneType.REPULSE:
			dir = -dir
		sum_force += dir * strength
	if sum_force.length() > Config.ZONE_FORCE_CAP:
		sum_force = sum_force.normalized() * Config.ZONE_FORCE_CAP
	return sum_force

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

func set_density_enabled(enabled: bool) -> void:
	_density_enabled = enabled
	if not _density_enabled:
		_clear_density_grid()

func is_density_enabled() -> bool:
	return _density_enabled

func get_density_grid() -> PackedFloat32Array:
	return _density_grid

func get_density_grid_size() -> Vector2i:
	return _density_grid_size

func get_density_version() -> int:
	return _density_version

func get_memory_grid_size() -> Vector2i:
	return _memory_grid_size

func set_memory_enabled(enabled: bool) -> void:
	_memory_enabled = enabled
	if not _memory_enabled:
		if not _memory_grid.is_empty():
			_memory_grid.fill(0.0)

func _init_memory_grid() -> void:
	_memory_grid_size = Config.MEMORY_GRID_SIZE
	var total = _memory_grid_size.x * _memory_grid_size.y
	_memory_grid.resize(total)
	_memory_grid.fill(0.0)
	_memory_buffer.resize(total)
	_memory_buffer.fill(0.0)

func _init_density_grid() -> void:
	_density_grid_size = Config.DENSITY_GRID_SIZE
	var total = _density_grid_size.x * _density_grid_size.y
	_density_grid.resize(total)
	_density_grid.fill(0.0)

func _update_density_cell_size() -> void:
	if _density_grid_size == Vector2i.ZERO or bounds_size == Vector2.ZERO:
		_density_cell_size = Vector2.ONE
		return
	_density_cell_size = Vector2(
		max(1.0, bounds_size.x / float(_density_grid_size.x)),
		max(1.0, bounds_size.y / float(_density_grid_size.y))
	)

func _update_memory_cell_size() -> void:
	if _memory_grid_size == Vector2i.ZERO or bounds_size == Vector2.ZERO:
		_memory_cell_size = Vector2.ONE
		return
	_memory_cell_size = Vector2(
		max(1.0, bounds_size.x / float(_memory_grid_size.x)),
		max(1.0, bounds_size.y / float(_memory_grid_size.y))
	)

func _density_index(x: int, y: int) -> int:
	return x + y * _density_grid_size.x

func _memory_index(x: int, y: int) -> int:
	return x + y * _memory_grid_size.x

func _density_cell_for_position(pos: Vector2) -> Vector2i:
	var x = int(floor(pos.x / _density_cell_size.x))
	var y = int(floor(pos.y / _density_cell_size.y))
	x = clampi(x, 0, _density_grid_size.x - 1)
	y = clampi(y, 0, _density_grid_size.y - 1)
	return Vector2i(x, y)

func _memory_cell_for_position(pos: Vector2) -> Vector2i:
	var x = int(floor(pos.x / _memory_cell_size.x))
	var y = int(floor(pos.y / _memory_cell_size.y))
	x = clampi(x, 0, _memory_grid_size.x - 1)
	y = clampi(y, 0, _memory_grid_size.y - 1)
	return Vector2i(x, y)

func _clear_density_grid() -> void:
	if _density_grid.is_empty():
		return
	_density_grid.fill(0.0)

func _apply_memory_decay(dt: float) -> void:
	if _memory_grid.is_empty():
		return
	var decay = exp(-Config.MEMORY_DECAY_RATE * dt)
	for i in _memory_grid.size():
		_memory_grid[i] *= decay
	_apply_memory_diffusion()

func _apply_memory_diffusion() -> void:
	if _memory_grid.is_empty():
		return
	var diffusion = Config.MEMORY_DIFFUSION
	if diffusion <= 0.0001:
		return
	var width = _memory_grid_size.x
	var height = _memory_grid_size.y
	for y in range(height):
		for x in range(width):
			var index = _memory_index(x, y)
			var sum = _memory_grid[index]
			var count = 1.0
			if x > 0:
				sum += _memory_grid[index - 1]
				count += 1.0
			if x + 1 < width:
				sum += _memory_grid[index + 1]
				count += 1.0
			if y > 0:
				sum += _memory_grid[index - width]
				count += 1.0
			if y + 1 < height:
				sum += _memory_grid[index + width]
				count += 1.0
			var avg = sum / count
			_memory_buffer[index] = lerp(_memory_grid[index], avg, diffusion)
	for i in _memory_grid.size():
		_memory_grid[i] = _memory_buffer[i]

func _deposit_memory_at(pos: Vector2, amount: float) -> void:
	if not _memory_enabled:
		return
	if amount <= 0.0 or _memory_grid.is_empty():
		return
	var cell = _memory_cell_for_position(pos)
	var radius = Config.MEMORY_DEPOSIT_RADIUS
	if radius <= 0:
		_add_memory_cell(cell.x, cell.y, amount)
		return
	var radius_sq = radius * radius
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var dist_sq = dx * dx + dy * dy
			if dist_sq > radius_sq:
				continue
			var cx = clampi(cell.x + dx, 0, _memory_grid_size.x - 1)
			var cy = clampi(cell.y + dy, 0, _memory_grid_size.y - 1)
			var weight = 1.0 / (1.0 + float(dist_sq))
			_add_memory_cell(cx, cy, amount * weight)

func _add_memory_cell(x: int, y: int, amount: float) -> void:
	var index = _memory_index(x, y)
	_memory_grid[index] = min(_memory_grid[index] + amount, Config.MEMORY_MAX)

func _compute_memory_force(pos: Vector2, phase: int) -> Vector2:
	if not _memory_enabled:
		return Vector2.ZERO
	if _memory_grid.is_empty():
		return Vector2.ZERO
	var cell = _memory_cell_for_position(pos)
	var x = cell.x
	var y = cell.y
	var left = _memory_grid[_memory_index(max(x - 1, 0), y)]
	var right = _memory_grid[_memory_index(min(x + 1, _memory_grid_size.x - 1), y)]
	var down = _memory_grid[_memory_index(x, max(y - 1, 0))]
	var up = _memory_grid[_memory_index(x, min(y + 1, _memory_grid_size.y - 1))]
	var dx = right - left
	var dy = up - down
	var grad = Vector2(
		dx / max(0.0001, _memory_cell_size.x),
		dy / max(0.0001, _memory_cell_size.y)
	)
	if grad.length_squared() < 0.000001:
		return Vector2.ZERO
	var phase_strength = Config.MEMORY_STRENGTH_WANDER
	match phase:
		Config.Phase.ALIGN:
			phase_strength = Config.MEMORY_STRENGTH_ALIGN
		Config.Phase.REPEL:
			phase_strength = Config.MEMORY_STRENGTH_REPEL
	return grad * (Config.MEMORY_FORCE_STRENGTH * phase_strength)

func _deposit_density_at(pos: Vector2) -> void:
	if _density_grid.is_empty():
		return
	var cell = _density_cell_for_position(pos)
	var radius = Config.DENSITY_KERNEL_RADIUS
	if radius <= 0:
		_add_density_cell(cell.x, cell.y, 1.0)
		return
	var radius_sq = radius * radius
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var dist_sq = dx * dx + dy * dy
			if dist_sq > radius_sq:
				continue
			var cx = clampi(cell.x + dx, 0, _density_grid_size.x - 1)
			var cy = clampi(cell.y + dy, 0, _density_grid_size.y - 1)
			var weight = exp(-float(dist_sq) * Config.DENSITY_KERNEL_FALLOFF)
			_add_density_cell(cx, cy, weight)

func _add_density_cell(x: int, y: int, amount: float) -> void:
	var index = _density_index(x, y)
	_density_grid[index] += amount
