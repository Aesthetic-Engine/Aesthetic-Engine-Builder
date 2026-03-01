extends Control
class_name WireframeCanvas
## WireframeCanvas — resolution-independent command-buffer renderer for wireframe/vector graphics.
##
## Usage:
##   1. Subclass or instance this node.
##   2. Register room drawers via register_room_drawer("room_id", callable).
##   3. Call load_scene("room_id") to trigger drawing.
##   4. Override _build_commands() in subclasses for custom drawing.
##
## Drawing API (call inside drawers or _build_commands):
##   dl(from, to, color, width)   — line
##   dr(rect, color, filled, width) — rectangle
##   dp(points, color, filled)    — polygon / polyline
##   dt(text, cx, y, color)       — centered text (3×5 pixel font, A-Z 0-9 !)
##   ds(val, x, y, color)         — seven-segment score (5 digits, 0-padded)
##
## Coordinate helpers:
##   px(frac) — fraction (0.0–1.0) of canvas width  → pixels
##   py(frac) — fraction (0.0–1.0) of canvas height → pixels

const DEFAULT_COLOR := Color(0.2, 1.0, 0.2, 1.0)
const DIM_COLOR := Color(0.14, 0.55, 0.14, 1.0)
const BG_COLOR := Color(0.02, 0.03, 0.02, 1.0)

# Draw command types
const CMD_LINE := 0
const CMD_RECT := 1
const CMD_POLY := 2

# Command buffer
var _cmds: Array = []

# Draw-in animation
var draw_in_enabled: bool = true
var _cmd_limit: int = -1
var _total_cmds: int = 0
var _draw_in_active: bool = false
var _draw_in_timer: float = 0.0
var _draw_in_rate: float = 40.0

@export var draw_in_duration: float = 1.8
@export var draw_in_delay: float = 0.25
@export var draw_in_min_rate: float = 40.0
@export var show_border: bool = true
@export var border_color: Color = Color(0.2, 1.0, 0.2, 1.0)

# Registered room drawers: room_id -> Callable(canvas: WireframeCanvas)
var _draw_funcs: Dictionary = {}

# Current procedural scene id
var _current_scene: String = ""
var _scene_active: bool = false

# Built-in font and segment data (initialized in _ready)
var _font_data: Dictionary
var _seg_data: Array


func _ready() -> void:
	_font_data = {
		"A": [0x7,0x5,0x7,0x5,0x5], "B": [0x6,0x5,0x6,0x5,0x6],
		"C": [0x7,0x4,0x4,0x4,0x7], "D": [0x6,0x5,0x5,0x5,0x6],
		"E": [0x7,0x4,0x7,0x4,0x7], "F": [0x7,0x4,0x7,0x4,0x4],
		"G": [0x7,0x4,0x5,0x5,0x7], "H": [0x5,0x5,0x7,0x5,0x5],
		"I": [0x7,0x2,0x2,0x2,0x7], "J": [0x1,0x1,0x1,0x5,0x7],
		"K": [0x5,0x6,0x4,0x6,0x5], "L": [0x4,0x4,0x4,0x4,0x7],
		"M": [0x5,0x7,0x5,0x5,0x5], "N": [0x5,0x5,0x7,0x5,0x5],
		"O": [0x7,0x5,0x5,0x5,0x7], "P": [0x7,0x5,0x7,0x4,0x4],
		"Q": [0x7,0x5,0x5,0x7,0x3], "R": [0x7,0x5,0x7,0x6,0x5],
		"S": [0x7,0x4,0x7,0x1,0x7], "T": [0x7,0x2,0x2,0x2,0x2],
		"U": [0x5,0x5,0x5,0x5,0x7], "V": [0x5,0x5,0x5,0x5,0x2],
		"W": [0x5,0x5,0x5,0x7,0x5], "X": [0x5,0x5,0x2,0x5,0x5],
		"Y": [0x5,0x5,0x2,0x2,0x2], "Z": [0x7,0x1,0x2,0x4,0x7],
		"0": [0x7,0x5,0x5,0x5,0x7], "1": [0x2,0x6,0x2,0x2,0x7],
		"2": [0x7,0x1,0x7,0x4,0x7], "3": [0x7,0x1,0x7,0x1,0x7],
		"4": [0x5,0x5,0x7,0x1,0x1], "5": [0x7,0x4,0x7,0x1,0x7],
		"6": [0x7,0x4,0x7,0x5,0x7], "7": [0x7,0x1,0x1,0x1,0x1],
		"8": [0x7,0x5,0x7,0x5,0x7], "9": [0x7,0x5,0x7,0x1,0x7],
		"!": [0x2,0x2,0x2,0x0,0x2],
	}
	_seg_data = [0x7E, 0x30, 0x6D, 0x79, 0x33, 0x5B, 0x5F, 0x70, 0x7F, 0x7B]


# ── Coordinate helpers ──

func px(frac_x: float) -> float:
	return frac_x * size.x


func py(frac_y: float) -> float:
	return frac_y * size.y


# ── Drawing API (append commands to buffer) ──

func dl(from: Vector2, to: Vector2, col: Color = DEFAULT_COLOR, width: float = 1.0) -> void:
	_cmds.append([CMD_LINE, from, to, col, width])


func dr(rect: Rect2, col: Color = DEFAULT_COLOR, filled: bool = false, width: float = 1.0) -> void:
	_cmds.append([CMD_RECT, rect, col, filled, width])


func dp(points: PackedVector2Array, col: Color = DEFAULT_COLOR, filled: bool = false) -> void:
	_cmds.append([CMD_POLY, points, col, filled])


func dt(text: String, cx: float, y: float, col: Color = DEFAULT_COLOR) -> void:
	var chars := text.to_upper()
	var total_w: float = chars.length() * 4.0 - 1.0
	var sx: float = cx - total_w * 0.5
	for i in range(chars.length()):
		var ch: String = chars[i]
		if ch == " ":
			continue
		if _font_data.has(ch):
			var rows: Array = _font_data[ch]
			for row_i in range(rows.size()):
				var bits: int = rows[row_i]
				var rx: float = sx + i * 4.0
				var ry: float = y + row_i
				if bits & 4:
					dr(Rect2(rx, ry, 1, 1), col, true)
				if bits & 2:
					dr(Rect2(rx + 1, ry, 1, 1), col, true)
				if bits & 1:
					dr(Rect2(rx + 2, ry, 1, 1), col, true)


func ds(val: int, x: float, y: float, col: Color = DEFAULT_COLOR) -> void:
	var s := str(clampi(val, 0, 99999)).lpad(5, "0")
	for i in range(s.length()):
		var v: int = s[i].to_int()
		var dx: float = x + i * 13.0
		var dw := 10.0
		var dh := 14.0
		var hh := dh * 0.5
		var b: int = _seg_data[clampi(v, 0, 9)]
		if b & 0x40:
			dl(Vector2(dx, y), Vector2(dx + dw, y), col, 1.5)
		if b & 0x20:
			dl(Vector2(dx, y), Vector2(dx, y + hh), col, 1.5)
		if b & 0x10:
			dl(Vector2(dx + dw, y), Vector2(dx + dw, y + hh), col, 1.5)
		if b & 0x08:
			dl(Vector2(dx, y + hh), Vector2(dx + dw, y + hh), col, 1.5)
		if b & 0x04:
			dl(Vector2(dx, y + hh), Vector2(dx, y + dh), col, 1.5)
		if b & 0x02:
			dl(Vector2(dx + dw, y + hh), Vector2(dx + dw, y + dh), col, 1.5)
		if b & 0x01:
			dl(Vector2(dx, y + dh), Vector2(dx + dw, y + dh), col, 1.5)


# ── Interior base helper (standard room perspective) ──

func draw_interior_base(wall_frac: float = 0.42) -> float:
	var green := DEFAULT_COLOR
	var dim := DIM_COLOR
	var w := size.x
	var h := size.y
	var wall_y := py(wall_frac)
	dl(Vector2(0, wall_y), Vector2(w, wall_y), green)
	dl(Vector2(0, py(wall_frac - 0.14)), Vector2(w, py(wall_frac - 0.14)), dim)
	dl(Vector2(0, py(0.02)), Vector2(w, py(0.02)), dim)
	dl(Vector2(0, wall_y - 1), Vector2(0, h), dim)
	dl(Vector2(w - 1, wall_y - 1), Vector2(w - 1, h), dim)
	var cx := px(0.5)
	for i in range(2):
		var t := (i + 1) * 0.28
		dl(Vector2(0, lerp(wall_y, h, t)), Vector2(w, lerp(wall_y, h, t)), dim)
	dl(Vector2(cx, wall_y), Vector2(px(0.12), h), dim)
	dl(Vector2(cx, wall_y), Vector2(px(0.88), h), dim)
	return wall_y


# ── Room drawer registration ──

func register_room_drawer(room_id: String, drawer: Callable) -> void:
	_draw_funcs[room_id] = drawer


func load_scene(room_id: String) -> void:
	_current_scene = room_id
	_scene_active = room_id != ""
	if draw_in_enabled and _scene_active:
		_start_reveal()
	else:
		_cmd_limit = -1
	queue_redraw()


func clear_scene() -> void:
	_current_scene = ""
	_scene_active = false
	_cmd_limit = -1
	queue_redraw()


# ── Draw-in animation ──

func _start_reveal() -> void:
	_draw_in_active = true
	_draw_in_timer = 0.0
	_cmd_limit = 0
	_cmds.clear()
	_build_commands()
	_total_cmds = _cmds.size()
	_draw_in_rate = maxf(draw_in_min_rate, float(_total_cmds) / draw_in_duration) if _total_cmds > 0 else draw_in_min_rate


func _process(delta: float) -> void:
	if _draw_in_active:
		_draw_in_timer += delta
		var elapsed := _draw_in_timer - draw_in_delay
		if elapsed > 0.0:
			_cmd_limit = int(elapsed * _draw_in_rate)
			if _total_cmds > 0 and _cmd_limit >= _total_cmds:
				_draw_in_active = false
				_cmd_limit = -1
		else:
			_cmd_limit = 0
		queue_redraw()


# ── Rendering ──

func _draw() -> void:
	_cmds.clear()
	_build_commands()
	_total_cmds = _cmds.size()

	var limit := _cmds.size() if _cmd_limit < 0 else mini(_cmd_limit, _cmds.size())
	for i in range(limit):
		var c: Array = _cmds[i]
		match c[0]:
			CMD_LINE:
				draw_line(c[1], c[2], c[3], c[4])
			CMD_RECT:
				draw_rect(c[1], c[2], c[3], c[4])
			CMD_POLY:
				if c[3]:
					draw_colored_polygon(c[1], c[2])
				else:
					draw_polyline(c[1], c[2], 1.0)

	if show_border:
		var hw := 0.5
		draw_rect(Rect2(Vector2(hw, hw), size - Vector2(hw * 2.0, hw * 2.0)), border_color, false, 1.0)


func _build_commands() -> void:
	if _scene_active and _draw_funcs.has(_current_scene):
		_draw_funcs[_current_scene].call(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
