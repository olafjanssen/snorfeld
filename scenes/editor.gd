extends Control

func _ready():
	await get_tree().process_frame

	# Detect screen DPI and set appropriate scale
	var dpi := DisplayServer.screen_get_dpi(0)

	# Use 2.0 for high-DPI (Retina/4K), 1.0 for standard
	var ui_scale := 2.0 if dpi > 144 else 1.0
	get_tree().root.content_scale_factor = ui_scale

	$VBoxContainer.offset_top = $MenuBar.size.y
	$VBoxContainer/HSplitContainer.split_offsets = PackedInt32Array([200, 800, 1600])
