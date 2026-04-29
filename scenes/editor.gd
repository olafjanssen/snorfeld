extends Control

@onready var file_popup: PopupMenu = $MenuBar/File
@onready var tree: Tree = $HSplitContainer/FileBrowser
@onready var markdown_editor: Control = $HSplitContainer/MarkdownEditor

const OPEN_FOLDER_ID: int = 0
const CONFIG_FILE: String = "user://config.cfg"
var config: ConfigFile = ConfigFile.new()
var current_path: String

func _ready():
	# Apply theme and font sizes via signals
	_update_theme()

	_load_config()
	file_popup.add_item("Open Folder...", OPEN_FOLDER_ID)
	file_popup.add_separator()
	file_popup.add_item("Quit", 1)
	file_popup.id_pressed.connect(_on_menu_item_pressed)
	await get_tree().process_frame
	$HSplitContainer.offset_top = $MenuBar.size.y
	_setup_file_tree()
	tree.item_selected.connect(_on_item_activated)

func _update_theme():
	Window.get_focused_window().set_content_scale_factor(2.0)

func _load_config():
	if config.load(CONFIG_FILE) != OK:
		current_path = "res://"
	else:
		current_path = config.get_value("general", "last_folder", "res://")

func _save_config():
	config.set_value("general", "last_folder", current_path)
	config.save(CONFIG_FILE)

func _ensure_trailing_slash(path: String) -> String:
	if not path.ends_with("/") and not path.ends_with("://"):
		return path + "/"
	return path

func _setup_file_tree():
	tree.clear()
	var root: TreeItem = tree.create_item()
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
	
	print(entries)

	entries.sort_custom(func(a, b): return a["name"].naturalnocasecmp_to(b["name"]) < 0)
	
	print(entries)
	
	for entry in entries:
		var item: TreeItem = tree.create_item(parent_item)
		item.set_text(0, entry["name"])
		item.set_metadata(0, {"path": entry["path"], "is_dir": entry["is_dir"]})
		if entry["is_dir"]:
			_refresh_files(item, _ensure_trailing_slash(entry["path"]))

func _on_item_activated():
	var item: TreeItem = tree.get_next_selected(null)
	while item:
		var info: Dictionary = item.get_metadata(0)
		var path: String = info["path"]
		var is_dir: bool = info["is_dir"]
		if is_dir:
			current_path = path
			_setup_file_tree()
			_save_config()
			return
		elif FileAccess.file_exists(path):
			var content: String = FileAccess.get_file_as_string(path)
			markdown_editor.call_deferred("set_text", content)
			return
		item = tree.get_next_selected(item)

func _on_menu_item_pressed(id: int):
	if id == OPEN_FOLDER_ID:
		_on_open_folder_pressed()
	elif id == 1:
		_save_config()
		get_tree().quit()

func _on_open_folder_pressed():
	var dialog: FileDialog = FileDialog.new()
	dialog.use_native_dialog = true
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.title = "Open Folder"
	add_child(dialog)
	dialog.dir_selected.connect(_on_dir_selected)
	dialog.popup_centered()

func _on_dir_selected(path: String):
	current_path = _ensure_trailing_slash(path)
	_setup_file_tree()
	_save_config()
