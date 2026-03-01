extends Control
## Sound Editor — retro synthesizer + step sequencer with Intel 8253 pitch quantization.
## Green phosphor aesthetic. Immediate-mode piano roll. WAV export.

const FONT_PATH := "res://content/fonts/PressStart2P-Regular.ttf"

const CRT_BLACK := Color(0.047, 0.078, 0.047, 1)
const DIM_GREEN := Color(0.14, 0.55, 0.14, 1)
const BASE_GREEN := Color(0.2, 1, 0.2, 1)
const BRIGHT_GREEN := Color(0.4, 1, 0.4, 1)

var _font: Font
var _synth: RetroSynth
var _piano_roll: PianoRoll
var _sequence: SequenceData

var _back_btn: Button
var _play_btn: Button
var _stop_btn: Button
var _save_btn: Button
var _clear_btn: Button
var _bpm_slider: HSlider
var _bpm_label: Label
var _vol_slider: HSlider
var _vol_label: Label
var _beats_btn: Button
var _oct_label: Label
var _status_label: Label
var _title_label: Label

var _file_dialog: FileDialog


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_font = load(FONT_PATH) as Font

	_sequence = SequenceData.new()
	_sequence.bpm = 120
	_sequence.wave_type = SequenceData.WaveType.SQUARE
	_sequence.total_beats = 16

	_synth = RetroSynth.new()
	_synth.name = "RetroSynth"
	add_child(_synth)
	_synth.playback_beat.connect(_on_playback_beat)
	_synth.playback_finished.connect(_on_playback_finished)

	_build_ui()
	_piano_roll.set_sequence(_sequence)
	_update_labels()


func _process(_delta: float) -> void:
	if _synth.is_playing():
		_piano_roll.set_playhead(_synth.get_beat_position())


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = CRT_BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_title_label = _make_label("SOUND EDITOR", 8, 4, BRIGHT_GREEN)

	var toolbar := HBoxContainer.new()
	toolbar.position = Vector2(8, 16)
	toolbar.size = Vector2(size.x - 16, 16)
	toolbar.add_theme_constant_override("separation", 4)
	add_child(toolbar)

	_play_btn = _make_button("PLAY")
	_play_btn.pressed.connect(_on_play)
	toolbar.add_child(_play_btn)

	_stop_btn = _make_button("STOP")
	_stop_btn.pressed.connect(_on_stop)
	toolbar.add_child(_stop_btn)

	_beats_btn = _make_button("16 BEATS")
	_beats_btn.pressed.connect(_on_cycle_beats)
	toolbar.add_child(_beats_btn)

	_save_btn = _make_button("SAVE WAV")
	_save_btn.pressed.connect(_on_save)
	toolbar.add_child(_save_btn)

	_clear_btn = _make_button("CLEAR")
	_clear_btn.pressed.connect(_on_clear)
	toolbar.add_child(_clear_btn)

	var dirge_btn := _make_button("DIRGE")
	dirge_btn.name = "DIRGE"
	dirge_btn.pressed.connect(_on_dirge)
	toolbar.add_child(dirge_btn)

	_back_btn = _make_button("BACK")
	_back_btn.pressed.connect(_on_back)
	toolbar.add_child(_back_btn)

	var bpm_row := HBoxContainer.new()
	bpm_row.position = Vector2(8, 34)
	bpm_row.size = Vector2(size.x - 16, 14)
	bpm_row.add_theme_constant_override("separation", 4)
	add_child(bpm_row)

	_bpm_label = Label.new()
	_bpm_label.text = "BPM:120"
	if _font:
		_bpm_label.add_theme_font_override("font", _font)
	_bpm_label.add_theme_font_size_override("font_size", 8)
	_bpm_label.add_theme_color_override("font_color", BASE_GREEN)
	_bpm_label.custom_minimum_size = Vector2(56, 0)
	bpm_row.add_child(_bpm_label)

	_bpm_slider = _make_slider(60, 240, 120, 10)
	_bpm_slider.custom_minimum_size = Vector2(100, 10)
	_bpm_slider.value_changed.connect(_on_bpm_changed)
	bpm_row.add_child(_bpm_slider)

	_vol_label = Label.new()
	_vol_label.text = "VOL:"
	if _font:
		_vol_label.add_theme_font_override("font", _font)
	_vol_label.add_theme_font_size_override("font_size", 8)
	_vol_label.add_theme_color_override("font_color", DIM_GREEN)
	_vol_label.custom_minimum_size = Vector2(32, 0)
	bpm_row.add_child(_vol_label)

	_vol_slider = _make_slider(0.1, 1.0, 0.85, 0.05)
	_vol_slider.custom_minimum_size = Vector2(60, 10)
	_vol_slider.value_changed.connect(_on_vol_changed)
	bpm_row.add_child(_vol_slider)

	_oct_label = Label.new()
	_oct_label.text = "OCT:2"
	if _font:
		_oct_label.add_theme_font_override("font", _font)
	_oct_label.add_theme_font_size_override("font_size", 8)
	_oct_label.add_theme_color_override("font_color", DIM_GREEN)
	_oct_label.custom_minimum_size = Vector2(40, 0)
	bpm_row.add_child(_oct_label)

	var oct_down := _make_button("-")
	oct_down.pressed.connect(_on_oct_down)
	bpm_row.add_child(oct_down)

	var oct_up := _make_button("+")
	oct_up.pressed.connect(_on_oct_up)
	bpm_row.add_child(oct_up)

	_piano_roll = PianoRoll.new()
	_piano_roll.name = "PianoRoll"
	var roll_size: Vector2 = _piano_roll.get_grid_size()
	_piano_roll.position = Vector2(8, 52)
	_piano_roll.size = roll_size
	_piano_roll.note_toggled.connect(_on_note_toggled)
	_piano_roll.note_preview.connect(_on_note_preview)
	add_child(_piano_roll)

	_status_label = _make_label("CLICK GRID TO PLACE NOTES", 8, 52 + roll_size.y + 4, DIM_GREEN)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.title = "Save WAV"
	_file_dialog.filters = PackedStringArray(["*.wav ; WAV Audio"])
	_file_dialog.size = Vector2(400, 300)
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)


func _make_label(text: String, x: float, y: float, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	if _font:
		lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = Vector2(x, y)
	add_child(lbl)
	return lbl


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	if _font:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 6)
	btn.add_theme_color_override("font_color", BASE_GREEN)
	btn.add_theme_color_override("font_hover_color", BRIGHT_GREEN)
	btn.add_theme_color_override("font_pressed_color", BRIGHT_GREEN)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.03, 0.08, 0.03, 1)
	normal_style.border_color = DIM_GREEN
	normal_style.set_border_width_all(1)
	normal_style.set_content_margin_all(2)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.06, 0.15, 0.06, 1)
	hover_style.border_color = BASE_GREEN
	hover_style.set_border_width_all(1)
	hover_style.set_content_margin_all(2)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.1, 0.3, 0.1, 1)
	pressed_style.border_color = BRIGHT_GREEN
	pressed_style.set_border_width_all(1)
	pressed_style.set_content_margin_all(2)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.custom_minimum_size = Vector2(0, 12)
	return btn


func _make_slider(min_val: float, max_val: float, default_val: float, step: float) -> HSlider:
	var sl := HSlider.new()
	sl.min_value = min_val
	sl.max_value = max_val
	sl.value = default_val
	sl.step = step

	var grabber_style := StyleBoxFlat.new()
	grabber_style.bg_color = BASE_GREEN
	grabber_style.set_content_margin_all(0)
	sl.add_theme_stylebox_override("grabber_area", grabber_style)
	sl.add_theme_stylebox_override("grabber_area_highlight", grabber_style)

	var slider_style := StyleBoxFlat.new()
	slider_style.bg_color = Color(0.06, 0.2, 0.06, 1)
	slider_style.set_content_margin_all(0)
	sl.add_theme_stylebox_override("slider", slider_style)

	return sl


func _update_labels() -> void:
	if _bpm_label:
		_bpm_label.text = "BPM:%d" % _sequence.bpm
	if _beats_btn:
		_beats_btn.text = "%d BEATS" % _sequence.total_beats
	if _oct_label and _piano_roll:
		_oct_label.text = "OCT:%d" % _piano_roll.get_octave_start()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()


func _on_play() -> void:
	_synth.play_sequence(_sequence)
	_status_label.text = "PLAYING..."
	_status_label.add_theme_color_override("font_color", BRIGHT_GREEN)


func _on_stop() -> void:
	_synth.stop()
	_piano_roll.set_playhead(-1.0)
	_status_label.text = "STOPPED"
	_status_label.add_theme_color_override("font_color", DIM_GREEN)


func _on_cycle_beats() -> void:
	var options: Array[int] = [8, 16, 32]
	var idx: int = options.find(_sequence.total_beats)
	_sequence.total_beats = options[(idx + 1) % options.size()]
	_update_labels()
	var roll_size: Vector2 = _piano_roll.get_grid_size()
	_piano_roll.size = roll_size
	_piano_roll.queue_redraw()


func _on_bpm_changed(val: float) -> void:
	_sequence.bpm = int(val)
	_update_labels()


func _on_vol_changed(val: float) -> void:
	_synth.master_volume = val


func _on_oct_down() -> void:
	_piano_roll.set_octave_start(_piano_roll.get_octave_start() - 1)
	_update_labels()


func _on_oct_up() -> void:
	_piano_roll.set_octave_start(_piano_roll.get_octave_start() + 1)
	_update_labels()


func _on_note_toggled(_beat: float, _freq: float, _added: bool) -> void:
	pass


func _on_note_preview(freq: float) -> void:
	_synth.preview_note(freq)


func _on_playback_beat(_beat: float) -> void:
	pass


func _on_playback_finished() -> void:
	_piano_roll.set_playhead(-1.0)
	_status_label.text = "DONE"
	_status_label.add_theme_color_override("font_color", DIM_GREEN)


func _on_save() -> void:
	_file_dialog.popup_centered()


func _on_file_selected(path: String) -> void:
	var ok: bool = _synth.export_wav(_sequence, path)
	if ok:
		_status_label.text = "SAVED: " + path.get_file()
		_status_label.add_theme_color_override("font_color", BRIGHT_GREEN)
	else:
		_status_label.text = "SAVE FAILED"
		_status_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))


func _on_clear() -> void:
	_sequence.notes.clear()
	_piano_roll.queue_redraw()
	_status_label.text = "CLEARED"
	_status_label.add_theme_color_override("font_color", DIM_GREEN)


func _on_dirge() -> void:
	_synth.stop()
	_piano_roll.set_playhead(-1.0)
	_sequence.notes.clear()

	_sequence.bpm = 72
	_sequence.total_beats = 8
	_bpm_slider.value = 72

	_piano_roll.set_octave_start(2)

	# Chopin — Marche funèbre (Sonata No. 2, Op. 35)
	var bb2: float = 440.0 * pow(2.0, (46.0 - 69.0) / 12.0)
	var db3: float = 440.0 * pow(2.0, (49.0 - 69.0) / 12.0)
	var c3: float  = 440.0 * pow(2.0, (48.0 - 69.0) / 12.0)
	var ab2: float = 440.0 * pow(2.0, (44.0 - 69.0) / 12.0)
	var gb2: float = 440.0 * pow(2.0, (42.0 - 69.0) / 12.0)
	var f2: float  = 440.0 * pow(2.0, (41.0 - 69.0) / 12.0)

	_sequence.set_note(0.00, bb2, 0.75)
	_sequence.set_note(0.75, bb2, 0.25)
	_sequence.set_note(1.00, bb2, 0.50)
	_sequence.set_note(1.50, bb2, 0.50)
	_sequence.set_note(2.00, db3, 0.50)
	_sequence.set_note(2.50, c3,  0.50)
	_sequence.set_note(3.00, bb2, 1.00)
	_sequence.set_note(4.00, ab2, 0.50)
	_sequence.set_note(4.50, gb2, 0.50)
	_sequence.set_note(5.00, f2,  2.00)

	var roll_size: Vector2 = _piano_roll.get_grid_size()
	_piano_roll.size = roll_size
	_piano_roll.queue_redraw()
	_update_labels()

	_status_label.text = "FUNERAL MARCH LOADED"
	_status_label.add_theme_color_override("font_color", BRIGHT_GREEN)


func _on_back() -> void:
	_synth.stop()
	get_tree().change_scene_to_file("res://main.tscn")


func grb_export_wav(path: String) -> bool:
	return _synth.export_wav(_sequence, path)
