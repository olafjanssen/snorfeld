extends PopupMenu

const OPEN_FOLDER_ID: int = 0
const SETTINGS_ID: int = 2

# Git menu items
const GIT_SHOW_PANEL_ID: int = 100
const GIT_INIT_ID: int = 101
const GIT_STAGE_ALL_ID: int = 102
const GIT_COMMIT_ID: int = 103
const GIT_PUSH_ID: int = 104
const GIT_PULL_ID: int = 105
const GIT_FETCH_ID: int = 106
const GIT_REFRESH_ID: int = 107

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
