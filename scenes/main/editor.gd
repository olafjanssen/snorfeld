extends Control

var story_bible: Window

func _ready():
	await get_tree().process_frame
	_update_icon_colors()

	# Detect screen DPI and set appropriate scale
	var dpi := DisplayServer.screen_get_dpi(0)

	# Use 2.0 for high-DPI (Retina/4K), 1.0 for standard
	var ui_scale := 2.0 if dpi > 144 else 1.0
	get_tree().root.content_scale_factor = ui_scale

	$VBoxContainer.offset_top = $MenuBar.size.y
	$VBoxContainer/HSplitContainer.split_offsets = PackedInt32Array([200, 800, 1600])

	$VBoxContainer/PanelContainer/HBoxContainer/SidebarButtonLeft.connect("pressed", _on_sidebar_left_button_pressed)
	$VBoxContainer/PanelContainer/HBoxContainer/SidebarButtonRight.connect("pressed", _on_sidebar_right_button_pressed)
	$VBoxContainer/WindowBar/HBoxContainer/OpenFolderButton.connect("pressed",_on_folder_open_button_pressed)
	$VBoxContainer/WindowBar/HBoxContainer/MenuButton.connect("pressed", _on_menu_open_button_pressed)

	EventBus.theme_changed.connect(_update_icon_colors)
	EventBus.open_story_bible.connect(_open_story_bible)

func _open_story_bible():
	if story_bible != null:
		story_bible.queue_free()
	var StoryBibleScene = preload("res://scenes/panels/story_bible.tscn")
	story_bible = StoryBibleScene.instantiate()
	get_tree().root.add_child(story_bible)
	story_bible.position = Vector2(820, 0)

func _on_sidebar_left_button_pressed():
	$VBoxContainer/HSplitContainer/TabContainer.visible = !$VBoxContainer/HSplitContainer/TabContainer.visible

func _on_sidebar_right_button_pressed():
	$VBoxContainer/HSplitContainer/ParagraphCheck.visible = !$VBoxContainer/HSplitContainer/ParagraphCheck.visible

func _on_folder_open_button_pressed():
	EventBus.request_open_folder.emit()

func _on_menu_open_button_pressed():
	EventBus.open_settings.emit()

func _update_icon_colors():
	var icon_color = get_theme_color("font_color", "Button")
	$VBoxContainer/WindowBar/HBoxContainer/OpenFolderButton.modulate = icon_color
	$VBoxContainer/WindowBar/HBoxContainer/MenuButton.modulate = icon_color
	$VBoxContainer/PanelContainer/HBoxContainer/SidebarButtonLeft.modulate = icon_color
	$VBoxContainer/PanelContainer/HBoxContainer/SidebarButtonRight.modulate = icon_color
