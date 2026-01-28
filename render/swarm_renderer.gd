extends Node2D
class_name SwarmRenderer

const Config = preload("res://scripts/config.gd")

var model: Object = null
@onready var overlay = get_node_or_null("../UiOverlay/Overlay")
var _density_image: Image = null
var _density_texture: ImageTexture = null
var _density_texture_size := Vector2i.ZERO
var _density_version := -1
var _perf_enabled := false
var _last_draw_ms := 0.0

func set_model(p_model: Object) -> void:
	model = p_model
	queue_redraw()

func set_perf_enabled(enabled: bool) -> void:
	_perf_enabled = enabled

func get_last_draw_time_ms() -> float:
	return _last_draw_ms

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var vp = get_viewport()
	var clear_mode = RenderingServer.VIEWPORT_CLEAR_ALWAYS
	if Config.TRAILS_ENABLED:
		clear_mode = RenderingServer.VIEWPORT_CLEAR_NEVER
	RenderingServer.viewport_set_clear_mode(vp.get_viewport_rid(), clear_mode)

func _draw() -> void:
	var perf_start := 0
	if _perf_enabled:
		perf_start = Time.get_ticks_usec()
	var viewport_rect = get_viewport_rect()
	if Config.TRAILS_ENABLED and viewport_rect.size != Vector2.ZERO:
		draw_rect(viewport_rect, Config.TRAIL_FADE_COLOR, true)

	if model == null:
		return
	if not model.has_method("get_agents"):
		return
	var agents = model.get_agents()
	if model.has_method("is_density_enabled") and model.is_density_enabled():
		if model.has_method("get_density_grid") and model.has_method("get_density_grid_size"):
			var density_version = -1
			if model.has_method("get_density_version"):
				density_version = model.get_density_version()
			_draw_density_glow(model.get_density_grid(), model.get_density_grid_size(), viewport_rect.size, density_version)
	var zones = []
	if model.has_method("get_zones"):
		zones = model.get_zones()
	_draw_zones(zones)
	if agents.is_empty():
		return

	var overlay_rect: Rect2
	var has_overlay = overlay != null and overlay is Control
	if has_overlay:
		overlay_rect = overlay.get_global_rect()

	for agent in agents:
		if has_overlay and overlay_rect.has_point(agent.position):
			continue
		var color = _color_with_density(_color_for_phase(agent.phase), agent.local_density)
		match Config.RENDER_STYLE:
			Config.RenderStyle.VELOCITY_LINES:
				var vel = agent.velocity
				if vel.length_squared() < 0.0001:
					_draw_agent_triangle(agent, color, Config.RENDER_POINT_RADIUS)
				else:
					var end_pos = agent.position + vel * Config.RENDER_VELOCITY_LINE_SCALE
					draw_line(agent.position, end_pos, color, 1.0, true)
			Config.RenderStyle.CIRCLES:
				_draw_agent_triangle(agent, color, Config.RENDER_CIRCLE_RADIUS)
			_:
				_draw_agent_triangle(agent, color, Config.RENDER_POINT_RADIUS)
	if _perf_enabled:
		_last_draw_ms = float(Time.get_ticks_usec() - perf_start) / 1000.0

func _color_for_phase(phase: int) -> Color:
	match phase:
		Config.Phase.ALIGN:
			return Config.COLOR_ALIGN
		Config.Phase.REPEL:
			return Config.COLOR_REPEL
		_:
			return Config.COLOR_WANDER

func _color_with_density(color: Color, local_density: float) -> Color:
	var t = clamp(local_density / max(0.0001, Config.DENSITY_THRESHOLD_HIGH), 0.0, 2.0)
	var boost = 1.0 + (t * Config.TRAIL_DENSITY_INTENSITY)
	var boosted = Color(
		clamp(color.r * boost, 0.0, 1.0),
		clamp(color.g * boost, 0.0, 1.0),
		clamp(color.b * boost, 0.0, 1.0),
		color.a
	)
	return boosted

func _draw_agent_triangle(agent, color: Color, radius: float) -> void:
	var dir = agent.velocity
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	var perp = Vector2(-dir.y, dir.x)
	var tip = agent.position + dir * (radius * 1.7)
	var base = agent.position - dir * (radius * 0.9)
	var left = base + perp * (radius * 0.9)
	var right = base - perp * (radius * 0.9)
	draw_polygon(PackedVector2Array([tip, left, right]), PackedColorArray([color, color, color]))

func _draw_zones(zones: Array) -> void:
	if zones == null or zones.is_empty():
		return
	for zone in zones:
		var base_color = Config.ZONE_COLOR_REPEL if zone.type == Config.ZoneType.REPULSE else Config.ZONE_COLOR_ATTRACT
		draw_circle(zone.center, zone.radius, base_color)
		var outer = base_color
		outer.a = Config.ZONE_GLOW_OUTER_ALPHA
		draw_circle(zone.center, zone.radius * 1.12, outer)

func _draw_density_glow(density_grid: PackedFloat32Array, grid_size: Vector2i, viewport_size: Vector2, version: int) -> void:
	if density_grid.is_empty() or grid_size == Vector2i.ZERO:
		return
	_ensure_density_texture(grid_size)
	if _density_image == null or _density_texture == null:
		return
	if version != _density_version:
		var p95 = _density_percentile(density_grid, Config.DENSITY_GLOW_PERCENTILE)
		if p95 <= 0.000001:
			return
		var index = 0
		for y in range(grid_size.y):
			for x in range(grid_size.x):
				var value = density_grid[index]
				index += 1
				if value <= 0.0:
					_density_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
					continue
				var t = clamp(value / p95, 0.0, 1.0)
				var alpha = lerp(Config.DENSITY_GLOW_ALPHA_MIN, Config.DENSITY_GLOW_ALPHA_MAX, t)
				_density_image.set_pixel(x, y, Color(t, 1.0 - t, 0.0, alpha))
		_density_texture.update(_density_image)
		_density_version = version
	draw_texture_rect(_density_texture, Rect2(Vector2.ZERO, viewport_size), false)

func _density_percentile(values: PackedFloat32Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var max_value := 0.0
	var non_zero := 0
	for i in values.size():
		var value = values[i]
		if value > 0.0:
			non_zero += 1
			if value > max_value:
				max_value = value
	if non_zero == 0 or max_value <= 0.0:
		return 0.0
	var bins = 64
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(bins)
	counts.fill(0)
	var inv_max = 1.0 / max_value
	for i in values.size():
		var value = values[i]
		if value <= 0.0:
			continue
		var t = clamp(value * inv_max, 0.0, 1.0)
		var bin = int(floor(t * float(bins - 1)))
		counts[bin] += 1
	var target = int(ceil(float(non_zero) * clamp(percentile, 0.0, 1.0)))
	var running = 0
	for b in range(bins):
		running += counts[b]
		if running >= target:
			var bin_value = (float(b) + 1.0) / float(bins)
			return bin_value * max_value
	return max_value

func _ensure_density_texture(grid_size: Vector2i) -> void:
	if _density_texture_size == grid_size and _density_image != null and _density_texture != null:
		return
	_density_texture_size = grid_size
	_density_image = Image.create(grid_size.x, grid_size.y, false, Image.FORMAT_RGBA8)
	_density_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_density_texture = ImageTexture.create_from_image(_density_image)
