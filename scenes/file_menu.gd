extends PopupMenu

const OPEN_FOLDER_ID: int = 0
const SETTINGS_ID: int = 2
const RUN_ALL_ANALYSES_ID: int = 200
const RUN_CHAPTER_ANALYSES_ID: int = 201

func _ready():
	add_item("Open Folder...", OPEN_FOLDER_ID)
	add_separator()
	add_item("Settings...", SETTINGS_ID)
	add_separator()
	add_item("Run All Analyses", RUN_ALL_ANALYSES_ID)
	add_item("Run Chapter Analyses", RUN_CHAPTER_ANALYSES_ID)
	add_separator()
	add_item("Quit", 1)
	id_pressed.connect(_on_item_pressed)


func _on_item_pressed(id: int):
	if id == OPEN_FOLDER_ID:
		GlobalSignals.request_open_folder.emit()
	elif id == SETTINGS_ID:
		GlobalSignals.open_settings.emit()
	elif id == RUN_ALL_ANALYSES_ID:
		GlobalSignals.run_all_analyses.emit()
	elif id == RUN_CHAPTER_ANALYSES_ID:
		GlobalSignals.run_chapter_analyses.emit()
	elif id == 1:
		get_tree().quit()
