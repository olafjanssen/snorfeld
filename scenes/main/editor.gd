extends Control

var story_bible: Window

func _ready():
	await get_tree().process_frame

	# Detect screen DPI and set appropriate scale
	var dpi := DisplayServer.screen_get_dpi(0)

	# Use 2.0 for high-DPI (Retina/4K), 1.0 for standard
	var ui_scale := 2.0 if dpi > 144 else 1.0
	get_tree().root.content_scale_factor = ui_scale

	$VBoxContainer.offset_top = $MenuBar.size.y
	$VBoxContainer/HSplitContainer.split_offsets = PackedInt32Array([200, 800, 1600])

	# Connect Story Bible menu signal
	EventBus.open_story_bible.connect(_open_story_bible)

func _open_story_bible():
	if story_bible != null:
		story_bible.queue_free()
	var StoryBibleScene = preload("res://scenes/panels/story_bible.tscn")
	story_bible = StoryBibleScene.instantiate()
	get_tree().root.add_child(story_bible)
	story_bible.position = Vector2(820, 0)
