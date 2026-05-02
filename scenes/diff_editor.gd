extends RichTextLabel

func _ready():
	GlobalSignals.file_selected.connect(_on_file_selected)
	GlobalSignals.show_git_diff.connect(_on_show_git_diff)

func _on_show_git_diff(_path: String, diff: String):
	# Filter out [url=...] and [/url] tags to make them non-clickable in this view
	# Keep [bgcolor] tags for coloring
	# Format: [url=meta][bgcolor=X]text[/bgcolor][/url] -> [bgcolor=X]text[/bgcolor]
	# First remove [url=...] by finding the first ] after [url=
	var filtered_diff = diff
	var url_start := filtered_diff.find("[url=")
	while url_start != -1:
		var url_end := filtered_diff.find("]", url_start)
		if url_end == -1:
			break
		filtered_diff = filtered_diff.substr(0, url_start) + filtered_diff.substr(url_end + 1)
		url_start = filtered_diff.find("[url=")

	# Remove [/url] tags
	filtered_diff = filtered_diff.replace("[/url]", "")

	text = filtered_diff
	visible = true

func _on_file_selected(_path: String):
	text = ""
	visible = false
