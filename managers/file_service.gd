extends Node

# FileService - Handles automatic saving of files with debouncing
# Implements:
# - Save when changing editor to another file
# - Save X seconds after last change (debounced)
# - Save when application closes

const SAVE_DEBOUNCE_SECONDS: float = 5.0

var current_file_path: String = ""
var has_unsaved_changes: bool = false
var is_saving: bool = false

# Map of file paths to their pending save timers
var pending_saves := {}
# Map of file paths to their content
var file_contents := {}

func _ready():
	# Connect to global signals
	CommandBus.save_file.connect(_on_save_file)
	EventBus.file_changed.connect(_on_file_changed)
	EventBus.file_selected.connect(_on_file_selected)
	CommandBus.save_all_files.connect(_on_save_all_files)

	# Connect to tree signals for application close
	var root: Node = get_tree().root
	root.connect("tree_exiting", _on_tree_exiting)

func _exit_tree():
	# Clean up all pending timers
	for timer in pending_saves.values():
		if timer:
			timer.stop()
			timer.queue_free()
	pending_saves.clear()
	file_contents.clear()

func _on_save_file(path: String):
	# Cancel any pending debounced save for this file
	if pending_saves.has(path):
		pending_saves[path].stop()
		pending_saves[path].queue_free()
		pending_saves.erase(path)
	# Save immediately
	_save_file(path)

func _on_file_changed(path: String, content: String):
	# Mark file as having unsaved changes
	has_unsaved_changes = true
	current_file_path = path

	# Store content for later save
	file_contents[path] = content

	# Debounce the save - reset timer (skip during shutdown)
	if not is_inside_tree():
		return

	if pending_saves.has(path):
		pending_saves[path].stop()
		pending_saves[path].start(SAVE_DEBOUNCE_SECONDS)
	else:
		var timer: Timer = Timer.new()
		timer.timeout.connect(_on_debounced_save_timeout.bind(path))
		add_child(timer)
		pending_saves[path] = timer
		timer.start(SAVE_DEBOUNCE_SECONDS)

func _on_debounced_save_timeout(path: String):
	# Save the file after debounce period
	if pending_saves.has(path):
		pending_saves[path].queue_free()
		pending_saves.erase(path)
	_save_file(path)

func _on_file_selected(path: String):
	# Save current file before switching to another
	if current_file_path != "" and current_file_path != path and has_unsaved_changes:
		_save_file(current_file_path)
	current_file_path = path

func _on_save_all_files():
	# Save all files that have pending changes
	for path in file_contents.keys():
		_save_file(path)

func _on_tree_exiting():
	# Request all editors to emit their final content
	CommandBus.save_all_files.emit()
	# Then save all files that have pending changes
	for path in file_contents.keys():
		_save_file(path)

func _save_file(path: String):
	if is_saving:
		return

	if not FileAccess.file_exists(path):
		return

	# Get content from the map
	var new_content: String = ""
	if file_contents.has(path):
		new_content = file_contents[path]

	if new_content == "":
		is_saving = false
		return

	# Compare with existing file content
	var existing_content: String = FileAccess.get_file_as_string(path)
	if existing_content == new_content:
		# Content hasn't changed, don't save
		file_contents.erase(path)
		is_saving = false
		return

	is_saving = true
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		is_saving = false
		return

	file.store_string(new_content)
	file.close()

	has_unsaved_changes = false
	file_contents.erase(path)
	EventBus.file_saved.emit(path)

	is_saving = false
