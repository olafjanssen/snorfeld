extends RichTextLabel

func _ready():
	EventBus.folder_opened.connect(_on_folder_opened)
	text = ""

func _on_folder_opened(path: String):
	text = path
