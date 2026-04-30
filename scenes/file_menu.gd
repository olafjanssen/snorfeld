extends PopupMenu

const OPEN_FOLDER_ID: int = 0
const SETTINGS_ID: int = 2

func _ready():
	add_item("Open Folder...", OPEN_FOLDER_ID)
	add_separator()
	add_item("Settings...", SETTINGS_ID)
	add_separator()
	add_item("Quit", 1)
	id_pressed.connect(_on_item_pressed)


func _on_item_pressed(id: int):
	if id == OPEN_FOLDER_ID:
		GlobalSignals.request_open_folder.emit()
	elif id == SETTINGS_ID:
		GlobalSignals.open_settings.emit()
	elif id == 1:
		get_tree().quit()
