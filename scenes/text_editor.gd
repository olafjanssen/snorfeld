extends Control

@onready var TitleMessage: Label = $VBoxContainer/PanelContainer/HBoxContainer/TitleMessage

func _ready():
	GlobalSignals.file_changed.connect(_on_file_changed)
	GlobalSignals.file_selected.connect(_on_file_selected)
	TitleMessage.text = ""

func _on_file_selected(path: String):
	TitleMessage.text = path.get_file() if path else ""

func _on_file_changed(path: String, content: String):
	if path:
		TitleMessage.text = path.get_file()
