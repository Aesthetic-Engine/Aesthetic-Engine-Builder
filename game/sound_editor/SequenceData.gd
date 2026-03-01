class_name SequenceData
extends Resource
## A complete tracker sequence — global params + all note events.
## Notes stored as Dictionary[float beat -> Array[NoteData]] for O(1) playback lookup.

enum WaveType { SQUARE }

@export var bpm: int = 120
@export var wave_type: WaveType = WaveType.SQUARE
@export var total_beats: int = 16
@export var notes: Dictionary = {}

# ADSR (seconds)
@export var attack: float = 0.01
@export var decay: float = 0.05
@export var sustain: float = 0.6
@export var release: float = 0.1


func set_note(beat: float, pitch_hz: float, duration: float = 0.25, vel: float = 0.8) -> void:
	var n := NoteData.new()
	n.pitch_hz = pitch_hz
	n.start_beat = beat
	n.duration_beats = duration
	n.velocity = vel
	notes[beat] = [n]


func clear_beat(beat: float) -> void:
	notes.erase(beat)


func has_note_at(beat: float) -> bool:
	return notes.has(beat) and not notes[beat].is_empty()


func get_pitch_at(beat: float) -> float:
	if not notes.has(beat) or notes[beat].is_empty():
		return -1.0
	return notes[beat][0].pitch_hz


func get_notes_at(beat: float) -> Array:
	return notes.get(beat, [])
