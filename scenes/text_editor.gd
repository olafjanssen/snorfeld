extends Control

@onready var TitleMessage: Label = $VBoxContainer/PanelContainer/HBoxContainer/TitleMessage

func _ready():
	GlobalSignals.file_changed.connect(_on_file_changed)
	GlobalSignals.file_selected.connect(_on_file_selected)
	GlobalSignals.show_git_diff.connect(_on_show_git_diff)

	TitleMessage.text = ""

func _on_file_selected(path: String):
	TitleMessage.text = path.get_file() if path else ""

func _on_show_git_diff(path: String, _diff: String):
	TitleMessage.text = path.get_file() + " (changes)" if path else ""

func _on_file_changed(path: String, _content: String):
	if path:
		TitleMessage.text = path.get_file()
