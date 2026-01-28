extends CanvasLayer
class_name UiOverlay

const Config = preload("res://scripts/config.gd")

signal start_requested
signal restart_requested
signal pause_toggled(paused: bool)
signal stats_toggled(enabled: bool)
signal density_toggled(enabled: bool)
signal memory_toggled(enabled: bool)
signal cohesion_ratio_changed(cohesion_ratio: float)
signal agent_count_changed(count: int)

@onready var start_button = get_node_or_null("Overlay/VBox/StartButton")
@onready var restart_button = get_node_or_null("Overlay/VBox/RestartButton")
@onready var stats_toggle = get_node_or_null("Overlay/VBox/StatsToggle")
@onready var density_toggle = get_node_or_null("Overlay/VBox/DensityToggle")
@onready var memory_toggle = get_node_or_null("Overlay/VBox/MemoryToggle")
@onready var title_label = get_node_or_null("Overlay/VBox/TitleLabel")
@onready var subtitle_label = get_node_or_null("Overlay/VBox/SubtitleLabel")
@onready var agents_label = get_node_or_null("Overlay/VBox/AgentsRow/AgentsLabel")
@onready var agents_input = get_node_or_null("Overlay/VBox/AgentsRow/AgentsInput")
@onready var cohesion_label = get_node_or_null("Overlay/VBox/CohesionLabel")
@onready var cohesion_slider = get_node_or_null("Overlay/VBox/CohesionSlider")
@onready var status_label = get_node_or_null("Overlay/VBox/StatusLabel")
@onready var divider = get_node_or_null("Overlay/VBox/Divider")
@onready var debug_label = get_node_or_null("Overlay/VBox/DebugLabel")
@onready var hover_viewport = get_node_or_null("HoverViewportContainer/HoverViewport")
@onready var hover_label = get_node_or_null("HoverViewportContainer/HoverViewport/HoverLayer/HoverLabel")
@onready var hover_backdrop = get_node_or_null("HoverViewportContainer/HoverViewport/HoverLayer/HoverBackdrop")
@onready var overlay_panel = get_node_or_null("Overlay")
@onready var overlay_backdrop = get_node_or_null("Overlay/Backdrop")
@onready var overlay_vbox = get_node_or_null("Overlay/VBox")
@onready var fps_panel = get_node_or_null("FpsPanel/FpsPanelBox")
@onready var fps_dot = get_node_or_null("FpsPanel/FpsRow/FpsDot")
@onready var fps_label = get_node_or_null("FpsPanel/FpsRow/FpsLabel")
var _paused := false
var _stats_enabled := false
var _density_enabled := false
var _pulse_time := 0.0
var _has_started := false
var _agent_count := Config.DEFAULT_AGENT_COUNT

const OVERLAY_PADDING = Vector2(8.0, 8.0)
const PANEL_RADIUS = 10
const PANEL_BG = Color(0.06, 0.08, 0.12, 0.86)
const PANEL_BORDER = Color(0.18, 0.24, 0.32, 0.9)
const TITLE_COLOR = Color(0.92, 0.95, 1.0, 1.0)
const SUBTITLE_COLOR = Color(0.62, 0.7, 0.82, 1.0)
const STATUS_COLOR = Color(0.7, 0.88, 0.7, 1.0)
const PULSE_SPEED = 1.1
const PULSE_AMPLITUDE = 0.06

func _ready() -> void:
	set_process(true)
	if start_button != null:
		start_button.pressed.connect(_on_start_pressed)
	if restart_button != null:
		restart_button.pressed.connect(_on_restart_pressed)
	if stats_toggle != null:
		stats_toggle.toggled.connect(_on_stats_toggled)
		stats_toggle.button_pressed = false
	if density_toggle != null:
		density_toggle.toggled.connect(_on_density_toggled)
		density_toggle.button_pressed = false
	if memory_toggle != null:
		memory_toggle.toggled.connect(_on_memory_toggled)
		memory_toggle.button_pressed = Config.MEMORY_ENABLED_DEFAULT
	if cohesion_slider != null:
		cohesion_slider.value_changed.connect(_on_cohesion_changed)
		_update_cohesion_label(cohesion_slider.value)
	if debug_label != null:
		debug_label.visible = Config.SHOW_DEBUG_UI
	if agents_input != null:
		_agent_count = Config.DEFAULT_AGENT_COUNT
		agents_input.text = str(_agent_count)
		agents_input.text_submitted.connect(_on_agent_count_submitted)
		agents_input.focus_exited.connect(_on_agent_count_focus_exited)
	_apply_ui_style()
	_sync_overlay_size()
	if overlay_vbox != null:
		overlay_vbox.resized.connect(_sync_overlay_size)
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

func _process(delta: float) -> void:
	_pulse_time += delta * PULSE_SPEED
	if overlay_backdrop == null:
		return
	var pulse = 1.0 + (sin(_pulse_time) * PULSE_AMPLITUDE)
	overlay_backdrop.self_modulate = Color(pulse, pulse, pulse, 1.0)
	if fps_label != null:
		fps_label.text = "FPS %d" % [int(Engine.get_frames_per_second())]

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
	if not _has_started:
		_has_started = true
		_paused = false
		if start_button != null:
			start_button.text = "Pause"
		start_requested.emit()
		_set_status("Running", true)
		return
	_paused = not _paused
	if start_button != null:
		start_button.text = "Start" if _paused else "Pause"
	pause_toggled.emit(_paused)
	_set_status("Paused" if _paused else "Running", not _paused)
	if hover_label != null and _paused:
		hover_label.text = ""
		hover_label.visible = false
	if hover_backdrop != null and _paused:
		hover_backdrop.visible = false

func _on_restart_pressed() -> void:
	restart_requested.emit()
	_set_status("Restarted", true)

func _on_stats_toggled(enabled: bool) -> void:
	_stats_enabled = enabled
	if hover_label != null:
		hover_label.visible = enabled and _paused
		if not enabled:
			hover_label.text = ""
	stats_toggled.emit(enabled)

func _on_density_toggled(enabled: bool) -> void:
	_density_enabled = enabled
	density_toggled.emit(enabled)

func _on_memory_toggled(enabled: bool) -> void:
	memory_toggled.emit(enabled)

func _on_cohesion_changed(value: float) -> void:
	_update_cohesion_label(value)
	var ratio = clamp(value / 100.0, 0.0, 1.0)
	cohesion_ratio_changed.emit(ratio)

func _on_agent_count_submitted(text: String) -> void:
	_apply_agent_count(text)

func _on_agent_count_focus_exited() -> void:
	if agents_input == null:
		return
	_apply_agent_count(agents_input.text)

func _apply_agent_count(text: String) -> void:
	if text.is_empty():
		return
	if not text.is_valid_int():
		return
	var value = int(text)
	if value <= 0:
		return
	if value == _agent_count:
		return
	_agent_count = value
	agent_count_changed.emit(value)

func set_paused(paused: bool) -> void:
	_paused = paused
	if start_button != null:
		start_button.text = "Start" if _paused else "Pause"
	_set_status("Paused" if _paused else "Running", not _paused)
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
	debug_label.text = "Seed: %d\nAvg speed: %.2f\nPhase W/A/R: %d / %d / %d" % [
		seed, avg_speed, wander, align, repel
	]
	if _paused and status_label != null:
		status_label.text = "Status: Paused"

func _set_status(text: String, running: bool) -> void:
	if status_label == null:
		return
	status_label.text = "Status: %s" % [text]
	status_label.add_theme_color_override("font_color", STATUS_COLOR if running else Color(0.9, 0.8, 0.6, 1.0))

func _update_cohesion_label(value: float) -> void:
	if cohesion_label == null:
		return
	var cohesion = int(round(value))
	var repel = 100 - cohesion
	cohesion_label.text = "Cohesion/Repel: %d/%d" % [cohesion, repel]

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

func _sync_overlay_size() -> void:
	if overlay_panel == null or overlay_vbox == null:
		return
	var content_size = overlay_vbox.get_combined_minimum_size()
	var target_size = content_size + OVERLAY_PADDING * 2.0
	overlay_panel.custom_minimum_size = target_size
	overlay_panel.size = target_size
	overlay_vbox.position = OVERLAY_PADDING
	overlay_vbox.size = content_size
	if overlay_backdrop != null:
		overlay_backdrop.size = target_size

func _apply_ui_style() -> void:
	if overlay_backdrop != null:
		var panel = StyleBoxFlat.new()
		panel.bg_color = PANEL_BG
		panel.border_color = PANEL_BORDER
		panel.border_width_left = 1
		panel.border_width_top = 1
		panel.border_width_right = 1
		panel.border_width_bottom = 1
		panel.corner_radius_bottom_left = PANEL_RADIUS
		panel.corner_radius_bottom_right = PANEL_RADIUS
		panel.corner_radius_top_left = PANEL_RADIUS
		panel.corner_radius_top_right = PANEL_RADIUS
		overlay_backdrop.add_theme_stylebox_override("panel", panel)
	if divider != null:
		divider.add_theme_color_override("separator_color", Color(0.2, 0.26, 0.34, 0.8))
	if title_label != null:
		title_label.add_theme_color_override("font_color", TITLE_COLOR)
		title_label.add_theme_font_size_override("font_size", 20)
	if subtitle_label != null:
		subtitle_label.add_theme_color_override("font_color", SUBTITLE_COLOR)
		subtitle_label.add_theme_font_size_override("font_size", 12)
	if status_label != null:
		status_label.add_theme_color_override("font_color", STATUS_COLOR)
	if debug_label != null:
		debug_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9, 1.0))
	if cohesion_label != null:
		cohesion_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95, 1.0))
	if cohesion_slider != null:
		cohesion_slider.add_theme_color_override("grabber", Color(0.85, 0.9, 1.0, 1.0))
		cohesion_slider.add_theme_color_override("grabber_highlight", Color(0.95, 0.98, 1.0, 1.0))
		cohesion_slider.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95, 1.0))
	for button in [start_button, restart_button]:
		if button == null:
			continue
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.16, 0.22, 1.0)
		style.border_color = Color(0.25, 0.34, 0.46, 1.0)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0))
		button.add_theme_font_size_override("font_size", 14)
	for toggle in [stats_toggle, density_toggle, memory_toggle]:
		if toggle == null:
			continue
		toggle.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95, 1.0))
		toggle.add_theme_font_size_override("font_size", 12)
	if fps_panel != null:
		var panel = StyleBoxFlat.new()
		panel.bg_color = PANEL_BG
		panel.border_color = PANEL_BORDER
		panel.border_width_left = 1
		panel.border_width_top = 1
		panel.border_width_right = 1
		panel.border_width_bottom = 1
		panel.corner_radius_bottom_left = PANEL_RADIUS
		panel.corner_radius_bottom_right = PANEL_RADIUS
		panel.corner_radius_top_left = PANEL_RADIUS
		panel.corner_radius_top_right = PANEL_RADIUS
		fps_panel.add_theme_stylebox_override("panel", panel)
	if fps_dot != null:
		fps_dot.color = Color(0.2, 0.9, 0.3, 1.0)
	if fps_label != null:
		fps_label.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7, 1.0))
		fps_label.add_theme_font_size_override("font_size", 12)
	if agents_label != null:
		agents_label.add_theme_color_override("font_color", SUBTITLE_COLOR)
		agents_label.add_theme_font_size_override("font_size", 12)
	if agents_input != null:
		agents_input.placeholder_text = "1000"
		agents_input.add_theme_color_override("font_color", TITLE_COLOR)
		agents_input.add_theme_font_size_override("font_size", 12)

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
		pass
	else:
		if overlay.get_global_rect().has_point(point):
			return true
	var fps_overlay = get_node_or_null("FpsPanel")
	if fps_overlay != null and fps_overlay is Control:
		return fps_overlay.get_global_rect().has_point(point)
	return false

func is_stats_enabled() -> bool:
	return _stats_enabled
