extends PanelContainer
## GitPanel - UI for git operations

signal panel_closed

@onready var status_label: RichTextLabel = $VBoxContainer/StatusHBox/StatusLabel
@onready var branch_label: RichTextLabel = $VBoxContainer/StatusHBox/BranchLabel
@onready var file_list: Tree = $VBoxContainer/FileTree
@onready var commit_message: TextEdit = $VBoxContainer/CommitHBox/CommitMessage
@onready var commit_button: Button = $VBoxContainer/CommitHBox/CommitButton
@onready var refresh_button: Button = $VBoxContainer/ActionHBox/RefreshButton
@onready var stage_all_button: Button = $VBoxContainer/ActionHBox/StageAllButton
@onready var push_button: Button = $VBoxContainer/RemoteHBox/PushButton
@onready var pull_button: Button = $VBoxContainer/RemoteHBox/PullButton
@onready var fetch_button: Button = $VBoxContainer/RemoteHBox/FetchButton

# Git status icons
var status_icons: Dictionary = {
	"modified": load("res://icons/git-modified.svg"),
	"untracked": load("res://icons/git-untracked.svg"),
	"deleted": load("res://icons/git-deleted.svg")
}

# Checkbox icons
var checkbox_icons: Dictionary = {
	"checked": load("res://icons/checkbox-checked.svg"),
	"unchecked": load("res://icons/checkbox-unchecked.svg")
}

# Track staged state per file
var file_staged_state: Dictionary = {}

# Track selected files
var selected_files: Array = []

func _ready():
	# Connect signals
	file_list.item_selected.connect(_on_file_selected)
	file_list.item_activated.connect(_on_file_activated)

	commit_button.pressed.connect(_on_commit_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	stage_all_button.pressed.connect(_on_stage_all_pressed)
	push_button.pressed.connect(_on_push_pressed)
	pull_button.pressed.connect(_on_pull_pressed)
	fetch_button.pressed.connect(_on_fetch_pressed)

	# Connect GitManager signals
	if GitManager != null:
		GitManager.git_repo_changed.connect(_on_git_repo_changed)
		GitManager.git_status_updated.connect(_on_git_status_updated)
		GitManager.git_operation_started.connect(_on_git_operation_started)
		GitManager.git_operation_completed.connect(_on_git_operation_completed)

	# Setup file list - 2 columns: status icon+filename (col 0), checkbox (col 1), hide root
	file_list.columns = 2
	file_list.column_titles_visible = false
	file_list.hide_root = true

	# Connect tree signals for checkbox toggles
	file_list.gui_input.connect(_on_tree_gui_input)

	# Initial update
	if GitManager != null:
		_on_git_repo_changed(GitManager.is_git_repo_cached)

func _on_git_repo_changed(is_git_repo: bool):
	if GitManager == null or not is_inside_tree():
		return
	if is_git_repo:
		status_label.text = "Git repository detected"
		branch_label.text = "Branch: " + GitManager.get_status().get("branch", "unknown")
		_update_file_list()
		_set_buttons_enabled(true)
	else:
		status_label.text = "Not a git repository"
		branch_label.text = ""
		file_list.clear()
		_set_buttons_enabled(false)

func _on_git_status_updated(status: Dictionary):
	if GitManager == null or not is_inside_tree():
		return
	# Update branch label
	if status.has("branch"):
		branch_label.text = "Branch: " + status["branch"]

	# Update status summary
	var summary_parts = []
	if status["modified"].size() > 0:
		summary_parts.append(str(status["modified"].size()) + " modified")
	if status["staged"].size() > 0:
		summary_parts.append(str(status["staged"].size()) + " staged")
	if status["untracked"].size() > 0:
		summary_parts.append(str(status["untracked"].size()) + " untracked")
	if status["deleted"].size() > 0:
		summary_parts.append(str(status["deleted"].size()) + " deleted")

	if summary_parts.size() > 0:
		status_label.text = " ".join(summary_parts)
	else:
		status_label.text = "Clean"

	# Update file list
	_update_file_list()

func _update_file_list():
	if GitManager == null or not is_inside_tree():
		return
	file_list.clear()

	# Create a root item (will be hidden due to hide_root = true)
	var root = file_list.create_item()

	var status = GitManager.get_status()
	if status.has("error"):
		return

	# Collect all files with their status and sort alphabetically
	var all_files: Array = []

	# Use file_status to get all unique files and their actual status
	if status.has("file_status"):
		for file_path in status["file_status"]:
			var file_status = status["file_status"][file_path]
			all_files.append({"path": file_path, "status": file_status})
	else:
		# Fallback to old method
		for file_path in status["modified"]:
			all_files.append({"path": file_path, "status": "modified"})
		for file_path in status["staged"]:
			all_files.append({"path": file_path, "status": "staged"})
		for file_path in status["untracked"]:
			all_files.append({"path": file_path, "status": "untracked"})
		for file_path in status["deleted"]:
			all_files.append({"path": file_path, "status": "deleted"})

	# Sort alphabetically by filename (not full path)
	all_files.sort_custom(func(a, b): return a["path"].get_file().naturalnocasecmp_to(b["path"].get_file()))

	# Add all files in sorted order
	for file_info in all_files:
		_add_file_to_list(root, file_info["path"], file_info["status"])

func _add_file_to_list(parent_item, file_path: String, status: String):
	print("Adding: ", file_path, " ", status)
	var item = file_list.create_item(parent_item)
	var file_name = file_path.get_file()

	# Combine status icon and filename in column 0
	item.set_text(0, file_name)
	item.set_metadata(0, {"path": file_path, "status": status})

	# Get the actual file status (not staged status) for the icon
	var git_status = GitManager.get_status()
	var actual_status = status
	if git_status.has("file_status") and git_status["file_status"].has(file_path):
		actual_status = git_status["file_status"][file_path]

	# Set status icon in column 0 based on actual file status
	if status_icons.has(actual_status):
		item.set_icon(0, status_icons[actual_status])

	# Set checkbox in column 1 - default to checked if already staged
	var is_staged = git_status.get("staged", []).has(file_path)
	file_staged_state[file_path] = is_staged
	item.set_icon(1, checkbox_icons["checked"] if is_staged else checkbox_icons["unchecked"])

func _on_file_selected():
	selected_files.clear()
	var item = file_list.get_selected()
	if item:
		var metadata = item.get_metadata(0)
		if metadata:
			selected_files.append(metadata["path"])

func _on_tree_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = event.position
		var item = file_list.get_item_at_position(mouse_pos)
		if item:
			# Check if click was in the checkbox column (column 1)
			var col = file_list.get_column_at_position(mouse_pos)
			if col == 1:
				var metadata = item.get_metadata(0)
				if metadata:
					_on_checkbox_clicked(item, metadata["path"])

func _on_checkbox_clicked(item, file_path: String) -> void:
	# Toggle staged state
	file_staged_state[file_path] = not file_staged_state[file_path]
	var is_staged = file_staged_state[file_path]
	item.set_icon(1, checkbox_icons["checked"] if is_staged else checkbox_icons["unchecked"])

	# Stage/unstage the file
	if is_staged:
		GitManager.stage_file(file_path)
	else:
		GitManager.unstage_file(file_path)

func _on_file_activated():
	# Double-click to show diff
	var item = file_list.get_selected()
	if item:
		var metadata = item.get_metadata(0)
		if metadata:
			var file_path = metadata["path"]
			var diff = GitManager.get_diff(file_path)
			if diff != "":
				# Show diff in a popup
				_show_diff_popup(file_path, diff)

func _show_diff_popup(file_path: String, diff: String):
	var popup = AcceptDialog.new()
	popup.title = "Diff: " + file_path.get_file()
	popup.dialog_text = "Git diff for this file:"

	var text_edit = TextEdit.new()
	text_edit.text = diff
	text_edit.editable = false
	text_edit.readonly = true
	text_edit.size = Vector2(600, 400)

	popup.add_child(text_edit)
	popup.size = Vector2(620, 450)

	get_parent().add_child(popup)
	popup.popup_centered()

func _on_commit_pressed():
	var message = commit_message.text.strip_edges()
	if message == "":
		_show_error("Please enter a commit message")
		return

	var success = GitManager.commit(message)
	if success:
		commit_message.text = ""

func _on_refresh_pressed():
	GitManager.refresh_status()

func _on_stage_all_pressed():
	# Simply call stage_all - the status update will refresh the tree via git_status_updated signal
	GitManager.stage_all()

func _on_push_pressed():
	GitManager.push()

func _on_pull_pressed():
	GitManager.pull()

func _on_fetch_pressed():
	GitManager.fetch()

func _set_buttons_enabled(enabled: bool):
	commit_button.disabled = not enabled
	refresh_button.disabled = not enabled
	stage_all_button.disabled = not enabled
	push_button.disabled = not enabled
	pull_button.disabled = not enabled
	fetch_button.disabled = not enabled

func _on_git_operation_started(operation: String):
	if GitManager == null or not is_inside_tree():
		return
	status_label.text = "Performing: " + operation + "..."

func _on_git_operation_completed(operation: String, success: bool, message: String):
	if GitManager == null or not is_inside_tree():
		return
	if success:
		status_label.text = message
	else:
		status_label.text = "Error: " + message

func _show_error(message: String):
	var dialog = AcceptDialog.new()
	dialog.title = "Error"
	dialog.dialog_text = message
	dialog.add_button("OK", true, "pressed")
	get_parent().add_child(dialog)
	dialog.popup_centered()
