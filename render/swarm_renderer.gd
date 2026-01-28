extends Node2D
class_name SwarmRenderer

const Config = preload("res://scripts/config.gd")

var model: Object = null
@onready var overlay = get_node_or_null("../UiOverlay/Overlay")

func set_model(p_model: Object) -> void:
	model = p_model
	queue_redraw()

func _ready() -> void:
	var vp = get_viewport()
	var clear_mode = RenderingServer.VIEWPORT_CLEAR_ALWAYS
	if Config.TRAILS_ENABLED:
		clear_mode = RenderingServer.VIEWPORT_CLEAR_NEVER
	RenderingServer.viewport_set_clear_mode(vp.get_viewport_rid(), clear_mode)

func _draw() -> void:
	var viewport_rect = get_viewport_rect()
	if Config.TRAILS_ENABLED and viewport_rect.size != Vector2.ZERO:
		draw_rect(viewport_rect, Config.TRAIL_FADE_COLOR, true)

	if model == null:
		return
	if not model.has_method("get_agents"):
		return
	var agents = model.get_agents()
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
		var color = _color_for_phase(agent.phase)
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

func _color_for_phase(phase: int) -> Color:
	match phase:
		Config.Phase.ALIGN:
			return Config.COLOR_ALIGN
		Config.Phase.REPEL:
			return Config.COLOR_REPEL
		_:
			return Config.COLOR_WANDER

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
