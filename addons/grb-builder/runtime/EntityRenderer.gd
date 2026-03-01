extends Control
class_name EntityRenderer
## Animated entity renderer — jitter, line-drop, phase-based visibility.
##
## Renders any wireframe entity
## with procedural animation effects:
##   - Vertex jitter (breathing sine + FastNoiseLite glitch)
##   - Stochastic line-drop (lines randomly omitted per frame)
##   - Phase coloring (dim → shadow → full)
##   - Flicker
##
## Usage:
##   1. Add EntityRenderer as a child of your WireframeCanvas or scene.
##   2. Register entity drawers: register_entity("id", callable)
##      Callable signature: (x, y, w, h, frame, color, renderer) -> void
##   3. Call show_entity("id") to display.

const BASE_GREEN := Color(0.2, 1.0, 0.2, 1.0)
const DIM_GREEN := Color(0.14, 0.55, 0.14, 1.0)
const SHADOW_COLOR := Color(0.08, 0.3, 0.08, 0.35)

enum Phase { ABSENT, LINE_DROP, SHADOW, FULL }
enum Frame { IDLE, ACTIVE, AGGRESSIVE, DISSOLVE }

var _entity_drawers: Dictionary = {}
var _visible_entity: String = ""
var _entity_frame: int = Frame.IDLE
var _alpha: float = 0.0
var _target_alpha: float = 0.0
var _phase: int = Phase.ABSENT

# Flicker
var _flicker_on: bool = true
var _flicker_timer: float = 0.0

# Dissolve
var _dissolving: bool = false
var _dissolve_timer: float = 0.0

# Jitter
var _jitter_noise: FastNoiseLite
var _jitter_time: float = 0.0
var _breathing_time: float = 0.0

# Line-drop
var _line_drop_seed: int = 0
var _line_drop_timer: float = 0.0

@export var alpha_lerp_speed: float = 2.0
@export var flicker_base_rate: float = 0.15
@export var dissolve_duration: float = 2.0

@export_group("Jitter")
@export var breathe_hz: float = 0.8
@export var breathe_amp: float = 1.5
@export var glitch_scale: float = 3.0
@export var glitch_speed: float = 4.0

@export_group("Line Drop")
@export var line_drop_max: float = 0.45
@export var line_drop_reseed_rate: float = 0.12

@export_group("Visibility")
@export var jitter_strength: float = 0.5
@export var line_drop_rate: float = 0.2

# Rendering area (fraction of parent size)
@export_group("Layout")
@export var entity_x_frac: float = 0.50
@export var entity_y_frac: float = 0.08
@export var entity_w_frac: float = 0.48
@export var entity_h_frac: float = 0.82


func _ready() -> void:
	_jitter_noise = FastNoiseLite.new()
	_jitter_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_jitter_noise.frequency = 0.05
	_jitter_noise.seed = randi()


func _process(delta: float) -> void:
	_alpha = lerpf(_alpha, _target_alpha, delta * alpha_lerp_speed)

	_update_flicker(delta)
	_update_jitter(delta)

	if _dissolving:
		_dissolve_timer += delta
		if _dissolve_timer >= dissolve_duration:
			_dissolving = false
			_visible_entity = ""
			_alpha = 0.0
			_phase = Phase.ABSENT

	if _visible_entity != "" or _dissolving:
		queue_redraw()


func _draw() -> void:
	if _visible_entity == "" and not _dissolving:
		return
	var effective_alpha: float = _alpha
	if not _flicker_on:
		effective_alpha *= 0.3
	if _dissolving:
		effective_alpha *= (1.0 - _dissolve_timer / dissolve_duration)
	if effective_alpha < 0.01:
		return

	var entity_color := Color(BASE_GREEN.r, BASE_GREEN.g, BASE_GREEN.b, effective_alpha)

	var gx: float = size.x * entity_x_frac
	var gy: float = size.y * entity_y_frac
	var gw: float = size.x * entity_w_frac
	var gh: float = size.y * entity_h_frac

	if _entity_drawers.has(_visible_entity):
		_entity_drawers[_visible_entity].call(gx, gy, gw, gh, _entity_frame, entity_color, self)
	else:
		_draw_placeholder(gx, gy, gw, gh, entity_color)


# ── Public API ──

func register_entity(entity_id: String, drawer: Callable) -> void:
	_entity_drawers[entity_id] = drawer


func show_entity(entity_id: String, frame: int = Frame.ACTIVE) -> void:
	_visible_entity = entity_id
	_entity_frame = frame
	_target_alpha = 1.0
	_alpha = 0.8
	_phase = Phase.FULL
	_dissolving = false
	queue_redraw()


func dissolve_entity(entity_id: String) -> void:
	_visible_entity = entity_id
	_entity_frame = Frame.DISSOLVE
	_dissolving = true
	_dissolve_timer = 0.0
	_alpha = 1.0
	_target_alpha = 0.0
	_phase = Phase.FULL
	queue_redraw()


func hide_entity() -> void:
	_target_alpha = 0.0
	_dissolving = false


func set_phase(phase: int) -> void:
	_phase = phase
	match phase:
		Phase.ABSENT:
			_target_alpha = 0.0
		Phase.LINE_DROP:
			_target_alpha = 0.55
		Phase.SHADOW:
			_target_alpha = 0.65
		Phase.FULL:
			_target_alpha = 1.0


func set_frame(frame: int) -> void:
	_entity_frame = frame
	queue_redraw()


func set_jitter_strength(strength: float) -> void:
	jitter_strength = clampf(strength, 0.0, 1.0)


func set_line_drop_rate(rate: float) -> void:
	line_drop_rate = clampf(rate, 0.0, line_drop_max)


# ── Jitter (call from entity drawers to offset points) ──

func jitter(point: Vector2) -> Vector2:
	if _phase == Phase.ABSENT:
		return point
	var breathe_offset := Vector2(
		sin(_breathing_time * TAU * breathe_hz) * breathe_amp,
		cos(_breathing_time * TAU * breathe_hz * 0.7) * breathe_amp * 0.6
	)
	var nx: float = _jitter_noise.get_noise_2d(point.x + _jitter_time * glitch_speed * 100.0, point.y)
	var ny: float = _jitter_noise.get_noise_2d(point.y + _jitter_time * glitch_speed * 100.0, point.x)
	var glitch_offset := Vector2(nx, ny) * glitch_scale
	return point + (breathe_offset + glitch_offset * jitter_strength) * jitter_strength


func should_draw_line(line_index: int) -> bool:
	if _phase != Phase.LINE_DROP:
		return true
	var hash_val: int = (line_index * 2654435761 + _line_drop_seed) & 0x7FFFFFFF
	var threshold: float = float(hash_val & 0xFFFF) / 65535.0
	return threshold >= line_drop_rate


func get_phase_color(base_color: Color) -> Color:
	match _phase:
		Phase.SHADOW:
			return Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, base_color.a)
		Phase.LINE_DROP:
			return Color(DIM_GREEN.r, DIM_GREEN.g, DIM_GREEN.b, base_color.a)
		_:
			return base_color


func get_display_state() -> Dictionary:
	var phase_name: String = "ABSENT"
	match _phase:
		Phase.LINE_DROP: phase_name = "LINE_DROP"
		Phase.SHADOW: phase_name = "SHADOW"
		Phase.FULL: phase_name = "FULL"
	return {
		"visible_entity": _visible_entity,
		"alpha": _alpha,
		"phase": phase_name,
		"dissolving": _dissolving
	}


# ── Internal ──

func _update_flicker(delta: float) -> void:
	if _alpha < 0.05:
		_flicker_on = true
		return
	_flicker_timer += delta
	var rate: float = flicker_base_rate
	match _phase:
		Phase.LINE_DROP:
			rate *= 2.0
		Phase.SHADOW:
			rate *= 1.2
	if _flicker_timer >= rate:
		_flicker_timer -= rate
		_flicker_on = randf() > 0.15


func _update_jitter(delta: float) -> void:
	_jitter_time += delta
	_breathing_time += delta
	_line_drop_timer += delta
	if _line_drop_timer >= line_drop_reseed_rate:
		_line_drop_timer -= line_drop_reseed_rate
		_line_drop_seed = randi()


func _draw_placeholder(x: float, y: float, w: float, h: float, color: Color) -> void:
	var pc := get_phase_color(color)
	var cx := x + w * 0.5
	var head_r := w * 0.22
	var body_top := y + h * 0.15
	var body_bot := y + h * 0.85
	var body_w := w * 0.45
	var lw: float = 1.5
	# Head arc
	if should_draw_line(0):
		var segments: int = 12
		for i in range(segments):
			var a0: float = PI + float(i) / float(segments) * PI
			var a1: float = PI + float(i + 1) / float(segments) * PI
			var p0 := Vector2(cx, body_top + head_r) + Vector2(cos(a0), sin(a0)) * head_r
			var p1 := Vector2(cx, body_top + head_r) + Vector2(cos(a1), sin(a1)) * head_r
			draw_line(jitter(p0), jitter(p1), pc, lw)
	# Body sides
	if should_draw_line(1):
		draw_line(jitter(Vector2(cx - body_w, body_top + head_r * 1.6)), jitter(Vector2(cx - body_w * 0.8, body_bot)), pc, lw)
	if should_draw_line(2):
		draw_line(jitter(Vector2(cx + body_w, body_top + head_r * 1.6)), jitter(Vector2(cx + body_w * 0.8, body_bot)), pc, lw)
	# Wavy bottom
	if should_draw_line(3):
		for i in range(5):
			var t0: float = float(i) / 5.0
			var t1: float = float(i + 1) / 5.0
			var x0: float = cx - body_w * 0.8 + (body_w * 1.6) * t0
			var x1: float = cx - body_w * 0.8 + (body_w * 1.6) * t1
			var y0: float = body_bot + sin(t0 * TAU * 1.5) * 4.0
			var y1: float = body_bot + sin(t1 * TAU * 1.5) * 4.0
			draw_line(jitter(Vector2(x0, y0)), jitter(Vector2(x1, y1)), pc, lw)
	# Eyes
	if should_draw_line(4):
		draw_rect(Rect2(jitter(Vector2(cx - head_r * 0.5, body_top + head_r * 0.7)), Vector2(3, 3)), pc, true)
	if should_draw_line(5):
		draw_rect(Rect2(jitter(Vector2(cx + head_r * 0.2, body_top + head_r * 0.7)), Vector2(3, 3)), pc, true)
