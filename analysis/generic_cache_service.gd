class_name GenericCacheService
extends ContentCache
## GenericCacheService - Base class for all caching services
## Provides task queue management, JSONL persistence, and caching infrastructure

# gdlint:ignore-file:file-length

## In-memory cache and queue tracking
var memory_cache: Dictionary = {}
var queued_keys: Dictionary = {}
var loaded_cache_dirs: Dictionary = {}

## Virtual methods - override in subclasses
## These return default values; subclasses should override with their actual values

## Get the service name for signals (e.g., "grammar", "character")
func _get_service_name() -> String:
	return "base"

## Get the cache subdirectory name (e.g., "paragraph", "characters")
func _get_cache_subdir() -> String:
	return "cache"

## Get the JSONL filename for this service
func _get_cache_filename() -> String:
	return "cache.jsonl"

## Analyze/process a single item and return cache data
## Subclasses must implement this
func _analyze(_payload: Dictionary) -> Dictionary:
	return {}

## Get cache key from a payload dictionary
## Default implementation uses 'hash' field, override if different
func _get_cache_key(payload: Dictionary) -> String:
	return payload.get("hash", "")

## Get cache key from loaded data dictionary
## Default implementation uses 'paragraph_hash', 'text_hash', or 'hash'
func _get_cache_key_from_data(data: Dictionary) -> String:
	if data.has("paragraph_hash"):
		return data["paragraph_hash"]
	elif data.has("text_hash"):
		return data["text_hash"]
	elif data.has("hash"):
		return data["hash"]
	return ""

## Get the cache directory for a file path
func _get_cache_dir_for_file(file_path: String) -> String:
	return file_path.get_base_dir().path_join(".snorfeld").path_join(_get_cache_subdir())

## ============================================================================
## Signal emission - override in subclasses to emit service-specific signals
## ============================================================================

## Emit queue updated signal
func _emit_queue_updated() -> void:
	EventBus.analysis_queue_updated.emit(_get_service_name(), task_queue.size())

## Emit task started signal
func _emit_task_started(remaining: int) -> void:
	EventBus.analysis_task_started.emit(_get_service_name(), remaining)

## Emit task completed signal
func _emit_task_completed(remaining: int) -> void:
	EventBus.analysis_task_completed.emit(_get_service_name(), remaining)

## ============================================================================
## Task Queue Management
## ============================================================================

## Queue a task for processing
## payload: Dictionary containing task data (must have 'hash' or use custom _get_cache_key)
func queue_task(payload: Dictionary, priority: bool = false) -> void:
	queue_mutex.lock()
	var key := _get_cache_key(payload)

	# Don't re-queue if already in queue or cached
	if queued_keys.has(key) or memory_cache.has(key):
		queue_mutex.unlock()
		return

	queued_keys[key] = true

	if priority:
		task_queue.insert(0, payload)
	else:
		task_queue.append(payload)
	queue_mutex.unlock()

	_emit_queue_updated()

	# Start processing if not already running
	if not processing:
		await _processing_start()

## Remove a task from the queue by its key
func remove_task_from_queue(key: String) -> void:
	queue_mutex.lock()
	var new_queue := []
	for task in task_queue:
		if _get_cache_key(task) != key:
			new_queue.append(task)
	task_queue = new_queue
	queued_keys.erase(key)
	queue_mutex.unlock()
	_emit_queue_updated()

## Check if a key is currently queued
func is_queued(key: String) -> bool:
	return queued_keys.has(key)

## Check if a key is cached
func is_cached(key: String) -> bool:
	return memory_cache.has(key)

## Get cached data by key
func get_cached(key: String) -> Dictionary:
	return memory_cache.get(key, {})

## ============================================================================
## Cache Loading and Persistence
## ============================================================================

## Ensure a cache directory's JSONL files are loaded into memory
func _ensure_cache_loaded(cache_dir: String) -> void:
	if loaded_cache_dirs.get(cache_dir, false):
		return
	_load_jsonl_cache(cache_dir)
	loaded_cache_dirs[cache_dir] = true

## Load JSONL cache file into memory
func _load_jsonl_cache(cache_dir: String) -> void:
	var jsonl_path := cache_dir.path_join(_get_cache_filename())
	if not FileUtils.file_exists(jsonl_path):
		return

	var content := FileUtils.read_file(jsonl_path)
	if content == "":
		return

	var lines := content.split("\n")
	for line in lines:
		line = line.strip_edges()
		if line == "":
			continue
		var data := JsonUtils.parse_json(line)
		if data == null or data.is_empty():
			continue
		var key := _get_cache_key_from_data(data)
		if key != "":
			memory_cache[key] = data

## Save data to JSONL file
func _save_to_jsonl(cache_dir: String, data: Dictionary) -> void:
	if not FileUtils.dir_exists(cache_dir):
		_create_cache_directory(cache_dir)

	var jsonl_path := cache_dir.path_join(_get_cache_filename())
	var file = FileAccess.open(jsonl_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_string(JsonUtils.stringify_json(data) + "\n")
		file.close()
	else:
		FileUtils.write_file(jsonl_path, JsonUtils.stringify_json(data) + "\n")

## Rewrite entire JSONL file from memory cache
func _rewrite_jsonl_file(cache_dir: String) -> void:
	var jsonl_path := cache_dir.path_join(_get_cache_filename())
	var content := ""
	for key in memory_cache:
		var data = memory_cache[key]
		content += JsonUtils.stringify_json(data) + "\n"
	FileUtils.write_file(jsonl_path, content)

## ============================================================================
## Task Processing (extends ContentCache _process_task)
## ============================================================================

## Override ContentCache's _process_task with generic implementation
func _process_task(task: Dictionary) -> void:
	# Determine cache directory from task
	var cache_dir: String
	if task.has("cache_dir"):
		cache_dir = task["cache_dir"]
	elif task.has("file_path"):
		cache_dir = _get_cache_dir_for_file(task["file_path"])
	else:
		# Cannot process without cache directory
		var key := _get_cache_key(task)
		queued_keys.erase(key)
		return

	# Ensure cache is loaded
	_ensure_cache_loaded(cache_dir)

	# Check if already cached
	var task_key := _get_cache_key(task)
	if memory_cache.has(task_key):
		queued_keys.erase(task_key)
		return

	# Analyze using subclass implementation
	@warning_ignore("redundant_await")
	var result := await _analyze(task)

	if result == null or result.is_empty():
		queued_keys.erase(task_key)
		return

	# Store in memory cache
	memory_cache[task_key] = result

	# Save to JSONL file
	_save_to_jsonl(cache_dir, result)

	# Clean up queue tracking
	queued_keys.erase(task_key)

## ============================================================================
## Utility Methods
## ============================================================================

## Clear all caches (call on project unload)
func clear_all_caches() -> void:
	memory_cache.clear()
	queued_keys.clear()
	loaded_cache_dirs.clear()

## Get cache statistics
func get_stats() -> Dictionary:
	return {
		"service_name": _get_service_name(),
		"cached_count": memory_cache.size(),
		"queued_count": queued_keys.size(),
		"loaded_dirs_count": loaded_cache_dirs.size()
	}
