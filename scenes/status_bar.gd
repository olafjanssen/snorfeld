extends RichTextLabel

@export var default_message: String = ""
@export var display_duration: float = 2.0

var timer: Timer
var icon_text : String = "[pulse freq=1.0 color=#ffffff40 ease=-4.0]✲[/pulse] "

# Git status tracking
var is_git_repo: bool = false
var git_branch: String = ""
var git_status_summary: String = ""

func _ready():
	_connect_global_signals()

	timer = Timer.new()
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)
	text = default_message

func _connect_global_signals():
	# Folder and file navigation
	GlobalSignals.folder_opened.connect(_on_folder_opened)

	# File saving
	GlobalSignals.file_saved.connect(_on_file_saved)

	# Paragraph cache progress
	GlobalSignals.cache_queue_updated.connect(_on_cache_queue_updated)
	GlobalSignals.cache_task_started.connect(_on_cache_task_started)
	GlobalSignals.cache_task_completed.connect(_on_cache_task_completed)
	GlobalSignals.cache_cleanup_started.connect(_on_cache_cleanup_started)
	GlobalSignals.cache_cleanup_completed.connect(_on_cache_cleanup_completed)

	# Git integration
	GlobalSignals.git_repo_changed.connect(_on_git_repo_changed)
	GlobalSignals.git_status_updated.connect(_on_git_status_updated)
	GlobalSignals.git_operation_started.connect(_on_git_operation_started)
	GlobalSignals.git_operation_completed.connect(_on_git_operation_completed)


func _on_folder_opened(path: String):
	_set_status(icon_text + "Opened folder: %s" % path)

func _on_file_saved(path: String):
	_set_status(icon_text + "Saved: %s" % path)

func _on_cache_queue_updated(queued: int, _processing: bool):
	if queued > 0:
		_set_status(icon_text + "Analysis: %d paragraphs queued" % queued, false)

func _on_cache_task_started(remaining: int):
	_set_status(icon_text + "Processing analysis: %d remaining" % remaining, true)

func _on_cache_task_completed(remaining: int):
	if remaining > 0:
		_set_status(icon_text + "Analysis processed: %d remaining" % remaining, true)
	else:
		_set_status(icon_text + "Analysis complete", true)

func _on_cache_cleanup_started():
	_set_status(icon_text + "Cleaning up old cache files...", true)

func _on_cache_cleanup_completed(removed_count: int):
	if removed_count > 0:
		_set_status(icon_text + "Cache cleanup: removed %d orphaned files" % removed_count)
	else:
		_set_status(icon_text + "Cache cleanup: nothing to remove")

func _set_status(message: String, persistent: bool = false):
	text = message
	if not persistent:
		timer.start(display_duration)
	else:
		timer.stop()

func _on_timer_timeout():
	text = default_message


## Git Status Integration

func _on_git_repo_changed(is_repo: bool):
	if not is_inside_tree():
		return
	is_git_repo = is_repo
	if is_repo and GitManager != null:
		# Request status update which will populate branch info
		GitManager.refresh_status()
		git_branch = "..."
		git_status_summary = "..."
		_update_git_status_display()
	else:
		git_branch = ""
		git_status_summary = ""
		_update_git_status_display()

func _on_git_status_updated(status: Dictionary):
	if GitManager == null or not is_inside_tree():
		return
	if status.has("branch"):
		git_branch = status["branch"]

	# Build status summary
	var parts = []
	var counts = status["counts"]
	if counts["modified"] > 0:
		parts.append("M" + str(counts["modified"]))
	if counts["staged"] > 0:
		parts.append("A" + str(counts["staged"]))
	if counts["untracked"] > 0:
		parts.append("?" + str(counts["untracked"]))
	if counts["deleted"] > 0:
		parts.append("D" + str(counts["deleted"]))

	git_status_summary = " ".join(parts) if parts.size() > 0 else "✓"
	_update_git_status_display()

func _on_git_operation_started(operation: String):
	if GitManager == null or not is_inside_tree():
		return
	_set_status(icon_text + "Git: %s..." % operation, true)

func _on_git_operation_completed(_operation: String, success: bool, message: String):
	if GitManager == null or not is_inside_tree():
		return
	if success:
		_set_status(icon_text + "Git: %s" % message, true)
	else:
		_set_status(icon_text + "Git Error: %s" % message, true)

func _update_git_status_display():
	if is_git_repo and git_branch != "":
		var git_info = "[color=#666]Git: %s [%s][/color]" % [git_branch, git_status_summary]
		if text == default_message:
			text = git_info + " " + default_message
		else:
			# Prepend git info to current message
			text = git_info + " " + text
