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

@onready var renderer = get_node_or_null("../SwarmRenderer")
@onready var ui_overlay = get_node_or_null("../UiOverlay")
@onready var viewport_size := get_viewport().get_visible_rect().size

func _ready() -> void:
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
		if ui_overlay.has_method("set_stats"):
			stats_updated.connect(ui_overlay.set_stats)

	model.initialize(Config.DEFAULT_AGENT_COUNT, viewport_size, rng)
	if renderer != null:
		renderer.queue_redraw()
	_emit_stats()

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
