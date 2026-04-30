extends Control

@onready var scroll: ScrollContainer = $ScrollContainer
@onready var markdown_label: MarkdownLabel = $ScrollContainer/MarginContainer/MarkdownContent

var text: String = ""
var cursor_position: int = 0

# Public methods for external access
func set_text(p_text: String):
	text = p_text
	cursor_position = min(cursor_position, text.length())
	_update_display()

func get_text() -> String:
	return text

func _ready():
	_update_display()
	GlobalSignals.file_selected.connect(_on_file_selected)

func _on_file_selected(path: String):
	if FileAccess.file_exists(path):
		var content: String = FileAccess.get_file_as_string(path)
		set_text(content)

func _update_display():
	if text.is_empty():
		markdown_label.markdown_text = "[pulse freq=1.0 color=#ffffff40][font gl=-5]|[/font][/pulse]"
		return

	var display_text: String = text
	if cursor_position <= text.length():
		var before_cursor: String = text.substr(0, cursor_position)
		if cursor_position < text.length():
			display_text = before_cursor + "[pulse freq=1.0 color=#ffffff40][font gl=-5]|[/font][/pulse]" + text.substr(cursor_position)
		else:
			display_text = before_cursor + "[pulse freq=1.0 color=#ffffff40][font gl=-5]|[/font][/pulse]"
	markdown_label.markdown_text = display_text
