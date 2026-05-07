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
	EventBus.folder_opened.connect(_on_folder_opened)

	# File saving
	EventBus.file_saved.connect(_on_file_saved)

	# Analysis progress signals (all services use this now)
	EventBus.analysis_queue_updated.connect(_on_analysis_queue_updated)
	EventBus.analysis_task_started.connect(_on_analysis_task_started)
	EventBus.analysis_task_completed.connect(_on_analysis_task_completed)
	EventBus.analysis_cleanup_started.connect(_on_analysis_cleanup_started)
	EventBus.analysis_cleanup_completed.connect(_on_analysis_cleanup_completed)

	# Git integration
	EventBus.git_operation_started.connect(_on_git_operation_started)
	EventBus.git_operation_completed.connect(_on_git_operation_completed)


func _on_folder_opened(path: String):
	_set_status(icon_text + "Opened folder: %s" % path)

func _on_file_saved(path: String):
	_set_status(icon_text + "Saved: %s" % path)

# Analysis progress handlers (all services use this now)
func _on_analysis_queue_updated(service_type: String, queued: int, _processing: bool):
	if queued > 0:
		_set_status(icon_text + "%d %s tasks queued" % [queued, service_type], false)

func _on_analysis_task_started(service_type: String, remaining: int):
	_set_status(icon_text + "Processing %s: %d remaining" % [service_type, remaining], true)

func _on_analysis_task_completed(service_type: String, remaining: int, _result: Dictionary):
	if remaining > 0:
		_set_status(icon_text + "Processed %s: %d remaining" % [service_type, remaining], false)
	else:
		_set_status(icon_text + "Completed %s" % [service_type], false)

func _on_analysis_cleanup_started(service_type: String):
	_set_status(icon_text + "Cleaning up old %s files..." % [service_type], true)

func _on_analysis_cleanup_completed(service_type: String, removed_count: int):
	if removed_count > 0:
		_set_status(icon_text + "%s cleanup: removed %d orphaned files" % [service_type, removed_count])
	else:
		_set_status(icon_text + "%s cleanup: nothing to remove" % [service_type])

func _set_status(message: String, persistent: bool = false):
	text = message
	if not persistent:
		timer.start(display_duration)
	else:
		timer.stop()

func _on_timer_timeout():
	text = default_message


## Git Status Integration

func _on_git_operation_started(operation: String):
	_set_status(icon_text + "Git: %s..." % operation, true)

func _on_git_operation_completed(_operation: String, success: bool, message: String):
	if success:
		_set_status(icon_text + "Git: %s" % message, true)
	else:
		_set_status(icon_text + "Git Error: %s" % message, true)
