extends CanvasLayer
class_name UiOverlay

const Config = preload("res://scripts/config.gd")

signal start_requested
signal restart_requested
signal pause_toggled(paused: bool)
signal stats_toggled(enabled: bool)

@onready var start_button = get_node_or_null("Overlay/VBox/StartButton")
@onready var restart_button = get_node_or_null("Overlay/VBox/RestartButton")
@onready var pause_button = get_node_or_null("Overlay/VBox/PauseButton")
@onready var stats_toggle = get_node_or_null("Overlay/VBox/StatsToggle")
@onready var debug_label = get_node_or_null("Overlay/VBox/DebugLabel")
@onready var hover_viewport = get_node_or_null("HoverViewportContainer/HoverViewport")
@onready var hover_label = get_node_or_null("HoverViewportContainer/HoverViewport/HoverLayer/HoverLabel")
@onready var hover_backdrop = get_node_or_null("HoverViewportContainer/HoverViewport/HoverLayer/HoverBackdrop")
var _paused := false
var _stats_enabled := false

func _ready() -> void:
	if start_button != null:
		start_button.pressed.connect(_on_start_pressed)
	if restart_button != null:
		restart_button.pressed.connect(_on_restart_pressed)
	if pause_button != null:
		pause_button.pressed.connect(_on_pause_pressed)
		pause_button.visible = Config.ALLOW_PAUSE
	if stats_toggle != null:
		stats_toggle.toggled.connect(_on_stats_toggled)
		stats_toggle.button_pressed = false
	if debug_label != null:
		debug_label.visible = Config.SHOW_DEBUG_UI
	_setup_hover_viewport()
	if hover_label != null:
		hover_label.visible = false
		if hover_label is RichTextLabel:
			hover_label.bbcode_enabled = true
			hover_label.fit_content = true
			hover_label.scroll_active = false
			hover_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			hover_label.add_theme_constant_override("outline_size", 1)
			hover_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		hover_label.add_theme_color_override("default_color", Color(1.0, 1.0, 1.0, 1.0))
		hover_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		hover_label.add_theme_color_override("font_color_default", Color(1.0, 1.0, 1.0, 1.0))
		hover_label.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		hover_label.z_index = 2
	if hover_backdrop != null:
		hover_backdrop.visible = false
		hover_backdrop.z_index = 1

func _setup_hover_viewport() -> void:
	if hover_viewport == null:
		return
	hover_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	hover_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	hover_viewport.transparent_bg = true
	hover_viewport.size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_sync_hover_viewport_size)

func _sync_hover_viewport_size() -> void:
	if hover_viewport == null:
		return
	hover_viewport.size = get_viewport().get_visible_rect().size

func _on_start_pressed() -> void:
	start_requested.emit()

func _on_restart_pressed() -> void:
	restart_requested.emit()

func _on_pause_pressed() -> void:
	_paused = !_paused
	if pause_button != null:
		pause_button.text = "Resume" if _paused else "Pause"
	pause_toggled.emit(_paused)
	if hover_label != null and not _paused:
		hover_label.text = ""
		hover_label.visible = false
	if hover_backdrop != null and not _paused:
		hover_backdrop.visible = false

func _on_stats_toggled(enabled: bool) -> void:
	_stats_enabled = enabled
	if hover_label != null:
		hover_label.visible = enabled and _paused
		if not enabled:
			hover_label.text = ""
	stats_toggled.emit(enabled)

func set_paused(paused: bool) -> void:
	_paused = paused
	if pause_button != null:
		pause_button.text = "Resume" if _paused else "Pause"
	if hover_label != null and not _paused:
		hover_label.text = ""
		hover_label.visible = false
	if hover_backdrop != null and not _paused:
		hover_backdrop.visible = false

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

func set_hover_stats(text: String) -> void:
	if hover_label == null:
		return
	if not _stats_enabled or not _paused or text.strip_edges().is_empty():
		hover_label.text = ""
		hover_label.visible = false
		if hover_backdrop != null:
			hover_backdrop.visible = false
		return
	hover_label.text = text
	hover_label.visible = true
	if hover_backdrop != null:
		hover_backdrop.visible = true

func set_hover_stats_at(text: String, anchor_pos: Vector2) -> void:
	if hover_label == null:
		return
	if not _stats_enabled or not _paused or text.strip_edges().is_empty():
		hover_label.text = ""
		hover_label.visible = false
		if hover_backdrop != null:
			hover_backdrop.visible = false
		return
	hover_label.text = text
	var offset = Vector2(12.0, 10.0)
	var pos = anchor_pos + offset
	var size = _hover_content_size()
	var padding = Vector2(8.0, 6.0)
	var viewport_rect = get_viewport().get_visible_rect()
	if pos.x + size.x > viewport_rect.size.x:
		pos.x = max(0.0, anchor_pos.x - size.x - 12.0)
	if pos.y + size.y > viewport_rect.size.y:
		pos.y = max(0.0, anchor_pos.y - size.y - 12.0)
	if pos.x < 0.0:
		pos.x = 0.0
	if pos.y < 0.0:
		pos.y = 0.0
	hover_label.position = pos + padding
	hover_label.size = size
	hover_label.visible = true
	if hover_backdrop != null:
		hover_backdrop.position = pos
		hover_backdrop.size = size + padding * 2.0
		hover_backdrop.visible = true

func _hover_content_size() -> Vector2:
	if hover_label == null:
		return Vector2.ZERO
	if hover_label is RichTextLabel:
		var rich = hover_label as RichTextLabel
		return Vector2(
			max(1.0, rich.get_content_width()),
			max(1.0, rich.get_content_height())
		)
	return hover_label.get_minimum_size()

func is_point_over_hover(point: Vector2) -> bool:
	if hover_label == null or not hover_label.visible:
		return false
	var rect = Rect2(hover_label.global_position, _hover_content_size())
	return rect.has_point(point)

func is_point_over_ui(point: Vector2) -> bool:
	var overlay = get_node_or_null("Overlay")
	if overlay == null or not (overlay is Control):
		return false
	return overlay.get_global_rect().has_point(point)

func is_stats_enabled() -> bool:
	return _stats_enabled
