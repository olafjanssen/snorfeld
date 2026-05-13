extends Control

@onready var TitleMessage: Label = $VBoxContainer/PanelContainer/HBoxContainer/TitleMessage

func _ready():
	EventBus.file_saved.connect(_on_file_saved)
	EventBus.editor_content_changed.connect(_on_editor_content_changed)
	EventBus.file_selected.connect(_on_file_selected)
	EventBus.show_git_diff.connect(_on_show_git_diff)

	TitleMessage.text = ""
	
	resized.connect(_on_resized)

func _on_resized():
	EventBus.editor_resized.emit(size)

func _on_file_selected(path: String):
	TitleMessage.text = path.get_file() if path else ""

func _on_show_git_diff(path: String, _diff: String):
	TitleMessage.text = path.get_file() + " (changes)" if path else ""

func _on_file_saved(path: String):
	# Update title when file is actually saved to disk
	if path:
		TitleMessage.text = path.get_file()

func _on_editor_content_changed(path: String, _content: String):
	# Show unsaved indicator when content changes in editor
	if path:
		TitleMessage.text = path.get_file() + " *"
