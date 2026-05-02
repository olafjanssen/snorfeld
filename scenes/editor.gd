extends Control

func _ready():
	await get_tree().process_frame
	$VBoxContainer.offset_top = $MenuBar.size.y
	$VBoxContainer/HSplitContainer.split_offsets = PackedInt32Array([200, 800, 1600])
