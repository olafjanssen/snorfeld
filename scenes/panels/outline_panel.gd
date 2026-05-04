extends Control
## OutlinePanel - Shows markdown headings from all project files in a tree format

@onready var outline_tree: Tree = $VBoxContainer/OutlineTree

# Cache of outline data per file: {file_path: [{"level": int, "text": String, "line": int}]}
var outline_cache: Dictionary = {}

# Text file extensions that support outline parsing
var text_file_whitelist: Array = ['txt', 'md', 'markdown', 'yml', 'yaml', 'json', 'csv', 'html', 'htm', 'xml', 'js', 'ts', 'py', 'rb', 'go', 'rs', 'java', 'c', 'cpp', 'h', 'hpp', 'sh', 'sql', 'log', 'cfg', 'ini', 'toml', 'tex', 'rst']

# Current project path
var current_path: String = "res://"

func _ready():
	outline_tree.item_selected.connect(_on_item_selected)
	EventBus.folder_opened.connect(_on_folder_opened)
	EventBus.file_selected.connect(_on_file_selected)
	EventBus.file_changed.connect(_on_file_changed)
	EventBus.file_saved.connect(_on_file_saved)

func _is_text_file(file_path: String) -> bool:
	for ext in text_file_whitelist:
		if file_path.ends_with(".%s" % ext):
			return true
	return false

func _on_folder_opened(path: String):
	current_path = path
	_rebuild_outline_tree()

func _on_file_selected(_file_path: String):
	pass

func _on_file_changed(file_path: String, _content: String):
	if outline_cache.has(file_path):
		outline_cache.erase(file_path)
	_rebuild_outline_tree()

func _on_file_saved(file_path: String):
	if outline_cache.has(file_path):
		outline_cache.erase(file_path)
	_rebuild_outline_tree()

func _rebuild_outline_tree():
	outline_tree.clear()

	var root = outline_tree.create_item()
	root.set_text(0, "Project Outline")
	root.set_metadata(0, {"type": "root"})

	var text_files = _find_all_text_files(current_path)
	text_files.sort()

	for file_path in text_files:
		var headings = _get_headings_for_file(file_path)
		for heading in headings:
			var heading_item = outline_tree.create_item(root)

			# Add symbol prefix based on level for better visual hierarchy
			var prefix = ""
			if heading["level"] == 1:
				prefix = "● "
			elif heading["level"] == 2:
				prefix = "○ "
			elif heading["level"] == 3:
				prefix = "▪ "
			else:
				prefix = ""
				for i in range(heading["level"] - 1):
					prefix += "  "

			var indent_text = ""
			for i in range(max(heading["level"] - 1, 0)):
				indent_text += "  "
			var display_text = indent_text + prefix + heading["text"]
			heading_item.set_text(0, display_text)
			heading_item.set_metadata(0, {
				"type": "heading",
				"file": file_path,
				"line": heading["line"],
				"level": heading["level"],
				"text": heading["text"]
			})

			if heading["level"] == 1:
				heading_item.set_icon(0, load("res://icons/h1.svg") if ResourceLoader.exists("res://icons/h1.svg") else null)
			elif heading["level"] == 2:
				heading_item.set_icon(0, load("res://icons/h2.svg") if ResourceLoader.exists("res://icons/h2.svg") else null)
			elif heading["level"] == 3:
				heading_item.set_icon(0, load("res://icons/h3.svg") if ResourceLoader.exists("res://icons/h3.svg") else null)

func _find_all_text_files(base_path: String) -> Array:
	var text_files: Array = []
	var dir = DirAccess.open(base_path)
	if dir == null:
		return text_files
	_dir_scan_recursive(dir, base_path, text_files)
	return text_files

func _dir_scan_recursive(dir: DirAccess, path: String, text_files: Array):
	dir.list_dir_begin()
	var file_name: String
	while true:
		file_name = dir.get_next()
		if file_name == "":
			break
		if file_name == "." or file_name == "..":
			continue
		var full_path = path + file_name
		var is_dir = dir.current_is_dir()
		if is_dir:
			if dir.change_dir(file_name) == OK:
				_dir_scan_recursive(dir, _ensure_trailing_slash(full_path), text_files)
				dir.change_dir("..")
		else:
			if _is_text_file(full_path):
				text_files.append(full_path)

func _ensure_trailing_slash(path: String) -> String:
	if not path.ends_with("/") and not path.ends_with("://"):
		return path + "/"
	return path

func _get_headings_for_file(file_path: String) -> Array:
	if outline_cache.has(file_path):
		return outline_cache[file_path]
	var headings = _parse_markdown_headings(file_path)
	if headings.size() > 0:
		outline_cache[file_path] = headings
	return headings

func _parse_markdown_headings(file_path: String) -> Array:
	var headings: Array = []
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return headings
	var line_num = 0
	while not file.eof_reached():
		var line = file.get_line()
		line_num += 1
		var stripped = line.strip_edges()
		if stripped.begins_with("#"):
			var level = 0
			while level < stripped.length() and stripped[level] == "#":
				level += 1
			if level < stripped.length() and (stripped[level] == " " or stripped[level] == "\t"):
				var text = stripped.substr(level).strip_edges()
				if text != "":
					headings.append({"level": level, "text": text, "line": line_num, "file": file_path})
	file.close()
	return headings

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
		EventBus.navigate_to_line.emit(file_path, line_num)
		EventBus.file_selected.emit(file_path)
