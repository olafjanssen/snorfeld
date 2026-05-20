extends PopupMenu

# gdlint:ignore-file:long-function

const OPEN_FOLDER_ID: int = 0
const SETTINGS_ID: int = 2
const STORY_BIBLE_ID: int = 3
const ABOUT_ID: int = 4
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
const CLEAR_GRAMMAR_CACHE_ID: int = 400
const CLEAR_STYLE_CACHE_ID: int = 401
const CLEAR_STRUCTURE_CACHE_ID: int = 402
const CLEAR_CHARACTER_CACHE_ID: int = 403
const CLEAR_OBJECT_CACHE_ID: int = 404
const CLEAR_EMBEDDING_CACHE_ID: int = 405
const OPTIMIZE_EMBEDDING_CACHE_ID: int = 406

func _ready():
	# File menu
	add_item("Open Folder...", OPEN_FOLDER_ID)
	add_separator()

	# View/Window menu
	add_item("Settings...", SETTINGS_ID)
	add_item("Story Bible", STORY_BIBLE_ID)
	add_item("About", ABOUT_ID)
	add_separator()

	# Analysis submenus
	_add_analysis_submenu("Grammar", RUN_ALL_GRAMMAR_ANALYSES_ID, RUN_CHAPTER_GRAMMAR_ANALYSES_ID, CLEAR_GRAMMAR_CACHE_ID)
	_add_analysis_submenu("Style", RUN_ALL_STYLE_ANALYSES_ID, RUN_CHAPTER_STYLE_ANALYSES_ID, CLEAR_STYLE_CACHE_ID)
	_add_analysis_submenu("Structure", RUN_ALL_STRUCTURE_ANALYSES_ID, RUN_CHAPTER_STRUCTURE_ANALYSES_ID, CLEAR_STRUCTURE_CACHE_ID)
	_add_analysis_submenu("Character", RUN_ALL_CHARACTER_ANALYSES_ID, RUN_CHAPTER_CHARACTER_ANALYSES_ID, CLEAR_CHARACTER_CACHE_ID)
	_add_analysis_submenu("Object", RUN_ALL_OBJECT_ANALYSES_ID, RUN_CHAPTER_OBJECT_ANALYSES_ID, CLEAR_OBJECT_CACHE_ID)
	add_separator()

	# Embeddings submenu
	var embeddings_menu := PopupMenu.new()
	add_child(embeddings_menu)
	embeddings_menu.add_item("Index Project Embeddings", INDEX_PROJECT_EMBEDDINGS_ID)
	embeddings_menu.add_item("Index Chapter Embeddings", INDEX_CHAPTER_EMBEDDINGS_ID)
	embeddings_menu.add_item("Clear Embedding Cache", CLEAR_EMBEDDING_CACHE_ID)
	embeddings_menu.add_item("Optimize Embedding Cache", OPTIMIZE_EMBEDDING_CACHE_ID)
	embeddings_menu.id_pressed.connect(_on_item_pressed)
	add_submenu_node_item("Embeddings", embeddings_menu)
	add_separator()

	# Quit at the end
	add_item("Quit", 1)

	id_pressed.connect(_on_item_pressed)

func _add_analysis_submenu(label: String, run_all_id: int, run_chapter_id: int, clear_cache_id: int) -> void:
	var submenu := PopupMenu.new()
	add_child(submenu)
	submenu.add_item("Run All %s Analyses" % label, run_all_id)
	submenu.add_item("Run Chapter %s Analyses" % label, run_chapter_id)
	submenu.add_item("Clear %s Cache" % label, clear_cache_id)
	submenu.id_pressed.connect(_on_item_pressed)
	add_submenu_node_item("%s" % label, submenu)


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

	# Map clear cache menu IDs to their service type
	var clear_cache_actions: Dictionary = {
		CLEAR_GRAMMAR_CACHE_ID: "GRAMMAR",
		CLEAR_STYLE_CACHE_ID: "STYLE",
		CLEAR_STRUCTURE_CACHE_ID: "STRUCTURE",
		CLEAR_CHARACTER_CACHE_ID: "CHARACTER",
		CLEAR_OBJECT_CACHE_ID: "OBJECT",
		CLEAR_EMBEDDING_CACHE_ID: "EMBEDDING"
	}

	if clear_cache_actions.has(id):
		CommandBus.delete_analysis_cache.emit(clear_cache_actions[id])
		return

	if id == OPTIMIZE_EMBEDDING_CACHE_ID:
		CommandBus.optimize_embedding_cache.emit()
		return

	if id == OPEN_FOLDER_ID:
		CommandBus.open_folder.emit()
		return

	if id == SETTINGS_ID:
		CommandBus.open_settings.emit()
		return

	if id == STORY_BIBLE_ID:
		CommandBus.open_story_bible.emit()
		return

	if id == ABOUT_ID:
		CommandBus.open_about.emit()
		return
