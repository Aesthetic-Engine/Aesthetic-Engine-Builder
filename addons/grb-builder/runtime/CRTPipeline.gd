extends Control
class_name CRTPipeline
## CRT display pipeline — composites wireframe content through phosphor decay,
## CRT screen shader, and glass reflection layers.
##
## Scene tree built programmatically:
##   CRTPipeline (this node, fullrect)
##     └─ ContentViewport (SubViewport, 320×200 — game content goes here)
##     └─ PhosphorBuffer  (SubViewport, 320×200 — feedback loop)
##         └─ DecayComposite (ColorRect + phosphor_decay shader)
##     └─ Screen (TextureRect + crt_screen shader — shows PhosphorBuffer output)
##     └─ GlassReflection (ColorRect + crt_reflection shader)
##
## Usage:
##   1. Instance CRTPipeline in your scene.
##   2. Add your WireframeCanvas (or any node) as child of get_content_root().
##   3. It renders automatically.

@export_group("Resolution")
@export var virtual_width: int = 320
@export var virtual_height: int = 200

@export_group("Phosphor Decay")
@export var use_phosphor_decay: bool = true
@export var decay_fast: float = 0.72
@export var decay_tail: float = 0.85

@export_group("CRT Screen")
@export var crt_curvature: float = 0.025
@export var crt_scanline_strength: float = 0.12
@export var crt_scanline_count: float = 200.0
@export var crt_glow_strength: float = 0.15
@export var crt_breathe_amp: float = 0.10
@export var crt_beam_strength: float = 0.12

@export_group("Extra Effects")
@export var extra_crt_effects: bool = false

@export_group("Reflection")
@export var reflection_opacity: float = 0.045

var _content_viewport: SubViewport
var _phosphor_buffer: SubViewport
var _decay_composite: ColorRect
var _screen: TextureRect
var _glass_reflection: ColorRect

var _screen_mat: ShaderMaterial
var _decay_mat: ShaderMaterial
var _reflection_mat: ShaderMaterial

const _CRT_SCREEN_SHADER = preload("res://addons/grb-builder/shaders/crt_screen.gdshader")
const _PHOSPHOR_DECAY_SHADER = preload("res://addons/grb-builder/shaders/phosphor_decay.gdshader")
const _CRT_REFLECTION_SHADER = preload("res://addons/grb-builder/shaders/crt_reflection.gdshader")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_pipeline()
	_apply_exports()


func get_content_root() -> SubViewport:
	return _content_viewport


func _build_pipeline() -> void:
	# Content SubViewport
	_content_viewport = SubViewport.new()
	_content_viewport.name = "ContentViewport"
	_content_viewport.size = Vector2i(virtual_width, virtual_height)
	_content_viewport.transparent_bg = false
	_content_viewport.handle_input_locally = false
	_content_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_content_viewport)

	# Phosphor decay feedback SubViewport
	_phosphor_buffer = SubViewport.new()
	_phosphor_buffer.name = "PhosphorBuffer"
	_phosphor_buffer.size = Vector2i(virtual_width, virtual_height)
	_phosphor_buffer.transparent_bg = false
	_phosphor_buffer.render_target_update_mode = SubViewport.UPDATE_ALWAYS if use_phosphor_decay else SubViewport.UPDATE_DISABLED
	add_child(_phosphor_buffer)

	_decay_mat = ShaderMaterial.new()
	_decay_mat.shader = _PHOSPHOR_DECAY_SHADER

	_decay_composite = ColorRect.new()
	_decay_composite.name = "DecayComposite"
	_decay_composite.size = Vector2(virtual_width, virtual_height)
	_decay_composite.material = _decay_mat
	_phosphor_buffer.add_child(_decay_composite)

	# Screen TextureRect (fills this control)
	_screen_mat = ShaderMaterial.new()
	_screen_mat.shader = _CRT_SCREEN_SHADER

	_screen = TextureRect.new()
	_screen.name = "Screen"
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_screen.material = _screen_mat
	add_child(_screen)

	if use_phosphor_decay:
		_screen.texture = _phosphor_buffer.get_texture()
	else:
		_screen.texture = _content_viewport.get_texture()

	# Glass reflection overlay
	_reflection_mat = ShaderMaterial.new()
	_reflection_mat.shader = _CRT_REFLECTION_SHADER

	_glass_reflection = ColorRect.new()
	_glass_reflection.name = "GlassReflection"
	_glass_reflection.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glass_reflection.material = _reflection_mat
	_glass_reflection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glass_reflection)


func set_extra_crt_effects(enabled: bool) -> void:
	extra_crt_effects = enabled
	if _screen_mat:
		_screen_mat.set_shader_parameter("u_extra_effects", enabled)
	if _phosphor_buffer:
		_phosphor_buffer.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if (use_phosphor_decay and enabled)
			else SubViewport.UPDATE_DISABLED
		)
	if _screen:
		if use_phosphor_decay and enabled:
			_screen.texture = _phosphor_buffer.get_texture()
		else:
			_screen.texture = _content_viewport.get_texture()
	if _glass_reflection:
		_glass_reflection.visible = enabled


func _apply_exports() -> void:
	_decay_mat.set_shader_parameter("decay_fast", decay_fast)
	_decay_mat.set_shader_parameter("decay_tail", decay_tail)

	_screen_mat.set_shader_parameter("curvature", crt_curvature)
	_screen_mat.set_shader_parameter("scanline_strength", crt_scanline_strength)
	_screen_mat.set_shader_parameter("scanline_count", crt_scanline_count)
	_screen_mat.set_shader_parameter("glow_strength", crt_glow_strength)
	_screen_mat.set_shader_parameter("breathe_amp", crt_breathe_amp)
	_screen_mat.set_shader_parameter("beam_strength", crt_beam_strength)
	_screen_mat.set_shader_parameter("u_extra_effects", extra_crt_effects)

	_reflection_mat.set_shader_parameter("opacity", reflection_opacity)

	if not extra_crt_effects:
		_phosphor_buffer.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_screen.texture = _content_viewport.get_texture()
		_glass_reflection.visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	var t := Time.get_ticks_msec() / 1000.0

	_screen_mat.set_shader_parameter("u_time", t)
	_reflection_mat.set_shader_parameter("u_time", t)

	if use_phosphor_decay and extra_crt_effects and _decay_mat:
		_decay_mat.set_shader_parameter("current_frame", _content_viewport.get_texture())
		_decay_mat.set_shader_parameter("previous_frame", _phosphor_buffer.get_texture())
