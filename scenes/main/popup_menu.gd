extends PopupMenu

const OPEN_FOLDER_ID: int = 0
const SETTINGS_ID: int = 2
const STORY_BIBLE_ID: int = 3
const RUN_ALL_GRAMMAR_ANALYSES_ID: int = 206
const RUN_CHAPTER_GRAMMAR_ANALYSES_ID: int = 207
const RUN_ALL_STYLE_ANALYSES_ID: int = 208
const RUN_CHAPTER_STYLE_ANALYSES_ID: int = 209
const RUN_ALL_STRUCTURE_ANALYSES_ID: int = 210
const RUN_CHAPTER_STRUCTURE_ANALYSES_ID: int = 211
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
	add_item("Run All Grammar Analyses", RUN_ALL_GRAMMAR_ANALYSES_ID)
	add_item("Run Chapter Grammar Analyses", RUN_CHAPTER_GRAMMAR_ANALYSES_ID)
	add_separator()
	add_item("Run All Style Analyses", RUN_ALL_STYLE_ANALYSES_ID)
	add_item("Run Chapter Style Analyses", RUN_CHAPTER_STYLE_ANALYSES_ID)
	add_separator()
	add_item("Run All Structure Analyses", RUN_ALL_STRUCTURE_ANALYSES_ID)
	add_item("Run Chapter Structure Analyses", RUN_CHAPTER_STRUCTURE_ANALYSES_ID)
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


# gdlint:ignore-function:long-function
func _on_item_pressed(id: int):
	match id:
		OPEN_FOLDER_ID:
			CommandBus.open_folder.emit()
		SETTINGS_ID:
			EventBus.open_settings.emit()
		STORY_BIBLE_ID:
			CommandBus.open_story_bible.emit()
		RUN_ALL_GRAMMAR_ANALYSES_ID:
			CommandBus.start_analysis.emit("GRAMMAR", "project")
		RUN_CHAPTER_GRAMMAR_ANALYSES_ID:
			CommandBus.start_analysis.emit("GRAMMAR", "chapter")
		RUN_ALL_STYLE_ANALYSES_ID:
			CommandBus.start_analysis.emit("STYLE", "project")
		RUN_CHAPTER_STYLE_ANALYSES_ID:
			CommandBus.start_analysis.emit("STYLE", "chapter")
		RUN_ALL_STRUCTURE_ANALYSES_ID:
			CommandBus.start_analysis.emit("STRUCTURE", "project")
		RUN_CHAPTER_STRUCTURE_ANALYSES_ID:
			CommandBus.start_analysis.emit("STRUCTURE", "chapter")
		RUN_ALL_CHARACTER_ANALYSES_ID:
			CommandBus.start_analysis.emit("CHARACTER", "project")
		RUN_CHAPTER_CHARACTER_ANALYSES_ID:
			CommandBus.start_analysis.emit("CHARACTER", "chapter")
		RUN_ALL_OBJECT_ANALYSES_ID:
			CommandBus.start_analysis.emit("OBJECT", "project")
		RUN_CHAPTER_OBJECT_ANALYSES_ID:
			CommandBus.start_analysis.emit("OBJECT", "chapter")
		INDEX_PROJECT_EMBEDDINGS_ID:
			CommandBus.start_analysis.emit("EMBEDDING", "project")
		INDEX_CHAPTER_EMBEDDINGS_ID:
			CommandBus.start_analysis.emit("EMBEDDING", "chapter")
		1:
			get_tree().quit()
