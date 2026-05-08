extends Tree

# gdlint:ignore-file:file-length

const CONFIG_FILE: String = "user://config.cfg"

# Constants
const HIGH_DPI_THRESHOLD: int = 144
const FILE_CHECK_INTERVAL: float = 5.0
const SECOND_TO_LAST_INDEX: int = -2

var config: ConfigFile = ConfigFile.new()
var current_path: String = ""
var is_building_tree: bool = false
var selected_file_path: String = ""
var is_programmatic_selection: bool = false

var text_file_whitelist: Array = [
	'txt', 'md', 'yml', 'yaml', 'json', 'csv', 'html', 'htm', 'xml',
	'js', 'ts', 'py', 'rb', 'go', 'rs', 'java', 'c', 'cpp', 'h', 'hpp',
	'sh', 'sql', 'log', 'cfg', 'ini', 'toml', 'tex', 'rst'
]

# Icon textures for theming
var folder_icon: Texture2D
var folder_open_icon: Texture2D
var file_icon: Texture2D
# Modulated versions
var folder_icon_img: ImageTexture
var folder_open_icon_img: ImageTexture
var file_icon_img: ImageTexture

# Map of file paths to their git status
var file_git_status: Dictionary = {}

var dir_check_timer: Timer
var last_dir_state: Dictionary = {}

func _ready():
	item_selected.connect(_on_item_selected)
	CommandBus.open_folder.connect(_on_open_folder_requested)
	EventBus.folder_opened.connect(_on_folder_opened)
	EventBus.theme_changed.connect(_on_theme_changed)

	# Load icon textures
	folder_icon = load("res://icons/folder.svg")
	folder_open_icon = load("res://icons/folder-open.svg")
	file_icon = load("res://icons/file.svg")
	# Initialize modulated textures
	folder_icon_img = ImageTexture.new()
	folder_open_icon_img = ImageTexture.new()
	file_icon_img = ImageTexture.new()
	_update_icon_colors()

	_load_config()

	# Setup directory watch timer
	dir_check_timer = Timer.new()
	dir_check_timer.timeout.connect(_on_dir_check_timeout)
	dir_check_timer.wait_time = FILE_CHECK_INTERVAL
	add_child(dir_check_timer)
	dir_check_timer.start()

func _load_config():
	# Use call_deferred to ensure tree is ready
	call_deferred("_load_config_deferred")

func _load_config_deferred():
	if config.load(CONFIG_FILE) == OK:
		var last_folder: String = config.get_value("general", "last_folder", "")
		if last_folder != "":
			EventBus.folder_opened.emit(last_folder)

func _save_config():
	if current_path != "":
		config.set_value("general", "last_folder", current_path)
		config.save(CONFIG_FILE)

func _save_last_file(file_path: String):
	# Don't save res:// paths or empty paths (internal project resources)
	if file_path != "" and not file_path.begins_with("res://"):
		config.set_value("general", "last_file", file_path)
		config.save(CONFIG_FILE)

func _ensure_trailing_slash(path: String) -> String:
	if path == "":
		return ""
	if not path.ends_with("/") and not path.ends_with("://"):
		return path + "/"
	return path

func _setup_file_tree(should_select_first: bool = false):
	if is_building_tree or current_path == "":
		return
	is_building_tree = true

	# Remember current selection before clearing
	var previous_selection: String = selected_file_path

	clear()
	var root_item: TreeItem = create_item()
	var path_parts: Array = current_path.split("/")
	var root_name: String = path_parts[SECOND_TO_LAST_INDEX] if current_path.ends_with("/") else path_parts[-1]

	root_item.set_text(0, root_name)
	root_item.set_icon(0, folder_open_icon_img)
	root_item.set_metadata(0, {"path": current_path, "is_dir": true})
	_refresh_files(root_item, _ensure_trailing_slash(current_path))

	# Restore previous selection or select first file
	if previous_selection != "" and not should_select_first:
		call_deferred("_select_file_by_path", previous_selection)
	elif should_select_first:
		call_deferred("_select_first_text_file")
	is_building_tree = false

func _select_file_by_path(path: String):
	var found: TreeItem = _find_tree_item_by_path(get_root(), path)
	if found != null:
		selected_file_path = path
		is_programmatic_selection = true
		found.select(0)
		is_programmatic_selection = false
		scroll_to_item(found)

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

	entries.sort_custom(func(a: Dictionary, b: Dictionary): return a["name"].naturalnocasecmp_to(b["name"]) < 0)

	for entry: Dictionary in entries:
		var item: TreeItem = create_item(parent_item)
		item.set_text(0, entry["name"])
		item.set_metadata(0, {"path": entry["path"], "is_dir": entry["is_dir"]})
		# Set icons for folders and files
		if entry["is_dir"]:
			item.set_icon(0, folder_icon_img)
			_refresh_files(item, _ensure_trailing_slash(entry["path"]))
		else:
			item.set_icon(0, file_icon_img)

func _is_text_file(file_path: String) -> bool:
	for ext: String in text_file_whitelist:
		if file_path.ends_with(".%s" % ext):
			return true
	return false

func _on_item_selected():
	if is_programmatic_selection:
		return
	var item: TreeItem = get_selected()
	if item == null:
		return
	var info: Dictionary = item.get_metadata(0)
	if info == null:
		return
	var path: String = info["path"]
	var is_dir: bool = info["is_dir"]

	selected_file_path = path if not is_dir else ""

	if is_dir:
		current_path = path
		EventBus.folder_opened.emit(path)
		_save_config()
	else:
		EventBus.file_selected.emit(path)
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
	EventBus.folder_opened.emit(current_path)
	_save_config()

func _on_folder_opened(path: String):
	if path == "":
		return
	current_path = path
	last_dir_state = _scan_directory_state(current_path)
	# Use call_deferred to avoid clear() during tree processing
	call_deferred("_setup_file_tree_deferred", true)

func _update_icon_colors():
	var icon_color: Color = get_theme_color("font_color", "Button")
	folder_icon_img = _create_modulated_texture(folder_icon, icon_color)
	folder_open_icon_img = _create_modulated_texture(folder_open_icon, icon_color)
	file_icon_img = _create_modulated_texture(file_icon, icon_color)
	# Force tree redraw
	if is_building_tree == false:
		call_deferred("_setup_file_tree_deferred", false)
	queue_redraw()

func _create_modulated_texture(base: Texture2D, color: Color) -> ImageTexture:
	var src_img: Image = base.get_image()
	var img: Image = Image.create(src_img.get_width(), src_img.get_height(), false, Image.FORMAT_RGBA8)
	img.copy_from(src_img)
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			img.set_pixel(x, y, img.get_pixel(x, y) * color)
	return ImageTexture.create_from_image(img)

func _on_theme_changed():
	_update_icon_colors()

func _on_dir_check_timeout():
	if is_building_tree or current_path == "":
		return

	var current_state: Dictionary = _scan_directory_state(current_path)
	var has_changes: bool = false

	# Check for new or modified items
	for path: String in current_state:
		if not last_dir_state.has(path) or last_dir_state[path] != current_state[path]:
			has_changes = true
			break

	# Check for deleted items
	for path: String in last_dir_state:
		if not current_state.has(path):
			has_changes = true
			break

	if has_changes:
		last_dir_state = current_state
		# Refresh only the tree, don't emit file_selected signals
		call_deferred("_setup_file_tree_deferred", false)

func _scan_directory_state(base_path: String) -> Dictionary:
	var state: Dictionary = {}
	var dir: DirAccess = DirAccess.open(base_path)
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

		var full_path: String = path + file_name
		var is_dir: bool = dir.current_is_dir()
		var mod_time: float = FileUtils.get_modified_time(full_path)

		if is_dir:
			state[full_path] = mod_time
			if dir.change_dir(file_name) == OK:
				_dir_scan_recursive(dir, _ensure_trailing_slash(full_path), state)
				dir.change_dir("..")
		else:
			state[full_path] = mod_time

func _setup_file_tree_deferred(should_select_first: bool = false):
	_setup_file_tree(should_select_first)

func _select_first_text_file():
	if current_path == "":
		return

	if _try_select_last_opened_file():
		return

	_select_first_text_file_from_tree()

## Try to select the last opened file if it exists
func _try_select_last_opened_file() -> bool:
	var last_file: String = _get_last_opened_file_path()
	if last_file == "":
		return false

	var found: TreeItem = _find_tree_item_by_path(get_root(), last_file)
	if found != null:
		selected_file_path = last_file
		found.select(0)
		scroll_to_item(found)
		return true
	return false

## Get the last opened file path from config
func _get_last_opened_file_path() -> String:
	if config.load(CONFIG_FILE) != OK:
		return ""
	var last_file: String = config.get_value("general", "last_file", "")
	if last_file == "" or last_file.begins_with("res://") or not FileUtils.file_exists(last_file):
		return ""
	return last_file

## Select the first text file found in the tree using BFS
func _select_first_text_file_from_tree():
	var root: TreeItem = get_root()
	if root == null:
		return

	var stack: Array = [root]
	while stack.size() > 0:
		var parent: TreeItem = stack.pop_back()
		for i: int in range(parent.get_child_count()):
			var child: TreeItem = parent.get_child(i)
			var info: Dictionary = child.get_metadata(0)
			if info == null:
				continue
			var path: String = info["path"]
			var is_dir: bool = info["is_dir"]
			if not is_dir and _is_text_file(path):
				child.select(0)
				scroll_to_item(child)
				return
			if is_dir:
				stack.append(child)

func _find_tree_item_by_path(parent: TreeItem, target_path: String) -> TreeItem:
	if parent == null:
		return null

	var info: Dictionary = parent.get_metadata(0)
	if info != null and info["path"] == target_path:
		return parent

	for i: int in range(parent.get_child_count()):
		var child: TreeItem = parent.get_child(i)
		var found: TreeItem = _find_tree_item_by_path(child, target_path)
		if found != null:
			return found

	return null
