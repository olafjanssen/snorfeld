extends Control

func _ready():
	await get_tree().process_frame
	$HSplitContainer.offset_top = $MenuBar.size.y
