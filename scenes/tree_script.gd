extends Tree

const CONFIG_FILE: String = "user://config.cfg"

var config: ConfigFile = ConfigFile.new()
var current_path: String = "res://"

var text_file_whitelist: Array = ['txt', 'md', 'yml', 'yaml', 'json', 'csv', 'html', 'htm', 'xml', 'js', 'ts', 'py', 'rb', 'go', 'rs', 'java', 'c', 'cpp', 'h', 'hpp', 'sh', 'sql', 'log', 'cfg', 'ini', 'toml', 'tex', 'rst']

func _ready():
	item_selected.connect(_on_item_selected)
	GlobalSignals.request_open_folder.connect(_on_open_folder_requested)
	GlobalSignals.folder_opened.connect(_on_folder_opened)
	_load_config()

func _load_config():
	if config.load(CONFIG_FILE) != OK:
		GlobalSignals.folder_opened.emit("res://")
	else:
		GlobalSignals.folder_opened.emit(config.get_value("general", "last_folder", "res://"))

func _save_config():
	config.set_value("general", "last_folder", current_path)
	config.save(CONFIG_FILE)

func _ensure_trailing_slash(path: String) -> String:
	if not path.ends_with("/") and not path.ends_with("://"):
		return path + "/"
	return path

func _setup_file_tree():
	clear()
	var root: TreeItem = create_item()
	root.set_text(0, current_path)
	_refresh_files(root, _ensure_trailing_slash(current_path))

func _refresh_files(parent_item: TreeItem, path: String):
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entries: Array = []
	var file_name: String
	while true:
		file_name = dir.get_next()
		if file_name == "":
			break
		if file_name == "." or file_name == "..":
			continue
		var full_path: String = path + file_name
		var is_dir: bool = dir.current_is_dir()
		entries.append({"name": file_name, "path": full_path, "is_dir": is_dir})

	entries.sort_custom(func(a, b): return a["name"].naturalnocasecmp_to(b["name"]) < 0)

	for entry in entries:
		var item: TreeItem = create_item(parent_item)
		item.set_text(0, entry["name"])
		item.set_metadata(0, {"path": entry["path"], "is_dir": entry["is_dir"]})
		if entry["is_dir"]:
			_refresh_files(item, _ensure_trailing_slash(entry["path"]))
		else:
			# Scan file and emit signal with paragraphs
			_scan_file_and_emit(entry["path"])

func _is_text_file(file_path: String) -> bool:
	for ext in text_file_whitelist:
		if file_path.ends_with(".%s" % ext):
			return true
	return false


func _scan_file_and_emit(file_path: String) -> void:
	# Only scan whitelisted text files
	if not _is_text_file(file_path):
		return

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file:
		var content := file.get_as_text()
		file.close()

		# Split into paragraphs (separated by double newlines)
		var paragraphs := content.split("\n\n")

		# Emit file_scanned signal with paragraphs and full content for context
		GlobalSignals.file_scanned.emit(file_path, paragraphs, content)

func _on_item_selected():
	var item: TreeItem = get_selected()
	if item == null:
		return
	var info: Dictionary = item.get_metadata(0)
	var path: String = info["path"]
	var is_dir: bool = info["is_dir"]

	if is_dir:
		current_path = path
		GlobalSignals.folder_opened.emit(path)
		_save_config()
	else:
		GlobalSignals.file_selected.emit(path)

func _on_open_folder_requested():
	var dialog: FileDialog = FileDialog.new()
	dialog.use_native_dialog = true
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.title = "Open Folder"
	get_parent().get_parent().add_child(dialog)
	dialog.dir_selected.connect(_on_dir_selected)
	dialog.popup_centered()

func _on_dir_selected(path: String):
	current_path = _ensure_trailing_slash(path)
	GlobalSignals.folder_opened.emit(current_path)
	_save_config()

func _on_folder_opened(path: String):
	current_path = path
	_setup_file_tree()
	# Select the first text file in the folder
	_select_first_text_file()

func _select_first_text_file():
	await get_tree().process_frame  # Wait for tree to be populated
	var first_text_item = _find_first_text_file_item(get_root())
	if first_text_item != null:
		first_text_item.select(0)
		_on_item_selected()

func _find_first_text_file_item(parent: TreeItem) -> TreeItem:
	for i in range(parent.get_child_count()):
		var child = parent.get_child(i)
		var info = child.get_metadata(0)
		if info != null:
			var path = info["path"]
			var is_dir = info["is_dir"]
			if not is_dir and _is_text_file(path):
				return child
			# Recursively check subdirectories
			var found = _find_first_text_file_item(child)
			if found != null:
				return found
	return null
