extends Control

@onready var scroll: ScrollContainer = $ScrollContainer
@onready var markdown_label: MarkdownLabel = $ScrollContainer/MarginContainer/MarkdownContent

var text: String = ""

# Public methods for external access
func set_text(p_text: String):
	text = p_text
	markdown_label.markdown_text = text

func get_text() -> String:
	return text

func _ready():
	markdown_label.markdown_text = text
	EventBus.file_selected.connect(_on_file_selected)

func _on_file_selected(path: String):
	var content := FileUtils.read_file(path)
	if content != "":
		set_text(content)
