extends Control
## OutlinePanel - Shows chapters and structure from BookService in a tree format

@onready var outline_tree: Tree = $VBoxContainer/OutlineTree

# Current project path
var current_path: String = ""

func _ready():
	outline_tree.item_selected.connect(_on_item_selected)
	EventBus.folder_opened.connect(_on_folder_opened)
	EventBus.file_selected.connect(_on_file_selected)
	BookService.project_loaded.connect(_on_project_loaded)
	BookService.project_unloaded.connect(_on_project_unloaded)
	BookService.content_changed.connect(_rebuild_outline_tree)


func _on_folder_opened(path: String):
	current_path = path


func _on_project_loaded(path: String):
	current_path = path
	_rebuild_outline_tree()


func _on_project_unloaded():
	current_path = ""
	outline_tree.clear()


func _on_file_selected(_file_path: String):
	pass


func _rebuild_outline_tree() -> void:
	outline_tree.clear()

	var root = outline_tree.create_item()
	root.set_text(0, "Project Outline")
	root.set_metadata(0, {"type": "root"})

	# Get all files from BookService
	var all_files := BookService.get_all_files()
	all_files.sort()

	for file_path in all_files:
		var file_data := BookService.get_file(file_path)
		if file_data.is_empty():
			continue

		# Get chapters for this file
		var chapter_ids := BookService.get_chapters_for_file(file_path)

		if chapter_ids.size() == 0:
			# File has no chapters, show as a leaf node
			var file_item = outline_tree.create_item(root)
			file_item.set_text(0, file_path.get_file())
			file_item.set_metadata(0, {"type": "file", "file": file_path})
			file_item.set_icon(0, load("res://icons/file.svg") if ResourceLoader.exists("res://icons/file.svg") else null)
		else:
			# File has chapters, show as a parent node
			var file_item = outline_tree.create_item(root)
			file_item.set_text(0, file_path.get_file())
			file_item.set_metadata(0, {"type": "file", "file": file_path})
			file_item.set_icon(0, load("res://icons/file.svg") if ResourceLoader.exists("res://icons/file.svg") else null)

			# Add chapters
			for chapter_id in chapter_ids:
				var chapter := BookService.get_chapter(chapter_id)
				if chapter.is_empty():
					continue

				var chapter_item = outline_tree.create_item(file_item)
				var level = chapter.get("level", 1)

				# Add symbol prefix based on level for better visual hierarchy
				var prefix = ""
				if level == 1:
					prefix = "● "
				elif level == 2:
					prefix = "○ "
				elif level == 3:
					prefix = "▪ "

				var display_text = prefix + chapter.get("title", "Untitled")
				chapter_item.set_text(0, display_text)
				chapter_item.set_metadata(0, {
					"type": "chapter",
					"file": file_path,
					"chapter_id": chapter_id,
					"line": chapter.get("line", 0),
					"level": level,
					"text": chapter.get("title", "")
				})

				# Set icons based on level
				if level == 1:
					chapter_item.set_icon(0, load("res://icons/h1.svg") if ResourceLoader.exists("res://icons/h1.svg") else null)
				elif level == 2:
					chapter_item.set_icon(0, load("res://icons/h2.svg") if ResourceLoader.exists("res://icons/h2.svg") else null)
				elif level == 3:
					chapter_item.set_icon(0, load("res://icons/h3.svg") if ResourceLoader.exists("res://icons/h3.svg") else null)


func _on_item_selected():
	var item = outline_tree.get_selected()
	if item == null:
		return
	var metadata = item.get_metadata(0)
	if metadata == null:
		return

	if metadata.get("type", "") == "chapter":
		var file_path = metadata["file"]
		var line_num = metadata["line"]
		EventBus.navigate_to_line.emit(file_path, line_num)
		EventBus.file_selected.emit(file_path)
	elif metadata.get("type", "") == "file":
		var file_path = metadata["file"]
		EventBus.file_selected.emit(file_path)
