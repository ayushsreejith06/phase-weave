extends Node
class_name SimulationController

const Config = preload("res://scripts/config.gd")
const SwarmModel = preload("res://scripts/swarm_model.gd")
const PhaseRules = preload("res://scripts/phase_rules.gd")

signal stats_updated(stats: Dictionary)

var rng := RandomNumberGenerator.new()
var model := SwarmModel.new()
var phase_rules := PhaseRules.new()
var tick_timer: Timer
var _paused := false
var _resize_timer: Timer
var _stats_enabled := false
var _held_zone_type := -1
var _density_glow_enabled := false
var _cohesion_ratio := 0.5

@onready var renderer = get_node_or_null("../SwarmRenderer")
@onready var ui_overlay = get_node_or_null("../UiOverlay")
@onready var viewport_size := get_viewport().get_visible_rect().size

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	rng.seed = Config.DEFAULT_SEED
	get_viewport().size_changed.connect(_on_viewport_resized)
	if Config.DEBUG_PRINT_SEED:
		print("Seed: %s" % [rng.seed])

	tick_timer = Timer.new()
	tick_timer.one_shot = false
	tick_timer.autostart = false
	tick_timer.wait_time = 1.0 / float(Config.TICKS_PER_SECOND)
	add_child(tick_timer)
	tick_timer.timeout.connect(_on_tick)

	_resize_timer = Timer.new()
	_resize_timer.one_shot = true
	_resize_timer.autostart = false
	_resize_timer.wait_time = 0.15
	add_child(_resize_timer)
	_resize_timer.timeout.connect(_apply_resize)

	if renderer != null and renderer.has_method("set_model"):
		renderer.set_model(model)

	if ui_overlay != null:
		if ui_overlay.has_signal("start_requested"):
			ui_overlay.start_requested.connect(_on_start_requested)
		if ui_overlay.has_signal("restart_requested"):
			ui_overlay.restart_requested.connect(_on_restart_requested)
		if ui_overlay.has_signal("pause_toggled"):
			ui_overlay.pause_toggled.connect(_on_pause_toggled)
		if ui_overlay.has_signal("stats_toggled"):
			ui_overlay.stats_toggled.connect(_on_stats_toggled)
		if ui_overlay.has_signal("density_toggled"):
			ui_overlay.density_toggled.connect(_on_density_toggled)
		if ui_overlay.has_signal("cohesion_ratio_changed"):
			ui_overlay.cohesion_ratio_changed.connect(_on_cohesion_ratio_changed)
		if ui_overlay.has_method("set_stats"):
			stats_updated.connect(ui_overlay.set_stats)

	model.initialize(Config.DEFAULT_AGENT_COUNT, viewport_size, rng)
	model.set_density_enabled(_density_glow_enabled)
	phase_rules.set_cohesion_ratio(_cohesion_ratio)
	if renderer != null:
		renderer.queue_redraw()
	_emit_stats()

func _process(_delta: float) -> void:
	_update_hover_stats()
	_update_held_zone(_delta)

func _on_start_requested() -> void:
	if _paused and ui_overlay != null and ui_overlay.has_method("set_paused"):
		ui_overlay.set_paused(false)
		_paused = false
	if tick_timer != null:
		tick_timer.start()

func _on_restart_requested() -> void:
	if tick_timer != null:
		tick_timer.stop()
	if ui_overlay != null and ui_overlay.has_method("set_paused"):
		ui_overlay.set_paused(false)
	_paused = false
	if Config.RESEED_ON_RESTART:
		rng.randomize()
	else:
		rng.seed = Config.DEFAULT_SEED
	if Config.DEBUG_PRINT_SEED:
		print("Seed: %s" % [rng.seed])
	model.initialize(Config.DEFAULT_AGENT_COUNT, viewport_size, rng)
	model.set_density_enabled(_density_glow_enabled)
	phase_rules.set_cohesion_ratio(_cohesion_ratio)
	if renderer != null:
		renderer.queue_redraw()
	_emit_stats()

func _on_pause_toggled(paused: bool) -> void:
	if tick_timer == null:
		return
	_paused = paused
	if paused:
		tick_timer.stop()
	else:
		tick_timer.start()
	if renderer != null:
		renderer.queue_redraw()

func _on_stats_toggled(enabled: bool) -> void:
	_stats_enabled = enabled
	if ui_overlay != null and ui_overlay.has_method("set_hover_stats") and not enabled:
		ui_overlay.set_hover_stats("")

func _on_density_toggled(enabled: bool) -> void:
	_density_glow_enabled = enabled
	model.set_density_enabled(enabled)
	if renderer != null:
		renderer.queue_redraw()

func _on_cohesion_ratio_changed(ratio: float) -> void:
	_cohesion_ratio = ratio
	phase_rules.set_cohesion_ratio(ratio)

func _on_tick() -> void:
	model.step(Config.TICK_DT, phase_rules)
	if renderer != null:
		renderer.queue_redraw()
	_emit_stats()

func _emit_stats() -> void:
	if stats_updated.get_connections().is_empty():
		return
	if _paused:
		return
	var agents = model.get_agents()
	if agents.is_empty():
		return

	var count_wander := 0
	var count_align := 0
	var count_repel := 0
	var speed_sum := 0.0

	for agent in agents:
		speed_sum += agent.velocity.length()
		match agent.phase:
			Config.Phase.ALIGN:
				count_align += 1
			Config.Phase.REPEL:
				count_repel += 1
			_:
				count_wander += 1

	var avg_speed = speed_sum / float(agents.size())
	var stats = {
		"seed": rng.seed,
		"agents": agents.size(),
		"avg_speed": avg_speed,
		"wander": count_wander,
		"align": count_align,
		"repel": count_repel
	}
	stats_updated.emit(stats)

func _on_viewport_resized() -> void:
	if _resize_timer == null:
		return
	_resize_timer.start()

func _apply_resize() -> void:
	viewport_size = get_viewport().get_visible_rect().size
	model.set_bounds_size(viewport_size)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = event.position
		if ui_overlay != null and ui_overlay.has_method("is_point_over_ui"):
			if ui_overlay.is_point_over_ui(mouse_pos):
				return
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				model.add_zone(Config.ZoneType.REPULSE, mouse_pos)
				_held_zone_type = Config.ZoneType.REPULSE
				if renderer != null:
					renderer.queue_redraw()
			MOUSE_BUTTON_RIGHT:
				model.add_zone(Config.ZoneType.ATTRACT, mouse_pos)
				_held_zone_type = Config.ZoneType.ATTRACT
				if renderer != null:
					renderer.queue_redraw()
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_held_zone_type = -1

func _update_hover_stats() -> void:
	if not _stats_enabled or not _paused:
		return
	if ui_overlay == null or not ui_overlay.has_method("set_hover_stats_at"):
		return
	var mouse_pos = get_viewport().get_mouse_position()
	if ui_overlay.has_method("is_point_over_ui") and ui_overlay.is_point_over_ui(mouse_pos):
		ui_overlay.set_hover_stats("")
		return
	var agent = model.find_agent_at_position(mouse_pos, Config.HOVER_PICK_RADIUS)
	if agent == null:
		ui_overlay.set_hover_stats("")
		return
	var dist_sq = mouse_pos.distance_squared_to(agent.position)
	if dist_sq > Config.HOVER_PICK_RADIUS * Config.HOVER_PICK_RADIUS:
		ui_overlay.set_hover_stats("")
		return
	var phase_name = _phase_name(agent.phase)
	var phase_color = _phase_color(agent.phase)
	var speed = agent.velocity.length()
	var text = "Phase: [color=%s]%s[/color]\nPos: %.1f, %.1f\nSpeed: %.1f\nVel: %.1f, %.1f\nDensity: %.2f\nSteer phase: %.2f, %.2f\nSteer memory: %.2f, %.2f\nSteer zone: %.2f, %.2f" % [
		phase_color.to_html(false),
		phase_name,
		agent.position.x, agent.position.y,
		speed,
		agent.velocity.x, agent.velocity.y,
		agent.local_density,
		agent.steering_phase.x, agent.steering_phase.y,
		agent.steering_memory.x, agent.steering_memory.y,
		agent.steering_zone.x, agent.steering_zone.y
	]
	ui_overlay.set_hover_stats_at(text, agent.position)

func _update_held_zone(delta: float) -> void:
	if _held_zone_type < 0:
		return
	var mouse_pos = get_viewport().get_mouse_position()
	if ui_overlay != null and ui_overlay.has_method("is_point_over_ui"):
		if ui_overlay.is_point_over_ui(mouse_pos):
			return
	model.grow_zone_at(_held_zone_type, mouse_pos, Config.ZONE_GROW_PER_SECOND * delta)
	if renderer != null:
		renderer.queue_redraw()

func _phase_name(phase: int) -> String:
	match phase:
		Config.Phase.ALIGN:
			return "Align"
		Config.Phase.REPEL:
			return "Repel"
		_:
			return "Wander"

func _phase_color(phase: int) -> Color:
	match phase:
		Config.Phase.ALIGN:
			return Config.COLOR_ALIGN
		Config.Phase.REPEL:
			return Config.COLOR_REPEL
		_:
			return Config.COLOR_WANDER
