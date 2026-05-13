class_name AnalysisService
extends Node
## AnalysisService - Unified base class for all analysis caching services
## Provides task queue management, JSONL persistence, caching infrastructure,
## field encoding/decoding, and configurable merge strategies

# gdlint:ignore-file:file-length,too-many-public-methods

## ============================================================================
## Configuration Properties - Set these in _ready() or constructor
## ============================================================================

# Service identifier for signals (e.g., "grammar", "character")
var service_name: String = "base"

# Cache subdirectory name (e.g., "paragraph", "characters")
var cache_subdir: String = "cache"

# JSONL filename for this service (e.g., "grammar.jsonl", "characters.jsonl")
var cache_filename: String = "cache.jsonl"

# Whether to merge data when the same key is encountered (for entity services)
var should_merge_on_duplicate: bool = false

# Merge strategies for entity services (key -> MergeStrategy enum value)
# Define MergeStrategy enum below, but import from MergeUtils for consistency
var merge_strategies: Dictionary = {}

# Field encoders: maps field names to encoding functions (e.g., for base64)
# Example: field_encoders = {"embedding": Marshalls.variant_to_base64}
var field_encoders: Dictionary = {}

# Field decoders: maps field names to decoding functions
# Example: field_decoders = {"embedding": Marshalls.base64_to_variant}
var field_decoders: Dictionary = {}

## ============================================================================
## State Variables
## ============================================================================

# In-memory cache: key -> data dictionary
var memory_cache: Dictionary = {}

# Track which keys are currently queued (to prevent duplicate queuing)
var queued_keys: Dictionary = {}

# Track which cache directories have been loaded into memory
var loaded_cache_dirs: Dictionary = {}

# Task queue for background processing
var task_queue: Array = []

# Mutex for thread-safe queue operations
var queue_mutex: Mutex = Mutex.new()

# Flag indicating if processing is currently running
var processing: bool = false

# Track the current file for analysis
var current_file_path: String = ""
var current_file_content: String = ""

## ============================================================================
## Virtual Methods - Override in subclasses
## ============================================================================

## Get the service name for signals (e.g., "grammar", "character")
## Default returns service_name property
func _get_service_name() -> String:
	return service_name

## Get the cache subdirectory name (e.g., "paragraph", "characters")
## Default returns cache_subdir property
func _get_cache_subdir() -> String:
	return cache_subdir

## Get the JSONL filename for this service
## Default returns cache_filename property
func _get_cache_filename() -> String:
	return cache_filename

## Get cache key from a payload dictionary
## Default implementation uses 'hash' field
func _get_cache_key(payload: Dictionary) -> String:
	return payload.get("hash", "")

## Get cache key from loaded data dictionary
## Default implementation checks paragraph_hash, text_hash, or hash
func _get_cache_key_from_data(data: Dictionary) -> String:
	if data.has("paragraph_hash"):
		return data["paragraph_hash"]
	elif data.has("text_hash"):
		return data["text_hash"]
	elif data.has("hash"):
		return data["hash"]
	return ""

## Whether to merge data when the same key is encountered
## Default returns should_merge_on_duplicate property
func _should_merge_on_duplicate() -> bool:
	return should_merge_on_duplicate

## Analyze/process a single item and return cache data
## Subclasses MUST implement this
func _analyze(_payload: Dictionary) -> Dictionary:
	return {}

## Get the cache directory for a file path
## If cache location is "global", uses user data folder with project hash; otherwise uses project folder
func _get_cache_dir_for_file(file_path: String) -> String:
	var cache_location := AppConfig.get_cache_location()
	if cache_location == "global":
		return _get_global_cache_dir_for_path(file_path)
	else:
		return file_path.get_base_dir().path_join(".snorfeld").path_join(_get_cache_subdir())

## Get the global cache directory for a given file path (user data folder with project hash)
func _get_global_cache_dir_for_path(file_path: String) -> String:
	var project_path := file_path.get_base_dir()
	var project_hash := HashingUtils.hash_md5(project_path)
	return "user://.snorfeld/global_cache/%s" % project_hash.path_join(_get_cache_subdir())

## Called when a task is about to be processed - allows custom preprocessing
func _will_process_task(_task: Dictionary) -> void:
	pass

## Encode field values before saving to JSONL
## Override to customize encoding for specific fields
func _encode_field(key: String, value: Variant) -> Variant:
	if field_encoders.has(key):
		return field_encoders[key].call(value)
	return value

## Decode field values after loading from JSONL
## Override to customize decoding for specific fields
func _decode_field(key: String, value: Variant) -> Variant:
	if field_decoders.has(key):
		return field_decoders[key].call(value)
	return value

## Merge existing data with new data when the same key is encountered
## Only called if _should_merge_on_duplicate() returns true
func _merge_data(existing: Dictionary, new: Dictionary) -> Dictionary:
	# Use merge strategies if configured
	if merge_strategies.size() > 0:
		return MergeUtils.merge_data_with_strategies(existing, new, merge_strategies)
	# Default: new data replaces old
	return new

## Clean up cache entries that don't have corresponding source files
## Override for custom cleanup logic
func _cleanup_unused_cache_entries(_cache_path: String, _project_path: String) -> int:
	# Default implementation: remove entries not in BookService
	# Override in subclasses for custom cleanup logic
	return 0

## ============================================================================
## Signal Emission
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
## payload: Dictionary containing task data
## priority: If true, insert at front of queue
func queue_task(payload: Dictionary, priority: bool = false) -> void:
	queue_mutex.lock()
	var key := _get_cache_key(payload)

	# Don't re-queue if already in queue or cached
	if queued_keys.has(key):
		queue_mutex.unlock()
		return

	# Check if already in memory cache
	if memory_cache.has(key) and not _should_merge_on_duplicate():
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
## Cache Loading and Persistence (JSONL)
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
		# Decode any encoded fields
		var decoded_data: Dictionary = _decode_data(data)
		var key := _get_cache_key_from_data(decoded_data)
		if key != "":
			memory_cache[key] = decoded_data

## Decode all encoded fields in a data dictionary
func _decode_data(data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate()
	for key in data:
		if field_decoders.has(key):
			result[key] = _decode_field(key, data[key])
	return result

## Encode all encodable fields in a data dictionary
func _encode_data(data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate()
	for key in data:
		if field_encoders.has(key):
			result[key] = _encode_field(key, data[key])
	return result

## Save data to JSONL file
func _save_to_jsonl(cache_dir: String, data: Dictionary) -> void:
	if not FileUtils.dir_exists(cache_dir):
		_create_cache_directory(cache_dir)

	var jsonl_path: String = cache_dir.path_join(_get_cache_filename())
	var encoded_data: Dictionary = _encode_data(data)

	var file: FileAccess = FileAccess.open(jsonl_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_string(JsonUtils.stringify_json(encoded_data) + "\n")
		file.close()
	else:
		FileUtils.write_file(jsonl_path, JsonUtils.stringify_json(encoded_data) + "\n")

## Rewrite entire JSONL file from memory cache
func _rewrite_jsonl_file(cache_dir: String) -> void:
	var jsonl_path: String = cache_dir.path_join(_get_cache_filename())
	var content := ""
	for key in memory_cache:
		var data: Dictionary = memory_cache[key]
		var encoded_data: Dictionary = _encode_data(data)
		content += JsonUtils.stringify_json(encoded_data) + "\n"
	FileUtils.write_file(jsonl_path, content)

## ============================================================================
## Task Processing
## ============================================================================

## Start processing tasks from the queue
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
			# Call will_process_task for custom preprocessing
			_will_process_task(task)

			# Await the task processing (it may be async with HTTP requests)
			await _process_task(task)
			_emit_task_completed(task_queue.size())

	processing = false
	_emit_queue_updated()

## Process a single task - main implementation
# gdlint:ignore-function:long-function
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
		if queued_keys.has(key):
			queued_keys.erase(key)
		return

	# Ensure cache is loaded
	_ensure_cache_loaded(cache_dir)

	# Check if already cached
	var task_key := _get_cache_key(task)

	if memory_cache.has(task_key):
		if _should_merge_on_duplicate():
			# Merge existing with new analysis
			@warning_ignore("redundant_await")
			var analysis_result := await _analyze(task)
			if analysis_result != null and not analysis_result.is_empty():
				var merged: Dictionary = _merge_data(memory_cache[task_key], analysis_result)
				memory_cache[task_key] = merged
				_save_to_jsonl(cache_dir, merged)
			queued_keys.erase(task_key)
			return
		else:
			# Already cached, skip
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

## Create cache directory
func _create_cache_directory(base_path: String) -> bool:
	if not DirAccess.dir_exists_absolute(base_path):
		var err := DirAccess.make_dir_recursive_absolute(base_path)
		return err == OK
	return true

## Check if file exists
func _file_exists(path: String) -> bool:
	return FileUtils.file_exists(path)

## Clear all caches (call on project unload)
func clear_all_caches() -> void:
	memory_cache.clear()
	queued_keys.clear()
	loaded_cache_dirs.clear()

## Delete the cache file for this analysis service
func delete_cache() -> void:
	var cache_dir: String
	var cache_location := AppConfig.get_cache_location()
	if cache_location == "global":
		var project_path: String = BookService.loaded_project_path
		var project_hash := HashingUtils.hash_md5(project_path)
		cache_dir = "user://global_cache/%s" % project_hash.path_join(_get_cache_subdir())
	else:
		var project_path: String = BookService.loaded_project_path
		cache_dir = project_path.path_join(".snorfeld").path_join(_get_cache_subdir())
	var jsonl_path: String = cache_dir.path_join(_get_cache_filename())

	# Clear memory cache
	memory_cache.clear()
	queued_keys.clear()
	loaded_cache_dirs.erase(cache_dir)

	# Delete the JSONL file
	FileUtils.remove_file(jsonl_path)

## Get cache statistics
func get_stats() -> Dictionary:
	return {
		"service_name": _get_service_name(),
		"cached_count": memory_cache.size(),
		"queued_count": queued_keys.size(),
		"loaded_dirs_count": loaded_cache_dirs.size()
	}

## ============================================================================
## Signal Handlers - Default implementations
## Override in subclasses for custom behavior
## ============================================================================

func _ready() -> void:
	# Connect common signals
	CommandBus.priority_analysis.connect(_on_priority_analysis_requested)
	CommandBus.delete_analysis_cache.connect(_on_delete_analysis_cache)
	EventBus.project_loaded.connect(_on_project_loaded)
	EventBus.project_unloaded.connect(_on_project_unloaded)

func _on_priority_analysis_requested(service_type: String, _file_path: String, payload: Dictionary) -> void:
	if service_type != _get_service_name():
		return
	# Default: queue with priority
	queue_task(payload, true)

func _on_delete_analysis_cache(analysis_type: String) -> void:
	if analysis_type != _get_service_name().to_upper():
		return
	delete_cache()

func _on_start_analysis(service_type: String, _scope: String) -> void:
	if service_type != _get_service_name().to_upper():
		return
	# Default: do nothing - override in subclasses
	pass

func _on_folder_opened(path: String) -> void:
	var cache_dir: String
	var cache_location := AppConfig.get_cache_location()
	if cache_location == "global":
		var project_hash := HashingUtils.hash_md5(path)
		cache_dir = "user://.snorfeld/global_cache/%s" % project_hash.path_join(_get_cache_subdir())
	else:
		cache_dir = path.path_join(".snorfeld").path_join(_get_cache_subdir())
	if FileUtils.dir_exists(cache_dir):
		_ensure_cache_loaded(cache_dir)
		EventBus.analysis_cleanup_started.emit(_get_service_name())
		var removed_count: int = _cleanup_unused_cache_entries(cache_dir, path)
		EventBus.analysis_cleanup_completed.emit(_get_service_name(), removed_count)

func _on_file_selected(path: String) -> void:
	current_file_path = path
	current_file_content = FileUtils.read_file(path)

func _on_project_loaded(path: String) -> void:
	var cache_dir: String
	var cache_location := AppConfig.get_cache_location()
	if cache_location == "global":
		var project_hash := HashingUtils.hash_md5(path)
		cache_dir = "user://.snorfeld/global_cache/%s" % project_hash.path_join(_get_cache_subdir())
	else:
		cache_dir = path.path_join(".snorfeld").path_join(_get_cache_subdir())
	_ensure_cache_loaded(cache_dir)

func _on_project_unloaded() -> void:
	clear_all_caches()
