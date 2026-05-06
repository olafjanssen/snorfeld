extends PopupMenu

const OPEN_FOLDER_ID: int = 0
const SETTINGS_ID: int = 2
const STORY_BIBLE_ID: int = 3
const RUN_ALL_ANALYSES_ID: int = 200
const RUN_CHAPTER_ANALYSES_ID: int = 201
const RUN_ALL_CHARACTER_ANALYSES_ID: int = 202
const RUN_CHAPTER_CHARACTER_ANALYSES_ID: int = 203
const RUN_ALL_OBJECT_ANALYSES_ID: int = 204
const RUN_CHAPTER_OBJECT_ANALYSES_ID: int = 205
const INDEX_PROJECT_EMBEDDINGS_ID: int = 300
const INDEX_CHAPTER_EMBEDDINGS_ID: int = 301

func _ready():
	add_item("Open Folder...", OPEN_FOLDER_ID)
	add_separator()
	add_item("Settings...", SETTINGS_ID)
	add_item("Story Bible", STORY_BIBLE_ID)
	add_separator()
	add_item("Run All Analyses", RUN_ALL_ANALYSES_ID)
	add_item("Run Chapter Analyses", RUN_CHAPTER_ANALYSES_ID)
	add_separator()
	add_item("Run All Character Analyses", RUN_ALL_CHARACTER_ANALYSES_ID)
	add_item("Run Chapter Character Analyses", RUN_CHAPTER_CHARACTER_ANALYSES_ID)
	add_separator()
	add_item("Run All Object Analyses", RUN_ALL_OBJECT_ANALYSES_ID)
	add_item("Run Chapter Object Analyses", RUN_CHAPTER_OBJECT_ANALYSES_ID)
	add_separator()
	add_item("Index Project Embeddings", INDEX_PROJECT_EMBEDDINGS_ID)
	add_item("Index Chapter Embeddings", INDEX_CHAPTER_EMBEDDINGS_ID)
	add_separator()
	add_item("Quit", 1)
	id_pressed.connect(_on_item_pressed)


func _on_item_pressed(id: int):
	if id == OPEN_FOLDER_ID:
		EventBus.request_open_folder.emit()
	elif id == SETTINGS_ID:
		EventBus.open_settings.emit()
	elif id == STORY_BIBLE_ID:
		EventBus.open_story_bible.emit()
	elif id == RUN_ALL_ANALYSES_ID:
		EventBus.run_all_analyses.emit()
	elif id == RUN_CHAPTER_ANALYSES_ID:
		EventBus.run_chapter_analyses.emit()
	elif id == RUN_ALL_CHARACTER_ANALYSES_ID:
		EventBus.run_all_character_analyses.emit()
	elif id == RUN_CHAPTER_CHARACTER_ANALYSES_ID:
		EventBus.run_chapter_character_analyses.emit()
	elif id == RUN_ALL_OBJECT_ANALYSES_ID:
		EventBus.run_all_object_analyses.emit()
	elif id == RUN_CHAPTER_OBJECT_ANALYSES_ID:
		EventBus.run_chapter_object_analyses.emit()
	elif id == INDEX_PROJECT_EMBEDDINGS_ID:
		EventBus.index_project_embeddings.emit()
	elif id == INDEX_CHAPTER_EMBEDDINGS_ID:
		EventBus.index_chapter_embeddings.emit()
	elif id == 1:
		get_tree().quit()
