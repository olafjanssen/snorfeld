class_name ContentCache
extends Node
## ContentCache - Base class for content caching services
## Provides common caching functionality for paragraph and character services

# Cache directory name (override in subclasses)
const CACHE_DIR_NAME := "cache"

# Task queue for cache creation
var task_queue := []
var queue_mutex := Mutex.new()
var processing := false

# Track the current file for analysis
var current_file_path: String = ""
var current_file_content: String = ""

## Virtual methods to be overridden by subclasses

# Get the cache subdirectory name (e.g., "paragraph", "characters")
func _get_cache_subdir() -> String:
	return CACHE_DIR_NAME

# Process a single task (implement in subclass)
func _process_task(_task: Dictionary):
	pass

# Emit queue updated signal
func _emit_queue_updated() -> void:
	pass

# Emit task started signal
func _emit_task_started(_remaining: int) -> void:
	pass

# Emit task completed signal
func _emit_task_completed(_remaining: int) -> void:
	pass

## Common functionality

# Create cache directory
func _create_cache_directory(base_path: String) -> bool:
	if not DirAccess.dir_exists_absolute(base_path):
		var err := DirAccess.make_dir_recursive_absolute(base_path)
		return err == OK
	return true

# Check if file exists
func _file_exists(path: String) -> bool:
	return FileUtils.file_exists(path)

# Cleanup unused cache files (files whose source no longer exists)
func _cleanup_unused_cache_files(cache_path: String, _source_dir: String) -> int:
	var removed_count := 0
	var dir: DirAccess = DirAccess.open(cache_path)
	if not dir:
		return 0

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			# Parse the hash from the filename to find source
			# This is a simplified check - we just verify the cache file can be read
			if not _file_exists(cache_path.path_join(file_name)):
				# File doesn't exist in cache, skip
				file_name = dir.get_next()
				continue

			# For now, keep all cache files during cleanup
			# Subclasses can override with more specific logic
		file_name = dir.get_next()
	dir.list_dir_end()
	return removed_count

# Start processing tasks from the queue
func _processing_start() -> void:
	if processing:
		return
	processing = true

	while task_queue.size() > 0:
		queue_mutex.lock()
		_emit_task_started(task_queue.size())
		var task: Dictionary = task_queue.pop_front()
		queue_mutex.unlock()

		if task:
			# Await the task processing (it may be async with HTTP requests)
			await _process_task(task)
			_emit_task_completed(task_queue.size())

	processing = false
	_emit_queue_updated()
