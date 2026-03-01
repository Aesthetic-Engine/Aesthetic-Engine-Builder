class_name PianoRoll
extends Control
## Immediate-mode piano roll grid. All rendering via _draw(), no child nodes.
## 2 octaves, quantized to quarter-beat columns. Starting octave adjustable.

signal note_toggled(beat: float, pitch_hz: float, added: bool)
signal note_preview(pitch_hz: float)

const CRT_BLACK := Color(0.047, 0.078, 0.047, 1)
const DIM_GREEN := Color(0.14, 0.55, 0.14, 1)
const BASE_GREEN := Color(0.2, 1, 0.2, 1)
const BRIGHT_GREEN := Color(0.4, 1, 0.4, 1)
const NOTE_COLOR := Color(0.15, 0.85, 0.15, 0.9)
const PLAYHEAD_COLOR := Color(0.4, 1, 0.4, 0.6)

const NOTE_NAMES: Array[String] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

# Grid dimensions
const LABEL_WIDTH: int = 24
const CELL_W: int = 8
const CELL_H: int = 6

# Pitch range: 2 octaves (24 semitones), starting octave adjustable
const NUM_OCTAVES: int = 2
const NUM_ROWS: int = 24
const GRID_TOP: int = 1

var _octave_start: int = 2  # Default C2–B3 for lower/somber range

var _sequence: SequenceData
var _playhead_beat: float = -1.0
var _font: Font
var _scroll_x: int = 0
var _hovering: bool = false
var _hover_col: int = -1
var _hover_row: int = -1


func _ready() -> void:
	_font = load("res://content/fonts/PressStart2P-Regular.ttf") as Font
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func set_sequence(seq: SequenceData) -> void:
	_sequence = seq
	queue_redraw()


func set_playhead(beat: float) -> void:
	_playhead_beat = beat
	queue_redraw()


func _draw() -> void:
	if _sequence == null:
		return

	var total_cols: int = _sequence.total_beats * 4
	var grid_w: int = total_cols * CELL_W
	var grid_h: int = GRID_TOP + NUM_ROWS * CELL_H

	# Background
	draw_rect(Rect2(0, 0, LABEL_WIDTH + grid_w, grid_h), CRT_BLACK, true)

	# Note labels (top = highest pitch, bottom = lowest)
	for row in range(NUM_ROWS):
		var semitone: int = (NUM_ROWS - 1 - row)
		@warning_ignore("integer_division")
		var octave: int = _octave_start + semitone / 12
		var note_idx: int = semitone % 12
		var name_str: String = NOTE_NAMES[note_idx] + str(octave)
		var is_sharp: bool = NOTE_NAMES[note_idx].length() > 1
		var label_color: Color = DIM_GREEN if is_sharp else BASE_GREEN
		var y: int = GRID_TOP + row * CELL_H

		if is_sharp:
			draw_rect(Rect2(0, y, LABEL_WIDTH, CELL_H), Color(0.03, 0.05, 0.03, 1), true)

		if _font:
			draw_string(_font, Vector2(1, y + CELL_H), name_str, HORIZONTAL_ALIGNMENT_LEFT, LABEL_WIDTH, 6, label_color)

	# Grid lines and notes
	for col in range(total_cols):
		var x: int = LABEL_WIDTH + col * CELL_W
		var beat: float = col * 0.25
		var is_beat: bool = col % 4 == 0
		var line_color: Color = DIM_GREEN if is_beat else Color(0.08, 0.25, 0.08, 0.6)

		draw_line(Vector2(x, GRID_TOP), Vector2(x, grid_h), line_color, 1.0)

		var note_pitch: float = _sequence.get_pitch_at(beat)
		if note_pitch > 0.0:
			var note_semi: int = _freq_to_semitone(note_pitch)
			if note_semi >= 0 and note_semi < NUM_ROWS:
				var note_row: int = NUM_ROWS - 1 - note_semi
				var ny: int = GRID_TOP + note_row * CELL_H
				var note_rect := Rect2(x + 1, ny + 1, CELL_W - 2, CELL_H - 2)
				draw_rect(note_rect, NOTE_COLOR, true)
				draw_rect(note_rect, BASE_GREEN, false, 1.0)

	# Horizontal grid lines
	for row in range(NUM_ROWS + 1):
		var y: int = GRID_TOP + row * CELL_H
		var is_octave: bool = row % 12 == 0
		draw_line(Vector2(LABEL_WIDTH, y), Vector2(LABEL_WIDTH + grid_w, y),
				DIM_GREEN if is_octave else Color(0.08, 0.25, 0.08, 0.4), 1.0)

	# Playhead
	if _playhead_beat >= 0.0:
		var px: float = float(LABEL_WIDTH) + _playhead_beat * 4.0 * float(CELL_W)
		draw_rect(Rect2(px, GRID_TOP, 2.0, float(NUM_ROWS * CELL_H)), PLAYHEAD_COLOR, true)

	# Hover highlight
	if _hovering and _hover_col >= 0 and _hover_row >= 0:
		var hx: int = LABEL_WIDTH + _hover_col * CELL_W
		var hy: int = GRID_TOP + _hover_row * CELL_H
		draw_rect(Rect2(hx, hy, CELL_W, CELL_H), Color(0.3, 1, 0.3, 0.2), true)

	# Border
	draw_rect(Rect2(0, 0, LABEL_WIDTH + grid_w, grid_h), BASE_GREEN, false, 1.0)
	draw_line(Vector2(LABEL_WIDTH, 0), Vector2(LABEL_WIDTH, grid_h), DIM_GREEN, 1.0)


func _gui_input(event: InputEvent) -> void:
	if _sequence == null:
		return

	if event is InputEventMouseMotion:
		var pos: Vector2 = event.position
		var result := _pos_to_grid(pos)
		_hover_col = result[0]
		_hover_row = result[1]
		_hovering = _hover_col >= 0 and _hover_row >= 0
		queue_redraw()

	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var pos: Vector2 = event.position
			var result := _pos_to_grid(pos)
			var col: int = result[0]
			var row: int = result[1]
			if col >= 0 and row >= 0:
				var beat: float = col * 0.25
				var semitone: int = (NUM_ROWS - 1 - row)
				var freq: float = _semitone_to_freq(semitone)
				var existing_pitch: float = _sequence.get_pitch_at(beat)
				if absf(existing_pitch - freq) < 0.5:
					# Clicking the same note again removes it
					_sequence.clear_beat(beat)
					note_toggled.emit(beat, freq, false)
				else:
					# Place or replace the single note at this beat
					_sequence.set_note(beat, freq, 0.25, 0.8)
					note_toggled.emit(beat, freq, true)
					note_preview.emit(freq)
				queue_redraw()


func _pos_to_grid(pos: Vector2) -> Array[int]:
	var total_cols: int = _sequence.total_beats * 4
	var gx: float = pos.x - LABEL_WIDTH
	var gy: float = pos.y - float(GRID_TOP)
	if gx < 0 or gy < 0:
		return [-1, -1]
	@warning_ignore("integer_division")
	var col: int = int(gx) / CELL_W
	@warning_ignore("integer_division")
	var row: int = int(gy) / CELL_H
	if col < 0 or col >= total_cols or row < 0 or row >= NUM_ROWS:
		return [-1, -1]
	return [col, row]


func _semitone_to_freq(semitone: int) -> float:
	var midi: int = 12 * (_octave_start + 1) + semitone
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


func _freq_to_semitone(freq: float) -> int:
	if freq <= 0.0:
		return -1
	var midi: float = 69.0 + 12.0 * log(freq / 440.0) / log(2.0)
	return int(roundf(midi)) - 12 * (_octave_start + 1)


func get_grid_size() -> Vector2:
	var h: int = GRID_TOP + NUM_ROWS * CELL_H
	if _sequence == null:
		return Vector2(LABEL_WIDTH + 16 * 4 * CELL_W, h)
	return Vector2(LABEL_WIDTH + _sequence.total_beats * 4 * CELL_W, h)


func set_octave_start(oct: int) -> void:
	_octave_start = clampi(oct, 1, 6)
	queue_redraw()


func get_octave_start() -> int:
	return _octave_start
