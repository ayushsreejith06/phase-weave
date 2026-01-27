extends CanvasLayer
class_name UiOverlay

const Config = preload("res://scripts/config.gd")

signal start_requested
signal restart_requested
signal pause_toggled(paused: bool)

@onready var start_button = get_node_or_null("Overlay/VBox/StartButton")
@onready var restart_button = get_node_or_null("Overlay/VBox/RestartButton")
@onready var pause_button = get_node_or_null("Overlay/VBox/PauseButton")
@onready var debug_label = get_node_or_null("Overlay/VBox/DebugLabel")
var _paused := false

func _ready() -> void:
	if start_button != null:
		start_button.pressed.connect(_on_start_pressed)
	if restart_button != null:
		restart_button.pressed.connect(_on_restart_pressed)
	if pause_button != null:
		pause_button.pressed.connect(_on_pause_pressed)
		pause_button.visible = Config.ALLOW_PAUSE
	if debug_label != null:
		debug_label.visible = Config.SHOW_DEBUG_UI

func _on_start_pressed() -> void:
	start_requested.emit()

func _on_restart_pressed() -> void:
	restart_requested.emit()

func _on_pause_pressed() -> void:
	_paused = !_paused
	if pause_button != null:
		pause_button.text = "Resume" if _paused else "Pause"
	pause_toggled.emit(_paused)

func set_paused(paused: bool) -> void:
	_paused = paused
	if pause_button != null:
		pause_button.text = "Resume" if _paused else "Pause"

func set_stats(stats: Dictionary) -> void:
	if debug_label == null:
		return
	var seed = int(stats.get("seed", 0))
	var agents = int(stats.get("agents", 0))
	var avg_speed = float(stats.get("avg_speed", 0.0))
	var wander = int(stats.get("wander", 0))
	var align = int(stats.get("align", 0))
	var repel = int(stats.get("repel", 0))
	debug_label.text = "Seed: %d\nAgents: %d\nAvg speed: %.2f\nPhase W/A/R: %d / %d / %d" % [
		seed, agents, avg_speed, wander, align, repel
	]
