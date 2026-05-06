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

	# Paragraph cache progress
	EventBus.cache_queue_updated.connect(_on_cache_queue_updated)
	EventBus.cache_task_started.connect(_on_cache_task_started)
	EventBus.cache_task_completed.connect(_on_cache_task_completed)
	EventBus.cache_cleanup_started.connect(_on_cache_cleanup_started)
	EventBus.cache_cleanup_completed.connect(_on_cache_cleanup_completed)

	# Embedding cache progress
	EventBus.embedding_cache_queue_updated.connect(_on_embedding_cache_queue_updated)
	EventBus.embedding_cache_task_started.connect(_on_embedding_cache_task_started)
	EventBus.embedding_cache_task_completed.connect(_on_embedding_cache_task_completed)

	# Git integration
	EventBus.git_operation_started.connect(_on_git_operation_started)
	EventBus.git_operation_completed.connect(_on_git_operation_completed)


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

# Embedding cache progress handlers
func _on_embedding_cache_queue_updated(queued: int, _processing: bool):
	if queued > 0:
		_set_status(icon_text + "Indexing embeddings: %d queued" % queued, false)

func _on_embedding_cache_task_started(remaining: int):
	_set_status(icon_text + "Indexing embeddings: %d remaining" % remaining, true)

func _on_embedding_cache_task_completed(remaining: int):
	if remaining > 0:
		_set_status(icon_text + "Indexing embeddings: %d remaining" % remaining, true)
	else:
		_set_status(icon_text + "Embedding indexing complete", true)

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
	if GitService == null or not is_inside_tree():
		return
	_set_status(icon_text + "Git: %s..." % operation, true)

func _on_git_operation_completed(_operation: String, success: bool, message: String):
	if GitService == null or not is_inside_tree():
		return
	if success:
		_set_status(icon_text + "Git: %s" % message, true)
	else:
		_set_status(icon_text + "Git Error: %s" % message, true)
