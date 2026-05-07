extends RichTextLabel

func _ready():
	EventBus.file_selected.connect(_on_file_selected)
	EventBus.show_git_diff.connect(_on_show_git_diff)

func _on_show_git_diff(_file_path: String, diff: String):
	# diff already contains only [bgcolor] tags (no [url] meta) when sent from git_panel
	text = diff
	visible = true

func _on_file_selected(_path: String):
	text = ""
	visible = false
