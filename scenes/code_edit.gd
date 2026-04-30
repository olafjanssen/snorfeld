extends CodeEdit

func _ready():
	var highlighter = load("res://scripts/markdown_highlighter.gd").new()
	syntax_highlighter = highlighter

	GlobalSignals.file_selected.connect(_on_file_selected)

func _on_file_selected(path: String):
	if FileAccess.file_exists(path):
		var content: String = FileAccess.get_file_as_string(path)
		set_text(content)
