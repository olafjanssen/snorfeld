extends Control
## GitPanel - UI for git operations

@onready var file_list: Tree = $VBoxContainer/FileTree
@onready var commit_message: TextEdit = $VBoxContainer/CommitHBox/PanelContainer/MarginContainer/CommitMessage
@onready var commit_button: Button = $VBoxContainer/CommitHBox/CommitButton
@onready var stage_all_button: Button = $VBoxContainer/RemoteHBox/StageAllButton
@onready var push_button: Button = $VBoxContainer/RemoteHBox/PushButton
@onready var pull_button: Button = $VBoxContainer/RemoteHBox/PullButton
@onready var fetch_button: Button = $VBoxContainer/RemoteHBox/FetchButton

# Git status icons
var status_icons: Dictionary = {
	"modified": load("res://icons/git-modified.svg"),
	"untracked": load("res://icons/git-untracked.svg"),
	"deleted": load("res://icons/git-deleted.svg"),
	"renamed": load("res://icons/git-renamed.svg"),
	"staged": load("res://icons/git-staged.svg")
}

# Checkbox icons
var checkbox_icons: Dictionary = {
	"checked": load("res://icons/checkbox-checked.svg"),
	"unchecked": load("res://icons/checkbox-unchecked.svg")
}

# Track staged state per file
var file_staged_state: Dictionary = {}
var next_button_id: int = 0

# Track selected files
var selected_files: Array = []

# Track current diff file
var _current_diff_file: String = ""

# Auto-refresh timer
var refresh_timer: Timer

func _ready():
	EventBus.theme_changed.connect(_on_theme_changed)
	# Connect signals
	file_list.item_selected.connect(_on_file_selected)
	file_list.item_activated.connect(_on_file_activated)

	commit_button.pressed.connect(_on_commit_pressed)
	stage_all_button.pressed.connect(_on_stage_all_pressed)
	push_button.pressed.connect(_on_push_pressed)
	pull_button.pressed.connect(_on_pull_pressed)
	fetch_button.pressed.connect(_on_fetch_pressed)

	# Connect GitService signals
	if GitService != null:
		EventBus.git_repo_changed.connect(_on_git_repo_changed)
		EventBus.git_status_updated.connect(_on_git_status_updated)

	# Connect tree button clicked signal for staging
	file_list.button_clicked.connect(_on_stage_button_clicked)

	# Setup auto-refresh timer
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 10.0
	refresh_timer.timeout.connect(_on_refresh_timeout)
	add_child(refresh_timer)
	refresh_timer.start()

	# Initial update
	if GitService != null:
		_on_git_repo_changed(GitService.is_git_repo_cached)

func _on_git_repo_changed(is_git_repo: bool):
	if GitService == null or not is_inside_tree():
		return
	if is_git_repo:
		_update_file_list()
		_set_buttons_enabled(true)
	else:
		file_list.clear()
		_set_buttons_enabled(false)

func _on_git_status_updated(_status: Dictionary):
	if GitService == null or not is_inside_tree():
		return

	# Update file list
	_update_file_list()

func _update_file_list():
	if GitService == null or not is_inside_tree():
		return
	file_list.clear()

	# Create a root item (will be hidden due to hide_root = true)
	var root = file_list.create_item()

	var status = GitService.get_status()
	if status.has("error"):
		return

	# Collect all files and sort alphabetically
	var all_files = status["files"].duplicate()

	# Sort alphabetically by filename (not full path)
	all_files.sort_custom(func(a, b): return a["path"].get_file().naturalnocasecmp_to(b["path"].get_file()) < 0)

	# Add all files in sorted order
	for file_info in all_files:
		_add_file_to_list(root, file_info["path"], file_info["change_type"], file_info["staged"])

func _add_file_to_list(parent_item, file_path: String, change_type: String, is_staged: bool):
	var item = file_list.create_item(parent_item)
	var file_name = file_path.get_file()

	# Set text and icon in column 0
	item.set_text(0, file_name)
	item.set_metadata(0, {"path": file_path, "change_type": change_type, "staged": is_staged})

	# Set status icon based on change type
	if status_icons.has(change_type):
		item.set_icon(0, status_icons[change_type])

	# Add stage button with unique ID
	var button_icon = checkbox_icons["checked"] if is_staged else checkbox_icons["unchecked"]
	item.add_button(0, button_icon, next_button_id, false, "Toggle staging")
	file_staged_state[file_path] = is_staged
	next_button_id += 1

func _on_file_selected():
	selected_files.clear()
	var item = file_list.get_selected()
	if item:
		var metadata = item.get_metadata(0)
		if metadata:
			selected_files.append(metadata["path"])

func _on_stage_button_clicked(item: TreeItem, _column: int, _button_index: int, _id: int) -> void:
	var metadata = item.get_metadata(0)
	if metadata:
		var file_path = metadata["path"]
		# Toggle staged state
		var is_staged = not file_staged_state[file_path]
		file_staged_state[file_path] = is_staged

		# Update button icon (button is always at index 0)
		item.set_button(0, 0, checkbox_icons["checked"] if is_staged else checkbox_icons["unchecked"])

		# Stage/unstage the file
		if is_staged:
			GitService.stage_file(file_path)
		else:
			GitService.unstage_file(file_path)

func _on_file_activated():
	# Double-click to show diff
	var item = file_list.get_selected()
	if item:
		var metadata = item.get_metadata(0)
		if metadata:
			var file_path = metadata["path"]
			_show_git_diff(file_path)

func _show_git_diff(file_path: String):
	_current_diff_file = file_path
	# Get absolute path
	var absolute_path = GitService.get_absolute_path(file_path)

	# Get current file content
	var current_content := FileUtils.read_file(absolute_path)

	# Get git version of the file
	var git_content = GitService.get_file_content_from_git(file_path)

	if git_content != "" and current_content != "":
		# Use DiffUtility to create a human-readable diff
		var diff_utility = DiffUtility.new()
		diff_utility.set_control(self)
		var diff_bbcode = diff_utility.calculate_diff(git_content, current_content)
		EventBus.show_git_diff.emit(file_path, diff_bbcode)

func _regenerate_diff():
	if _current_diff_file != "":
		_show_git_diff(_current_diff_file)

func _on_theme_changed():
	_regenerate_diff()

func _on_commit_pressed():
	var message = commit_message.text.strip_edges()
	if message == "":
		_show_error("Please enter a commit message")
		return

	var success = GitService.commit(message)
	if success:
		commit_message.text = ""
		_update_file_list()


func _on_refresh_timeout():
	_update_file_list()

func _on_stage_all_pressed():
	# Simply call stage_all - the status update will refresh the tree via git_status_updated signal
	GitService.stage_all()

func _on_push_pressed():
	GitService.push()
	_update_file_list()

func _on_pull_pressed():
	GitService.pull()
	_update_file_list()

func _on_fetch_pressed():
	GitService.fetch()
	_update_file_list()

func _set_buttons_enabled(enabled: bool):
	commit_button.disabled = not enabled
	stage_all_button.disabled = not enabled
	push_button.disabled = not enabled
	pull_button.disabled = not enabled
	fetch_button.disabled = not enabled

func _show_error(message: String):
	var dialog = AcceptDialog.new()
	dialog.title = "Error"
	dialog.dialog_text = message
	dialog.add_button("OK", true, "pressed")
	get_parent().add_child(dialog)
	dialog.popup_centered()
