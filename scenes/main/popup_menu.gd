extends PopupMenu

# gdlint:ignore-file:long-function

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


func _on_item_pressed(id: int):
	if id == 1:
		get_tree().quit()
		return

	# Map menu IDs to their service type and scope
	var analysis_actions: Dictionary = {
		RUN_ALL_GRAMMAR_ANALYSES_ID: {"type": "GRAMMAR", "scope": "project"},
		RUN_CHAPTER_GRAMMAR_ANALYSES_ID: {"type": "GRAMMAR", "scope": "chapter"},
		RUN_ALL_STYLE_ANALYSES_ID: {"type": "STYLE", "scope": "project"},
		RUN_CHAPTER_STYLE_ANALYSES_ID: {"type": "STYLE", "scope": "chapter"},
		RUN_ALL_STRUCTURE_ANALYSES_ID: {"type": "STRUCTURE", "scope": "project"},
		RUN_CHAPTER_STRUCTURE_ANALYSES_ID: {"type": "STRUCTURE", "scope": "chapter"},
		RUN_ALL_CHARACTER_ANALYSES_ID: {"type": "CHARACTER", "scope": "project"},
		RUN_CHAPTER_CHARACTER_ANALYSES_ID: {"type": "CHARACTER", "scope": "chapter"},
		RUN_ALL_OBJECT_ANALYSES_ID: {"type": "OBJECT", "scope": "project"},
		RUN_CHAPTER_OBJECT_ANALYSES_ID: {"type": "OBJECT", "scope": "chapter"},
		INDEX_PROJECT_EMBEDDINGS_ID: {"type": "EMBEDDING", "scope": "project"},
		INDEX_CHAPTER_EMBEDDINGS_ID: {"type": "EMBEDDING", "scope": "chapter"}
	}

	if analysis_actions.has(id):
		var action: Dictionary = analysis_actions[id]
		if action["scope"] == "project":
			CommandBus.delete_analysis_cache.emit(action["type"])

		CommandBus.start_analysis.emit(action["type"], action["scope"])
		return

	if id == OPEN_FOLDER_ID:
		CommandBus.open_folder.emit()
		return

	if id == SETTINGS_ID:
		CommandBus.open_settings.emit()
		return

	if id == STORY_BIBLE_ID:
		CommandBus.open_story_bible.emit()
