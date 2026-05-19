extends Control

@onready var titleMessage: Label = $VBoxContainer/PanelContainer/HBoxContainer/TitleMessage
@onready var codeEditor: CodeEdit = $VBoxContainer/MarginContainer2/ScrollContainer/CodeEdit
@onready var scrollContainer: ScrollContainer = $VBoxContainer/MarginContainer2/ScrollContainer

func _ready():
	EventBus.file_saved.connect(_on_file_saved)
	EventBus.editor_content_changed.connect(_on_editor_content_changed)
	EventBus.file_selected.connect(_on_file_selected)
	EventBus.show_git_diff.connect(_on_show_git_diff)

	titleMessage.text = ""

	resized.connect(_on_resized)

func _on_resized():
	EventBus.editor_resized.emit()

func _on_file_selected(path: String):
	titleMessage.text = path.get_file() if path else ""

func _on_show_git_diff(path: String, _diff: String):
	titleMessage.text = path.get_file() + " (changes)" if path else ""

func _on_file_saved(path: String):
	# Update title when file is actually saved to disk
	if path:
		titleMessage.text = path.get_file()

func _on_editor_content_changed(path: String, _content: String):
	# Show unsaved indicator when content changes in editor
	if path:
		titleMessage.text = path.get_file() + " *"


	
	
	
