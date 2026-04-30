extends Control

func _ready():
	Window.get_focused_window().set_content_scale_factor(2.0)
	await get_tree().process_frame
	$HSplitContainer.offset_top = $MenuBar.size.y
