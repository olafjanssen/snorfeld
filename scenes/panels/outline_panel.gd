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


const MAX_INDENT_LEVEL: int = 3
const LEVEL_1: int = 1
const LEVEL_2: int = 2

# gdlint:ignore-function:long-function
func _do_rebuild_outline_tree() -> void:
	rebuild_scheduled = false
	outline_tree.clear()

	var root: TreeItem = outline_tree.create_item()
	root.set_text(0, "Project Outline")
	root.set_metadata(0, {"type": "root"})

	# Get all files from BookService
	var all_files: Array = BookService.get_all_files()
	all_files.sort()

	# Build flat list of all headings from all files (all levels, not just chapters)
	var all_headings: Array = BookService.get_all_project_headings()

	for heading: Dictionary in all_headings:
		var level: int = heading.get("level", 1)
		var heading_item: TreeItem = outline_tree.create_item(root)

		# Add indentation based on heading level
		var indent_text: String = _get_indent_for_level(level)

		# Add symbol prefix based on level for better visual hierarchy
		var prefix: String = _get_prefix_for_level(level)

		var display_text: String = indent_text + prefix + heading.get("text", "Untitled")
		heading_item.set_text(0, display_text)
		heading_item.set_metadata(0, {
			"type": "heading",
			"file": heading.get("file", ""),
			"line": heading.get("line", 0),
			"level": level,
			"text": heading.get("text", "")
		})

		# Set icons based on level
		_set_icon_for_level(heading_item, level)

## Get indentation string for a heading level
func _get_indent_for_level(level: int) -> String:
	var indent_text: String = ""
	for _i in range(max(level - 1, 0)):
		indent_text += "  "
	return indent_text

## Get prefix symbol for a heading level
func _get_prefix_for_level(level: int) -> String:
	if level == LEVEL_1:
		return "● "
	elif level == LEVEL_2:
		return "○ "
	else:
		return "▪ "

## Set icon for a heading level
func _set_icon_for_level(item: TreeItem, level: int):
	if level == LEVEL_1:
		item.set_icon(0, load("res://icons/h1.svg") if ResourceLoader.exists("res://icons/h1.svg") else null)
	elif level == LEVEL_2:
		item.set_icon(0, load("res://icons/h2.svg") if ResourceLoader.exists("res://icons/h2.svg") else null)
	elif level <= MAX_INDENT_LEVEL:
		item.set_icon(0, load("res://icons/h3.svg") if ResourceLoader.exists("res://icons/h3.svg") else null)


func _on_item_selected():
	var item: TreeItem = outline_tree.get_selected()
	if item == null:
		return
	var metadata: Dictionary = item.get_metadata(0)
	if metadata == null:
		return

	if metadata.get("type", "") == "heading":
		var file_path: String = metadata["file"]
		var line_num: int = metadata["line"]
		CommandBus.navigate_to_line.emit(file_path, line_num)
		EventBus.file_selected.emit(file_path)
