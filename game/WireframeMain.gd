extends Control

var _pipeline: CRTPipeline
var _canvas: WireframeCanvas


func _ready() -> void:
	_pipeline = CRTPipeline.new()
	_pipeline.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_pipeline)
	_canvas = WireframeCanvas.new()
	_canvas.draw_in_enabled = false
	_canvas.size = Vector2(_pipeline.virtual_width, _pipeline.virtual_height)
	_pipeline.get_content_root().add_child(_canvas)


func _process(_delta: float) -> void:
	_canvas.queue_redraw()
