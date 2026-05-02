extends RichTextLabel

func _ready():
	GlobalSignals.file_selected.connect(_on_file_selected)
	GlobalSignals.show_git_diff.connect(_on_show_git_diff)

func _on_show_git_diff(_path: String, diff: String):
	text = diff
	visible = true

func _on_file_selected(_path: String):
	text = ""
	visible = false
