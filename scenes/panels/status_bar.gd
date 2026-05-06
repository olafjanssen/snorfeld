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

	# Unified cache progress signals (all services use this now)
	EventBus.cache_queue_updated.connect(_on_unified_cache_queue_updated)
	EventBus.cache_task_started.connect(_on_unified_cache_task_started)
	EventBus.cache_task_completed.connect(_on_unified_cache_task_completed)
	EventBus.unified_cache_cleanup_started.connect(_on_unified_cache_cleanup_started)
	EventBus.unified_cache_cleanup_completed.connect(_on_unified_cache_cleanup_completed)

	# Git integration
	EventBus.git_operation_started.connect(_on_git_operation_started)
	EventBus.git_operation_completed.connect(_on_git_operation_completed)


func _on_folder_opened(path: String):
	_set_status(icon_text + "Opened folder: %s" % path)

func _on_file_saved(path: String):
	_set_status(icon_text + "Saved: %s" % path)

# Unified cache progress handlers (all services use this now)
func _on_unified_cache_queue_updated(service_type: String, queued: int, _processing: bool):
	if queued > 0:
		_set_status(icon_text + "[%s] %d queued" % [service_type, queued], false)

func _on_unified_cache_task_started(service_type: String, remaining: int):
	_set_status(icon_text + "[%s] Processing: %d remaining" % [service_type, remaining], true)

func _on_unified_cache_task_completed(service_type: String, remaining: int, _result: Dictionary):
	if remaining > 0:
		_set_status(icon_text + "[%s] Processed: %d remaining" % [service_type, remaining], true)
	else:
		_set_status(icon_text + "[%s] Complete" % [service_type], true)

func _on_unified_cache_cleanup_started(service_type: String):
	_set_status(icon_text + "[%s] Cleaning up old cache files..." % [service_type], true)

func _on_unified_cache_cleanup_completed(service_type: String, removed_count: int):
	if removed_count > 0:
		_set_status(icon_text + "[%s] Cache cleanup: removed %d orphaned files" % [service_type, removed_count])
	else:
		_set_status(icon_text + "[%s] Cache cleanup: nothing to remove" % [service_type])

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
