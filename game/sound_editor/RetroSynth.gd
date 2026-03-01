class_name RetroSynth
extends Node
## 1-bit speaker emulation: Sharp MZ-80B / Intel 8253 PIT.
## The PIT toggles a single pin — output is +1 or -1, nothing else.
## No DAC, no amplitude envelope, no volume knob on the hardware.
## Monophonic. Square wave only.

signal playback_beat(beat: float)
signal playback_finished()

const PIT_CLOCK: float = 1193180.0

var _sample_rate: int = 44100

# Speaker pin state — toggling (note on) or idle (silent)
var _phase: float = 0.0
var _phase_inc: float = 0.0
var _note_active: bool = false
var _note_elapsed: float = 0.0
var _note_duration: float = 0.0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _generator: AudioStreamGenerator

# Sequencer state
var _sequence: SequenceData
var _playing: bool = false
var _beat_position: float = 0.0
var _last_qbeat: int = -1

# Volume applied as player gain, NOT per-sample — keeps output truly 1-bit
var master_volume: float = 0.85:
	set(v):
		master_volume = v
		if _player:
			_player.volume_db = linear_to_db(clampf(v, 0.01, 1.0))

# Legacy fields kept for save/load compatibility
var wave_type: int = SequenceData.WaveType.SQUARE
var attack: float = 0.01
var decay: float = 0.05
var sustain_level: float = 0.6
var release: float = 0.1


func _ready() -> void:
	_sample_rate = int(AudioServer.get_mix_rate())

	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = _sample_rate
	_generator.buffer_length = 0.1

	_player = AudioStreamPlayer.new()
	_player.stream = _generator
	_player.bus = &"Master"
	_player.volume_db = linear_to_db(clampf(master_volume, 0.01, 1.0))
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	if _playback == null:
		return
	_fill_buffer()


func _fill_buffer() -> void:
	var frames_available: int = _playback.get_frames_available()
	if frames_available <= 0:
		return

	var bps: float = 0.0
	if _sequence and _playing:
		bps = _sequence.bpm / 60.0

	for _i in range(frames_available):
		if _playing and _sequence and bps > 0.0:
			var curr_qbeat: int = int(_beat_position * 4.0)
			if curr_qbeat != _last_qbeat:
				_last_qbeat = curr_qbeat
				var check_beat: float = curr_qbeat * 0.25
				if check_beat >= 0.0 and check_beat < _sequence.total_beats:
					var notes_here: Array = _sequence.get_notes_at(check_beat)
					if not notes_here.is_empty():
						var n: NoteData = notes_here[0]
						_trigger_note(n.pitch_hz, n.duration_beats / bps)

			_beat_position += bps / float(_sample_rate)

			if _beat_position >= _sequence.total_beats:
				_playing = false
				_beat_position = 0.0
				_note_active = false
				playback_finished.emit()

		# 1-bit output: pin is either high (+1), low (-1), or idle (0)
		var sample: float = 0.0
		if _note_active:
			_note_elapsed += 1.0 / float(_sample_rate)
			if _note_elapsed >= _note_duration:
				_note_active = false

		if _note_active:
			sample = 1.0 if _phase < 0.5 else -1.0
			_phase += _phase_inc
			if _phase >= 1.0:
				_phase -= 1.0
		else:
			_phase = 0.0

		_playback.push_frame(Vector2(sample, sample))


func _trigger_note(freq_hz: float, duration_sec: float) -> void:
	var actual_freq: float = _quantize_pit(freq_hz)
	_phase_inc = actual_freq / float(_sample_rate)
	_phase = 0.0
	_note_active = true
	_note_elapsed = 0.0
	_note_duration = duration_sec


func _quantize_pit(freq: float) -> float:
	if freq <= 0.0:
		return 0.0
	@warning_ignore("integer_division")
	var divisor: int = int(PIT_CLOCK / freq)
	if divisor <= 0:
		divisor = 1
	return PIT_CLOCK / float(divisor)


# --- Public API ---

func play_sequence(seq: SequenceData) -> void:
	_sequence = seq
	wave_type = seq.wave_type
	attack = seq.attack
	decay = seq.decay
	sustain_level = seq.sustain
	release = seq.release
	_beat_position = 0.0
	_last_qbeat = -1
	_note_active = false
	_playing = true


func stop() -> void:
	_playing = false
	_note_active = false
	_beat_position = 0.0
	_last_qbeat = -1


func is_playing() -> bool:
	return _playing


func get_beat_position() -> float:
	return _beat_position


func preview_note(freq_hz: float) -> void:
	_trigger_note(freq_hz, 0.15)


func export_wav(seq: SequenceData, path: String) -> bool:
	var bps: float = seq.bpm / 60.0
	var total_seconds: float = seq.total_beats / bps + 0.5
	var total_samples: int = int(total_seconds * _sample_rate)

	var pcm := PackedFloat32Array()
	pcm.resize(total_samples)

	var phase: float = 0.0
	var phase_inc: float = 0.0
	var note_on: bool = false
	var note_elapsed: float = 0.0
	var note_dur: float = 0.0
	var beat_pos: float = 0.0
	var last_qbeat: int = -1

	for si in range(total_samples):
		var curr_qbeat: int = int(beat_pos * 4.0)
		if curr_qbeat != last_qbeat:
			last_qbeat = curr_qbeat
			var check_beat: float = curr_qbeat * 0.25
			if check_beat >= 0.0 and check_beat < seq.total_beats:
				var notes_here: Array = seq.get_notes_at(check_beat)
				if not notes_here.is_empty():
					var n: NoteData = notes_here[0]
					var actual_freq: float = _quantize_pit(n.pitch_hz)
					phase_inc = actual_freq / float(_sample_rate)
					phase = 0.0
					note_on = true
					note_elapsed = 0.0
					note_dur = n.duration_beats / bps

		var sample: float = 0.0
		if note_on:
			note_elapsed += 1.0 / float(_sample_rate)
			if note_elapsed >= note_dur:
				note_on = false

		if note_on:
			sample = 1.0 if phase < 0.5 else -1.0
			phase += phase_inc
			if phase >= 1.0:
				phase -= 1.0

		pcm[si] = sample
		beat_pos += bps / float(_sample_rate)

	var byte_data := PackedByteArray()
	byte_data.resize(total_samples * 2)
	for si in range(total_samples):
		var s16: int = int(pcm[si] * 32767.0)
		byte_data[si * 2] = s16 & 0xFF
		byte_data[si * 2 + 1] = (s16 >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = _sample_rate
	wav.stereo = false
	wav.data = byte_data

	var err := wav.save_to_wav(path)
	return err == OK
