extends Tree

const CONFIG_FILE: String = "user://config.cfg"

var config: ConfigFile = ConfigFile.new()
var current_path: String = "res://"
var is_building_tree: bool = false

var text_file_whitelist: Array = ['txt', 'md', 'yml', 'yaml', 'json', 'csv', 'html', 'htm', 'xml', 'js', 'ts', 'py', 'rb', 'go', 'rs', 'java', 'c', 'cpp', 'h', 'hpp', 'sh', 'sql', 'log', 'cfg', 'ini', 'toml', 'tex', 'rst']

# Git status icons
var git_status_icons: Dictionary = {
	"modified": load("res://icons/git-modified.svg"),
	"staged": load("res://icons/git-staged.svg"),
	"untracked": load("res://icons/git-untracked.svg"),
	"deleted": load("res://icons/git-deleted.svg")
}

# Map of file paths to their git status
var file_git_status: Dictionary = {}

var dir_check_timer: Timer
var last_dir_state: Dictionary = {}

func _ready():
	item_selected.connect(_on_item_selected)
	GlobalSignals.request_open_folder.connect(_on_open_folder_requested)
	GlobalSignals.folder_opened.connect(_on_folder_opened)
	GlobalSignals.git_file_status_changed.connect(_on_git_file_status_changed)

	_load_config()

	# Setup directory watch timer
	dir_check_timer = Timer.new()
	dir_check_timer.timeout.connect(_on_dir_check_timeout)
	dir_check_timer.wait_time = 5.0
	add_child(dir_check_timer)
	dir_check_timer.start()

func _load_config():
	# Use call_deferred to ensure tree is ready
	call_deferred("_load_config_deferred")

func _load_config_deferred():
	if config.load(CONFIG_FILE) != OK:
		GlobalSignals.folder_opened.emit("res://")
	else:
		GlobalSignals.folder_opened.emit(config.get_value("general", "last_folder", "res://"))

func _save_config():
	config.set_value("general", "last_folder", current_path)
	config.save(CONFIG_FILE)

func _save_last_file(file_path: String):
	config.set_value("general", "last_file", file_path)
	config.save(CONFIG_FILE)

func _ensure_trailing_slash(path: String) -> String:
	if not path.ends_with("/") and not path.ends_with("://"):
		return path + "/"
	return path

func _setup_file_tree():
	if is_building_tree:
		return
	is_building_tree = true

	clear()
	var root_item: TreeItem = create_item()
	var path_parts = current_path.split("/")
	var root_name = path_parts[-2] if current_path.ends_with("/") else path_parts[-1]

	root_item.set_text(0, root_name)
	root_item.set_icon(0, load("res://icons/folder-open.svg"))
	root_item.set_metadata(0, {"path": current_path, "is_dir": true})
	_refresh_files(root_item, _ensure_trailing_slash(current_path))

	# Select first text file after building tree
	call_deferred("_select_first_text_file")
	is_building_tree = false

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
		# Set icons for folders and files
		if entry["is_dir"]:
			item.set_icon(0, load("res://icons/folder.svg"))
			_refresh_files(item, _ensure_trailing_slash(entry["path"]))
		else:
			item.set_icon(0, load("res://icons/file.svg"))
			# Add git status icon if available
			_update_git_status_icon(item, entry["path"])
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
	var info = item.get_metadata(0)
	if info == null:
		return
	var path: String = info["path"]
	var is_dir: bool = info["is_dir"]

	if is_dir:
		current_path = path
		GlobalSignals.folder_opened.emit(path)
		_save_config()
	else:
		GlobalSignals.file_selected.emit(path)
		_save_last_file(path)

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
	last_dir_state = _scan_directory_state(current_path)
	# Use call_deferred to avoid clear() during tree processing
	call_deferred("_setup_file_tree_deferred")

func _on_dir_check_timeout():
	if is_building_tree:
		return

	var current_state = _scan_directory_state(current_path)
	var has_changes = false

	# Check for new or modified items
	for path in current_state:
		if not last_dir_state.has(path) or last_dir_state[path] != current_state[path]:
			has_changes = true
			break

	# Check for deleted items
	for path in last_dir_state:
		if not current_state.has(path):
			has_changes = true
			break

	if has_changes:
		last_dir_state = current_state
		# Refresh only the tree, don't emit file_selected signals
		call_deferred("_setup_file_tree_deferred")

func _scan_directory_state(base_path: String) -> Dictionary:
	var state: Dictionary = {}
	var dir = DirAccess.open(base_path)
	if dir == null:
		return state
	_dir_scan_recursive(dir, _ensure_trailing_slash(base_path), state)
	return state

func _dir_scan_recursive(dir: DirAccess, path: String, state: Dictionary):
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
		var mod_time = FileAccess.get_modified_time(full_path)

		if is_dir:
			state[full_path] = mod_time
			if dir.change_dir(file_name) == OK:
				_dir_scan_recursive(dir, _ensure_trailing_slash(full_path), state)
				dir.change_dir("..")
		else:
			state[full_path] = mod_time

func _setup_file_tree_deferred():
	_setup_file_tree()

func _select_first_text_file():
	# Try to select the last opened file first
	var last_file = ""
	if config.load(CONFIG_FILE) == OK:
		last_file = config.get_value("general", "last_file", "")

	if last_file != "" and FileAccess.file_exists(last_file):
		# Try to find the last opened file in the tree
		var found = _find_tree_item_by_path(get_root(), last_file)
		if found != null:
			found.select(0)
			return

	# Fall back to first text file in the entire tree
	var root = get_root()
	if root == null:
		return

	# Use a simple iterative approach
	var stack = [root]
	while stack.size() > 0:
		var parent = stack.pop_back()
		for i in range(parent.get_child_count()):
			var child = parent.get_child(i)
			var info = child.get_metadata(0)
			if info != null:
				var path = info["path"]
				var is_dir = info["is_dir"]
				if not is_dir and _is_text_file(path):
					child.select(0)
					return
				if is_dir:
					stack.append(child)

func _find_tree_item_by_path(parent: TreeItem, target_path: String) -> TreeItem:
	if parent == null:
		return null

	var info = parent.get_metadata(0)
	if info != null and info["path"] == target_path:
		return parent

	for i in range(parent.get_child_count()):
		var child = parent.get_child(i)
		var found = _find_tree_item_by_path(child, target_path)
		if found != null:
			return found

	return null


## Git Status Integration

func _update_git_status_icon(item: TreeItem, file_path: String) -> void:
	# Only update for text files
	if not _is_text_file(file_path):
		return

	# Get git status for this file
	var status = "not_git"
	if GitManager != null:
		status = GitManager.get_file_status(file_path)
	file_git_status[file_path] = status

	# Set icon based on status
	if git_status_icons.has(status):
		item.set_icon(1, git_status_icons[status])

func _on_git_file_status_changed(file_path: String, status: String):
	if not is_inside_tree():
		return
	# Update the status cache
	file_git_status[file_path] = status

	# Find the tree item for this file and update its icon
	var root = get_root()
	if root == null:
		return

	var item = _find_tree_item_by_path(root, file_path)
	if item != null:
		if git_status_icons.has(status):
			item.set_icon(1, git_status_icons[status])
		else:
			# Clear the git status icon
			item.set_icon(1, null)

func _on_git_repo_changed(is_git_repo: bool):
	if GitManager == null or not is_inside_tree():
		return
	# Clear all git status icons
	file_git_status.clear()

	# Refresh the tree to update icons
	if is_git_repo:
		# Re-scan and update all file icons
		call_deferred("_refresh_git_icons")
	else:
		# Clear git status column
		_clear_git_icons(get_root())

func _refresh_git_icons():
	_clear_git_icons(get_root())
	# Re-query status for all tracked files
	if GitManager.get_git_root() != "":
		GitManager.refresh_status()

func _clear_git_icons(parent: TreeItem):
	if parent == null:
		return

	# Clear git status icon (column 1)
	parent.set_icon(1, null)

	for i in range(parent.get_child_count()):
		var child = parent.get_child(i)
		_clear_git_icons(child)
