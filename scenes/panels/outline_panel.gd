extends Control
## OutlinePanel - Shows chapters and structure from BookService in a tree format

@onready var outline_tree: Tree = $VBoxContainer/OutlineTree

# Current project path
var current_path: String = ""
var rebuild_scheduled: bool = false

func _ready():
	outline_tree.item_selected.connect(_on_item_selected)
	EventBus.folder_opened.connect(_on_folder_opened)
	if BookService != null:
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


func _rebuild_outline_tree() -> void:
	# Use call_deferred to avoid modifying tree during signal processing (reentrancy issue)
	if not rebuild_scheduled:
		rebuild_scheduled = true
		call_deferred("_do_rebuild_outline_tree")


func _do_rebuild_outline_tree() -> void:
	rebuild_scheduled = false
	outline_tree.clear()

	var root = outline_tree.create_item()
	root.set_text(0, "Project Outline")
	root.set_metadata(0, {"type": "root"})

	# Get all files from BookService
	var all_files := BookService.get_all_files()
	all_files.sort()

	# Build flat list of all headings from all files (all levels, not just chapters)
	var all_headings := BookService.get_all_project_headings()

	for heading in all_headings:
		var level = heading.get("level", 1)
		var heading_item = outline_tree.create_item(root)

		# Add indentation based on heading level
		var indent_text = ""
		for _i in range(max(level - 1, 0)):
			indent_text += "  "

		# Add symbol prefix based on level for better visual hierarchy
		var prefix = ""
		if level == 1:
			prefix = "● "
		elif level == 2:
			prefix = "○ "
		elif level == 3:
			prefix = "▪ "

		var display_text = indent_text + prefix + heading.get("text", "Untitled")
		heading_item.set_text(0, display_text)
		heading_item.set_metadata(0, {
			"type": "heading",
			"file": heading.get("file", ""),
			"line": heading.get("line", 0),
			"level": level,
			"text": heading.get("text", "")
		})

		# Set icons based on level
		if level == 1:
			heading_item.set_icon(0, load("res://icons/h1.svg") if ResourceLoader.exists("res://icons/h1.svg") else null)
		elif level == 2:
			heading_item.set_icon(0, load("res://icons/h2.svg") if ResourceLoader.exists("res://icons/h2.svg") else null)
		elif level == 3:
			heading_item.set_icon(0, load("res://icons/h3.svg") if ResourceLoader.exists("res://icons/h3.svg") else null)


func _on_item_selected():
	var item = outline_tree.get_selected()
	if item == null:
		return
	var metadata = item.get_metadata(0)
	if metadata == null:
		return

	if metadata.get("type", "") == "heading":
		var file_path = metadata["file"]
		var line_num = metadata["line"]
		CommandBus.navigate_to_line.emit(file_path, line_num)
		EventBus.file_selected.emit(file_path)
