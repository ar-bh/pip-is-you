extends CanvasLayer

@onready var ground: ColorRect = $Ground

func _ready() -> void:
	layer = -10
	var peach := Color(0.965, 0.627, 0.412, 1.0)
	RenderingServer.set_default_clear_color(peach)
	_fit()
	var vp := get_viewport()
	if not vp.size_changed.is_connected(_fit):
		vp.size_changed.connect(_fit)

func _fit() -> void:
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.offset_left = 0.0
	ground.offset_top = 0.0
	ground.offset_right = 0.0
	ground.offset_bottom = 0.0
	ground.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ground.grow_vertical = Control.GROW_DIRECTION_BOTH
