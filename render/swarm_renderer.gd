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
					draw_circle(agent.position, Config.RENDER_POINT_RADIUS, color)
				else:
					var end_pos = agent.position + vel * Config.RENDER_VELOCITY_LINE_SCALE
					draw_line(agent.position, end_pos, color, 1.0, true)
			Config.RenderStyle.CIRCLES:
				draw_circle(agent.position, Config.RENDER_CIRCLE_RADIUS, color)
			_:
				draw_circle(agent.position, Config.RENDER_POINT_RADIUS, color)

func _color_for_phase(phase: int) -> Color:
	match phase:
		Config.Phase.ALIGN:
			return Config.COLOR_ALIGN
		Config.Phase.REPEL:
			return Config.COLOR_REPEL
		_:
			return Config.COLOR_WANDER
