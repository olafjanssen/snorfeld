extends PopupMenu
## Git Menu - Handles git-related menu items

const SHOW_PANEL_ID: int = 0
const INIT_REPO_ID: int = 1
const STAGE_ALL_ID: int = 2
const COMMIT_ID: int = 3
const PUSH_ID: int = 4
const PULL_ID: int = 5
const FETCH_ID: int = 6
const REFRESH_ID: int = 7

func _ready():
	add_item("Show Git Panel", SHOW_PANEL_ID)
	add_item("Initialize Repository...", INIT_REPO_ID)
	add_separator()
	add_item("Stage All", STAGE_ALL_ID)
	add_item("Commit...", COMMIT_ID)
	add_separator()
	add_item("Push", PUSH_ID)
	add_item("Pull", PULL_ID)
	add_item("Fetch", FETCH_ID)
	add_separator()
	add_item("Refresh Status", REFRESH_ID)

	id_pressed.connect(_on_item_pressed)

	# Connect to git repo changed signal to update menu state
	if GitManager != null:
		GitManager.git_repo_changed.connect(_on_git_repo_changed_for_menu)

func _on_item_pressed(id: int):
	if GitManager == null and id != SHOW_PANEL_ID:
		return
	if id == SHOW_PANEL_ID:
		GlobalSignals.request_open_git_panel.emit()
	elif id == INIT_REPO_ID:
		_on_init_repo()
	elif id == STAGE_ALL_ID:
		GitManager.stage_all()
	elif id == COMMIT_ID:
		_show_commit_dialog()
	elif id == PUSH_ID:
		GitManager.push()
	elif id == PULL_ID:
		GitManager.pull()
	elif id == FETCH_ID:
		GitManager.fetch()
	elif id == REFRESH_ID:
		GitManager.refresh_status()

func _on_init_repo():
	var dialog = ConfirmationDialog.new()
	dialog.title = "Initialize Git Repository"
	dialog.dialog_text = "Are you sure you want to initialize a git repository in this folder?"
	dialog.add_button("Yes", true, "confirmed")
	dialog.add_button("No", false, "cancelled")

	get_parent().get_parent().add_child(dialog)
	dialog.confirmed.connect(_on_init_confirmed)
	dialog.popup_centered()

func _on_init_confirmed():
	if GitManager == null:
		return
	# Get current folder from TreeScript
	var tree_script = get_node("/root/Editor/VBoxContainer/HSplitContainer/FileBrowser")
	var path = ""
	if tree_script and tree_script.current_path != "":
		path = tree_script.current_path
	elif GlobalSignals.current_path != "":
		path = GlobalSignals.current_path

	if path != "":
		GitManager.init_git_repo(path)
func _show_commit_dialog():
	var dialog = AcceptDialog.new()
	dialog.title = "Commit"
	dialog.dialog_text = "Enter commit message:"

	var text_edit = TextEdit.new()
	text_edit.size = Vector2(400, 100)
	text_edit.placeholder_text = "Enter commit message..."

	var hbox = HBoxContainer.new()
	hbox.add_child(text_edit)

	var commit_button = Button.new()
	commit_button.text = "Commit"
	commit_button.pressed.connect(_on_commit_from_dialog.bind(text_edit))

	hbox.add_child(commit_button)
	dialog.add_child(hbox)

	get_parent().get_parent().add_child(dialog)
	dialog.popup_centered()

func _on_commit_from_dialog(text_edit: TextEdit):
	if GitManager == null:
		return
	var message = text_edit.text.strip_edges()
	if message != "":
		GitManager.commit(message)
		text_edit.get_parent().get_parent().queue_free()

func _on_git_repo_changed_for_menu(is_git_repo: bool):
	if not is_inside_tree():
		return
	if get_item_count() > 0:
		set_item_disabled(INIT_REPO_ID, is_git_repo)
		set_item_disabled(STAGE_ALL_ID, not is_git_repo)
		set_item_disabled(COMMIT_ID, not is_git_repo)
		set_item_disabled(PUSH_ID, not is_git_repo)
		set_item_disabled(PULL_ID, not is_git_repo)
		set_item_disabled(FETCH_ID, not is_git_repo)
		set_item_disabled(REFRESH_ID, not is_git_repo)

func _update_menu_state(path: String = ""):
	if GitManager == null or not is_inside_tree():
		return
	_on_git_repo_changed_for_menu(GitManager.is_git_repo_cached)
